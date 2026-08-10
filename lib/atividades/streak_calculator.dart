import 'package:routine/atividades/activity_exception.dart';
import 'package:routine/atividades/atividade.dart';

/// Sequência de hábito calculada para uma atividade recorrente.
class HabitStreak {
  const HabitStreak({
    required this.current,
    required this.best,
    required this.lastCompletedDate,
  });

  /// Dias/ocorrências consecutivas concluídas até agora.
  final int current;

  /// Maior sequência já alcançada (pode ser igual a [current]).
  final int best;

  /// Data da ocorrência concluída mais recente, ou `null` se nenhuma.
  final DateTime? lastCompletedDate;

  static const zero = HabitStreak(current: 0, best: 0, lastCompletedDate: null);
}

/// Calcula [HabitStreak] a partir de uma atividade recorrente e suas
/// exceções (`activity_exception`) — dado que já existe hoje, sem precisar
/// de tabela nova. Puro Dart, sem dependência de Flutter/DB — testável
/// isoladamente.
class StreakCalculator {
  const StreakCalculator();

  /// [exceptions] deve conter todas as exceções da atividade (não só de um
  /// dia). [today] é injetável pra teste; default `DateTime.now()`.
  /// [lookbackDays] limita até onde no passado a sequência é procurada,
  /// pra não escanear indefinidamente hábitos muito antigos.
  HabitStreak compute({
    required Atividade atividade,
    required List<ActivityException> exceptions,
    DateTime? today,
    int lookbackDays = 730,
  }) {
    if (!atividade.repetirSemanalmente || atividade.diasDaSemana.isEmpty) {
      return HabitStreak.zero;
    }

    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final startDate =
        DateTime(atividade.data.year, atividade.data.month, atividade.data.day);
    final earliestFloor = DateTime(
      todayDate.year,
      todayDate.month,
      todayDate.day - lookbackDays,
    );
    final floor = startDate.isAfter(earliestFloor) ? startDate : earliestFloor;

    final excludedDays = <DateTime>{};
    final statusByDay = <DateTime, String>{};
    for (final exception in exceptions) {
      final day =
          DateTime(exception.data.year, exception.data.month, exception.data.day);
      if (exception.tipo == ActivityException.excluida) {
        excludedDays.add(day);
      } else if (exception.tipo == ActivityException.editada) {
        final status = exception.statusOverride;
        if (status != null) {
          statusByDay[day] = AtividadeStatus.normalize(status);
        }
      }
    }

    DateTime occurrenceEndOn(DateTime day) => DateTime(
          day.year,
          day.month,
          day.day,
          atividade.horaFim.hour,
          atividade.horaFim.minute,
        );

    // Ocorrências relevantes, da mais recente pra mais antiga.
    final relevantDays = <DateTime>[];
    for (var day = todayDate;
        !day.isBefore(floor);
        day = DateTime(day.year, day.month, day.day - 1)) {
      if (!atividade.diasDaSemana.contains(day.weekday)) continue;
      if (excludedDays.contains(day)) continue;

      if (day == todayDate) {
        final completedToday = statusByDay[day] == AtividadeStatus.concluida;
        if (!completedToday && now.isBefore(occurrenceEndOn(day))) {
          continue; // ocorrência de hoje ainda não terminou -- não conta ainda
        }
      }

      relevantDays.add(day);
    }

    var current = 0;
    var best = 0;
    var run = 0;
    var stillCounting = true;
    DateTime? lastCompletedDate;

    for (final day in relevantDays) {
      final completed = statusByDay[day] == AtividadeStatus.concluida;
      if (completed) {
        run++;
        lastCompletedDate ??= day;
        if (stillCounting) current = run;
        if (run > best) best = run;
      } else {
        stillCounting = false;
        run = 0;
      }
    }

    return HabitStreak(
      current: current,
      best: best,
      lastCompletedDate: lastCompletedDate,
    );
  }
}

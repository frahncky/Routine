import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/atividades/activity_exception.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/streak_calculator.dart';

void main() {
  const calculator = StreakCalculator();
  final today = DateTime(2026, 1, 15);

  Atividade makeAtividade({
    required DateTime data,
    List<int> diasDaSemana = const [1, 2, 3, 4, 5, 6, 7],
    bool repetirSemanalmente = true,
  }) {
    return Atividade(
      id: 1,
      titulo: 'Academia',
      descricao: '',
      data: data,
      horaInicio: const TimeOfDay(hour: 9, minute: 0),
      horaFim: const TimeOfDay(hour: 10, minute: 0),
      status: AtividadeStatus.pendente,
      participantes: const [],
      repetirSemanalmente: repetirSemanalmente,
      diasDaSemana: diasDaSemana,
    );
  }

  int idCounter = 0;
  ActivityException completedOn(DateTime day) {
    return ActivityException(
      id: idCounter++,
      atividadeId: 1,
      data: day,
      tipo: ActivityException.editada,
      camposEditados: {'status': AtividadeStatus.concluida},
    );
  }

  ActivityException excludedOn(DateTime day) {
    return ActivityException(
      id: idCounter++,
      atividadeId: 1,
      data: day,
      tipo: ActivityException.excluida,
      camposEditados: null,
    );
  }

  DateTime daysBefore(int n) => DateTime(today.year, today.month, today.day - n);

  test('non-recurring activity has no streak', () {
    final atividade = makeAtividade(
      data: today.subtract(const Duration(days: 10)),
      repetirSemanalmente: false,
    );
    final result = calculator.compute(
      atividade: atividade,
      exceptions: [completedOn(today)],
      today: today,
    );
    expect(result.current, 0);
    expect(result.best, 0);
    expect(result.lastCompletedDate, isNull);
  });

  test('no completions at all yields zero streak', () {
    final atividade = makeAtividade(data: today.subtract(const Duration(days: 30)));
    final result = calculator.compute(
      atividade: atividade,
      exceptions: const [],
      today: DateTime(today.year, today.month, today.day, 23, 0),
    );
    expect(result.current, 0);
    expect(result.best, 0);
    expect(result.lastCompletedDate, isNull);
  });

  test('simple consecutive streak counts current and best equally', () {
    final atividade = makeAtividade(data: today.subtract(const Duration(days: 60)));
    final exceptions = [
      for (var i = 0; i < 5; i++) completedOn(daysBefore(i)),
    ];
    final result = calculator.compute(
      atividade: atividade,
      exceptions: exceptions,
      today: today,
    );
    expect(result.current, 5);
    expect(result.best, 5);
    expect(result.lastCompletedDate, today);
  });

  test('missed day breaks current streak but best keeps the longer run', () {
    final atividade = makeAtividade(data: today.subtract(const Duration(days: 60)));
    final exceptions = [
      // Sequencia atual: hoje, ontem, anteontem (3 dias).
      completedOn(daysBefore(0)),
      completedOn(daysBefore(1)),
      completedOn(daysBefore(2)),
      // daysBefore(3) sem excecao -> nao concluido -> quebra.
      // Sequencia mais antiga e maior: 4 dias seguidos.
      completedOn(daysBefore(4)),
      completedOn(daysBefore(5)),
      completedOn(daysBefore(6)),
      completedOn(daysBefore(7)),
    ];
    final result = calculator.compute(
      atividade: atividade,
      exceptions: exceptions,
      today: today,
    );
    expect(result.current, 3);
    expect(result.best, 4);
  });

  test('excluded day does not break the streak nor count towards it', () {
    final atividade = makeAtividade(data: today.subtract(const Duration(days: 60)));
    final exceptions = [
      completedOn(daysBefore(0)),
      completedOn(daysBefore(1)),
      excludedOn(daysBefore(2)),
      completedOn(daysBefore(3)),
    ];
    final result = calculator.compute(
      atividade: atividade,
      exceptions: exceptions,
      today: today,
    );
    expect(result.current, 3);
    expect(result.best, 3);
  });

  test('today not yet finished and not completed is ignored, not a break', () {
    final atividade = makeAtividade(data: today.subtract(const Duration(days: 60)));
    final exceptions = [
      completedOn(daysBefore(1)),
      completedOn(daysBefore(2)),
    ];
    // "Agora" as 8h, atividade termina as 10h -- ocorrencia de hoje ainda
    // nao passou do horario.
    final result = calculator.compute(
      atividade: atividade,
      exceptions: exceptions,
      today: DateTime(today.year, today.month, today.day, 8, 0),
    );
    expect(result.current, 2);
    expect(result.best, 2);
  });

  test('today already finished and not completed breaks the streak', () {
    final atividade = makeAtividade(data: today.subtract(const Duration(days: 60)));
    final exceptions = [
      completedOn(daysBefore(1)),
      completedOn(daysBefore(2)),
    ];
    // "Agora" as 11h, ja passou do horario de fim (10h) e hoje nao foi
    // marcada concluida.
    final result = calculator.compute(
      atividade: atividade,
      exceptions: exceptions,
      today: DateTime(today.year, today.month, today.day, 11, 0),
    );
    expect(result.current, 0);
    expect(result.best, 2);
  });

  test('lookbackDays limits how far back best streak is searched', () {
    final atividade = makeAtividade(data: today.subtract(const Duration(days: 800)));
    final exceptions = [
      // Sequencia enorme, mas totalmente fora da janela de 30 dias.
      for (var i = 745; i <= 750; i++) completedOn(daysBefore(i)),
      // Dentro da janela.
      completedOn(daysBefore(0)),
    ];
    final result = calculator.compute(
      atividade: atividade,
      exceptions: exceptions,
      today: today,
      lookbackDays: 30,
    );
    expect(result.current, 1);
    expect(result.best, 1);
  });

  test('respects diasDaSemana -- only expected weekdays count', () {
    // today.weekday determina quais dias sao "esperados"; escolhe so o
    // weekday de hoje como dia esperado, entao dias adjacentes nao contam
    // nem quebram.
    final atividade = makeAtividade(
      data: today.subtract(const Duration(days: 60)),
      diasDaSemana: [today.weekday],
    );
    final exceptions = [
      completedOn(daysBefore(0)),
      completedOn(daysBefore(7)),
      completedOn(daysBefore(14)),
    ];
    final result = calculator.compute(
      atividade: atividade,
      exceptions: exceptions,
      today: today,
    );
    expect(result.current, 3);
    expect(result.best, 3);
  });
}

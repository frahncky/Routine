import 'package:routine/atividades/activity_exception.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/streak_calculator.dart';
import 'package:routine/helper/database_helper.dart';

class StreakRepository {
  StreakRepository({DB? db, StreakCalculator? calculator})
      : _db = db ?? DB.instance,
        _calculator = calculator ?? const StreakCalculator();

  final DB _db;
  final StreakCalculator _calculator;

  Future<HabitStreak> streakForActivity(Atividade atividade) async {
    if (!atividade.repetirSemanalmente) return HabitStreak.zero;
    final rows = await _db.getActivityExceptionsForActivity(atividade.id);
    final exceptions = rows.map(ActivityException.fromMap).toList();
    return _calculator.compute(atividade: atividade, exceptions: exceptions);
  }
}

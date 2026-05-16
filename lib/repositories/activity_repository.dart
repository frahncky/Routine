import 'package:routine/atividades/atividade.dart';
import 'package:routine/helper/database_helper.dart';

class ActivityRepository {
  ActivityRepository({DB? db}) : _db = db ?? DB.instance;

  final DB _db;

  Future<int> insert(Atividade atividade) {
    return _db.insertActivity(atividade);
  }

  Future<void> update(Atividade atividade) {
    return _db.updateActivity(atividade);
  }

  Future<bool> delete(int id) {
    return _db.deleteActivity(id);
  }

  Future<Map<String, dynamic>?> getById(int id) {
    return _db.getActivityById(id);
  }

  Future<List<Map<String, dynamic>>> getForDateIncludingRecurring({
    required DateTime date,
    required List<String> status,
  }) {
    return _db.getActivitiesForDateIncludingRecurring(
      date: date,
      status: status,
    );
  }

  Future<List<Map<String, dynamic>>> getByStatus({
    required List<String> status,
  }) {
    return _db.getActivitiesByStatus(status: status);
  }

  Future<List<Map<String, dynamic>>> getAll({
    required int year,
    required int month,
    required int day,
    required List<String> status,
  }) {
    return _db.getAllActivities(
      year: year,
      month: month,
      day: day,
      status: status,
    );
  }

  Future<List<String>> getAllYears() {
    return _db.getAllActivityYears();
  }
}

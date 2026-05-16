import 'package:routine/helper/database_helper.dart';

class SettingsRepository {
  SettingsRepository({DB? db}) : _db = db ?? DB.instance;

  final DB _db;

  Future<String?> get(String key) {
    return _db.getConfig(key);
  }

  Future<void> set(String key, String value) {
    return _db.setConfig(key, value);
  }
}

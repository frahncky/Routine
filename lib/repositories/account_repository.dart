import 'package:routine/helper/database_helper.dart';

class AccountRepository {
  AccountRepository({DB? db}) : _db = db ?? DB.instance;

  final DB _db;

  Future<Map<String, dynamic>?> getUser() {
    return _db.getUser();
  }

  Future<String?> getEmail() {
    return _db.getEmailFromDB();
  }

  Future<void> createAccount(
    String name,
    String email,
    String avatarUrl,
    String authProvider,
  ) {
    return _db.createAccount(name, email, avatarUrl, authProvider);
  }

  Future<void> updateAccount({
    required String email,
    String? name,
    String? avatarUrl,
    String? typeAccount,
  }) {
    return _db.updateAccount(
      email: email,
      name: name,
      avatarUrl: avatarUrl,
      typeAccount: typeAccount,
    );
  }

  Future<void> deleteAccount() {
    return _db.deleteAccount();
  }

  Future<void> clearLocalData() {
    return _db.clearLocalData();
  }

  Future<Map<String, int>> getDowngradeImpactSummary() {
    return _db.getDowngradeImpactSummary();
  }
}

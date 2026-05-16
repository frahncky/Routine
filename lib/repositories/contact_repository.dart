import 'package:routine/features/contacts/contact_group.dart';
import 'package:routine/helper/database_helper.dart';

class ContactRepository {
  ContactRepository({DB? db}) : _db = db ?? DB.instance;

  final DB _db;

  Future<bool> insert(String name, String email) {
    return _db.insertContact(name, email);
  }

  Future<bool> update(String name, String email) {
    return _db.updateContact(name, email);
  }

  Future<void> delete(String email) {
    return _db.deleteContact(email);
  }

  Future<List<Map<String, dynamic>>> getAll() {
    return _db.getAllContacts();
  }

  Future<int> createGroup({
    required String name,
    required List<String> memberEmails,
  }) {
    return _db.createContactGroup(name: name, memberEmails: memberEmails);
  }

  Future<bool> updateGroup({
    required int groupId,
    required String name,
    required List<String> memberEmails,
  }) {
    return _db.updateContactGroup(
      groupId: groupId,
      name: name,
      memberEmails: memberEmails,
    );
  }

  Future<void> deleteGroup(int groupId) {
    return _db.deleteContactGroup(groupId);
  }

  Future<List<ContactGroup>> getGroupsWithMembers() {
    return _db.getContactGroupsWithMembers();
  }
}

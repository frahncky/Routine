import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Espelha atividades/contatos/grupos no Firestore para os planos com
/// `PlanRules.hasCloudBackup`, para permitir recuperação em um novo
/// dispositivo. Não é sincronização em tempo real entre dispositivos:
/// exclusões são espelhadas como exclusão real (sem tombstone) e
/// `restoreAll` resolve conflitos por "última escrita vence" comparando
/// `updated_at`.
class BackupService {
  BackupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _activitiesRef(String email) =>
      _firestore.collection('users').doc(email).collection('backup_activities');

  CollectionReference<Map<String, dynamic>> _contactsRef(String email) =>
      _firestore.collection('users').doc(email).collection('backup_contacts');

  CollectionReference<Map<String, dynamic>> _groupsRef(String email) =>
      _firestore
          .collection('users')
          .doc(email)
          .collection('backup_contact_groups');

  Future<void> pushActivity(
    String email,
    Map<String, dynamic> activityRow,
  ) async {
    final uuid = activityRow['uuid']?.toString();
    if (email.isEmpty || uuid == null || uuid.isEmpty) return;
    try {
      final payload = Map<String, dynamic>.from(activityRow)..remove('id');
      await _activitiesRef(email).doc(uuid).set(payload);
    } catch (e) {
      debugPrint('Falha ao enviar backup de atividade: $e');
    }
  }

  Future<void> deleteActivityBackup(String email, String? uuid) async {
    if (email.isEmpty || uuid == null || uuid.isEmpty) return;
    try {
      await _activitiesRef(email).doc(uuid).delete();
    } catch (e) {
      debugPrint('Falha ao remover backup de atividade: $e');
    }
  }

  Future<void> pushContact(
    String email,
    Map<String, dynamic> contactRow,
  ) async {
    final contactEmail =
        contactRow['email']?.toString().trim().toLowerCase() ?? '';
    if (email.isEmpty || contactEmail.isEmpty) return;
    try {
      await _contactsRef(email).doc(contactEmail).set({
        'name': contactRow['name'],
        'email': contactEmail,
        'avatarUrl': contactRow['avatarUrl'],
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Falha ao enviar backup de contato: $e');
    }
  }

  Future<void> deleteContactBackup(String email, String contactEmail) async {
    final normalized = contactEmail.trim().toLowerCase();
    if (email.isEmpty || normalized.isEmpty) return;
    try {
      await _contactsRef(email).doc(normalized).delete();
    } catch (e) {
      debugPrint('Falha ao remover backup de contato: $e');
    }
  }

  Future<void> pushContactGroup(
    String email, {
    required String uuid,
    required String name,
    required List<String> memberEmails,
  }) async {
    if (email.isEmpty || uuid.isEmpty) return;
    try {
      await _groupsRef(email).doc(uuid).set({
        'name': name,
        'memberEmails': memberEmails,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Falha ao enviar backup de grupo de contatos: $e');
    }
  }

  Future<void> deleteContactGroupBackup(String email, String? uuid) async {
    if (email.isEmpty || uuid == null || uuid.isEmpty) return;
    try {
      await _groupsRef(email).doc(uuid).delete();
    } catch (e) {
      debugPrint('Falha ao remover backup de grupo de contatos: $e');
    }
  }

  /// Retorna os documentos de backup crus (cada map inclui `uuid`/`email`
  /// como id do documento) para quem for orquestrar a restauração local.
  Future<List<Map<String, dynamic>>> fetchActivities(String email) async {
    if (email.isEmpty) return const [];
    final snapshot = await _activitiesRef(email).get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'uuid': doc.id})
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchContacts(String email) async {
    if (email.isEmpty) return const [];
    final snapshot = await _contactsRef(email).get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'email': doc.id})
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchContactGroups(String email) async {
    if (email.isEmpty) return const [];
    final snapshot = await _groupsRef(email).get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'uuid': doc.id})
        .toList();
  }
}

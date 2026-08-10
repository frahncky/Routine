import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/backup/backup_service.dart';
import 'package:routine/features/contacts/contact_group.dart';
import 'package:routine/features/contacts/contatos.dart';
import 'package:routine/features/convites/convite_atividade.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DB {
  DB._();
  static final DB instance = DB._();
  static Database? _database;
  static FirebaseFirestore? _firestoreOverride;
  static const Uuid _uuid = Uuid();

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  BackupService get _backupService =>
      BackupService(firestore: _firestoreOverride);

  @visibleForTesting
  static void setFirestoreForTesting(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  // Fecha a conexao cacheada sem apagar o arquivo, para permitir que testes
  // preparem um banco em uma versao antiga e exercitem o _onUpgrade real.
  @visibleForTesting
  static Future<void> closeForTesting() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    return await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'Routine.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_user);
    await db.execute(_activity);
    await db.execute(_contacts);
    await db.execute(_contactGroups);
    await db.execute(_contactGroupMembers);
    await db.execute(_activityException);
    await db.execute(_inviteProcessed);
    await db.execute(_config); // Cria tabela de configurações
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_activityException);
    }
    if (oldVersion < 3) {
      await db.execute(_inviteProcessed);
    }
    if (oldVersion < 4) {
      await db.execute(_contactGroups);
      await db.execute(_contactGroupMembers);
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE activity ADD COLUMN uuid TEXT');
      await db.execute('ALTER TABLE activity ADD COLUMN updated_at INTEGER');
      await db.execute('ALTER TABLE contacts ADD COLUMN updated_at INTEGER');
      await db.execute('ALTER TABLE contact_groups ADD COLUMN uuid TEXT');
      await _backfillUuidsAndTimestamps(db);
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE activity ADD COLUMN reminder_minutes TEXT');
    }
    // Garante que a tabela config exista após upgrade
    await db.execute(_config);
  }

  // Preenche uuid/updated_at das linhas criadas antes da versao 5, para que
  // o backup em nuvem tenha um identificador estavel entre dispositivos.
  Future<void> _backfillUuidsAndTimestamps(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final activities = await db.query('activity',
        columns: ['id'], where: 'uuid IS NULL');
    for (final row in activities) {
      await db.update(
        'activity',
        {'uuid': _uuid.v4(), 'updated_at': now},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    final groups = await db.query('contact_groups',
        columns: ['id'], where: 'uuid IS NULL');
    for (final row in groups) {
      await db.update(
        'contact_groups',
        {'uuid': _uuid.v4()},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    await db.update(
      'contacts',
      {'updated_at': now},
      where: 'updated_at IS NULL',
    );
  }

  String get _user => '''
    CREATE TABLE user(
      name TEXT,
      email TEXT UNIQUE,
      password TEXT,
      avatarUrl TEXT,
      typeAccount TEXT,
      authProvider TEXT
    );
  ''';

  String get _activity => '''
    CREATE TABLE activity(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      describe TEXT,
      date INTEGER,
      initHour TEXT,
      endtHour TEXT,
      participants TEXT,
      status TEXT,
      repetirSemanalmente INTEGER,
      diasDaSemana TEXT,
      uuid TEXT,
      updated_at INTEGER,
      reminder_minutes TEXT
    );
  ''';

  String get _contacts => '''
    CREATE TABLE contacts(
      name TEXT,
      email TEXT UNIQUE,
      avatarUrl TEXT,
      updated_at INTEGER
    );
  ''';

  String get _contactGroups => '''
    CREATE TABLE IF NOT EXISTS contact_groups(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE COLLATE NOCASE,
      created_at INTEGER,
      updated_at INTEGER,
      uuid TEXT
    );
  ''';

  String get _contactGroupMembers => '''
    CREATE TABLE IF NOT EXISTS contact_group_members(
      group_id INTEGER,
      contact_email TEXT,
      PRIMARY KEY(group_id, contact_email)
    );
  ''';

  String get _activityException => '''
    CREATE TABLE activity_exception(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      atividade_id INTEGER,
      data INTEGER,
      tipo TEXT,
      campos_editados TEXT
    );
  ''';

  String get _inviteProcessed => '''
    CREATE TABLE IF NOT EXISTS invite_processed(
      invite_id TEXT PRIMARY KEY,
      activity_id INTEGER,
      processed_at INTEGER
    );
  ''';

  String get _config => '''
    CREATE TABLE IF NOT EXISTS config(
      key TEXT PRIMARY KEY,
      value TEXT
    );
  ''';

  // USUÁRIO

  String _normalizeUserEmail(String email) => email.trim().toLowerCase();

  String _currentFirebaseEmail() {
    try {
      return _normalizeUserEmail(
          FirebaseAuth.instance.currentUser?.email ?? '');
    } catch (_) {
      return '';
    }
  }

  Future<void> createAccount(
    String name,
    String email,
    String avatarUrl,
    String authProvider,
  ) async {
    final db = await database;
    final normalizedEmail = _normalizeUserEmail(email);

    if (normalizedEmail.isNotEmpty) {
      await db.delete(
        'user',
        where: 'LOWER(TRIM(email)) = ?',
        whereArgs: [normalizedEmail],
      );
    }

    await db.insert(
      'user',
      {
        'name': name,
        'email': normalizedEmail,
        'avatarUrl': avatarUrl,
        'typeAccount': PlanRules.gratuito,
        'authProvider': authProvider,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (normalizedEmail.isNotEmpty) {
      try {
        final userRef = _firestore.collection('users');
        await userRef.doc(normalizedEmail).set({
          'name': name,
          'email': normalizedEmail,
          'avatarUrl': avatarUrl,
          'typeAccount': PlanRules.gratuito,
          'authProvider': authProvider,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Falha ao sincronizar createAccount no Firestore: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> getUser() async {
    final db = await database;
    final currentEmail = _currentFirebaseEmail();
    List<Map<String, dynamic>> users = [];

    if (currentEmail.isNotEmpty) {
      users = await db.query(
        'user',
        where: 'LOWER(TRIM(email)) = ?',
        whereArgs: [currentEmail],
        orderBy: 'rowid DESC',
        limit: 1,
      );
    }

    if (users.isEmpty) {
      users = await db.query('user', orderBy: 'rowid DESC', limit: 1);
    }

    if (users.isEmpty) return null;

    final localUser = Map<String, dynamic>.from(users.first);
    if (currentEmail.isNotEmpty) {
      await _refreshLocalPlanFromFirestore(db, localUser, currentEmail);
    }

    final currentPlan = localUser['typeAccount']?.toString();
    final normalizedPlan = PlanRules.normalize(currentPlan);
    if (currentPlan != normalizedPlan) {
      final email = localUser['email']?.toString();
      if (email != null && email.isNotEmpty) {
        await db.update(
          'user',
          {'typeAccount': normalizedPlan},
          where: 'LOWER(TRIM(email)) = ?',
          whereArgs: [_normalizeUserEmail(email)],
        );
      }
      localUser['typeAccount'] = normalizedPlan;
    }

    return localUser;
  }

  Future<void> _refreshLocalPlanFromFirestore(
    Database db,
    Map<String, dynamic> localUser,
    String normalizedEmail,
  ) async {
    try {
      final remoteUser =
          await _firestore.collection('users').doc(normalizedEmail).get();
      final remoteData = remoteUser.data();
      if (remoteData == null || !remoteData.containsKey('typeAccount')) {
        return;
      }

      final remotePlan =
          PlanRules.normalize(remoteData['typeAccount']?.toString());
      final previousPlan =
          PlanRules.normalize(localUser['typeAccount']?.toString());
      if (remotePlan == previousPlan) return;

      await db.update(
        'user',
        {'typeAccount': remotePlan},
        where: 'LOWER(TRIM(email)) = ?',
        whereArgs: [normalizedEmail],
      );
      localUser['typeAccount'] = remotePlan;

      // Plano mudou por fora do app (ex.: Cloud Function liberou o plano
      // apos validar a compra, ou a assinatura expirou/foi cancelada) —
      // aplica os mesmos efeitos que uma mudanca local dispararia (backup
      // completo ao ganhar acesso, limpeza de dados colaborativos ao
      // perder).
      await _applyPlanTransitionEffects(
        previousPlan: previousPlan,
        newPlan: remotePlan,
      );
    } catch (e) {
      debugPrint('Falha ao sincronizar plano remoto: $e');
    }
  }

  Future<void> updateAccount({
    required String email,
    String? name,
    String? avatarUrl,
    String? typeAccount,
  }) async {
    final db = await database;
    final normalizedEmail = _normalizeUserEmail(email);
    final previousPlan = await _getCurrentNormalizedPlan();
    final updateFields = <String, dynamic>{};
    if (name != null) updateFields['name'] = name;
    if (avatarUrl != null) updateFields['avatarUrl'] = avatarUrl;
    if (typeAccount != null) {
      updateFields['typeAccount'] = PlanRules.normalize(typeAccount);
    }
    if (updateFields.isEmpty) return;
    var updatedRows = await db.update(
      'user',
      updateFields,
      where: 'LOWER(TRIM(email)) = ?',
      whereArgs: [normalizedEmail],
    );

    if (updatedRows == 0 && normalizedEmail.isNotEmpty) {
      updatedRows = await db.update(
        'user',
        updateFields,
        where: 'email = ?',
        whereArgs: [normalizedEmail],
      );
    }

    if (updatedRows == 0) {
      await db.update(
        'user',
        updateFields,
        where: 'rowid = (SELECT rowid FROM user ORDER BY rowid DESC LIMIT 1)',
      );
    }

    try {
      final userRef = _firestore.collection('users');
      final payload = Map<String, dynamic>.from(updateFields)
        ..['updated_at'] = FieldValue.serverTimestamp();
      await userRef.doc(normalizedEmail).set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Falha ao sincronizar updateAccount no Firestore: $e');
    }

    if (typeAccount != null) {
      await _applyPlanTransitionEffects(
        previousPlan: previousPlan,
        newPlan: updateFields['typeAccount'].toString(),
      );
    }
  }

  Future<void> deleteAccount() async {
    final email = await getEmailFromDB();
    if (email != null && email.isNotEmpty) {
      await _firestore.collection('users').doc(email).delete();
    }
    await clearLocalData();
  }

  Future<void> clearLocalData() async {
    await resetDatabase();
  }

  Future<void> resetDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'Routine.db');
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    await deleteDatabase(dbPath);
    await DB.instance.database;
  }

  Future<String?> getEmailFromDB() async {
    final user = await getUser();
    final email = user?['email']?.toString().trim();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  Future<String> _getCurrentNormalizedPlan() async {
    final user = await getUser();
    return PlanRules.normalize(user?['typeAccount']?.toString());
  }

  Future<bool> _canUseCollaborativeFeatures() async {
    final plan = await _getCurrentNormalizedPlan();
    return PlanRules.hasFullAccess(plan);
  }

  Future<bool> _canUseCloudBackup() async {
    final plan = await _getCurrentNormalizedPlan();
    return PlanRules.hasCloudBackup(plan);
  }

  Future<int> countActivities() async {
    final db = await database;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM activity'),
        ) ??
        0;
  }

  Future<bool> hasAnyActivities() async {
    return (await countActivities()) > 0;
  }

  // BACKUP EM NUVEM

  Future<void> _pushActivityBackupIfEligible(
    Map<String, dynamic> activityRow,
  ) async {
    if (!await _canUseCloudBackup()) return;
    final email = await getEmailFromDB();
    if (email == null) return;
    await _backupService.pushActivity(email, activityRow);
  }

  Future<void> _deleteActivityBackupIfEligible(String? uuid) async {
    if (uuid == null || uuid.isEmpty) return;
    if (!await _canUseCloudBackup()) return;
    final email = await getEmailFromDB();
    if (email == null) return;
    await _backupService.deleteActivityBackup(email, uuid);
  }

  // Exceções (status por ocorrência de atividade recorrente, incluindo o
  // que alimenta a sequência/streak de hábito) precisam do uuid da
  // atividade dona, não do atividade_id local — resolve via getActivityById.
  Future<void> _pushActivityExceptionBackupIfEligible({
    required int atividadeId,
    required DateTime data,
    required String tipo,
    Map<String, dynamic>? camposEditados,
  }) async {
    if (!await _canUseCloudBackup()) return;
    final email = await getEmailFromDB();
    if (email == null) return;
    final activity = await getActivityById(atividadeId);
    final activityUuid = activity?['uuid']?.toString();
    if (activityUuid == null || activityUuid.isEmpty) return;
    await _backupService.pushActivityException(
      email,
      activityUuid: activityUuid,
      data: data,
      tipo: tipo,
      camposEditados: camposEditados,
    );
  }

  // Contatos/grupos so sao alcancaveis por quem ja passou por
  // _canUseCollaborativeFeatures(), que implica hasCloudBackup — nao
  // precisa de checagem extra aqui.
  Future<void> _pushContactBackup(Map<String, dynamic> contactRow) async {
    final email = await getEmailFromDB();
    if (email == null) return;
    await _backupService.pushContact(email, contactRow);
  }

  Future<void> _deleteContactBackup(String contactEmail) async {
    final email = await getEmailFromDB();
    if (email == null) return;
    await _backupService.deleteContactBackup(email, contactEmail);
  }

  Future<void> _pushContactGroupBackup({
    required String uuid,
    required String name,
    required List<String> memberEmails,
  }) async {
    final email = await getEmailFromDB();
    if (email == null) return;
    await _backupService.pushContactGroup(
      email,
      uuid: uuid,
      name: name,
      memberEmails: memberEmails,
    );
  }

  Future<void> _deleteContactGroupBackup(String? uuid) async {
    if (uuid == null || uuid.isEmpty) return;
    final email = await getEmailFromDB();
    if (email == null) return;
    await _backupService.deleteContactGroupBackup(email, uuid);
  }

  // Envia um snapshot completo dos dados locais para o Firestore. Disparado
  // ao ganhar hasCloudBackup e tambem exposto para o botao manual
  // "Fazer backup agora".
  Future<void> backupAllToCloud() async {
    if (!await _canUseCloudBackup()) return;
    final email = await getEmailFromDB();
    if (email == null) return;
    final db = await database;

    final activities = await db.query('activity');
    for (final activity in activities) {
      await _backupService.pushActivity(email, activity);
    }

    final exceptions = await db.query('activity_exception');
    for (final exception in exceptions) {
      final atividadeId = exception['atividade_id'] as int?;
      final dataMillis = exception['data'] as int?;
      final tipo = exception['tipo']?.toString();
      if (atividadeId == null || dataMillis == null || tipo == null) continue;
      final activityRow = await db.query('activity',
          columns: ['uuid'], where: 'id = ?', whereArgs: [atividadeId], limit: 1);
      final activityUuid =
          activityRow.isNotEmpty ? activityRow.first['uuid']?.toString() : null;
      if (activityUuid == null || activityUuid.isEmpty) continue;
      await _backupService.pushActivityException(
        email,
        activityUuid: activityUuid,
        data: DateTime.fromMillisecondsSinceEpoch(dataMillis),
        tipo: tipo,
        camposEditados: _decodeCamposEditados(exception['campos_editados']),
      );
    }

    if (await _canUseCollaborativeFeatures()) {
      final contacts = await db.query('contacts');
      for (final contact in contacts) {
        await _backupService.pushContact(email, contact);
      }

      final groups = await getContactGroupsWithMembers();
      for (final group in groups) {
        final groupRow = await db.query('contact_groups',
            columns: ['uuid'], where: 'id = ?', whereArgs: [group.id]);
        final uuid =
            groupRow.isNotEmpty ? groupRow.first['uuid']?.toString() : null;
        if (uuid == null || uuid.isEmpty) continue;
        await _backupService.pushContactGroup(
          email,
          uuid: uuid,
          name: group.name,
          memberEmails: group.members.map((c) => c.email).toList(),
        );
      }
    }

    await setConfig('last_backup_at', DateTime.now().millisecondsSinceEpoch.toString());
  }

  // Busca o backup na nuvem e faz upsert local: atividades por uuid,
  // contatos por email, grupos por uuid — se ja existir localmente, so
  // sobrescreve quando o registro remoto for mais novo (updated_at).
  Future<int> restoreCloudBackup() async {
    final plan = await _getCurrentNormalizedPlan();
    if (!PlanRules.hasCloudBackup(plan)) return 0;
    final email = await getEmailFromDB();
    if (email == null) return 0;
    final db = await database;
    var restoredCount = 0;

    final remoteActivities = await _backupService.fetchActivities(email);
    for (final remote in remoteActivities) {
      final uuid = remote['uuid']?.toString();
      if (uuid == null || uuid.isEmpty) continue;
      final local = await db.query('activity',
          where: 'uuid = ?', whereArgs: [uuid], limit: 1);
      final remoteUpdatedAt = _asMillis(remote['updated_at']);

      final payload = Map<String, dynamic>.from(remote);
      if (local.isEmpty) {
        await db.insert('activity', payload,
            conflictAlgorithm: ConflictAlgorithm.replace);
        restoredCount++;
      } else {
        final localUpdatedAt = _asMillis(local.first['updated_at']);
        if (remoteUpdatedAt > localUpdatedAt) {
          payload['id'] = local.first['id'];
          await db.update('activity', payload,
              where: 'id = ?', whereArgs: [local.first['id']]);
          restoredCount++;
        }
      }
    }

    final remoteExceptions = await _backupService.fetchActivityExceptions(email);
    for (final remote in remoteExceptions) {
      final activityUuid = remote['activity_uuid']?.toString();
      final tipo = remote['tipo']?.toString();
      final dataInt = remote['data'] is int
          ? remote['data'] as int
          : int.tryParse(remote['data']?.toString() ?? '');
      if (activityUuid == null ||
          activityUuid.isEmpty ||
          tipo == null ||
          dataInt == null) {
        continue;
      }

      final activityRow = await db.query('activity',
          columns: ['id'], where: 'uuid = ?', whereArgs: [activityUuid], limit: 1);
      if (activityRow.isEmpty) continue;
      final atividadeId = activityRow.first['id'] as int;

      final data = DateTime.fromMillisecondsSinceEpoch(dataInt);
      final start =
          DateTime(data.year, data.month, data.day, 0, 0).millisecondsSinceEpoch;
      final end = DateTime(data.year, data.month, data.day, 23, 59, 59, 999)
          .millisecondsSinceEpoch;
      final existing = await db.query(
        'activity_exception',
        where: 'atividade_id = ? AND tipo = ? AND data BETWEEN ? AND ?',
        whereArgs: [atividadeId, tipo, start, end],
        limit: 1,
      );
      // Exceções não têm updated_at local pra comparar (LWW) — se já existe
      // algo pra esse dia+tipo, o dispositivo local venceu; só preenche o
      // que faltava (caso comum: reinstalação com banco local vazio).
      if (existing.isNotEmpty) continue;

      final camposEditados = _decodeCamposEditados(remote['campos_editados']);
      await db.insert('activity_exception', {
        'atividade_id': atividadeId,
        'data': dataInt,
        'tipo': tipo,
        'campos_editados':
            camposEditados != null ? jsonEncode(camposEditados) : null,
      });
      restoredCount++;
    }

    if (await _canUseCollaborativeFeatures()) {
      final remoteContacts = await _backupService.fetchContacts(email);
      for (final contact in remoteContacts) {
        final contactEmail = contact['email']?.toString();
        if (contactEmail == null || contactEmail.isEmpty) continue;
        final local = await db.query('contacts',
            where: 'LOWER(TRIM(email)) = ?',
            whereArgs: [_normalizeEmail(contactEmail)],
            limit: 1);
        if (local.isEmpty ||
            _asMillis(contact['updated_at']) >
                _asMillis(local.first['updated_at'])) {
          await db.insert('contacts', contact,
              conflictAlgorithm: ConflictAlgorithm.replace);
          restoredCount++;
        }
      }

      final remoteGroups = await _backupService.fetchContactGroups(email);
      for (final group in remoteGroups) {
        final uuid = group['uuid']?.toString();
        if (uuid == null || uuid.isEmpty) continue;
        final existing = await db.query('contact_groups',
            where: 'uuid = ?', whereArgs: [uuid], limit: 1);
        final remoteUpdatedAt = _asMillis(group['updated_at']);
        int groupId;
        if (existing.isEmpty) {
          groupId = await db.insert('contact_groups', {
            'name': group['name'],
            'created_at': remoteUpdatedAt,
            'updated_at': remoteUpdatedAt,
            'uuid': uuid,
          });
        } else {
          final localUpdatedAt = _asMillis(existing.first['updated_at']);
          if (remoteUpdatedAt <= localUpdatedAt) continue;
          groupId = existing.first['id'] as int;
          await db.update(
            'contact_groups',
            {'name': group['name'], 'updated_at': remoteUpdatedAt},
            where: 'id = ?',
            whereArgs: [groupId],
          );
        }
        await db.delete('contact_group_members',
            where: 'group_id = ?', whereArgs: [groupId]);
        final memberEmails = (group['memberEmails'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        for (final memberEmail in memberEmails) {
          await db.insert(
            'contact_group_members',
            {'group_id': groupId, 'contact_email': memberEmail},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        restoredCount++;
      }
    }

    return restoredCount;
  }

  int _asMillis(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic>? _decodeCamposEditados(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final text = raw.toString();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<Map<String, int>> getDowngradeImpactSummary() async {
    final db = await database;
    final contactsCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM contacts'),
        ) ??
        0;
    final activitiesWithParticipants = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM activity WHERE participants IS NOT NULL AND participants != '' AND participants != '[]'",
          ),
        ) ??
        0;

    return {
      'contacts': contactsCount,
      'activities': activitiesWithParticipants,
    };
  }

  Future<void> _applyPlanTransitionEffects({
    required String previousPlan,
    required String newPlan,
  }) async {
    final prev = PlanRules.normalize(previousPlan);
    final next = PlanRules.normalize(newPlan);
    if (prev == next) return;

    // Ganhou backup em nuvem (ex.: basico -> avancado/colaborativo): envia
    // um snapshot completo dos dados locais para o Firestore.
    if (!PlanRules.hasCloudBackup(prev) && PlanRules.hasCloudBackup(next)) {
      await backupAllToCloud();
    }

    // Perdeu backup em nuvem (ex.: avancado -> basico): os documentos ja
    // enviados ao Firestore sao mantidos de proposito (ficam recuperaveis
    // se o usuario assinar de novo), so paramos de enviar novidades.

    final downgradedFromPremium =
        PlanRules.hasFullAccess(prev) && PlanRules.isPersonalAgendaOnly(next);
    if (!downgradedFromPremium) return;

    final db = await database;
    await db.delete('contacts');
    await db.delete('contact_group_members');
    await db.delete('contact_groups');
    await db.update(
      'activity',
      {'participants': jsonEncode(<Map<String, dynamic>>[])},
      where:
          "participants IS NOT NULL AND participants != '' AND participants != '[]'",
    );
  }

  Future<Atividade> _sanitizeActivityForCurrentPlan(
    Atividade atividade, {
    required bool isUpdate,
  }) async {
    if (await _canUseCollaborativeFeatures()) return atividade;

    if (!isUpdate || atividade.id == 0) {
      return atividade.copyWith(participantes: []);
    }

    final existingMap = await getActivityById(atividade.id);
    if (existingMap == null) {
      return atividade.copyWith(participantes: []);
    }

    final existingActivity = Atividade.fromMap(existingMap);

    // Em plano pessoal, impede adicionar novos participantes:
    // - se já não existia participante, mantém vazio;
    // - se já existia, preserva os existentes;
    // - se o payload vier vazio, permite limpar explicitamente.
    if (atividade.participantes.isEmpty) {
      return atividade.copyWith(participantes: []);
    }
    if (existingActivity.participantes.isEmpty) {
      return atividade.copyWith(participantes: []);
    }
    return atividade.copyWith(participantes: existingActivity.participantes);
  }

  // ATIVIDADES

  Future<int> insertActivity(Atividade atividade) async {
    final db = await database;
    final sanitizedActivity =
        await _sanitizeActivityForCurrentPlan(atividade, isUpdate: false);
    final map = sanitizedActivity.toMap();
    map['uuid'] = _uuid.v4();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert(
      'activity',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _pushActivityBackupIfEligible({...map, 'id': id});
    return id;
  }

  Future<void> updateActivity(Atividade atividade) async {
    final db = await database;
    final sanitizedActivity =
        await _sanitizeActivityForCurrentPlan(atividade, isUpdate: true);
    final map = sanitizedActivity.toMap();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'activity',
      map,
      where: 'id = ?',
      whereArgs: [sanitizedActivity.id],
    );
    final refreshed = await getActivityById(sanitizedActivity.id);
    if (refreshed != null) {
      await _pushActivityBackupIfEligible(refreshed);
    }
  }

  Future<bool> updateParticipantPresence({
    required int activityId,
    required String participantEmail,
    required String status,
    int? delayMinutes,
  }) async {
    if (!await _canUseCollaborativeFeatures()) return false;

    final currentEmail = (await getEmailFromDB() ?? '').trim().toLowerCase();
    final normalizedEmail = participantEmail.trim().toLowerCase();
    if (currentEmail.isEmpty || currentEmail != normalizedEmail) return false;

    final map = await getActivityById(activityId);
    if (map == null) return false;

    final activity = Atividade.fromMap(map);
    final normalizedStatus = ParticipanteStatus.normalize(status);
    final validatedDelay =
        delayMinutes != null && delayMinutes > 0 ? delayMinutes : null;

    var updated = false;
    final updatedParticipants = activity.participantes.map((participant) {
      if (participant.email.trim().toLowerCase() != normalizedEmail) {
        return participant;
      }
      updated = true;
      return participant.copyWith(
        status: normalizedStatus,
        atrasoMinutos: normalizedStatus == ParticipanteStatus.atrasado
            ? validatedDelay
            : null,
      );
    }).toList();

    if (!updated) return false;

    await updateActivity(activity.copyWith(participantes: updatedParticipants));
    return true;
  }

  Future<bool> deleteActivity(int id) async {
    final db = await database;
    final existing = await getActivityById(id);
    final result =
        await db.delete('activity', where: 'id = ?', whereArgs: [id]);
    if (result > 0) {
      await _deleteActivityBackupIfEligible(existing?['uuid']?.toString());
    }
    return result > 0;
  }

  Future<Map<String, dynamic>?> getActivityById(int id) async {
    final db = await database;
    final result = await db.query('activity', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllActivities({
    required int year,
    required int month,
    required int day,
    required List<String> status,
  }) async {
    final db = await database;
    final start = DateTime(year, month, day, 0, 0, 0).millisecondsSinceEpoch;
    final end =
        DateTime(year, month, day, 23, 59, 59, 999).millisecondsSinceEpoch;
    var where = 'date BETWEEN ? AND ?';
    final whereArgs = <Object>[start, end];
    if (status.isNotEmpty) {
      final placeholders = List.filled(status.length, '?').join(',');
      where += ' AND status IN ($placeholders)';
      whereArgs.addAll(status);
    }

    final result = await db.query(
      'activity',
      where: where,
      whereArgs: whereArgs,
      orderBy:
          "date ASC, CAST(substr(initHour, 1, instr(initHour, ':') - 1) AS INTEGER) ASC, CAST(substr(initHour, instr(initHour, ':') + 1) AS INTEGER) ASC",
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> getActivitiesForDateIncludingRecurring({
    required DateTime date,
    required List<String> status,
  }) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0)
        .millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
    // Recorrentes so devem aparecer do dia de criacao em diante.
    var where =
        '(date BETWEEN ? AND ? OR (repetirSemanalmente = 1 AND date <= ?))';
    final whereArgs = <Object>[start, end, end];
    if (status.isNotEmpty) {
      final placeholders = List.filled(status.length, '?').join(',');
      where += ' AND status IN ($placeholders)';
      whereArgs.addAll(status);
    }

    return db.query(
      'activity',
      where: where,
      whereArgs: whereArgs,
      orderBy:
          "date ASC, CAST(substr(initHour, 1, instr(initHour, ':') - 1) AS INTEGER) ASC, CAST(substr(initHour, instr(initHour, ':') + 1) AS INTEGER) ASC",
    );
  }

  Future<List<Map<String, dynamic>>> getActivitiesByStatus({
    required List<String> status,
  }) async {
    final db = await database;
    if (status.isEmpty) {
      return db.query(
        'activity',
        orderBy:
            "date ASC, CAST(substr(initHour, 1, instr(initHour, ':') - 1) AS INTEGER) ASC, CAST(substr(initHour, instr(initHour, ':') + 1) AS INTEGER) ASC",
      );
    }
    final placeholders = List.filled(status.length, '?').join(',');
    final result = await db.query(
      'activity',
      where: 'status IN ($placeholders)',
      whereArgs: status,
      orderBy:
          "date ASC, CAST(substr(initHour, 1, instr(initHour, ':') - 1) AS INTEGER) ASC, CAST(substr(initHour, instr(initHour, ':') + 1) AS INTEGER) ASC",
    );
    return result;
  }

  Future<int?> getMinActivityDateMillis() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MIN(date) FROM activity');
    if (result.isNotEmpty && result.first.values.isNotEmpty) {
      final minValue = result.first.values.first;
      if (minValue != null && minValue is int) {
        return minValue;
      }
    }
    return null;
  }

  Future<List<String>> getAllActivityYears() async {
    final db = await database;
    final List<Map<String, dynamic>> results =
        await db.query('activity', columns: ['date']);
    final Set<String> years = {};
    for (var row in results) {
      final dateMillis = row['date'];
      if (dateMillis != null && dateMillis is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
        years.add(date.year.toString());
      }
    }
    final List<String> sortedYears = years.toList();
    sortedYears.sort();
    return sortedYears;
  }

  Future<List<Participante>> getParticipantesFromJson(
      String participantsJson) async {
    try {
      final List<dynamic> participantesList = jsonDecode(participantsJson);
      return participantesList.map((e) => Participante.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  String formatTime(dynamic time) {
    if (time is DateTime) {
      final DateFormat formatter = DateFormat('HH:mm');
      return formatter.format(time);
    } else if (time is String) {
      return time;
    }
    return '';
  }

  // CONTATOS

  Future<bool> insertContact(String name, String email) async {
    if (!await _canUseCollaborativeFeatures()) return false;
    final db = await database;
    final normalizedInputEmail = _normalizeEmail(email);
    if (normalizedInputEmail.isEmpty) return false;
    final contactRef = _firestore.collection('users');
    final docSnapshot = await contactRef.doc(normalizedInputEmail).get();
    if (!docSnapshot.exists) return false;

    final firebaseData = docSnapshot.data()!;
    final firebaseEmail = _normalizeEmail(
      firebaseData['email']?.toString() ?? normalizedInputEmail,
    );
    final firebaseAvatarUrl = firebaseData['avatarUrl']?.toString() ?? '';
    final contactMap = {
      'name': name.trim(),
      'email': firebaseEmail,
      'avatarUrl': firebaseAvatarUrl,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    await db.insert(
      'contacts',
      contactMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _pushContactBackup(contactMap);
    return true;
  }

  Future<bool> updateContact(String name, String email) async {
    if (!await _canUseCollaborativeFeatures()) return false;
    final db = await database;
    final normalizedInputEmail = _normalizeEmail(email);
    if (normalizedInputEmail.isEmpty) return false;
    final contactRef = _firestore.collection('users');
    final docSnapshot = await contactRef.doc(normalizedInputEmail).get();
    if (!docSnapshot.exists) return false;

    final firebaseData = docSnapshot.data()!;
    final firebaseEmail = _normalizeEmail(
      firebaseData['email']?.toString() ?? normalizedInputEmail,
    );
    final firebaseAvatarUrl = firebaseData['avatarUrl']?.toString() ?? '';
    final contactMap = {
      'name': name.trim(),
      'email': firebaseEmail,
      'avatarUrl': firebaseAvatarUrl,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    final updatedRows = await db.update(
      'contacts',
      contactMap,
      where: 'LOWER(TRIM(email)) = ?',
      whereArgs: [normalizedInputEmail],
    );
    if (updatedRows > 0) {
      await _pushContactBackup(contactMap);
    }
    return updatedRows > 0;
  }

  Future<void> deleteContact(String email) async {
    if (!await _canUseCollaborativeFeatures()) return;
    final db = await database;
    final normalizedEmail = _normalizeEmail(email);
    await db.transaction((txn) async {
      await txn.delete(
        'contact_group_members',
        where: 'contact_email = ?',
        whereArgs: [normalizedEmail],
      );
      await txn.delete(
        'contacts',
        where: 'LOWER(TRIM(email)) = ?',
        whereArgs: [normalizedEmail],
      );
    });
    await _deleteContactBackup(normalizedEmail);
  }

  Future<List<Map<String, dynamic>>> getAllContacts() async {
    if (!await _canUseCollaborativeFeatures()) return [];
    final db = await database;
    return await db.query('contacts');
  }

  // GRUPOS DE CONTATOS

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<int> createContactGroup({
    required String name,
    required List<String> memberEmails,
  }) async {
    if (!await _canUseCollaborativeFeatures()) return -1;
    final db = await database;
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return -1;

    final normalizedEmails = memberEmails
        .map(_normalizeEmail)
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList();

    final uuid = _uuid.v4();
    final groupId = await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final groupId = await txn.insert(
        'contact_groups',
        {
          'name': normalizedName,
          'created_at': now,
          'updated_at': now,
          'uuid': uuid,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (normalizedEmails.isNotEmpty) {
        final placeholders =
            List.filled(normalizedEmails.length, '?').join(',');
        final validContacts = await txn.query(
          'contacts',
          columns: ['email'],
          where: 'LOWER(TRIM(email)) IN ($placeholders)',
          whereArgs: normalizedEmails,
        );

        for (final contact in validContacts) {
          final email = _normalizeEmail(contact['email']?.toString() ?? '');
          if (email.isEmpty) continue;
          await txn.insert(
            'contact_group_members',
            {
              'group_id': groupId,
              'contact_email': email,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      return groupId;
    });
    await _pushContactGroupBackup(
      uuid: uuid,
      name: normalizedName,
      memberEmails: normalizedEmails,
    );
    return groupId;
  }

  Future<bool> updateContactGroup({
    required int groupId,
    required String name,
    required List<String> memberEmails,
  }) async {
    if (!await _canUseCollaborativeFeatures()) return false;
    if (groupId <= 0) return false;
    final db = await database;
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return false;

    final normalizedEmails = memberEmails
        .map(_normalizeEmail)
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList();

    final success = await db.transaction((txn) async {
      final updatedRows = await txn.update(
        'contact_groups',
        {
          'name': normalizedName,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [groupId],
      );
      if (updatedRows == 0) return false;

      await txn.delete(
        'contact_group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );

      if (normalizedEmails.isNotEmpty) {
        final placeholders =
            List.filled(normalizedEmails.length, '?').join(',');
        final validContacts = await txn.query(
          'contacts',
          columns: ['email'],
          where: 'LOWER(TRIM(email)) IN ($placeholders)',
          whereArgs: normalizedEmails,
        );

        for (final contact in validContacts) {
          final email = _normalizeEmail(contact['email']?.toString() ?? '');
          if (email.isEmpty) continue;
          await txn.insert(
            'contact_group_members',
            {
              'group_id': groupId,
              'contact_email': email,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      return true;
    });

    if (success) {
      final groupRow = await db.query('contact_groups',
          columns: ['uuid'], where: 'id = ?', whereArgs: [groupId]);
      final uuid = groupRow.isNotEmpty ? groupRow.first['uuid']?.toString() : null;
      if (uuid != null && uuid.isNotEmpty) {
        await _pushContactGroupBackup(
          uuid: uuid,
          name: normalizedName,
          memberEmails: normalizedEmails,
        );
      }
    }
    return success;
  }

  Future<void> deleteContactGroup(int groupId) async {
    if (!await _canUseCollaborativeFeatures()) return;
    if (groupId <= 0) return;
    final db = await database;
    final groupRow = await db.query('contact_groups',
        columns: ['uuid'], where: 'id = ?', whereArgs: [groupId]);
    final uuid =
        groupRow.isNotEmpty ? groupRow.first['uuid']?.toString() : null;
    await db.transaction((txn) async {
      await txn.delete(
        'contact_group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      await txn.delete(
        'contact_groups',
        where: 'id = ?',
        whereArgs: [groupId],
      );
    });
    await _deleteContactGroupBackup(uuid);
  }

  Future<List<ContactGroup>> getContactGroupsWithMembers() async {
    if (!await _canUseCollaborativeFeatures()) return [];
    final db = await database;

    final groupsRaw = await db.query(
      'contact_groups',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    if (groupsRaw.isEmpty) return [];

    final membersRaw = await db.rawQuery('''
      SELECT
        m.group_id AS group_id,
        c.name AS name,
        c.email AS email,
        c.avatarUrl AS avatarUrl
      FROM contact_group_members m
      INNER JOIN contacts c ON LOWER(TRIM(c.email)) = m.contact_email
      ORDER BY c.name COLLATE NOCASE ASC
    ''');

    final membersByGroup = <int, List<Contact>>{};
    for (final row in membersRaw) {
      final groupIdValue = row['group_id'];
      final groupId = groupIdValue is int
          ? groupIdValue
          : int.tryParse(groupIdValue?.toString() ?? '');
      if (groupId == null) continue;
      final contact = Contact(
        name: row['name']?.toString() ?? 'Sem nome',
        email: row['email']?.toString() ?? '',
        avatarUrl: row['avatarUrl']?.toString() ?? '',
      );
      membersByGroup.putIfAbsent(groupId, () => <Contact>[]).add(contact);
    }

    return groupsRaw.map((groupMap) {
      final idValue = groupMap['id'];
      final id = idValue is int
          ? idValue
          : int.tryParse(idValue?.toString() ?? '') ?? 0;
      return ContactGroup(
        id: id,
        name: groupMap['name']?.toString() ?? 'Sem nome',
        members: membersByGroup[id] ?? const <Contact>[],
      );
    }).toList();
  }

  // CONVITES DE ATIVIDADE

  String _buildInviteId({
    required String ownerEmail,
    required String participantEmail,
    required Atividade atividade,
  }) {
    final raw =
        '${ownerEmail.toLowerCase()}|${participantEmail.toLowerCase()}|${atividade.id}|${atividade.data.millisecondsSinceEpoch}|${atividade.horaInicio.hour}:${atividade.horaInicio.minute}|${atividade.horaFim.hour}:${atividade.horaFim.minute}|${atividade.titulo.toLowerCase()}';
    return sha1.convert(utf8.encode(raw)).toString();
  }

  Future<int> sendActivityInvites(Atividade atividade) async {
    if (atividade.participantes.isEmpty) return 0;
    if (!await _canUseCollaborativeFeatures()) return 0;

    final ownerEmail = await getEmailFromDB();
    if (ownerEmail == null || ownerEmail.isEmpty) return 0;

    final owner = await getUser();
    final ownerName = owner?['name']?.toString() ?? 'Usuário';
    var sent = 0;

    for (final participante in atividade.participantes) {
      final participantEmail = participante.email.trim().toLowerCase();
      if (participantEmail.isEmpty) continue;
      if (participantEmail == ownerEmail.toLowerCase()) continue;

      final inviteId = _buildInviteId(
        ownerEmail: ownerEmail,
        participantEmail: participantEmail,
        atividade: atividade,
      );
      final inviteRef = _firestore.collection('activity_invites').doc(inviteId);

      try {
        final existing = await inviteRef.get();
        final existingData = existing.data();
        final existingStatus =
            existingData?['status']?.toString().toLowerCase() ?? '';

        // Evita reabrir convite já respondido.
        if (existing.exists &&
            (existingStatus == 'accepted' || existingStatus == 'declined')) {
          continue;
        }

        await inviteRef.set({
          'owner_email': ownerEmail.toLowerCase(),
          'owner_name': ownerName,
          'participant_email': participantEmail,
          'participant_name': participante.nome,
          'activity_title': atividade.titulo,
          'activity_payload': atividade.toMap(),
          'status': 'pending',
          'created_at':
              existingData?['created_at'] ?? FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        sent++;
      } catch (e) {
        debugPrint('Falha ao enviar convite para $participantEmail: $e');
      }
    }

    return sent;
  }

  Future<List<ConviteAtividade>> getPendingActivityInvites() async {
    if (!await _canUseCollaborativeFeatures()) return [];

    final currentEmail = await getEmailFromDB();
    if (currentEmail == null || currentEmail.isEmpty) return [];

    try {
      final query = await _firestore
          .collection('activity_invites')
          .where('participant_email', isEqualTo: currentEmail.toLowerCase())
          .get();

      final invites = query.docs
          .map((doc) => ConviteAtividade.fromMap(doc.id, doc.data()))
          .where((invite) => invite.isPending)
          .toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? a.activityDate;
          final bTime = b.createdAt ?? b.activityDate;
          return bTime.compareTo(aTime);
        });

      return invites;
    } catch (e) {
      debugPrint('Falha ao buscar convites pendentes: $e');
      return [];
    }
  }

  Future<bool> acceptActivityInvite(ConviteAtividade invite) async {
    if (!await _canUseCollaborativeFeatures()) return false;

    final currentEmail = await getEmailFromDB();
    if (currentEmail == null || currentEmail.isEmpty) return false;
    if (invite.participantEmail.toLowerCase() != currentEmail.toLowerCase()) {
      return false;
    }

    final db = await database;
    final alreadyProcessed = await db.query(
      'invite_processed',
      where: 'invite_id = ?',
      whereArgs: [invite.id],
      limit: 1,
    );

    if (alreadyProcessed.isNotEmpty) {
      await _firestore.collection('activity_invites').doc(invite.id).set({
        'status': 'accepted',
        'updated_at': FieldValue.serverTimestamp(),
        'responded_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    }

    final payload = Map<String, dynamic>.from(invite.activityPayload);
    payload['id'] = 0;

    late Atividade activityFromInvite;
    try {
      activityFromInvite = Atividade.fromMap(payload);
    } catch (_) {
      return false;
    }

    final normalizedParticipants = activityFromInvite.participantes.map((p) {
      final normalizedStatus = ParticipanteStatus.normalize(p.status);
      if (p.email.toLowerCase() == currentEmail.toLowerCase()) {
        return p.copyWith(
          status: ParticipanteStatus.aceito,
          atrasoMinutos: null,
        );
      }
      return p.copyWith(
        status: normalizedStatus,
        atrasoMinutos: normalizedStatus == ParticipanteStatus.atrasado
            ? p.atrasoMinutos
            : null,
      );
    }).toList();

    final activityToInsert = activityFromInvite.copyWith(
      id: 0,
      status: AtividadeStatus.pendente,
      participantes: normalizedParticipants,
    );

    final insertedId = await insertActivity(activityToInsert);

    await db.insert(
      'invite_processed',
      {
        'invite_id': invite.id,
        'activity_id': insertedId,
        'processed_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _firestore.collection('activity_invites').doc(invite.id).set({
      'status': 'accepted',
      'updated_at': FieldValue.serverTimestamp(),
      'responded_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  Future<bool> declineActivityInvite(ConviteAtividade invite) async {
    final currentEmail = await getEmailFromDB();
    if (currentEmail == null || currentEmail.isEmpty) return false;
    if (invite.participantEmail.toLowerCase() != currentEmail.toLowerCase()) {
      return false;
    }

    final db = await database;
    await db.insert(
      'invite_processed',
      {
        'invite_id': invite.id,
        'activity_id': null,
        'processed_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _firestore.collection('activity_invites').doc(invite.id).set({
      'status': 'declined',
      'updated_at': FieldValue.serverTimestamp(),
      'responded_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return true;
  }

  // EXCEÇÕES DE ATIVIDADE

  Future<void> addActivityException({
    required int atividadeId,
    required DateTime data,
    required String tipo, // 'excluida' ou 'editada'
    Map<String, dynamic>? camposEditados,
  }) async {
    final db = await database;
    await db.insert('activity_exception', {
      'atividade_id': atividadeId,
      'data': data.millisecondsSinceEpoch,
      'tipo': tipo,
      'campos_editados':
          camposEditados != null ? jsonEncode(camposEditados) : null,
    });
    await _pushActivityExceptionBackupIfEligible(
      atividadeId: atividadeId,
      data: data,
      tipo: tipo,
      camposEditados: camposEditados,
    );
  }

  Future<void> upsertActivityException({
    required int atividadeId,
    required DateTime data,
    required String tipo, // 'excluida' ou 'editada'
    Map<String, dynamic>? camposEditados,
  }) async {
    final db = await database;
    final start =
        DateTime(data.year, data.month, data.day, 0, 0).millisecondsSinceEpoch;
    final end = DateTime(data.year, data.month, data.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    await db.delete(
      'activity_exception',
      where: 'atividade_id = ? AND tipo = ? AND data BETWEEN ? AND ?',
      whereArgs: [atividadeId, tipo, start, end],
    );

    await db.insert('activity_exception', {
      'atividade_id': atividadeId,
      'data': data.millisecondsSinceEpoch,
      'tipo': tipo,
      'campos_editados':
          camposEditados != null ? jsonEncode(camposEditados) : null,
    });
    await _pushActivityExceptionBackupIfEligible(
      atividadeId: atividadeId,
      data: data,
      tipo: tipo,
      camposEditados: camposEditados,
    );
  }

  Future<List<Map<String, dynamic>>> getActivityExceptionsForDay(
      DateTime data) async {
    final db = await database;
    final start =
        DateTime(data.year, data.month, data.day, 0, 0).millisecondsSinceEpoch;
    final end = DateTime(data.year, data.month, data.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    return await db.query(
      'activity_exception',
      where: 'data BETWEEN ? AND ?',
      whereArgs: [start, end],
    );
  }

  Future<List<Map<String, dynamic>>> getActivityExceptionsForActivity(
      int atividadeId) async {
    final db = await database;
    return await db.query(
      'activity_exception',
      where: 'atividade_id = ?',
      whereArgs: [atividadeId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllActivityExceptions() async {
    final db = await database;
    return await db.query(
      'activity_exception',
      orderBy: 'data ASC, id ASC',
    );
  }

  // CONFIGURAÇÕES GERAIS

  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.execute(_config);
    await db.insert(
      'config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getConfig(String key) async {
    final db = await database;
    await db.execute(_config);
    final result = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

}

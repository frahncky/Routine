import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/contacts/contact_group.dart';
import 'package:routine/features/contacts/contatos.dart';
import 'package:routine/features/convites/convite_atividade.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DB {
  DB._();
  static final DB instance = DB._();
  static Database? _database;
  static FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  @visibleForTesting
  static void setFirestoreForTesting(FirebaseFirestore? firestore) {
    _firestoreOverride = firestore;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    return await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'Routine.db');
    return await openDatabase(
      path,
      version: 4,
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
    // Garante que a tabela config exista após upgrade
    await db.execute(_config);
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
      diasDaSemana TEXT
    );
  ''';

  String get _contacts => '''
    CREATE TABLE contacts(
      name TEXT,
      email TEXT UNIQUE,
      avatarUrl TEXT
    );
  ''';

  String get _contactGroups => '''
    CREATE TABLE IF NOT EXISTS contact_groups(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE COLLATE NOCASE,
      created_at INTEGER,
      updated_at INTEGER
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
        'typeAccount': PlanRules.gratis,
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
          'typeAccount': PlanRules.gratis,
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
    return await db.insert(
      'activity',
      sanitizedActivity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateActivity(Atividade atividade) async {
    final db = await database;
    final sanitizedActivity =
        await _sanitizeActivityForCurrentPlan(atividade, isUpdate: true);
    await db.update(
      'activity',
      sanitizedActivity.toMap(),
      where: 'id = ?',
      whereArgs: [sanitizedActivity.id],
    );
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
    final result =
        await db.delete('activity', where: 'id = ?', whereArgs: [id]);
    return result > 0;
  }

  Future<Map<String, dynamic>?> getActivityById(int id) async {
    final db = await database;
    final result = await db.query('activity', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> listarAtividades() async {
    final db = await database;
    await db.query('activity');
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
    if (email.isEmpty) return false;
    final contactRef = _firestore.collection('users');
    final docSnapshot = await contactRef.doc(email).get();
    if (!docSnapshot.exists) return false;

    final firebaseData = docSnapshot.data()!;
    final firebaseEmail = firebaseData['email'];
    final firebaseAvatarUrl = firebaseData['avatarUrl'];
    await db.insert(
      'contacts',
      {
        'name': name,
        'email': firebaseEmail,
        'avatarUrl': firebaseAvatarUrl,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<bool> updateContact(String name, String email) async {
    if (!await _canUseCollaborativeFeatures()) return false;
    final db = await database;
    if (email.isEmpty) return false;
    final contactRef = _firestore.collection('users');
    final docSnapshot = await contactRef.doc(email).get();
    if (!docSnapshot.exists) return false;

    final firebaseData = docSnapshot.data()!;
    final firebaseEmail = firebaseData['email'];
    final firebaseAvatarUrl = firebaseData['avatarUrl'];
    final updatedRows = await db.update(
      'contacts',
      {
        'name': name,
        'email': firebaseEmail,
        'avatarUrl': firebaseAvatarUrl,
      },
      where: 'email = ?',
      whereArgs: [email],
    );
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
        where: 'email = ?',
        whereArgs: [normalizedEmail],
      );
    });
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

    return db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final groupId = await txn.insert(
        'contact_groups',
        {
          'name': normalizedName,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (normalizedEmails.isNotEmpty) {
        final placeholders =
            List.filled(normalizedEmails.length, '?').join(',');
        final validContacts = await txn.query(
          'contacts',
          columns: ['email'],
          where: 'email IN ($placeholders)',
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

    return db.transaction((txn) async {
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
          where: 'email IN ($placeholders)',
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
  }

  Future<void> deleteContactGroup(int groupId) async {
    if (!await _canUseCollaborativeFeatures()) return;
    if (groupId <= 0) return;
    final db = await database;
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
      INNER JOIN contacts c ON c.email = m.contact_email
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

  Future<List<Atividade>> getAtividadesComExcecoes() async {
    final db = await database;

    // Obter todas as atividades
    final atividades = await db.query('activity');

    // Obter todas as exceções
    final excecoes = await db.query('activity_exception');

    final atividadesFiltradas = <Atividade>[];

    for (final atividade in atividades) {
      final atividadeId = atividade['id'] as int;

      // Filtrar exceções para esta atividade
      final excecoesAtividade =
          excecoes.where((e) => e['atividade_id'] == atividadeId);

      // Filtrar datas excluídas
      final datasExcluidas = excecoesAtividade
          .where((e) => e['tipo'] == 'excluida')
          .map((e) => DateTime.fromMillisecondsSinceEpoch(e['data'] as int))
          .toSet();

      // Substituir instâncias editadas
      final edicoes = excecoesAtividade.where((e) => e['tipo'] == 'editada');

      // Adicionar instâncias não excluídas
      for (final data in _gerarDatasRepetitivas(atividade)) {
        if (!datasExcluidas.contains(data)) {
          final edicao = edicoes.firstWhere(
            (e) =>
                DateTime.fromMillisecondsSinceEpoch(e['data'] as int) == data,
            orElse: () => <String, dynamic>{},
          );

          if (edicao.isNotEmpty && edicao['campos_editados'] != null) {
            // Substituir campos editados
            atividadesFiltradas.add(Atividade.fromMap({
              ...atividade,
              ...jsonDecode(edicao['campos_editados'] as String),
            }));
          } else {
            atividadesFiltradas.add(Atividade.fromMap(atividade));
          }
        }
      }
    }

    return atividadesFiltradas;
  }

// Método auxiliar para gerar datas repetitivas
  List<DateTime> _gerarDatasRepetitivas(Map<String, dynamic> atividade) {
    final datas = <DateTime>[];
    final repetirSemanalmente = atividade['repetirSemanalmente'] == 1;
    final diasDaSemanaRaw = atividade['diasDaSemana'] as String?;
    final diasDaSemana = diasDaSemanaRaw == null || diasDaSemanaRaw.isEmpty
        ? <int>[]
        : diasDaSemanaRaw
            .split(',')
            .map((e) => int.tryParse(e) ?? 0)
            .where((e) => e > 0)
            .toList();

    if (repetirSemanalmente && diasDaSemana.isNotEmpty) {
      final dataInicial =
          DateTime.fromMillisecondsSinceEpoch(atividade['date'] as int);
      final dataFinal =
          DateTime.now().add(const Duration(days: 365)); // Exemplo: 1 ano

      for (var data = dataInicial;
          data.isBefore(dataFinal);
          data = data.add(const Duration(days: 1))) {
        if (diasDaSemana.contains(data.weekday)) {
          datas.add(data);
        }
      }
    } else {
      datas.add(DateTime.fromMillisecondsSinceEpoch(atividade['date'] as int));
    }

    return datas;
  }
}

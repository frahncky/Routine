import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_user);
    await db.execute(_activity);
    await db.execute(_contacts);
    await db.execute(_activityException);
    await db.execute(_config); // Cria tabela de configurações
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_activityException);
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

  String get _activityException => '''
    CREATE TABLE activity_exception(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      atividade_id INTEGER,
      data INTEGER,
      tipo TEXT,
      campos_editados TEXT
    );
  ''';

  String get _config => '''
    CREATE TABLE IF NOT EXISTS config(
      key TEXT PRIMARY KEY,
      value TEXT
    );
  ''';

  // USUÁRIO

  Future<void> createAccount(
    String name,
    String email,
    String avatarUrl,
    String authProvider,
  ) async {
    final db = await database;
    await db.insert(
      'user',
      {
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'typeAccount': PlanRules.gratis,
        'authProvider': authProvider,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (email.isNotEmpty) {
      try {
        final userRef = _firestore.collection('users');
        await userRef.doc(email).set({
          'name': name,
          'email': email,
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
    final users = await db.query('user', limit: 1);
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
          where: 'email = ?',
          whereArgs: [email],
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
    final previousPlan = await _getCurrentNormalizedPlan();
    final updateFields = <String, dynamic>{};
    if (name != null) updateFields['name'] = name;
    if (avatarUrl != null) updateFields['avatarUrl'] = avatarUrl;
    if (typeAccount != null) {
      updateFields['typeAccount'] = PlanRules.normalize(typeAccount);
    }
    if (updateFields.isEmpty) return;
    await db.update(
      'user',
      updateFields,
      where: 'email = ?',
      whereArgs: [email],
    );

    try {
      final userRef = _firestore.collection('users');
      final payload = Map<String, dynamic>.from(updateFields)
        ..['updated_at'] = FieldValue.serverTimestamp();
      await userRef.doc(email).set(payload, SetOptions(merge: true));
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
    final db = await database;
    final user = await db.query('user', limit: 1);
    return user.isEmpty ? null : user.first['email'] as String?;
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
    var where = '(date BETWEEN ? AND ? OR repetirSemanalmente = 1)';
    final whereArgs = <Object>[start, end];
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
    await db.delete('contacts', where: 'email = ?', whereArgs: [email]);
  }

  Future<List<Map<String, dynamic>>> getAllContacts() async {
    if (!await _canUseCollaborativeFeatures()) return [];
    final db = await database;
    return await db.query('contacts');
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

import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;

  Participante p(String name, String email) =>
      Participante(nome: name, email: email, fotoUrl: null, status: 'pendente');

  Atividade makeActivity({
    required String title,
    required List<Participante> participantes,
    int id = 0,
  }) {
    return Atividade(
      id: id,
      titulo: title,
      descricao: 'descricao',
      data: DateTime(2026, 1, 10),
      horaInicio: const TimeOfDay(hour: 9, minute: 0),
      horaFim: const TimeOfDay(hour: 10, minute: 0),
      status: AtividadeStatus.pendente,
      participantes: participantes,
    );
  }

  Future<void> seedUserPlan(
    String plan, {
    String email = 'tester@routine.app',
    String name = 'Tester',
  }) async {
    final db = await DB.instance.database;
    await db.insert(
      'user',
      {
        'name': name,
        'email': email,
        'avatarUrl': '',
        'typeAccount': plan,
        'authProvider': 'email',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    DB.setFirestoreForTesting(fakeFirestore);
    await DB.instance.resetDatabase();
  });

  tearDown(() async {
    await DB.instance.resetDatabase();
    DB.setFirestoreForTesting(null);
  });

  group('Contacts by plan', () {
    test('basico blocks collaborative contact operations', () async {
      await seedUserPlan(PlanRules.basico);

      await fakeFirestore.collection('users').doc('friend@routine.app').set({
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': 'https://example.com/friend.png',
      });

      final inserted =
          await DB.instance.insertContact('Friend', 'friend@routine.app');
      expect(inserted, isFalse);

      final db = await DB.instance.database;
      await db.insert('contacts', {
        'name': 'LocalOnly',
        'email': 'local@routine.app',
        'avatarUrl': '',
      });

      final listed = await DB.instance.getAllContacts();
      expect(listed, isEmpty);

      await DB.instance.deleteContact('local@routine.app');
      final stillThere = await db.query(
        'contacts',
        where: 'email = ?',
        whereArgs: ['local@routine.app'],
      );
      expect(stillThere.length, 1);
    });

    test('avancado also blocks collaborative contact operations', () async {
      // Prova que a Opcao A (contatos exclusivos do colaborativo) nao
      // regrediu com a introducao do plano avancado.
      await seedUserPlan(PlanRules.avancado);

      await fakeFirestore.collection('users').doc('friend@routine.app').set({
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': 'https://example.com/friend.png',
      });

      final inserted =
          await DB.instance.insertContact('Friend', 'friend@routine.app');
      expect(inserted, isFalse);

      final listed = await DB.instance.getAllContacts();
      expect(listed, isEmpty);
    });

    test('colaborativo allows contact insert, update and delete', () async {
      await seedUserPlan(PlanRules.colaborativo);

      await fakeFirestore.collection('users').doc('friend@routine.app').set({
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': 'https://example.com/friend.png',
      });

      final inserted =
          await DB.instance.insertContact('Friend', 'friend@routine.app');
      expect(inserted, isTrue);

      final updated = await DB.instance
          .updateContact('Friend Updated', 'friend@routine.app');
      expect(updated, isTrue);

      final all = await DB.instance.getAllContacts();
      expect(all.length, 1);
      expect(all.first['name'], 'Friend Updated');

      await DB.instance.deleteContact('friend@routine.app');
      final afterDelete = await DB.instance.getAllContacts();
      expect(afterDelete, isEmpty);
    });
  });

  group('Contact groups by plan', () {
    test('basico blocks contact group operations', () async {
      await seedUserPlan(PlanRules.basico);

      final db = await DB.instance.database;
      await db.insert('contacts', {
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': '',
      });

      final createdId = await DB.instance.createContactGroup(
        name: 'Equipe',
        memberEmails: ['friend@routine.app'],
      );
      expect(createdId, -1);

      final groups = await DB.instance.getContactGroupsWithMembers();
      expect(groups, isEmpty);
    });

    test('avancado also blocks contact group operations', () async {
      await seedUserPlan(PlanRules.avancado);

      final createdId = await DB.instance.createContactGroup(
        name: 'Equipe',
        memberEmails: [],
      );
      expect(createdId, -1);
    });

    test('colaborativo creates, updates and deletes contact groups',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      final db = await DB.instance.database;
      await db.insert('contacts', {
        'name': 'Friend A',
        'email': 'a@routine.app',
        'avatarUrl': '',
      });
      await db.insert('contacts', {
        'name': 'Friend B',
        'email': 'b@routine.app',
        'avatarUrl': '',
      });

      final groupId = await DB.instance.createContactGroup(
        name: 'Time Produto',
        memberEmails: ['a@routine.app'],
      );
      expect(groupId, greaterThan(0));

      var groups = await DB.instance.getContactGroupsWithMembers();
      expect(groups.length, 1);
      expect(groups.first.name, 'Time Produto');
      expect(groups.first.members.length, 1);
      expect(groups.first.members.first.email, 'a@routine.app');

      final updated = await DB.instance.updateContactGroup(
        groupId: groupId,
        name: 'Time Core',
        memberEmails: ['a@routine.app', 'b@routine.app'],
      );
      expect(updated, isTrue);

      groups = await DB.instance.getContactGroupsWithMembers();
      expect(groups.length, 1);
      expect(groups.first.name, 'Time Core');
      expect(groups.first.members.length, 2);

      await DB.instance.deleteContactGroup(groupId);
      groups = await DB.instance.getContactGroupsWithMembers();
      expect(groups, isEmpty);
    });
  });

  group('Activity participants by plan', () {
    test('basico strips participants on insert', () async {
      await seedUserPlan(PlanRules.basico);

      final id = await DB.instance.insertActivity(
        makeActivity(
          title: 'Atividade pessoal',
          participantes: [p('A', 'a@routine.app')],
        ),
      );

      final map = await DB.instance.getActivityById(id);
      expect(map, isNotNull);
      final saved = Atividade.fromMap(map!);
      expect(saved.participantes, isEmpty);
    });

    test('colaborativo keeps participants on insert', () async {
      await seedUserPlan(PlanRules.colaborativo);

      final id = await DB.instance.insertActivity(
        makeActivity(
          title: 'Atividade colaborativa',
          participantes: [p('A', 'a@routine.app')],
        ),
      );

      final map = await DB.instance.getActivityById(id);
      expect(map, isNotNull);
      final saved = Atividade.fromMap(map!);
      expect(saved.participantes.length, 1);
      expect(saved.participantes.first.email, 'a@routine.app');
    });

    test('colaborativo updates participant presence status and late minutes',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      final id = await DB.instance.insertActivity(
        makeActivity(
          title: 'Reuniao',
          participantes: [p('Tester', 'tester@routine.app')],
        ),
      );

      final markedLate = await DB.instance.updateParticipantPresence(
        activityId: id,
        participantEmail: 'tester@routine.app',
        status: ParticipanteStatus.atrasado,
        delayMinutes: 15,
      );
      expect(markedLate, isTrue);

      final lateMap = await DB.instance.getActivityById(id);
      final late = Atividade.fromMap(lateMap!);
      expect(late.participantes.first.status, ParticipanteStatus.atrasado);
      expect(late.participantes.first.atrasoMinutos, 15);

      final cancelled = await DB.instance.updateParticipantPresence(
        activityId: id,
        participantEmail: 'tester@routine.app',
        status: ParticipanteStatus.recusado,
      );
      expect(cancelled, isTrue);

      final cancelledMap = await DB.instance.getActivityById(id);
      final afterCancel = Atividade.fromMap(cancelledMap!);
      expect(
          afterCancel.participantes.first.status, ParticipanteStatus.recusado);
      expect(afterCancel.participantes.first.atrasoMinutos, isNull);
    });

    test('basico prevents adding new participants on update when none existed',
        () async {
      await seedUserPlan(PlanRules.basico);

      final id = await DB.instance.insertActivity(
        makeActivity(title: 'Sem participantes', participantes: []),
      );

      final current =
          Atividade.fromMap((await DB.instance.getActivityById(id))!);
      final changed = current.copyWith(
        participantes: [p('Novo', 'novo@routine.app')],
      );

      await DB.instance.updateActivity(changed);
      final updatedMap = await DB.instance.getActivityById(id);
      final updated = Atividade.fromMap(updatedMap!);
      expect(updated.participantes, isEmpty);
    });

    test('basico preserves existing participants from colaborativo on update',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      final id = await DB.instance.insertActivity(
        makeActivity(
          title: 'Migrada',
          participantes: [p('Original', 'original@routine.app')],
        ),
      );

      final db = await DB.instance.database;
      await db.update(
        'user',
        {'typeAccount': PlanRules.basico},
        where: 'email = ?',
        whereArgs: ['tester@routine.app'],
      );

      final current =
          Atividade.fromMap((await DB.instance.getActivityById(id))!);
      final changed = current.copyWith(
        titulo: 'Migrada editada',
        participantes: [p('Novo', 'novo@routine.app')],
      );

      await DB.instance.updateActivity(changed);
      final updatedMap = await DB.instance.getActivityById(id);
      final updated = Atividade.fromMap(updatedMap!);
      expect(updated.participantes.length, 1);
      expect(updated.participantes.first.email, 'original@routine.app');
      expect(updated.titulo, 'Migrada editada');
    });
  });

  group('Plan transition effects', () {
    test('downgrade impact summary counts collaborative local records',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      final db = await DB.instance.database;
      await db.insert('contacts', {
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': '',
      });

      await DB.instance.insertActivity(
        makeActivity(
          title: 'Atividade colaborativa',
          participantes: [p('A', 'a@routine.app')],
        ),
      );
      await DB.instance.insertActivity(
        makeActivity(
          title: 'Atividade pessoal',
          participantes: [],
        ),
      );

      final impact = await DB.instance.getDowngradeImpactSummary();
      expect(impact['contacts'], 1);
      expect(impact['activities'], 1);
    });

    test('downgrade from colaborativo to basico clears collaborative local data',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      final db = await DB.instance.database;
      await db.insert('contacts', {
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': '',
      });

      final id = await DB.instance.insertActivity(
        makeActivity(
          title: 'Atividade colaborativa',
          participantes: [p('A', 'a@routine.app')],
        ),
      );

      await DB.instance.updateAccount(
        email: 'tester@routine.app',
        typeAccount: PlanRules.basico,
      );

      final contacts = await db.query('contacts');
      expect(contacts, isEmpty);

      final updatedMap = await DB.instance.getActivityById(id);
      final updated = Atividade.fromMap(updatedMap!);
      expect(updated.participantes, isEmpty);
    });

    test(
        'profile updates without plan change preserve collaborative local data',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      final db = await DB.instance.database;
      await db.insert('contacts', {
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': '',
      });

      final id = await DB.instance.insertActivity(
        makeActivity(
          title: 'Atividade colaborativa',
          participantes: [p('A', 'a@routine.app')],
        ),
      );

      await DB.instance.updateAccount(
        email: 'tester@routine.app',
        name: 'Tester Updated',
      );

      final contacts = await db.query('contacts');
      expect(contacts.length, 1);

      final updatedMap = await DB.instance.getActivityById(id);
      final updated = Atividade.fromMap(updatedMap!);
      expect(updated.participantes.length, 1);
      expect(updated.participantes.first.email, 'a@routine.app');
    });
  });

  group('Cloud backup by plan', () {
    test('basico does not push activity backup to Firestore', () async {
      await seedUserPlan(PlanRules.basico);

      await DB.instance.insertActivity(
        makeActivity(title: 'Local apenas', participantes: []),
      );

      final backups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .get();
      expect(backups.docs, isEmpty);
    });

    test('avancado pushes activity backup on insert/update and removes it on delete',
        () async {
      await seedUserPlan(PlanRules.avancado);

      final id = await DB.instance.insertActivity(
        makeActivity(title: 'Atividade avancada', participantes: []),
      );
      final saved = Atividade.fromMap((await DB.instance.getActivityById(id))!);

      var backups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .get();
      expect(backups.docs.length, 1);
      expect(backups.docs.first.data()['title'], 'Atividade avancada');

      await DB.instance.updateActivity(saved.copyWith(titulo: 'Renomeada'));
      backups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .get();
      expect(backups.docs.length, 1);
      expect(backups.docs.first.data()['title'], 'Renomeada');

      await DB.instance.deleteActivity(id);
      backups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .get();
      expect(backups.docs, isEmpty);
    });

    test('avancado pushes activity exception backup on upsert', () async {
      await seedUserPlan(PlanRules.avancado);

      final id = await DB.instance.insertActivity(makeActivity(
        title: 'Academia',
        participantes: [],
      ));
      final activityUuid =
          (await DB.instance.getActivityById(id))!['uuid'] as String;
      final day = DateTime(2026, 1, 12);

      await DB.instance.upsertActivityException(
        atividadeId: id,
        data: day,
        tipo: 'editada',
        camposEditados: {'status': AtividadeStatus.concluida},
      );

      final exceptionBackups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activity_exceptions')
          .get();
      expect(exceptionBackups.docs.length, 1);
      final doc = exceptionBackups.docs.first.data();
      expect(doc['activity_uuid'], activityUuid);
      expect(doc['tipo'], 'editada');
      expect(doc['campos_editados'], {'status': AtividadeStatus.concluida});
    });

    test('colaborativo pushes contact and contact group backups', () async {
      await seedUserPlan(PlanRules.colaborativo);

      await fakeFirestore.collection('users').doc('friend@routine.app').set({
        'name': 'Friend',
        'email': 'friend@routine.app',
        'avatarUrl': '',
      });
      await DB.instance.insertContact('Friend', 'friend@routine.app');
      await DB.instance.createContactGroup(
        name: 'Equipe',
        memberEmails: ['friend@routine.app'],
      );

      final contactBackups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_contacts')
          .get();
      expect(contactBackups.docs.length, 1);

      final groupBackups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_contact_groups')
          .get();
      expect(groupBackups.docs.length, 1);
      expect(groupBackups.docs.first.data()['memberEmails'],
          ['friend@routine.app']);
    });

    test(
        'downgrade from colaborativo to gratuito keeps existing cloud backup docs',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      await DB.instance.insertActivity(
        makeActivity(title: 'Antes do downgrade', participantes: []),
      );

      var backups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .get();
      expect(backups.docs.length, 1);

      await DB.instance.updateAccount(
        email: 'tester@routine.app',
        typeAccount: PlanRules.gratuito,
      );

      backups = await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .get();
      expect(backups.docs.length, 1,
          reason: 'backup docs already sent should not be deleted on downgrade');
    });
  });

  group('Activity invites', () {
    test('colaborativo sends and accepts invite', () async {
      await seedUserPlan(
        PlanRules.colaborativo,
        email: 'owner@routine.app',
        name: 'Owner',
      );

      final id = await DB.instance.insertActivity(
        makeActivity(
          title: 'Atividade por convite',
          participantes: [p('Invitee', 'invitee@routine.app')],
        ),
      );

      final ownerActivity =
          Atividade.fromMap((await DB.instance.getActivityById(id))!);
      final sent = await DB.instance.sendActivityInvites(ownerActivity);
      expect(sent, 1);

      final db = await DB.instance.database;
      await db.update(
        'user',
        {
          'name': 'Invitee',
          'email': 'invitee@routine.app',
        },
        where: 'email = ?',
        whereArgs: ['owner@routine.app'],
      );

      final pending = await DB.instance.getPendingActivityInvites();
      expect(pending.length, 1);

      final accepted = await DB.instance.acceptActivityInvite(pending.first);
      expect(accepted, isTrue);

      final pendingAfter = await DB.instance.getPendingActivityInvites();
      expect(pendingAfter, isEmpty);

      final processed = await db.query(
        'invite_processed',
        where: 'invite_id = ?',
        whereArgs: [pending.first.id],
      );
      expect(processed.length, 1);

      final activities = await db.query('activity');
      expect(activities.length, 2);

      final inviteDoc = await fakeFirestore
          .collection('activity_invites')
          .doc(pending.first.id)
          .get();
      expect(inviteDoc.data()?['status'], 'accepted');
    });
  });

  group('DB.countActivities', () {
    test('counts activities regardless of plan and reflects deletes', () async {
      await seedUserPlan(PlanRules.gratuito);
      expect(await DB.instance.countActivities(), 0);

      final id1 = await DB.instance
          .insertActivity(makeActivity(title: 'Uma', participantes: []));
      await DB.instance
          .insertActivity(makeActivity(title: 'Duas', participantes: []));
      expect(await DB.instance.countActivities(), 2);

      await DB.instance.deleteActivity(id1);
      expect(await DB.instance.countActivities(), 1);
    });
  });

  group('Recurring activity behavior', () {
    test('does not list recurring activity before its start date', () async {
      await seedUserPlan(PlanRules.colaborativo);

      final recurring = Atividade(
        id: 0,
        titulo: 'Treino semanal',
        descricao: 'descricao',
        data: DateTime(2026, 1, 15), // quinta-feira
        horaInicio: const TimeOfDay(hour: 9, minute: 0),
        horaFim: const TimeOfDay(hour: 10, minute: 0),
        status: AtividadeStatus.pendente,
        participantes: const [],
        repetirSemanalmente: true,
        diasDaSemana: const [4], // quinta-feira
      );

      await DB.instance.insertActivity(recurring);

      final beforeStart =
          await DB.instance.getActivitiesForDateIncludingRecurring(
        date: DateTime(2026, 1, 8), // quinta anterior
        status: [AtividadeStatus.pendente],
      );
      expect(beforeStart, isEmpty);

      final onStart = await DB.instance.getActivitiesForDateIncludingRecurring(
        date: DateTime(2026, 1, 15),
        status: [AtividadeStatus.pendente],
      );
      expect(onStart.length, 1);

      final afterStart =
          await DB.instance.getActivitiesForDateIncludingRecurring(
        date: DateTime(2026, 1, 22), // quinta seguinte
        status: [AtividadeStatus.pendente],
      );
      expect(afterStart.length, 1);
    });

    test('upsertActivityException keeps only latest edit for same day',
        () async {
      await seedUserPlan(PlanRules.colaborativo);

      final id = await DB.instance.insertActivity(
        makeActivity(title: 'Rotina', participantes: []),
      );

      final targetDay = DateTime(2026, 1, 10);

      await DB.instance.upsertActivityException(
        atividadeId: id,
        data: targetDay,
        tipo: 'editada',
        camposEditados: {'status': AtividadeStatus.concluida},
      );

      await DB.instance.upsertActivityException(
        atividadeId: id,
        data: targetDay,
        tipo: 'editada',
        camposEditados: {'status': AtividadeStatus.pendente},
      );

      final excecoes = await DB.instance.getActivityExceptionsForDay(targetDay);
      final edits = excecoes
          .where((e) => e['atividade_id'] == id && e['tipo'] == 'editada')
          .toList();
      expect(edits.length, 1);

      final campos = jsonDecode(edits.first['campos_editados'] as String)
          as Map<String, dynamic>;
      expect(campos['status'], AtividadeStatus.pendente);
    });
  });

  group('DB.restoreCloudBackup', () {
    test('repopulates an empty local database from cloud backup', () async {
      await seedUserPlan(PlanRules.avancado);

      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .doc('remote-uuid-1')
          .set({
        'title': 'Vinda da nuvem',
        'describe': '',
        'date': DateTime(2026, 2, 1).millisecondsSinceEpoch,
        'initHour': '08:00',
        'endtHour': '09:00',
        'participants': '[]',
        'status': 'Pendente',
        'repetirSemanalmente': 0,
        'diasDaSemana': '',
        'updated_at': 1000,
      });

      expect(await DB.instance.hasAnyActivities(), isFalse);
      final restored = await DB.instance.restoreCloudBackup();
      expect(restored, 1);
      expect(await DB.instance.hasAnyActivities(), isTrue);

      final db = await DB.instance.database;
      final rows = await db.query('activity');
      expect(rows.single['title'], 'Vinda da nuvem');
      expect(rows.single['uuid'], 'remote-uuid-1');
    });

    test('restores activity exceptions along with their owning activity',
        () async {
      await seedUserPlan(PlanRules.avancado);

      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .doc('remote-uuid-2')
          .set({
        'title': 'Academia',
        'describe': '',
        'date': DateTime(2026, 1, 5).millisecondsSinceEpoch,
        'initHour': '07:00',
        'endtHour': '08:00',
        'participants': '[]',
        'status': 'Pendente',
        'repetirSemanalmente': 1,
        'diasDaSemana': '1,2,3,4,5',
        'updated_at': 1000,
      });
      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activity_exceptions')
          .doc('remote-exception-1')
          .set({
        'activity_uuid': 'remote-uuid-2',
        'data': DateTime(2026, 1, 12).millisecondsSinceEpoch,
        'tipo': 'editada',
        'campos_editados': {'status': AtividadeStatus.concluida},
        'updated_at': 1000,
      });

      final restored = await DB.instance.restoreCloudBackup();
      expect(restored, 2);

      final db = await DB.instance.database;
      final activityRow = (await db.query('activity')).single;
      final exceptions = await db.query('activity_exception');
      expect(exceptions.length, 1);
      expect(exceptions.single['atividade_id'], activityRow['id']);
      expect(exceptions.single['tipo'], 'editada');
      final campos = jsonDecode(exceptions.single['campos_editados'] as String)
          as Map<String, dynamic>;
      expect(campos['status'], AtividadeStatus.concluida);
    });

    test('does nothing for plans without cloud backup', () async {
      await seedUserPlan(PlanRules.basico);

      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .doc('remote-uuid-1')
          .set({'title': 'Nao deveria vir', 'updated_at': 1000});

      final restored = await DB.instance.restoreCloudBackup();
      expect(restored, 0);
      expect(await DB.instance.hasAnyActivities(), isFalse);
    });

    test('last-write-wins: newer remote overwrites older local', () async {
      await seedUserPlan(PlanRules.avancado);

      final id = await DB.instance
          .insertActivity(makeActivity(title: 'Local', participantes: []));
      final localRow = await DB.instance.getActivityById(id);
      final uuid = localRow!['uuid'] as String;
      final localUpdatedAt = localRow['updated_at'] as int;

      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .doc(uuid)
          .set({
        'title': 'Nuvem mais recente',
        'describe': '',
        'date': DateTime(2026, 1, 10).millisecondsSinceEpoch,
        'initHour': '09:00',
        'endtHour': '10:00',
        'participants': '[]',
        'status': 'Pendente',
        'repetirSemanalmente': 0,
        'diasDaSemana': '',
        'updated_at': localUpdatedAt + 100000,
      });

      await DB.instance.restoreCloudBackup();

      final refreshed = await DB.instance.getActivityById(id);
      expect(refreshed!['title'], 'Nuvem mais recente');
    });

    test('older remote does not overwrite newer local', () async {
      await seedUserPlan(PlanRules.avancado);

      final id = await DB.instance
          .insertActivity(makeActivity(title: 'Local', participantes: []));
      final localRow = await DB.instance.getActivityById(id);
      final uuid = localRow!['uuid'] as String;
      final localUpdatedAt = localRow['updated_at'] as int;

      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_activities')
          .doc(uuid)
          .set({
        'title': 'Nuvem antiga',
        'describe': '',
        'date': DateTime(2026, 1, 10).millisecondsSinceEpoch,
        'initHour': '09:00',
        'endtHour': '10:00',
        'participants': '[]',
        'status': 'Pendente',
        'repetirSemanalmente': 0,
        'diasDaSemana': '',
        'updated_at': localUpdatedAt - 100000,
      });

      await DB.instance.restoreCloudBackup();

      final refreshed = await DB.instance.getActivityById(id);
      expect(refreshed!['title'], 'Local');
    });

    test('contacts and groups also honor last-write-wins', () async {
      await seedUserPlan(PlanRules.colaborativo);
      final db = await DB.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('contacts', {
        'name': 'Local Newer',
        'email': 'friend@routine.app',
        'avatarUrl': '',
        'updated_at': now,
      });
      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_contacts')
          .doc('friend@routine.app')
          .set({
        'name': 'Cloud Older',
        'email': 'friend@routine.app',
        'avatarUrl': '',
        'updated_at': now - 100000,
      });

      await db.insert('contact_groups', {
        'name': 'Local Older Group',
        'created_at': now,
        'updated_at': now,
        'uuid': 'group-uuid-1',
      });
      await fakeFirestore
          .collection('users')
          .doc('tester@routine.app')
          .collection('backup_contact_groups')
          .doc('group-uuid-1')
          .set({
        'name': 'Cloud Newer Group',
        'memberEmails': <String>[],
        'updated_at': now + 100000,
      });

      await DB.instance.restoreCloudBackup();

      final contactRows = await db.query('contacts',
          where: 'email = ?', whereArgs: ['friend@routine.app']);
      expect(contactRows.single['name'], 'Local Newer');

      final groupRows = await db.query('contact_groups',
          where: 'uuid = ?', whereArgs: ['group-uuid-1']);
      expect(groupRows.single['name'], 'Cloud Newer Group');
    });
  });

  group('Schema migration v4 -> v5', () {
    test('backfills uuid/updated_at for rows created before v5', () async {
      await DB.closeForTesting();
      final dbPath = join(await getDatabasesPath(), 'Routine.db');
      await deleteDatabase(dbPath);

      final legacyDb = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE activity(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT, describe TEXT, date INTEGER,
              initHour TEXT, endtHour TEXT, participants TEXT, status TEXT,
              repetirSemanalmente INTEGER, diasDaSemana TEXT
            );
          ''');
          await db.execute('''
            CREATE TABLE user(
              name TEXT, email TEXT UNIQUE, password TEXT, avatarUrl TEXT,
              typeAccount TEXT, authProvider TEXT
            );
          ''');
          await db.execute(
              'CREATE TABLE contacts(name TEXT, email TEXT UNIQUE, avatarUrl TEXT);');
          await db.execute('''
            CREATE TABLE contact_groups(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT UNIQUE COLLATE NOCASE,
              created_at INTEGER, updated_at INTEGER
            );
          ''');
          await db.execute(
              'CREATE TABLE contact_group_members(group_id INTEGER, contact_email TEXT, PRIMARY KEY(group_id, contact_email));');
          await db.execute(
              'CREATE TABLE invite_processed(invite_id TEXT PRIMARY KEY, activity_id INTEGER, processed_at INTEGER);');
          await db.execute(
              'CREATE TABLE config(key TEXT PRIMARY KEY, value TEXT);');
        },
      );

      final legacyActivityId = await legacyDb.insert('activity', {
        'title': 'Legado',
        'describe': '',
        'date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'initHour': '09:00',
        'endtHour': '10:00',
        'participants': '[]',
        'status': 'Pendente',
        'repetirSemanalmente': 0,
        'diasDaSemana': '',
      });
      final legacyGroupId = await legacyDb.insert('contact_groups', {
        'name': 'Grupo antigo',
        'created_at': 0,
        'updated_at': 0,
      });
      await legacyDb.close();

      // Reabre pelo DB, agora na versao 5 — deve disparar o _onUpgrade real.
      final upgradedDb = await DB.instance.database;

      final activity = await upgradedDb.query(
        'activity',
        where: 'id = ?',
        whereArgs: [legacyActivityId],
      );
      expect(activity.single['uuid'], isNotNull);
      expect((activity.single['uuid'] as String).isNotEmpty, isTrue);
      expect(activity.single['updated_at'], isNotNull);

      final group = await upgradedDb.query(
        'contact_groups',
        where: 'id = ?',
        whereArgs: [legacyGroupId],
      );
      expect(group.single['uuid'], isNotNull);
      expect((group.single['uuid'] as String).isNotEmpty, isTrue);
    });
  });
}

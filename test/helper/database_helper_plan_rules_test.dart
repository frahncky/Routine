import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('premium allows contact insert, update and delete', () async {
      await seedUserPlan(PlanRules.premium);

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

    test('premium creates, updates and deletes contact groups', () async {
      await seedUserPlan(PlanRules.premium);

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

    test('premium keeps participants on insert', () async {
      await seedUserPlan(PlanRules.premium);

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

    test('premium updates participant presence status and late minutes',
        () async {
      await seedUserPlan(PlanRules.premium);

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

    test('basico preserves existing participants from premium on update',
        () async {
      await seedUserPlan(PlanRules.premium);

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
      await seedUserPlan(PlanRules.premium);

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

    test('downgrade from premium to basico clears collaborative local data',
        () async {
      await seedUserPlan(PlanRules.premium);

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
      await seedUserPlan(PlanRules.premium);

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

  group('Activity invites', () {
    test('premium sends and accepts invite', () async {
      await seedUserPlan(
        PlanRules.premium,
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

  group('Recurring activity behavior', () {
    test('does not list recurring activity before its start date', () async {
      await seedUserPlan(PlanRules.premium);

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
      await seedUserPlan(PlanRules.premium);

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
}

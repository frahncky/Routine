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

  Future<void> seedUserPlan(String plan) async {
    final db = await DB.instance.database;
    await db.insert(
      'user',
      {
        'name': 'Tester',
        'email': 'tester@routine.app',
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

      final inserted = await DB.instance.insertContact('Friend', 'friend@routine.app');
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

      final inserted = await DB.instance.insertContact('Friend', 'friend@routine.app');
      expect(inserted, isTrue);

      final updated = await DB.instance.updateContact('Friend Updated', 'friend@routine.app');
      expect(updated, isTrue);

      final all = await DB.instance.getAllContacts();
      expect(all.length, 1);
      expect(all.first['name'], 'Friend Updated');

      await DB.instance.deleteContact('friend@routine.app');
      final afterDelete = await DB.instance.getAllContacts();
      expect(afterDelete, isEmpty);
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

    test('basico prevents adding new participants on update when none existed', () async {
      await seedUserPlan(PlanRules.basico);

      final id = await DB.instance.insertActivity(
        makeActivity(title: 'Sem participantes', participantes: []),
      );

      final current = Atividade.fromMap((await DB.instance.getActivityById(id))!);
      final changed = current.copyWith(
        participantes: [p('Novo', 'novo@routine.app')],
      );

      await DB.instance.updateActivity(changed);
      final updatedMap = await DB.instance.getActivityById(id);
      final updated = Atividade.fromMap(updatedMap!);
      expect(updated.participantes, isEmpty);
    });

    test('basico preserves existing participants from premium on update', () async {
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

      final current = Atividade.fromMap((await DB.instance.getActivityById(id))!);
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
    test('downgrade from premium to basico clears collaborative local data', () async {
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

    test('profile updates without plan change preserve collaborative local data', () async {
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
}

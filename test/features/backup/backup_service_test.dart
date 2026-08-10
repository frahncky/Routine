import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/features/backup/backup_service.dart';

// Testes puros de BackupService, sem tocar no sqlite real: os testes que
// exercitam DB.restoreCloudBackup / migracao de schema ficam em
// test/helper/database_helper_plan_rules_test.dart, que ja e o unico
// arquivo de teste com acesso ao arquivo Routine.db compartilhado pelo
// singleton DB — manter dois arquivos abrindo o mesmo arquivo sqlite em
// processos concorrentes (flutter test roda arquivos em paralelo) causa
// "database is locked".
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('BackupService push/fetch', () {
    test('pushActivity writes to users/{email}/backup_activities/{uuid}',
        () async {
      final service = BackupService(firestore: fakeFirestore);
      await service.pushActivity('owner@routine.app', {
        'id': 42,
        'uuid': 'abc-123',
        'title': 'Reuniao',
        'describe': '',
        'date': 0,
        'initHour': '09:00',
        'endtHour': '10:00',
        'participants': '[]',
        'status': 'Pendente',
        'repetirSemanalmente': 0,
        'diasDaSemana': '',
        'updated_at': 100,
      });

      final doc = await fakeFirestore
          .collection('users')
          .doc('owner@routine.app')
          .collection('backup_activities')
          .doc('abc-123')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['title'], 'Reuniao');
      // O id local nao deve vazar para o backup (nao e estavel entre
      // dispositivos).
      expect(doc.data()!.containsKey('id'), isFalse);
    });

    test('pushActivity does nothing without a uuid', () async {
      final service = BackupService(firestore: fakeFirestore);
      await service.pushActivity('owner@routine.app', {'title': 'Sem uuid'});

      final snapshot = await fakeFirestore
          .collection('users')
          .doc('owner@routine.app')
          .collection('backup_activities')
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test('fetchActivities returns docs with uuid populated from the doc id',
        () async {
      await fakeFirestore
          .collection('users')
          .doc('owner@routine.app')
          .collection('backup_activities')
          .doc('abc-123')
          .set({'title': 'Reuniao', 'updated_at': 100});

      final service = BackupService(firestore: fakeFirestore);
      final result = await service.fetchActivities('owner@routine.app');
      expect(result.single['uuid'], 'abc-123');
      expect(result.single['title'], 'Reuniao');
    });

    test('deleteActivityBackup removes the document', () async {
      await fakeFirestore
          .collection('users')
          .doc('owner@routine.app')
          .collection('backup_activities')
          .doc('abc-123')
          .set({'title': 'Reuniao'});

      final service = BackupService(firestore: fakeFirestore);
      await service.deleteActivityBackup('owner@routine.app', 'abc-123');

      final doc = await fakeFirestore
          .collection('users')
          .doc('owner@routine.app')
          .collection('backup_activities')
          .doc('abc-123')
          .get();
      expect(doc.exists, isFalse);
    });

    test('pushContactGroup stores memberEmails as an array', () async {
      final service = BackupService(firestore: fakeFirestore);
      await service.pushContactGroup(
        'owner@routine.app',
        uuid: 'group-1',
        name: 'Equipe',
        memberEmails: ['a@routine.app', 'b@routine.app'],
      );

      final doc = await fakeFirestore
          .collection('users')
          .doc('owner@routine.app')
          .collection('backup_contact_groups')
          .doc('group-1')
          .get();
      expect(doc.data()!['memberEmails'], ['a@routine.app', 'b@routine.app']);
    });
  });
}

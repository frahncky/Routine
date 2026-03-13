import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart' as app;
import 'package:routine/notifications/notifications.dart';

const bool _e2eRunEnabled =
    bool.fromEnvironment('E2E_RUN', defaultValue: false);
const String _e2eEmail = String.fromEnvironment('E2E_EMAIL');
const String _e2ePassword = String.fromEnvironment('E2E_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E Firebase: profile + notifications flow', (tester) async {
    if (!_e2eRunEnabled || _e2eEmail.isEmpty || _e2ePassword.isEmpty) {
      debugPrint(
        'E2E skipped. Use --dart-define=E2E_RUN=true '
        '--dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...',
      );
      return;
    }

    app.profileImagePickerOverride = null;
    var createdActivityId = 0;

    try {
      app.main();
      await _waitFor(
        tester,
        find.byType(MaterialApp),
        timeout: const Duration(seconds: 25),
      );

      await _loginIfNeeded(tester);
      await _openSettingsTab(tester);
      await _runProfileFlow(tester);
      createdActivityId = await _runNotificationsFlow(tester);
      await _signOut(tester);
    } finally {
      app.profileImagePickerOverride = null;
      if (createdActivityId > 0) {
        await DB.instance.deleteActivity(createdActivityId);
        await syncAllActivityNotifications();
      }
    }
  });
}

Future<void> _loginIfNeeded(WidgetTester tester) async {
  final loginEmailField = find.byKey(const Key('login_email_field'));
  if (loginEmailField.evaluate().isNotEmpty) {
    await tester.enterText(loginEmailField, _e2eEmail);
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      _e2ePassword,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
  }

  await _waitFor(
    tester,
    find.byKey(const Key('bottom_nav_item_3')),
    timeout: const Duration(seconds: 60),
  );
}

Future<void> _openSettingsTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bottom_nav_item_3')));
  await _waitFor(
    tester,
    find.byKey(const Key('settings_edit_name_button')),
    timeout: const Duration(seconds: 20),
  );
}

Future<void> _runProfileFlow(WidgetTester tester) async {
  final newName = 'E2E-${DateTime.now().millisecondsSinceEpoch % 100000}';

  await tester.tap(find.byKey(const Key('settings_edit_name_button')));
  await _waitFor(
    tester,
    find.byKey(const Key('settings_name_field')),
    timeout: const Duration(seconds: 8),
  );
  await tester.enterText(find.byKey(const Key('settings_name_field')), newName);
  await tester.tap(find.byKey(const Key('settings_edit_name_button')));

  await _waitForCondition(
    tester,
    () => app.currentUserProfileNotifier.value.name == newName,
    timeout: const Duration(seconds: 20),
  );
  expect(app.currentUserProfileNotifier.value.name, newName);

  final avatarPath = await _createTestAvatarFilePath();
  app.profileImagePickerOverride = () async => avatarPath;
  await tester.tap(find.byKey(const Key('settings_edit_photo_button')));

  await _waitForCondition(
    tester,
    () => app.currentUserProfileNotifier.value.avatarUrl == avatarPath,
    timeout: const Duration(seconds: 20),
  );
  expect(app.currentUserProfileNotifier.value.avatarUrl, avatarPath);
}

Future<int> _runNotificationsFlow(WidgetTester tester) async {
  final notificationsSwitch =
      find.byKey(const Key('settings_notifications_switch'));
  await _waitFor(
    tester,
    notificationsSwitch,
    timeout: const Duration(seconds: 10),
  );

  var switchWidget = tester.widget<Switch>(notificationsSwitch);
  if (!switchWidget.value) {
    await tester.tap(notificationsSwitch);
    await _waitForCondition(
      tester,
      () => tester.widget<Switch>(notificationsSwitch).value,
      timeout: const Duration(seconds: 8),
    );
  }

  final minutesField = find.byKey(const Key('settings_minutes_before_field'));
  await _waitFor(tester, minutesField, timeout: const Duration(seconds: 10));
  await tester.enterText(minutesField, '1');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump(const Duration(milliseconds: 600));

  final start = DateTime.now().add(const Duration(minutes: 5));
  final end = start.add(const Duration(minutes: 30));
  final activity = Atividade(
    id: 0,
    titulo: 'E2E Notification',
    descricao: 'validacao automatizada',
    data: DateTime(start.year, start.month, start.day),
    horaInicio: TimeOfDay(hour: start.hour, minute: start.minute),
    horaFim: TimeOfDay(hour: end.hour, minute: end.minute),
    status: AtividadeStatus.pendente,
    participantes: const [],
  );

  final activityId = await DB.instance.insertActivity(activity);
  await syncAllActivityNotifications();

  final pendingAfterSchedule = await debugPendingNotificationCount();
  expect(
    pendingAfterSchedule,
    greaterThanOrEqualTo(1),
    reason: 'Expected at least one pending notification after scheduling.',
  );

  await tester.tap(notificationsSwitch);
  await _waitForCondition(
    tester,
    () => !tester.widget<Switch>(notificationsSwitch).value,
    timeout: const Duration(seconds: 8),
  );
  final pendingAfterDisable = await debugPendingNotificationCount();
  expect(
    pendingAfterDisable,
    0,
    reason: 'Expected no pending notifications after disabling notifications.',
  );

  return activityId;
}

Future<void> _signOut(WidgetTester tester) async {
  final signOutText = find.text('Sair');
  if (signOutText.evaluate().isNotEmpty) {
    await tester.tap(signOutText);
  } else {
    await FirebaseAuth.instance.signOut();
    await DB.instance.clearLocalData();
  }

  await _waitFor(
    tester,
    find.byKey(const Key('login_email_field')),
    timeout: const Duration(seconds: 25),
  );
}

Future<String> _createTestAvatarFilePath() async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/routine_e2e_avatar.png');
  await file.writeAsBytes(_onePixelPng, flush: true);
  return file.path;
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for finder: $finder');
}

Future<void> _waitForCondition(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (condition()) return;
  }
  throw TestFailure('Timed out waiting for condition to be true.');
}

const List<int> _onePixelPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  255,
  255,
  63,
  0,
  5,
  254,
  2,
  254,
  167,
  115,
  129,
  203,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

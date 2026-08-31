import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart' as app;

const bool _enabled =
    bool.fromEnvironment('PLAY_STORE_SCREENSHOTS', defaultValue: false);
const _notificationsChannel =
    MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('gera as seis capturas atuais da Play Store', (tester) async {
    expect(
      _enabled,
      isTrue,
      reason: 'Use --dart-define=PLAY_STORE_SCREENSHOTS=true. Essa protecao '
          'evita limpar o banco local de uma instalacao comum.',
    );
    _mockNotifications();
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_notificationsChannel, null);
    });

    await Firebase.initializeApp();
    expect(
      FirebaseAuth.instance.currentUser,
      isNull,
      reason: 'Use um emulador de teste sem sessao autenticada. A automacao '
          'nao encerra sessoes nem acessa contas reais.',
    );

    var ownsDatabase = false;
    addTearDown(() async {
      if (ownsDatabase) await DB.instance.clearLocalData();
    });
    await DB.instance.clearLocalData();
    ownsDatabase = true;
    await _seedDatabase(DateTime.now());

    await tester.pumpWidget(const ProviderScope(child: app.MyApp()));
    await _waitFor(tester, find.text('Revisar prioridades'), seconds: 25);
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await _shot(binding, tester, '01-home-atividades-do-dia');
    await _openTab(tester, 1, find.text('Por dia'));
    await _shot(binding, tester, '04-historico-de-atividades');

    await _openPopulatedForm(tester);
    await _shot(binding, tester, '02-cadastro-de-atividade');
    await _back(tester);
    // A lista do Progresso ficou rolada durante _openPopulatedForm; o cabeçalho
    // "Por dia" é um sliver lazy no topo, então precisa voltar ao topo.
    final progressoList = find.byType(CustomScrollView).hitTestable();
    for (var i = 0; i < 8 && find.text('Por dia').evaluate().isEmpty; i++) {
      if (progressoList.evaluate().isEmpty) break;
      await tester.drag(progressoList.first, const Offset(0, 1400));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _waitFor(tester, find.text('Por dia'));

    await _openTab(
      tester,
      3,
      find.byKey(const Key('settings_profile_avatar')),
    );
    await _waitFor(tester, find.text('Configurações'));
    await _shot(binding, tester, '05-configuracoes-e-perfil');

    await _align(tester, find.text('Gerenciar'));
    await tester.tap(find.text('Gerenciar'));
    await _waitFor(tester, find.text('Escolha como usar o Routine'));
    await _align(tester, find.text('Básico'));
    await _shot(binding, tester, '06-planos-e-recursos');
    await _back(tester);
    await _waitFor(tester, find.text('Configurações'));

    await _align(tester, find.text('Lembretes'));
    await _waitFor(
      tester,
      find.byKey(const Key('settings_notifications_switch')),
    );
    await _shot(binding, tester, '03-lembretes-e-notificacoes');
  });
}

void _mockNotifications() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_notificationsChannel, (call) async {
    switch (call.method) {
      case 'initialize':
      case 'requestNotificationsPermission':
      case 'requestExactAlarmsPermission':
      case 'canScheduleExactNotifications':
      case 'areNotificationsEnabled':
        return true;
      case 'pendingNotificationRequests':
      case 'getActiveNotifications':
        return <Map<String, Object?>>[];
      default:
        return null;
    }
  });
}

Future<void> _seedDatabase(DateTime runAt) async {
  final today = DateTime(runAt.year, runAt.month, runAt.day);
  final currentMinutes = runAt.hour * 60 + runAt.minute;
  final focusStart = currentMinutes.clamp(7 * 60, 21 * 60);
  final updatedAt = runAt.millisecondsSinceEpoch;
  final activities = <_Fixture>[
    _Fixture(
      'Revisar prioridades',
      'Organizar as três entregas mais importantes do dia.',
      today,
      '08:00',
      '08:30',
      'Pendente',
      '10',
    ),
    _Fixture(
      'Sessão de foco',
      'Avançar no projeto sem interrupções por 45 minutos.',
      today,
      _time(focusStart),
      _time(focusStart + 45),
      'Pendente',
      '10,30',
    ),
    _Fixture(
      'Caminhada ao ar livre',
      'Pausa para respirar, caminhar e renovar a energia.',
      today,
      '18:00',
      '18:40',
      'Pendente',
      '30',
    ),
    _Fixture(
      'Alongamento matinal',
      'Mobilidade leve para começar o dia com disposição.',
      today,
      '07:00',
      '07:20',
      'Concluida',
      '',
    ),
    _Fixture(
      'Leitura e aprendizado',
      'Trinta minutos de leitura do livro da semana.',
      today,
      '12:30',
      '13:00',
      'Concluida',
      '',
    ),
    _Fixture(
      'Planejamento concluído',
      'Revisar agenda, metas e próximos passos da rotina.',
      today,
      '20:00',
      '20:30',
      'Concluida',
      '10',
    ),
    _Fixture(
      'Treino funcional',
      'Sessão curta para manter consistência e bem-estar.',
      today.subtract(const Duration(days: 1)),
      '07:30',
      '08:15',
      'Concluida',
      '',
    ),
    _Fixture(
      'Meditação guiada',
      'Dez minutos de presença antes de iniciar as tarefas.',
      today.subtract(const Duration(days: 2)),
      '07:00',
      '07:10',
      'Concluida',
      '',
    ),
    _Fixture(
      'Revisão semanal',
      'Atividade remarcada para a próxima semana.',
      today.subtract(const Duration(days: 3)),
      '17:00',
      '17:30',
      'Cancelada',
      '',
    ),
  ];

  final database = await DB.instance.database;
  await database.transaction((transaction) async {
    await transaction.insert('user', {
      'name': 'Marina Alves',
      'email': 'marina.demo@routine.local',
      'avatarUrl': '',
      'typeAccount': 'gratuito',
      'authProvider': 'screenshot-fixture',
    });
    await transaction.insert('config', {
      'key': 'notificacoesAtivas',
      'value': 'true',
    });
    await transaction.insert('config', {
      'key': 'minutosAntesNotificacao',
      'value': '15',
    });

    for (var index = 0; index < activities.length; index++) {
      final activity = activities[index];
      await transaction.insert('activity', {
        'title': activity.title,
        'describe': activity.description,
        'date': activity.date.millisecondsSinceEpoch,
        'initHour': activity.start,
        'endtHour': activity.end,
        'participants': jsonEncode(const <Object>[]),
        'status': activity.status,
        'repetirSemanalmente': 0,
        'diasDaSemana': '',
        'uuid': 'play-store-$updatedAt-$index',
        'updated_at': updatedAt,
        'reminder_minutes': activity.reminders,
      });
    }
  });
}

String _time(int totalMinutes) {
  final hour = totalMinutes ~/ 60;
  final minute = totalMinutes % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

Future<void> _openTab(
  WidgetTester tester,
  int index,
  Finder ready,
) async {
  final tab = find.byKey(Key('bottom_nav_item_$index'));
  await _waitFor(tester, tab);
  await tester.tap(tab);
  await tester.pump(const Duration(milliseconds: 700));
  await _waitFor(tester, ready);
}

/// Volta uma tela sem depender do tooltip em inglês ("Back") que o
/// `tester.pageBack()` procura — o app roda em pt-BR e o tooltip é "Voltar".
Future<void> _back(WidgetTester tester) async {
  final candidates = <Finder>[
    find.byType(BackButton),
    find.byTooltip('Voltar'),
    find.byTooltip('Back'),
    find.widgetWithIcon(IconButton, Icons.arrow_back),
    find.widgetWithIcon(IconButton, Icons.arrow_back_ios),
    find.widgetWithIcon(IconButton, Icons.close),
  ];
  for (final finder in candidates) {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 650));
      return;
    }
  }
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
  navigator.pop();
  await tester.pump(const Duration(milliseconds: 650));
}

Future<void> _openPopulatedForm(WidgetTester tester) async {
  final reuse = find.byTooltip('Reutilizar');
  final expanders = find.byTooltip('Mostrar detalhes');
  final progress = find.byType(CustomScrollView).hitTestable();

  // No redesign, as ações do card (incl. "Reutilizar") ficam dentro do card
  // expandido. Abrir um card concluído — rolando a lista quando não houver
  // nenhum chevron "Mostrar detalhes" visível.
  for (var attempt = 0; attempt < 16 && reuse.evaluate().isEmpty; attempt++) {
    final expander = expanders.hitTestable();
    if (expander.evaluate().isNotEmpty) {
      await tester.ensureVisible(expander.first);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(expander.first);
      await tester.pump(const Duration(milliseconds: 450));
    } else {
      await tester.drag(progress, const Offset(0, -320));
      await tester.pump(const Duration(milliseconds: 350));
    }
  }
  expect(
    reuse,
    findsWidgets,
    reason: 'Uma atividade concluída deveria oferecer Reutilizar.',
  );
  await tester.ensureVisible(reuse.first);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(reuse.first);
  await _waitFor(tester, find.text('Cadastrar Atividade'));
  await _waitFor(tester, find.text('Descrição'));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _align(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      280,
      scrollable: find.byType(Scrollable).hitTestable().first,
      maxScrolls: 12,
    );
  }
  await _waitFor(tester, finder);
  await Scrollable.ensureVisible(
    tester.element(finder.first),
    alignment: 0.08,
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
  );
  await tester.pump(const Duration(milliseconds: 550));
}

Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 450));
  await binding.takeScreenshot(name);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  int seconds = 15,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Tempo esgotado aguardando: $finder');
}

class _Fixture {
  const _Fixture(
    this.title,
    this.description,
    this.date,
    this.start,
    this.end,
    this.status,
    this.reminders,
  );

  final String title;
  final String description;
  final DateTime date;
  final String start;
  final String end;
  final String status;
  final String reminders;
}

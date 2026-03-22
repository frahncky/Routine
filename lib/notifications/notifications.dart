import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
bool _notificationsInitialized = false;
Future<void>? _notificationsInitInFlight;

const _activityChannelId = 'atividades_channel_v2';
const _activityChannelName = 'Atividades';
const _activityChannelDescription = 'Notificações de atividades agendadas';

Future<void> initNotifications() async {
  if (_notificationsInitialized) return;
  final inFlight = _notificationsInitInFlight;
  if (inFlight != null) {
    await inFlight;
    return;
  }

  final initFuture = _initNotificationsInternal();
  _notificationsInitInFlight = initFuture;
  try {
    await initFuture;
    _notificationsInitialized = true;
  } finally {
    if (identical(_notificationsInitInFlight, initFuture)) {
      _notificationsInitInFlight = null;
    }
  }
}

Future<void> _initNotificationsInternal() async {
  tzdata.initializeTimeZones();

  const initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettingsDarwin = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        _activityChannelId,
        _activityChannelName,
        description: _activityChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await androidImplementation.requestNotificationsPermission();
    final canScheduleExact =
        await androidImplementation.canScheduleExactNotifications();
    if (canScheduleExact != true) {
      await androidImplementation.requestExactAlarmsPermission();
    }
  }
}

Future<void> syncAllActivityNotifications() async {
  try {
    await initNotifications();
    final notificationsEnabled =
        await DB.instance.getConfig('notificacoesAtivas');
    final minutesRaw = await DB.instance.getConfig('minutosAntesNotificacao');
    final minutesBefore = int.tryParse(minutesRaw ?? '') ?? 10;

    await flutterLocalNotificationsPlugin.cancelAll();

    if (notificationsEnabled == 'false' || minutesBefore <= 0) {
      return;
    }

    final maps = await DB.instance.getActivitiesByStatus(
      status: [
        AtividadeStatus.pendente,
        AtividadeStatus.andamento,
        AtividadeStatus.atrasada,
        'Ativa',
      ],
    );

    for (final map in maps) {
      final activity = Atividade.fromMap(map);
      try {
        await _scheduleActivityNotification(
          activity,
          minutesBefore: minutesBefore,
        );
      } catch (e) {
        debugPrint(
            'Falha ao agendar notificacao da atividade ${activity.id}: $e');
      }
    }
  } catch (e) {
    debugPrint('Falha ao sincronizar notificacoes: $e');
  }
}

Future<void> syncActivityNotification(Atividade activity) async {
  try {
    await initNotifications();
    final notificationsEnabled =
        await DB.instance.getConfig('notificacoesAtivas');
    final minutesRaw = await DB.instance.getConfig('minutosAntesNotificacao');
    final minutesBefore = int.tryParse(minutesRaw ?? '') ?? 10;

    await cancelarNotificacaoAtividade(activity.id);

    if (notificationsEnabled == 'false' || minutesBefore <= 0) {
      return;
    }

    await _scheduleActivityNotification(
      activity,
      minutesBefore: minutesBefore,
    );
  } catch (e) {
    debugPrint(
        'Falha ao sincronizar notificacao da atividade ${activity.id}: $e');
  }
}

Future<void> agendarNotificacaoAtividade({
  required int id,
  required String titulo,
  required DateTime inicioAtividade,
  required int minutosAntes,
}) async {
  final scheduledDate =
      inicioAtividade.subtract(Duration(minutes: minutosAntes));
  if (!scheduledDate.isAfter(DateTime.now())) {
    return;
  }

  final scheduledUtc = tz.TZDateTime.from(scheduledDate.toUtc(), tz.UTC);
  final scheduleMode = await _resolveAndroidScheduleMode();
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Atividade em breve',
    'Sua atividade "$titulo" começa em $minutosAntes minutos.',
    scheduledUtc,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _activityChannelId,
        _activityChannelName,
        channelDescription: _activityChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentSound: true,
      ),
    ),
    androidScheduleMode: scheduleMode,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> cancelarNotificacaoAtividade(int id) async {
  await flutterLocalNotificationsPlugin.cancel(id);
}

Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
  final androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation == null) {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  final canScheduleExact =
      await androidImplementation.canScheduleExactNotifications();
  if (canScheduleExact == true) {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }
  return AndroidScheduleMode.inexactAllowWhileIdle;
}

Future<int> debugPendingNotificationCount() async {
  try {
    await initNotifications();
    final pending =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return pending.length;
  } catch (e) {
    debugPrint('Falha ao obter notificacoes pendentes: $e');
    return -1;
  }
}

Future<void> _scheduleActivityNotification(
  Atividade activity, {
  required int minutesBefore,
}) async {
  final nextStart = await _nextOccurrenceStart(activity);
  if (nextStart == null) {
    await cancelarNotificacaoAtividade(activity.id);
    return;
  }

  await agendarNotificacaoAtividade(
    id: activity.id,
    titulo: activity.titulo,
    inicioAtividade: nextStart,
    minutosAntes: minutesBefore,
  );
}

Future<DateTime?> _nextOccurrenceStart(Atividade activity,
    {DateTime? now}) async {
  final reference = now ?? DateTime.now();
  final normalizedStatus = AtividadeStatus.normalize(activity.status);
  if (normalizedStatus == AtividadeStatus.concluida ||
      normalizedStatus == AtividadeStatus.cancelada) {
    return null;
  }

  DateTime buildStart(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      activity.horaInicio.hour,
      activity.horaInicio.minute,
    );
  }

  if (!activity.repetirSemanalmente || activity.diasDaSemana.isEmpty) {
    final start = buildStart(activity.data);
    return start.isAfter(reference) ? start : null;
  }

  final firstPossibleDay = DateTime(
    activity.data.year,
    activity.data.month,
    activity.data.day,
  );
  var searchDay = DateTime(reference.year, reference.month, reference.day);
  if (searchDay.isBefore(firstPossibleDay)) {
    searchDay = firstPossibleDay;
  }

  for (var i = 0; i < 14; i++) {
    final candidateDay = searchDay.add(Duration(days: i));
    if (!activity.diasDaSemana.contains(candidateDay.weekday)) {
      continue;
    }

    if (await _isOccurrenceBlockedByException(activity, candidateDay)) {
      continue;
    }

    final start = buildStart(candidateDay);
    if (start.isAfter(reference)) {
      return start;
    }
  }

  return null;
}

Future<bool> _isOccurrenceBlockedByException(
  Atividade activity,
  DateTime candidateDay,
) async {
  final exceptions =
      await DB.instance.getActivityExceptionsForDay(candidateDay);

  for (final exception in exceptions) {
    final activityId = exception['atividade_id'];
    if (activityId != activity.id) {
      continue;
    }

    final type = exception['tipo']?.toString().toLowerCase();
    if (type == 'excluida') {
      return true;
    }

    if (type != 'editada') {
      continue;
    }

    final rawFields = exception['campos_editados']?.toString();
    if (rawFields == null || rawFields.isEmpty) {
      continue;
    }

    final normalizedFields = rawFields.toLowerCase();
    if (normalizedFields.contains('concluida') ||
        normalizedFields.contains('cancelada')) {
      return true;
    }
  }

  return false;
}

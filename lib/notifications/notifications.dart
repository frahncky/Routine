import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tzdata.initializeTimeZones();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> agendarNotificacaoAtividade({
  required int id,
  required String titulo,
  required DateTime inicioAtividade,
  required int minutosAntes,
}) async {
  final scheduledDate = inicioAtividade.subtract(Duration(minutes: minutosAntes));
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Atividade em breve',
    'Sua atividade "$titulo" começa em $minutosAntes minutos!',
    tz.TZDateTime.from(scheduledDate, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'atividades_channel',
        'Atividades',
        channelDescription: 'Notificações de atividades agendadas',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );
}

Future<void> cancelarNotificacaoAtividade(int id) async {
  await flutterLocalNotificationsPlugin.cancel(id);
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/notifications/notifications.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/theme/app_theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Notificador global para notificações.
final notificacoesAtivasNotifier = ValueNotifier<bool>(true);

// ValueNotifiers separados.
final changeName = ValueNotifier(false);
final changeAvatar = ValueNotifier(false);
final changeHome = ValueNotifier(false);
final planChangeNotifier = ValueNotifier<int>(0);

// MergeListenable controlado por contador para não perder eventos.
final mergedChange =
    MergeListenable([changeName, changeAvatar, changeHome, planChangeNotifier]);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final ativo = await DB.instance.getConfig('notificacoesAtivas');
  notificacoesAtivasNotifier.value = ativo == null ? true : ativo == 'true';
  await initNotifications();
  await syncAllActivityNotifications();
  runApp(const MyApp());
}

class MergeListenable extends ValueNotifier<int> {
  final List<Listenable> listenables;

  MergeListenable(this.listenables) : super(0) {
    for (final l in listenables) {
      l.addListener(_onChange);
    }
  }

  void _onChange() {
    value++;
  }

  void markChanged() {
    value++;
  }

  @override
  void dispose() {
    for (final l in listenables) {
      l.removeListener(_onChange);
    }
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Routine',
      theme: AppTheme.light,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('pt'),
      ],
      home: AuthWrapper(),
    );
  }
}

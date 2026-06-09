import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/notifications/notifications.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/theme/app_theme.dart';
import 'package:routine/l10n/app_localizations.dart';
import 'package:routine/testing/e2e_hooks.dart';

export 'package:routine/testing/e2e_hooks.dart'
  show currentUserProfileNotifier, profileImagePickerOverride;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    _configureCrashlytics();
    runApp(const ProviderScope(child: MyApp()));
    unawaited(_bootstrapAppServices());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    debugPrint('Erro não tratado: $error');
    debugPrintStack(stackTrace: stack);
  });
}

void _configureCrashlytics() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
}

Future<void> _bootstrapAppServices() async {
  await _initializeNotificationsSafely();
}

Future<void> _initializeNotificationsSafely() async {
  try {
    await initNotifications();
    await syncAllActivityNotifications();
  } catch (e) {
    debugPrint('Falha ao inicializar notificações: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    currentUserProfileNotifier.value = profile;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Routine',
      theme: AppTheme.light,
      locale: const Locale('pt', 'BR'),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale == null) return const Locale('pt', 'BR');
        for (final supported in supportedLocales) {
          if (supported.languageCode == deviceLocale.languageCode) {
            return supported;
          }
        }
        return const Locale('pt', 'BR');
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en'),
        Locale('pt'),
      ],
      home: const AuthWrapper(),
    );
  }
}

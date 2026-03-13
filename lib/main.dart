import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
final currentUserProfileNotifier =
    ValueNotifier(const CurrentUserProfile(name: 'Sem nome', avatarUrl: null));

// MergeListenable controlado por contador para não perder eventos.
final mergedChange =
    MergeListenable([changeName, changeAvatar, changeHome, planChangeNotifier]);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final ativo = await DB.instance.getConfig('notificacoesAtivas');
  notificacoesAtivasNotifier.value = ativo == null ? true : ativo == 'true';
  await refreshCurrentUserProfile();
  await initNotifications();
  await syncAllActivityNotifications();
  runApp(const MyApp());
}

class CurrentUserProfile {
  const CurrentUserProfile({
    required this.name,
    required this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;

  static const Object _unset = Object();

  CurrentUserProfile copyWith({
    String? name,
    Object? avatarUrl = _unset,
  }) {
    return CurrentUserProfile(
      name: name ?? this.name,
      avatarUrl: avatarUrl == _unset ? this.avatarUrl : avatarUrl as String?,
    );
  }
}

Future<void> refreshCurrentUserProfile() async {
  final local = await DB.instance.getUser();
  if (local != null) {
    currentUserProfileNotifier.value = CurrentUserProfile(
      name: _normalizeProfileName(local['name']?.toString()),
      avatarUrl: _normalizeAvatarUrl(local['avatarUrl']?.toString()),
    );
    return;
  }

  final usuario = FirebaseAuth.instance.currentUser;
  currentUserProfileNotifier.value = CurrentUserProfile(
    name: _normalizeProfileName(usuario?.displayName),
    avatarUrl: _normalizeAvatarUrl(usuario?.photoURL),
  );
}

void updateCurrentUserProfile({
  String? name,
  Object? avatarUrl = CurrentUserProfile._unset,
}) {
  currentUserProfileNotifier.value = currentUserProfileNotifier.value.copyWith(
    name: name,
    avatarUrl: avatarUrl,
  );
}

void clearCurrentUserProfile() {
  currentUserProfileNotifier.value =
      const CurrentUserProfile(name: 'Sem nome', avatarUrl: null);
}

String _normalizeProfileName(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Sem nome' : trimmed;
}

String? _normalizeAvatarUrl(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
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

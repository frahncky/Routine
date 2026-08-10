import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main_tabs.dart';
import 'package:routine/providers/app_providers.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  String? _lastSyncedUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.hasError
            ? null
            : (snapshot.data ?? FirebaseAuth.instance.currentUser);
        if (user != null) {
          _syncProfileIfNeeded(user);
        } else {
          _clearSyncedProfileState();
        }
        return const MainTabs();
      },
    );
  }

  void _syncProfileIfNeeded(User? user) {
    final uid = user?.uid;
    if (uid == null || uid == _lastSyncedUid) return;

    _lastSyncedUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(userProfileProvider.notifier).refresh();
      } catch (_) {}
      await _offerCloudRestoreIfNeeded();
    });
  }

  void _clearSyncedProfileState() {
    if (_lastSyncedUid == null) return;
    _lastSyncedUid = null;
    ref.read(userProfileProvider.notifier).clear();
  }

  // Se a conta tem backup em nuvem e o dispositivo esta "vazio" (instalacao
  // nova/reinstalada), oferece restaurar os dados uma vez por sessao.
  Future<void> _offerCloudRestoreIfNeeded() async {
    try {
      final userMap = await DB.instance.getUser();
      final plan = PlanRules.normalize(userMap?['typeAccount']?.toString());
      if (!PlanRules.hasCloudBackup(plan)) return;
      if (await DB.instance.hasAnyActivities()) return;
      if (!mounted) return;

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restaurar dados da nuvem?'),
          content: const Text(
            'Encontramos um backup na nuvem para esta conta. Deseja restaurar suas atividades neste dispositivo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (shouldRestore == true) {
        await DB.instance.restoreCloudBackup();
        if (!mounted) return;
        ref.read(appChangeProvider.notifier).state++;
      }
    } catch (_) {}
  }
}

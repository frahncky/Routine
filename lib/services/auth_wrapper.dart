import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    });
  }

  void _clearSyncedProfileState() {
    if (_lastSyncedUid == null) return;
    _lastSyncedUid = null;
    ref.read(userProfileProvider.notifier).clear();
  }
}

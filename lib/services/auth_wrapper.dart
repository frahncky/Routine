import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:routine/main.dart';
import 'package:routine/main_tabs.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
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
        await refreshCurrentUserProfile();
      } catch (_) {
        // Ignore profile sync failures here to avoid auth flow disruption.
      }
    });
  }

  void _clearSyncedProfileState() {
    if (_lastSyncedUid == null) return;
    _lastSyncedUid = null;
    clearCurrentUserProfile();
  }
}

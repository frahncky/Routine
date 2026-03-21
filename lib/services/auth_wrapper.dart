import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/login/login_screen.dart';
import 'package:routine/main.dart';
import 'package:routine/main_tabs.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  String? _lastSyncedUid;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        final googleUser = await GoogleSignIn().signInSilently();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await FirebaseAuth.instance.signInWithCredential(credential);
        }
      }
    } catch (_) {
      // Silent auto-login failures should not delete user data.
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          )
        : StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text('Erro ao verificar autenticacao')),
                );
              }

              if (snapshot.hasData) {
                _syncProfileIfNeeded(snapshot.data);
                return const MainTabs();
              }

              _clearSyncedProfileState();
              return const LoginScreen();
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

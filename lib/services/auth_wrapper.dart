import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/login/login_screen.dart';
import 'package:routine/main_tabs.dart';

class AuthWrapper extends StatefulWidget {
  AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;

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
        ? Scaffold(
            body: Center(child: CircularProgressIndicator()),
          )
        : StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('Erro ao verificar autenticacao')),
                );
              } else if (snapshot.hasData) {
                return MainTabs();
              } else {
                return LoginScreen();
              }
            },
          );
  }
}


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/widgets/show_snackbar.dart';

class Verifyemail extends StatefulWidget {
  const Verifyemail({super.key});

  @override
  State<Verifyemail> createState() => _VerifyemailState();
}

class _VerifyemailState extends State<Verifyemail> {
  @override
  void initState() {
    super.initState();
    _sendVerifyLink();
  }

  Future<void> _sendVerifyLink() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Link enviado para o seu e-mail',
        message: 'Verifique seu e-mail para confirmar a conta.',
        backgroundColor: Colors.blue.shade700,
        icon: Icons.email,
      );
    } catch (_) {}
  }

  Future<void> _reload() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificação de e-mail')),
      body: const Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: Text('Abra seu e-mail para obter o link de verificação'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reload,
        child: const Icon(Icons.restart_alt_rounded),
      ),
    );
  }
}

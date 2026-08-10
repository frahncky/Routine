import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/login/login_screen.dart';

class Forgot extends StatefulWidget {
  const Forgot({super.key});

  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      showSnackbar(
        context: context,
        title: 'Erro',
        message: 'Informe o e-mail para recuperação.',
        variant: SnackbarVariant.error,
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _email.text.trim());
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Recuperação de senha',
        message: 'Um link foi enviado para o seu e-mail.',
        variant: SnackbarVariant.warning,
        icon: Icons.check_circle,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Erro',
        message: e.message ?? 'Falha ao enviar link de recuperação.',
        variant: SnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperação de senha')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(hintText: 'Entre com o e-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _resetPassword,
              child: const Text('Enviar link'),
            ),
          ],
        ),
      ),
    );
  }
}

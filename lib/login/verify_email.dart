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
        variant: SnackbarVariant.info,
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verificação de e-mail')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 44,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Confirme seu e-mail',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Abra seu e-mail para obter o link de verificação. Depois de confirmar, toque em atualizar.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Já confirmei, atualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

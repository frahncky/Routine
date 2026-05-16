import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/services/auth_wrapper.dart';

class Signup extends StatefulWidget {
  const Signup({super.key, this.redirectAfterSignup});

  final Widget? redirectAfterSignup;

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final TextEditingController nameUser = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  @override
  void dispose() {
    nameUser.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    if (nameUser.text.isEmpty || email.text.isEmpty || password.text.isEmpty) {
      showSnackbar(
        context: context,
        title: 'Campos obrigatórios',
        message: 'Preencha todos os campos.',
        backgroundColor: Colors.orange.shade700,
        icon: Icons.warning,
      );
      return;
    }

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      await userCredential.user?.updateDisplayName(nameUser.text.trim());
      await userCredential.user?.reload();

      await DB.instance.createAccount(
        nameUser.text.trim(),
        email.text.trim(),
        userCredential.user?.photoURL ?? '',
        'email',
      );

      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Conta criada',
        message: 'Sua conta foi criada com sucesso.',
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => widget.redirectAfterSignup ?? const AuthWrapper(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Este e-mail já está em uso.';
          break;
        case 'invalid-email':
          message = 'E-mail inválido.';
          break;
        case 'weak-password':
          message = 'A senha deve ter pelo menos 6 caracteres.';
          break;
        default:
          message = 'Erro: ${e.message}';
      }
      showSnackbar(
        context: context,
        title: 'Erro no cadastro',
        message: message,
        backgroundColor: Colors.red.shade400,
        icon: Icons.error,
      );
    } catch (e) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Erro inesperado',
        message: e.toString(),
        backgroundColor: Colors.red.shade400,
        icon: Icons.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo cadastro')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: nameUser,
              decoration: const InputDecoration(hintText: 'Nome de usuário'),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: email,
              decoration: const InputDecoration(hintText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: password,
              decoration: const InputDecoration(hintText: 'Senha'),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => signup(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: signup,
              child: const Text('Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}

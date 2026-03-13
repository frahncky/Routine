import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/login/login_screen.dart';
import 'package:get/get.dart';

class Forgot extends StatefulWidget {
  const Forgot({super.key});

  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  final TextEditingController email = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    if (email.text.trim().isEmpty) {
      showSnackbar(
        title: "Erro",
        message: "Informe o e-mail para recuperação.",
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.text.trim());

      showSnackbar(
        title: "Recuperação de senha",
        message: "Um link foi enviado para o seu e-mail.",
        backgroundColor: Colors.orange.shade200,
        icon: Icons.check_circle,
      );

      Get.offAll(() =>  LoginScreen());
    } on FirebaseAuthException catch (e) {
      showSnackbar(
        title: "Erro",
        message: e.message ?? "Falha ao enviar link de recuperação.",
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text('Recuperação de senha')),
      body: Padding(
        padding:  EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: email,
              decoration:  InputDecoration(hintText: 'Entre com o e-mail'),
              keyboardType: TextInputType.emailAddress,
            ),
             SizedBox(height: 20),
            ElevatedButton(
              onPressed: resetPassword,
              child:  Text('Enviar link'),
            ),
          ],
        ),
      ),
    );
  }
}

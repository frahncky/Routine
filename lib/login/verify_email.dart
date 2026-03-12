import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:routine/services/auth_wrapper.dart';

class Verifyemail extends StatefulWidget {
  const Verifyemail({super.key});

  @override
  State<Verifyemail> createState() => _VerifyemailState();
}

class _VerifyemailState extends State<Verifyemail> {
  @override
  void initState() {
    sendverifylink();
    super.initState();
  }

  sendverifylink() async {
    final user = FirebaseAuth.instance.currentUser!;
    await user.sendEmailVerification().then((value) => {
          Get.snackbar(
              "Link enviado para o seu e-mail",
              "Verifique seu e-mail para confirmar a conta.",
              margin: EdgeInsets.all(30),
              snackPosition: SnackPosition.BOTTOM,),
        });
  }

  reload() async {
    await FirebaseAuth.instance.currentUser!
        .reload()
        .then((value) => {Get.offAll(AuthWrapper())});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Verificação de e-mail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Text("Abra seu e-mail para obter o link de verificação"),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (() => reload()),
        child: Icon(Icons.restart_alt_rounded),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/services/auth_wrapper.dart';

class Signup extends StatefulWidget {
   Signup({super.key});

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
    // Verificar se todos os campos foram preenchidos
    if (nameUser.text.isEmpty || email.text.isEmpty || password.text.isEmpty) {
      Get.snackbar(
        "Campos obrigatórios",
        "Preencha todos os campos.",
        snackPosition: SnackPosition.BOTTOM,
        margin:  EdgeInsets.all(30),
      );
      return;
    }

    try {
      // Criar o usuário no Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      // Atualizar o nome do usuário no Firebase Auth
      await userCredential.user?.updateDisplayName(nameUser.text.trim());
      await userCredential.user?.reload();

      // Criar o usuário no banco de dados local (SQLite)
      await DB.instance.createAccount(
        nameUser.text.trim(),
        email.text.trim(),
        '', // avatarUrl (deixar vazio por enquanto)
        'email', // authProvider (não será Google/Apple, portanto, "email")
      );

      // Exibir mensagem de sucesso
      showSnackbar(
        title: "Conta criada",
        message: "Sua conta foi criada com sucesso.",
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );

      // Redirecionar para a tela de autenticação
      Get.offAll(() =>  AuthWrapper());
    } on FirebaseAuthException catch (e) {
      // Erros de autenticação Firebase
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = "Este e-mail já está em uso.";
          break;
        case 'invalid-email':
          message = "E-mail inválido.";
          break;
        case 'weak-password':
          message = "A senha deve ter pelo menos 6 caracteres.";
          break;
        default:
          message = "Erro: ${e.message}";
      }

      // Exibir erro no cadastro
      Get.snackbar(
        "Erro no cadastro",
        message,
        snackPosition: SnackPosition.BOTTOM,
        margin:  EdgeInsets.all(30),
      );
    } catch (e) {
      // Erro inesperado
      Get.snackbar(
        "Erro inesperado",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin:  EdgeInsets.all(30),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:  Text('Novo cadastro')),
      body: Padding(
        padding:  EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Campo para o nome de usuário
            TextField(
              controller: nameUser,
              decoration:  InputDecoration(hintText: 'Nome de usuário'),
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            // Campo para o e-mail
            TextField(
              controller: email,
              decoration:  InputDecoration(hintText: 'E-mail'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            // Campo para a senha
            TextField(
              controller: password,
              decoration:  InputDecoration(hintText: 'Senha'),
              obscureText: true,
              textInputAction: TextInputAction.done,
            ),
             SizedBox(height: 20),
            // Botão de cadastro
            ElevatedButton(
              onPressed: signup,
              child:  Text('Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}

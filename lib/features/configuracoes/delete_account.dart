import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/login/login_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future<void> deleteAccount(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    showSnackbar(
      title: "Erro",
      message: "Nenhum usuário autenticado.",
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
    return;
  }

  // Exibe o único diálogo de confirmação para a exclusão da conta
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title:  Text('Tem certeza que deseja excluir sua conta?'),
      content:  Text('Esta ação não pode ser desfeita.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Cancelar
          child:  Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true), // Confirmar
          child:  Text('Confirmar'),
        ),
      ],
    ),
  );

  // Se o usuário confirmar, deleta a conta
  if (confirmar == true) {
    try {
      final provider = user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : '';

      switch (provider) {
        case 'password':
          await _deleteWithEmail(); // Deletar conta com email e senha
          break;
        case 'google.com':
          await _deleteWithGoogle(); // Deletar conta com Google
          break;
        case 'apple.com':
          await _deleteWithApple(); // Deletar conta com Apple
          break;
        default:
          throw Exception('Provedor não suportado: $provider');
      }

      await _onAccountDeleted(); // Ações após a exclusão
    } catch (e) {
      showSnackbar(
        title: "Erro",
        message: e.toString(),
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }
}

Future<void> _deleteWithEmail() async {
  final user = FirebaseAuth.instance.currentUser!;
  await user.delete(); // Deletar conta com email
}

Future<void> _deleteWithGoogle() async {
  final user = FirebaseAuth.instance.currentUser!;
  final googleUser = await GoogleSignIn().signIn();
  if (googleUser == null) throw Exception('Login com Google cancelado.');

  final googleAuth = await googleUser.authentication;
  final cred = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  await user.reauthenticateWithCredential(cred);
  await user.delete(); // Deletar conta com Google
}

Future<void> _deleteWithApple() async {
  final user = FirebaseAuth.instance.currentUser!;

  final appleCred = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email],
  );

  final oauthCred = OAuthProvider("apple.com").credential(
    idToken: appleCred.identityToken,
    accessToken: appleCred.authorizationCode,
  );

  await user.reauthenticateWithCredential(oauthCred);
  await user.delete(); // Deletar conta com Apple
}

Future<void> _onAccountDeleted() async {
  await DB.instance.deleteAccount();
  
  showSnackbar(
    title: "Conta deletada",
    message: "Sua conta foi deletada com sucesso!",
    backgroundColor: Colors.red.shade300,
    icon: Icons.check_circle,
  );
  Get.offAll(() =>  LoginScreen());
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future<void> deleteAccount(BuildContext context, WidgetRef ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    showSnackbar(
      context: context,
      title: 'Erro',
      message: 'Nenhum usuário autenticado.',
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
    return;
  }

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Tem certeza de que deseja excluir sua conta?'),
      content: const Text('Esta ação não pode ser desfeita.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );

  if (confirmar != true) return;
  if (!context.mounted) return;

  try {
    final provider = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    switch (provider) {
      case 'password':
        await _deleteWithEmail(context, user);
        break;
      case 'google.com':
        await _deleteWithGoogle(user);
        break;
      case 'apple.com':
        await _deleteWithApple(user);
        break;
      default:
        throw Exception('Provedor não suportado: $provider');
    }

    if (!context.mounted) return;
    await _onAccountDeleted(context, ref);
  } on FirebaseAuthException catch (e) {
    if (!context.mounted) return;
    final message = e.code == 'requires-recent-login'
        ? 'Reautentique para excluir a conta.'
        : (e.message ?? 'Falha ao excluir conta.');
    showSnackbar(
      context: context,
      title: 'Erro',
      message: message,
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
  } catch (e) {
    if (!context.mounted) return;
    showSnackbar(
      context: context,
      title: 'Erro',
      message: e.toString(),
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
  }
}

Future<void> _deleteWithEmail(BuildContext context, User user) async {
  final email = user.email;
  if (email == null || email.isEmpty) {
    throw Exception('Conta sem e-mail válido para reautenticação.');
  }

  final password = await _askPassword(context, email);
  if (password == null || password.isEmpty) {
    throw Exception('Exclusão cancelada.');
  }

  final credential =
      EmailAuthProvider.credential(email: email, password: password);
  await user.reauthenticateWithCredential(credential);
  await user.delete();
}

Future<void> _deleteWithGoogle(User user) async {
  final googleSignIn = GoogleSignIn.instance;
  await googleSignIn.initialize();

  late final GoogleSignInAccount googleUser;
  try {
    googleUser = await googleSignIn.authenticate();
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw Exception('Login com Google cancelado.');
    }
    rethrow;
  }

  final googleAuth = googleUser.authentication;
  final cred = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  await user.reauthenticateWithCredential(cred);
  await user.delete();
}

Future<void> _deleteWithApple(User user) async {
  final appleCred = await SignInWithApple.getAppleIDCredential(
    scopes: [AppleIDAuthorizationScopes.email],
  );

  final oauthCred = OAuthProvider('apple.com').credential(
    idToken: appleCred.identityToken,
    accessToken: appleCred.authorizationCode,
  );

  await user.reauthenticateWithCredential(oauthCred);
  await user.delete();
}

Future<String?> _askPassword(BuildContext context, String email) async {
  final controller = TextEditingController();
  bool obscure = true;

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Confirmar senha'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(email),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  onTapOutside: (_) => FocusScope.of(dialogContext).unfocus(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
    },
  );

  controller.dispose();
  return result;
}

Future<void> _onAccountDeleted(BuildContext context, WidgetRef ref) async {
  await DB.instance.deleteAccount();
  if (!context.mounted) return;
  ref.read(userProfileProvider.notifier).clear();

  showSnackbar(
    context: context,
    title: 'Conta excluída',
    message: 'Sua conta foi excluída com sucesso!',
    backgroundColor: Colors.red.shade300,
    icon: Icons.check_circle,
  );

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const AuthWrapper()),
    (route) => false,
  );
}

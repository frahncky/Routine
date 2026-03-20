import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/login/forgot.dart';
import 'package:routine/login/signup.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool isloading = false;
  bool showPassword = false;

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-mail invalido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      case 'network-request-failed':
        return 'Sem conexao. Verifique sua internet.';
      default:
        return 'Nao foi possivel autenticar agora.';
    }
  }

  String _resolveLocalEmail(User? user, {required String provider}) {
    final userEmail = user?.email?.trim();
    if (userEmail != null && userEmail.isNotEmpty) {
      return userEmail;
    }

    final uid = user?.uid.trim();
    if (uid != null && uid.isNotEmpty) {
      return '$uid@$provider.local';
    }

    return '';
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  // Função de login com email e senha
  Future<void> signIn() async {
    if (!mounted) return;
    setState(() => isloading = true);

    if (email.text.isEmpty || password.text.isEmpty) {
      showSnackbar(
        title: "Campos obrigatórios",
        message: "Preencha e-mail e senha",
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
      if (mounted) {
        setState(() => isloading = false);
      }
      return;
    }

    try {
      // Login com Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      final currentUser = FirebaseAuth.instance.currentUser;

      // Atualizar ou criar o usuário no banco de dados local (SQLite)
      await DB.instance.createAccount(
        currentUser?.displayName ?? '',
        email.text.trim(),
        currentUser?.photoURL ?? '',
        'email',
      );

      showSnackbar(
        title: "Login realizado",
        message: "Você entrou com sucesso!",
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );

      Get.offAll(() => AuthWrapper());
    } on FirebaseAuthException catch (e) {
      showSnackbar(
        title: "Erro no login",
        message: _authErrorMessage(e),
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
    } catch (_) {
      showSnackbar(
        title: "Erro no login",
        message: "Nao foi possivel realizar login agora.",
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() => isloading = false);
      }
    }
  }

  // Função de login com provedores (Google ou Apple)
  Future<void> loginWithProvider(String provider) async {
    if (!mounted) return;
    setState(() => isloading = true);

    try {
      UserCredential userCredential;

      if (provider == 'google') {
        // Login com Google
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          Get.snackbar("Aviso", "Login com Google cancelado.");
          return;
        }
        final GoogleSignInAuthentication? googleAuth =
            await googleUser.authentication;

        if (googleAuth?.accessToken == null || googleAuth?.idToken == null) {
          Get.snackbar("Erro", "Falha na autenticação com Google.");
          return;
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        // Login com Apple
        final appleCredentials = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName
          ],
        );
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredentials.identityToken,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      }

      await userCredential.user?.reload();

      final user = FirebaseAuth.instance.currentUser;
      final providerId =
          user?.providerData.first.providerId; // 'google.com' ou 'apple.com'
      final localProvider = providerId == 'google.com' ? 'google' : 'apple';
      final resolvedEmail =
          _resolveLocalEmail(user, provider: localProvider);

      if (resolvedEmail.isEmpty) {
        showSnackbar(
          title: "Erro",
          message: "Nao foi possivel obter um e-mail para sua conta.",
          backgroundColor: Colors.red.shade300,
          icon: Icons.error,
        );
        return;
      }

      // Atualizar ou criar o usuário no banco de dados local (SQLite)
      await DB.instance.createAccount(
        user?.displayName ?? '',
        resolvedEmail,
        user?.photoURL ?? '',
        localProvider,
      );

      // Exibir mensagem de sucesso
      showSnackbar(
        title: "Login realizado",
        message: "Você entrou com sucesso!",
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );

      // Navegar para a tela inicial
      Get.offAll(() => AuthWrapper());
    } on FirebaseAuthException catch (e) {
      showSnackbar(
        title: "Erro",
        message: _authErrorMessage(e),
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
    } catch (_) {
      showSnackbar(
        title: "Erro",
        message:
            "Falha ao autenticar com ${provider == 'google' ? 'Google' : 'Apple'}.",
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() => isloading = false);
      }
    }
  }

  Widget _buildProviderButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.black87),
      label: Text(
        label,
        style: const TextStyle(color: Colors.black87),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return isloading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            resizeToAvoidBottomInset: true,
            body: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Builder(
                        builder: (_) {
                          final photoUrl =
                              FirebaseAuth.instance.currentUser?.photoURL;
                          final hasPhoto =
                              photoUrl != null && photoUrl.trim().isNotEmpty;
                          return CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage:
                                hasPhoto ? NetworkImage(photoUrl) : null,
                            child: hasPhoto
                                ? null
                                : const Icon(Icons.person, size: 40),
                          );
                        },
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      Text(
                        "Bem-vindo ao Routine",
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      TextField(
                        key: const Key('login_email_field'),
                        controller: email,
                        decoration:
                            InputDecoration(hintText: 'Entre com o e-mail'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      SizedBox(height: 15),
                      TextField(
                        key: const Key('login_password_field'),
                        controller: password,
                        decoration: InputDecoration(
                          hintText: 'Entre com a senha',
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                showPassword =
                                    !showPassword; // Alterna a visibilidade
                              });
                            },
                          ),
                        ),
                        obscureText:
                            !showPassword, // Controla a visibilidade da senha
                        textInputAction: TextInputAction.done,
                      ),
                      SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Get.to(() => Signup()),
                            child: Text('Cadastrar',
                                style: TextStyle(color: Colors.blue)),
                          ),
                          TextButton(
                            onPressed: () => Get.to(() => const Forgot()),
                            child: Text('Esqueci a senha',
                                style: TextStyle(color: Colors.blue)),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        key: const Key('login_submit_button'),
                        onPressed: signIn,
                        child: Text('Entrar',
                            style: TextStyle(fontSize: 18, color: Colors.blue)),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("Ou entre com"),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          SizedBox(
                            width: screenWidth * 0.3,
                            child: _buildProviderButton(
                              label: 'Google',
                              icon: Icons.g_mobiledata,
                              onPressed: () => loginWithProvider('google'),
                            ),
                          ),
                          SizedBox(
                            width: screenWidth * 0.3,
                            child: _buildProviderButton(
                              label: 'Apple',
                              icon: Icons.apple,
                              onPressed: () => loginWithProvider('apple'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}

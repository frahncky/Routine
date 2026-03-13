import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:routine/login/forgot.dart';
import 'package:routine/login/signup.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
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
        '',
        'email',
      );

      showSnackbar(
        title: "Login realizado",
        message: "Você entrou com sucesso!",
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );

      Get.offAll(() => AuthWrapper());
    } catch (e) {
      showSnackbar(
        title: "Erro no login",
        message: "Login não realizado! ${e.toString()}",
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
        final GoogleSignInAuthentication? googleAuth = await googleUser.authentication;

        if (googleAuth?.accessToken == null || googleAuth?.idToken == null) {
          Get.snackbar("Erro", "Falha na autenticação com Google.");
          return;
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        // Login com Apple
        final appleCredentials = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        );
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: appleCredentials.identityToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      }

      await userCredential.user?.reload();

      final user = FirebaseAuth.instance.currentUser;
      final providerId = user?.providerData.first.providerId; // 'google.com' ou 'apple.com'

      // Atualizar ou criar o usuário no banco de dados local (SQLite)
      await DB.instance.createAccount(
        user?.displayName ?? '',
        user?.email ?? '',
        '',
        providerId == 'google.com' ? 'google' : 'apple',
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
    } catch (e) {
      Get.snackbar("Erro", "Falha ao autenticar com $provider: $e");
    } finally {
      if (mounted) {
        setState(() => isloading = false);
      }
    }
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
                      CircleAvatar(
                        radius: 45,
                        backgroundImage: NetworkImage(
                          FirebaseAuth.instance.currentUser?.photoURL ?? 
                              'https://www.example.com/default_image_url.png',
                        ),
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
                        controller: email,
                        decoration:  InputDecoration(hintText: 'Entre com o e-mail'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                       SizedBox(height: 15),
                      TextField(
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
                                showPassword = !showPassword; // Alterna a visibilidade
                              });
                            },
                          ),
                        ),
                        obscureText: !showPassword, // Controla a visibilidade da senha
                        textInputAction: TextInputAction.done,
                      ),
                       SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Get.to(() => Signup()),
                            child:  Text('Cadastrar', style: TextStyle(color: Colors.blue)),
                          ),
                          TextButton(
                            onPressed: () => Get.to(() => const Forgot()),
                            child:  Text('Esqueci a senha', style: TextStyle(color: Colors.blue)),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: signIn,
                        child:  Text('Entrar', style: TextStyle(fontSize: 18, color: Colors.blue)),
                      ),
                       SizedBox(height: 20),
                      Row(
                        children:  [
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
                            child: SignInButton(
                              Buttons.Google,
                              text: 'Google',
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side:  BorderSide(color: Colors.grey),
                              ),
                              onPressed: () => loginWithProvider('google'),
                            ),
                          ),
                          SizedBox(
                            width: screenWidth * 0.3,
                            child: SignInButton(
                              Buttons.Apple,
                              text: 'Apple',
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side:  BorderSide(color: Colors.grey),
                              ),
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/login/forgot.dart';
import 'package:routine/login/signup.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool isloading = false;
  bool showPassword = false;
  bool _appleSignInAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadAppleAvailability();
  }

  Future<void> _loadAppleAvailability() async {
    try {
      final available = await SignInWithApple.isAvailable();
      if (!mounted) return;
      setState(() {
        _appleSignInAvailable = available;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appleSignInAvailable = false;
      });
    }
  }

  bool _isValidEmail(String value) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(value);
  }

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
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (!mounted || isloading) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final emailValue = email.text.trim().toLowerCase();
    final passwordValue = password.text;

    setState(() => isloading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailValue,
        password: passwordValue,
      );
      if (!mounted) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      final resolvedEmail =
          _resolveLocalEmail(currentUser, provider: 'email');

      if (resolvedEmail.isEmpty) {
        showSnackbar(
          title: 'Erro no login',
          message: 'Nao foi possivel obter o e-mail da conta.',
          backgroundColor: Colors.red.shade300,
          icon: Icons.error,
        );
        return;
      }

      await DB.instance.createAccount(
        currentUser?.displayName ?? '',
        resolvedEmail,
        currentUser?.photoURL ?? '',
        'email',
      );
      if (!mounted) return;

      showSnackbar(
        title: 'Login realizado',
        message: 'Voce entrou com sucesso!',
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );

      Get.offAll(() => AuthWrapper());
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showSnackbar(
        title: 'Erro no login',
        message: _authErrorMessage(e),
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
    } catch (_) {
      if (!mounted) return;
      showSnackbar(
        title: 'Erro no login',
        message: 'Nao foi possivel realizar login agora.',
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
    } finally {
      if (mounted) {
        setState(() => isloading = false);
      }
    }
  }

  Future<void> loginWithProvider(String provider) async {
    if (!mounted || isloading) return;
    FocusScope.of(context).unfocus();
    setState(() => isloading = true);

    try {
      UserCredential userCredential;

      if (provider == 'google') {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          showSnackbar(
            title: 'Aviso',
            message: 'Login com Google cancelado.',
            backgroundColor: Colors.orange.shade300,
            icon: Icons.info,
          );
          return;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          showSnackbar(
            title: 'Erro',
            message: 'Falha na autenticacao com Google.',
            backgroundColor: Colors.red.shade300,
            icon: Icons.error,
          );
          return;
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        if (!_appleSignInAvailable) {
          showSnackbar(
            title: 'Apple indisponivel',
            message:
                'Sign in with Apple nao esta disponivel neste dispositivo.',
            backgroundColor: Colors.orange.shade300,
            icon: Icons.info,
          );
          return;
        }

        final appleCredentials = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final token = appleCredentials.identityToken;
        if (token == null || token.isEmpty) {
          showSnackbar(
            title: 'Erro',
            message: 'Falha na autenticacao com Apple.',
            backgroundColor: Colors.red.shade300,
            icon: Icons.error,
          );
          return;
        }

        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: token,
        );
        userCredential = await FirebaseAuth.instance
            .signInWithCredential(oauthCredential);
      }

      await userCredential.user?.reload();
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      final localProvider = provider == 'google' ? 'google' : 'apple';
      final resolvedEmail =
          _resolveLocalEmail(user, provider: localProvider);

      if (resolvedEmail.isEmpty) {
        showSnackbar(
          title: 'Erro',
          message: 'Nao foi possivel obter um e-mail para sua conta.',
          backgroundColor: Colors.red.shade300,
          icon: Icons.error,
        );
        return;
      }

      await DB.instance.createAccount(
        user?.displayName ?? '',
        resolvedEmail,
        user?.photoURL ?? '',
        localProvider,
      );
      if (!mounted) return;

      showSnackbar(
        title: 'Login realizado',
        message: 'Você entrou com sucesso!',
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );

      Get.offAll(() => AuthWrapper());
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showSnackbar(
        title: 'Erro',
        message: _authErrorMessage(e),
        backgroundColor: Colors.red.shade300,
        icon: Icons.error,
      );
    } catch (_) {
      if (!mounted) return;
      showSnackbar(
        title: 'Erro',
        message:
            'Falha ao autenticar com ${provider == 'google' ? 'Google' : 'Apple'}.',
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: isloading,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
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
                          'Bem-vindo ao Routine',
                          style: TextStyle(
                            fontSize: screenWidth * 0.07,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.05),
                        TextFormField(
                          key: const Key('login_email_field'),
                          focusNode: _emailFocusNode,
                          controller: email,
                          decoration: const InputDecoration(
                            hintText: 'Entre com o e-mail',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s')),
                          ],
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) {
                            final emailValue = (value ?? '').trim();
                            if (emailValue.isEmpty) {
                              return 'Informe seu e-mail.';
                            }
                            if (!_isValidEmail(emailValue)) {
                              return 'Digite um e-mail valido.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          onTapOutside: (_) =>
                              FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          key: const Key('login_password_field'),
                          focusNode: _passwordFocusNode,
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
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: !showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) {
                            final passwordValue = (value ?? '').trim();
                            if (passwordValue.isEmpty) {
                              return 'Informe sua senha.';
                            }
                            if (passwordValue.length < 6) {
                              return 'Senha deve ter ao menos 6 caracteres.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => signIn(),
                          onTapOutside: (_) =>
                              FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Get.to(() => Signup()),
                              child: const Text(
                                'Cadastrar',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Get.to(() => const Forgot()),
                              child: const Text(
                                'Esqueci a senha',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          key: const Key('login_submit_button'),
                          onPressed: isloading ? null : signIn,
                          child: Text(
                            isloading ? 'Entrando...' : 'Entrar',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('Ou entre com'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            SizedBox(
                              width: _appleSignInAvailable
                                  ? screenWidth * 0.3
                                  : screenWidth * 0.5,
                              child: _buildProviderButton(
                                label: 'Google',
                                icon: Icons.g_mobiledata,
                                onPressed: () => loginWithProvider('google'),
                              ),
                            ),
                            if (_appleSignInAvailable)
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
            ),
          ),
          if (isloading)
            Container(
              color: Colors.black.withValues(alpha: 0.12),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

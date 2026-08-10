import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/login/forgot.dart';
import 'package:routine/login/signup.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/widgets/show_snackbar.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.redirectAfterLogin});

  final Widget? redirectAfterLogin;

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
      setState(() => _appleSignInAvailable = available);
    } catch (_) {
      if (!mounted) return;
      setState(() => _appleSignInAvailable = false);
    }
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      default:
        return 'Não foi possível autenticar agora.';
    }
  }

  String _resolveLocalEmail(User? user, {required String provider}) {
    final userEmail = user?.email?.trim();
    if (userEmail != null && userEmail.isNotEmpty) return userEmail;
    final uid = user?.uid.trim();
    if (uid != null && uid.isNotEmpty) return '$uid@$provider.local';
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

  void _snack(String title, String message,
      {SnackbarVariant variant = SnackbarVariant.info, IconData? icon}) {
    showSnackbar(
        context: context,
        title: title,
        message: message,
        variant: variant,
        icon: icon);
  }

  Future<void> signIn() async {
    if (!mounted || isloading) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
      final resolvedEmail = _resolveLocalEmail(currentUser, provider: 'email');

      if (resolvedEmail.isEmpty) {
        _snack('Erro no login', 'Não foi possível obter o e-mail da conta.',
            variant: SnackbarVariant.error);
        return;
      }

      await DB.instance.createAccount(
        currentUser?.displayName ?? '',
        resolvedEmail,
        currentUser?.photoURL ?? '',
        'email',
      );
      if (!mounted) return;

      _snack('Login realizado', 'Você entrou com sucesso!',
          variant: SnackbarVariant.success);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => widget.redirectAfterLogin ?? const AuthWrapper()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _snack('Erro no login', _authErrorMessage(e),
          variant: SnackbarVariant.error);
    } catch (_) {
      if (!mounted) return;
      _snack('Erro no login', 'Não foi possível realizar login agora.',
          variant: SnackbarVariant.error);
    } finally {
      if (mounted) setState(() => isloading = false);
    }
  }

  Future<void> loginWithProvider(String provider) async {
    if (!mounted || isloading) return;
    FocusScope.of(context).unfocus();
    setState(() => isloading = true);

    try {
      UserCredential userCredential;

      if (provider == 'google') {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize();

        final GoogleSignInAccount googleUser;
        try {
          googleUser = await googleSignIn.authenticate();
        } on GoogleSignInException catch (e) {
          if (e.code == GoogleSignInExceptionCode.canceled) {
            if (!mounted) return;
            _snack('Aviso', 'Login com Google cancelado.',
                variant: SnackbarVariant.warning, icon: Icons.info);
            return;
          }
          rethrow;
        }

        final googleAuth = googleUser.authentication;
        if (googleAuth.idToken == null) {
          if (!mounted) return;
          _snack('Erro', 'Falha na autenticação com Google.',
              variant: SnackbarVariant.error);
          return;
        }

        final credential =
            GoogleAuthProvider.credential(idToken: googleAuth.idToken);
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        if (!_appleSignInAvailable) {
          _snack('Apple indisponível',
              'Sign in with Apple não está disponível neste dispositivo.',
              variant: SnackbarVariant.warning, icon: Icons.info);
          return;
        }

        final appleCredentials =
            await SignInWithApple.getAppleIDCredential(scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ]);

        final token = appleCredentials.identityToken;
        if (token == null || token.isEmpty) {
          if (!mounted) return;
          _snack('Erro', 'Falha na autenticação com Apple.',
              variant: SnackbarVariant.error);
          return;
        }

        final oauthCredential =
            OAuthProvider('apple.com').credential(idToken: token);
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      }

      await userCredential.user?.reload();
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      final localProvider = provider == 'google' ? 'google' : 'apple';
      final resolvedEmail = _resolveLocalEmail(user, provider: localProvider);

      if (resolvedEmail.isEmpty) {
        _snack('Erro', 'Não foi possível obter um e-mail para sua conta.',
            variant: SnackbarVariant.error);
        return;
      }

      await DB.instance.createAccount(
        user?.displayName ?? '',
        resolvedEmail,
        user?.photoURL ?? '',
        localProvider,
      );
      if (!mounted) return;

      _snack('Login realizado', 'Você entrou com sucesso!',
          variant: SnackbarVariant.success);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => widget.redirectAfterLogin ?? const AuthWrapper()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _snack('Erro', _authErrorMessage(e), variant: SnackbarVariant.error);
    } catch (_) {
      if (!mounted) return;
      _snack(
          'Erro',
          'Falha ao autenticar com '
              '${provider == 'google' ? 'Google' : 'Apple'}.',
          variant: SnackbarVariant.error);
    } finally {
      if (mounted) setState(() => isloading = false);
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
      label: Text(label, style: const TextStyle(color: Colors.black87)),
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
                              hintText: 'Entre com o e-mail'),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(RegExp(r'\s'))
                          ],
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email
                          ],
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) {
                            final v = (value ?? '').trim();
                            if (v.isEmpty) {
                              return 'Informe seu e-mail.';
                            }
                            if (!_isValidEmail(v)) {
                              return 'Digite um e-mail válido.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
                              onPressed: () =>
                                  setState(() => showPassword = !showPassword),
                            ),
                          ),
                          obscureText: !showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (value) {
                            final v = (value ?? '').trim();
                            if (v.isEmpty) {
                              return 'Informe sua senha.';
                            }
                            if (v.length < 6) {
                              return 'Senha deve ter ao menos 6 caracteres.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => signIn(),
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Signup(
                                    redirectAfterSignup:
                                        widget.redirectAfterLogin,
                                  ),
                                ),
                              ),
                              child: const Text('Cadastrar',
                                  style: TextStyle(color: Colors.blue)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const Forgot()),
                              ),
                              child: const Text('Esqueci a senha',
                                  style: TextStyle(color: Colors.blue)),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          key: const Key('login_submit_button'),
                          onPressed: isloading ? null : signIn,
                          child: Text(
                            isloading ? 'Entrando...' : 'Entrar',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.blue),
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
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

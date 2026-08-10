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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameUser = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool _showPassword = false;
  bool _submitting = false;

  @override
  void dispose() {
    nameUser.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  Future<void> signup() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
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
        variant: SnackbarVariant.success,
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
        variant: SnackbarVariant.error,
      );
    } catch (e) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Erro inesperado',
        message: e.toString(),
        variant: SnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo cadastro')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: nameUser,
                      decoration:
                          const InputDecoration(labelText: 'Nome de usuário'),
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Informe seu nome.'
                          : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Informe seu e-mail.';
                        if (!_isValidEmail(v)) {
                          return 'Digite um e-mail válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: password,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => signup(),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Informe uma senha.';
                        if (v.length < 6) {
                          return 'Senha deve ter ao menos 6 caracteres.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _submitting ? null : signup,
                      child: Text(_submitting ? 'Cadastrando...' : 'Cadastrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

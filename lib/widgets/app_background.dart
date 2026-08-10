import 'package:flutter/material.dart';

/// Gradiente de fundo padrão das telas internas do app — antes repetido
/// literalmente em `home_screen.dart`, `historico_screen.dart` e
/// `contacts_screen.dart`.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4F8FF), Color(0xFFEAF1FF)],
        ),
      ),
      child: child,
    );
  }
}

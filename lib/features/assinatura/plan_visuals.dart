import 'package:flutter/material.dart';
import 'package:routine/features/assinatura/plan_rules.dart';

/// Fonte única de verdade pras cores de cada plano — os gradientes usados
/// nos cards de [features/assinatura/assinatura_screen.dart], reaproveitados
/// aqui pra qualquer outra tela que precise identificar um plano
/// visualmente (ex.: configuracoes_screen.dart), evitando duas telas
/// mostrarem o mesmo plano em cores diferentes.
class PlanVisuals {
  const PlanVisuals._();

  static List<Color> gradientFor(String plan) {
    switch (PlanRules.normalize(plan)) {
      case PlanRules.basico:
        return const [Color(0xFFDFF7FF), Color(0xFFBDE3F9)];
      case PlanRules.avancado:
        return const [Color(0xFFE7FCEB), Color(0xFFCFF5D8)];
      case PlanRules.colaborativo:
        return const [Color(0xFFE7E8FF), Color(0xFFC7CEFF)];
      default:
        return const [Color(0xFFFFF4D6), Color(0xFFFED7AA)];
    }
  }

  static Color borderFor(String plan) {
    switch (PlanRules.normalize(plan)) {
      case PlanRules.basico:
        return const Color(0xFF0EA5E9);
      case PlanRules.avancado:
        return const Color(0xFF22C55E);
      case PlanRules.colaborativo:
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

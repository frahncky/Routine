class PlanRules {
  static const String gratis = 'gratis';
  static const String basico = 'basico';
  static const String premium = 'premium';

  static String normalize(String? rawPlan) {
    if (rawPlan == null || rawPlan.trim().isEmpty) return gratis;
    final plan = rawPlan.trim().toLowerCase();
    switch (plan) {
      case 'gratis':
      case 'gratuita':
      case 'gratuito':
      case 'free':
        return gratis;
      case 'basico':
      case 'básico':
      case 'basic':
      case 'individual':
        return basico;
      case 'premium':
      case 'familia':
      case 'família':
      case 'vip':
      case 'pro':
        return premium;
      default:
        return gratis;
    }
  }

  static bool hasAds(String plan) {
    return normalize(plan) == gratis;
  }

  static bool isPersonalAgendaOnly(String plan) {
    final normalized = normalize(plan);
    return normalized == gratis || normalized == basico;
  }

  static bool hasFullAccess(String plan) {
    return normalize(plan) == premium;
  }

  static String displayName(String plan) {
    switch (normalize(plan)) {
      case basico:
        return 'Básico';
      case premium:
        return 'Premium';
      case gratis:
      default:
        return 'Grátis';
    }
  }
}

class PlanRules {
  static const String gratis = 'gratis';
  static const String basico = 'basico';
  static const String premium = 'premium';

  static const List<String> validPlans = [gratis, basico, premium];

  static String normalize(String? rawPlan) {
    final token = _normalizeToken(rawPlan);
    switch (token) {
      case 'gratis':
      case 'gratuita':
      case 'gratuito':
      case 'free':
        return gratis;
      case 'basico':
      case 'basic':
      case 'individual':
        return basico;
      case 'premium':
      case 'familia':
      case 'vip':
      case 'pro':
      case 'family':
        return premium;
      default:
        return gratis;
    }
  }

  static bool isValid(String plan) {
    return validPlans.contains(normalize(plan));
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
        return 'B\u00E1sico';
      case premium:
        return 'Premium';
      case gratis:
      default:
        return 'Gr\u00E1tis';
    }
  }

  static String _normalizeToken(String? rawPlan) {
    if (rawPlan == null || rawPlan.trim().isEmpty) return gratis;

    var normalized = rawPlan.trim().toLowerCase();
    normalized = _foldDiacritics(normalized);
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _foldDiacritics(String value) {
    var result = value;
    const replacements = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };

    replacements.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }
}

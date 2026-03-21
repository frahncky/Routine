class PlanRules {
  static const String gratis = 'gratis';
  static const String basico = 'basico';
  static const String premium = 'premium';

  static const List<String> validPlans = [gratis, basico, premium];
  static const Set<String> _gratisTokens = {
    'gratis',
    'gratuita',
    'gratuito',
    'free',
  };
  static const Set<String> _basicoTokens = {'basico', 'basic', 'individual'};
  static const Set<String> _premiumTokens = {
    'premium',
    'familia',
    'vip',
    'pro',
    'family',
  };
  static const Set<String> _validTokens = {
    ..._gratisTokens,
    ..._basicoTokens,
    ..._premiumTokens,
  };

  static String normalize(String? rawPlan) {
    final token = _normalizeToken(rawPlan);
    if (_gratisTokens.contains(token)) return gratis;
    if (_basicoTokens.contains(token)) return basico;
    if (_premiumTokens.contains(token)) return premium;
    return gratis;
  }

  static bool isValid(String plan) {
    return _validTokens.contains(_normalizeToken(plan));
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
      'Ã¡': 'a',
      'Ã ': 'a',
      'Ã¢': 'a',
      'Ã£': 'a',
      'Ã¤': 'a',
      'Ã©': 'e',
      'Ã¨': 'e',
      'Ãª': 'e',
      'Ã«': 'e',
      'Ã­': 'i',
      'Ã¬': 'i',
      'Ã®': 'i',
      'Ã¯': 'i',
      'Ã³': 'o',
      'Ã²': 'o',
      'Ã´': 'o',
      'Ãµ': 'o',
      'Ã¶': 'o',
      'Ãº': 'u',
      'Ã¹': 'u',
      'Ã»': 'u',
      'Ã¼': 'u',
      'Ã§': 'c',
    };

    replacements.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }
}

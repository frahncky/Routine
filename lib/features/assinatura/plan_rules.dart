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

  static const Set<String> _basicoTokens = {
    'basico',
    'basic',
    'individual',
  };

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
    normalized = _fixCommonMojibake(normalized);
    normalized = _foldDiacritics(normalized);
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _fixCommonMojibake(String value) {
    var result = value;
    const fixes = {
      // One-pass mojibake (UTF-8 interpreted as Latin-1)
      '\u00C3\u00A1': '\u00E1',
      '\u00C3\u00A0': '\u00E0',
      '\u00C3\u00A2': '\u00E2',
      '\u00C3\u00A3': '\u00E3',
      '\u00C3\u00A4': '\u00E4',
      '\u00C3\u00A9': '\u00E9',
      '\u00C3\u00A8': '\u00E8',
      '\u00C3\u00AA': '\u00EA',
      '\u00C3\u00AB': '\u00EB',
      '\u00C3\u00AD': '\u00ED',
      '\u00C3\u00AC': '\u00EC',
      '\u00C3\u00AE': '\u00EE',
      '\u00C3\u00AF': '\u00EF',
      '\u00C3\u00B3': '\u00F3',
      '\u00C3\u00B2': '\u00F2',
      '\u00C3\u00B4': '\u00F4',
      '\u00C3\u00B5': '\u00F5',
      '\u00C3\u00B6': '\u00F6',
      '\u00C3\u00BA': '\u00FA',
      '\u00C3\u00B9': '\u00F9',
      '\u00C3\u00BB': '\u00FB',
      '\u00C3\u00BC': '\u00FC',
      '\u00C3\u00A7': '\u00E7',
      // Common double-encoded patterns
      '\u00C3\u0192\u00C2\u00A1': '\u00E1',
      '\u00C3\u0192\u00C2\u00AD': '\u00ED',
      '\u00C3\u0192\u00C2\u00A7': '\u00E7',
    };

    fixes.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }

  static String _foldDiacritics(String value) {
    var result = value;
    const replacements = {
      '\u00E1': 'a',
      '\u00E0': 'a',
      '\u00E2': 'a',
      '\u00E3': 'a',
      '\u00E4': 'a',
      '\u00E9': 'e',
      '\u00E8': 'e',
      '\u00EA': 'e',
      '\u00EB': 'e',
      '\u00ED': 'i',
      '\u00EC': 'i',
      '\u00EE': 'i',
      '\u00EF': 'i',
      '\u00F3': 'o',
      '\u00F2': 'o',
      '\u00F4': 'o',
      '\u00F5': 'o',
      '\u00F6': 'o',
      '\u00FA': 'u',
      '\u00F9': 'u',
      '\u00FB': 'u',
      '\u00FC': 'u',
      '\u00E7': 'c',
    };

    replacements.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
  }
}

class PlanRules {
  static const String gratuito = 'gratuito';
  static const String basico = 'basico';
  static const String avancado = 'avancado';
  static const String colaborativo = 'colaborativo';

  static const List<String> validPlans = [
    gratuito,
    basico,
    avancado,
    colaborativo,
  ];

  static const Set<String> _gratuitoTokens = {
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

  static const Set<String> _avancadoTokens = {
    'plus',
    'avancado',
    'avancada',
    'advanced',
    'intermediario',
    'intermediate',
  };

  static const Set<String> _colaborativoTokens = {
    'premium',
    'colaborativo',
    'colaborativa',
    'collaborative',
    'familia',
    'vip',
    'pro',
    'family',
  };

  static const Set<String> _validTokens = {
    ..._gratuitoTokens,
    ..._basicoTokens,
    ..._avancadoTokens,
    ..._colaborativoTokens,
  };

  static String normalize(String? rawPlan) {
    final token = _normalizeToken(rawPlan);
    if (_gratuitoTokens.contains(token)) return gratuito;
    if (_basicoTokens.contains(token)) return basico;
    if (_avancadoTokens.contains(token)) return avancado;
    if (_colaborativoTokens.contains(token)) return colaborativo;
    return gratuito;
  }

  static bool isValid(String plan) {
    if (plan.trim().isEmpty) return false;
    return _validTokens.contains(_normalizeToken(plan));
  }

  static bool isPersonalAgendaOnly(String plan) {
    final normalized = normalize(plan);
    return normalized == gratuito ||
        normalized == basico ||
        normalized == avancado;
  }

  static bool hasFullAccess(String plan) {
    return normalize(plan) == colaborativo;
  }

  static bool hasCloudBackup(String plan) {
    final normalized = normalize(plan);
    return normalized == avancado || normalized == colaborativo;
  }

  // Sentinela pra "sem limite prático" — usado em comparações numéricas
  // (ex.: totalAtividades >= activityLimit(plan)) sem precisar de um branch
  // separado pra planos ilimitados.
  static const int unlimitedActivities = 1 << 30;

  static const Map<String, int> _activityLimits = {
    gratuito: 7,
    basico: 20,
    avancado: unlimitedActivities,
    colaborativo: unlimitedActivities,
  };

  static int activityLimit(String plan) {
    final normalized = normalize(plan);
    return _activityLimits[normalized] ?? _activityLimits[gratuito]!;
  }

  static bool hasUnlimitedActivities(String plan) {
    return activityLimit(plan) >= unlimitedActivities;
  }

  static String displayName(String plan) {
    switch (normalize(plan)) {
      case basico:
        return 'Básico';
      case avancado:
        return 'Avançado';
      case colaborativo:
        return 'Colaborativo';
      case gratuito:
      default:
        return 'Gratuito';
    }
  }

  static String _normalizeToken(String? rawPlan) {
    if (rawPlan == null || rawPlan.trim().isEmpty) return gratuito;

    var normalized = rawPlan.trim();
    normalized = _fixCommonMojibake(normalized);
    normalized = normalized.toLowerCase();
    normalized = _fixCommonMojibake(normalized);
    normalized = _foldDiacritics(normalized);
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String _fixCommonMojibake(String value) {
    var result = value;
    const fixes = {
      // One-pass mojibake (UTF-8 interpreted as Latin-1)
      'Ã¡': 'á',
      'Ã ': 'à',
      'Ã¢': 'â',
      'Ã£': 'ã',
      'Ã¤': 'ä',
      'Ã©': 'é',
      'Ã¨': 'è',
      'Ãª': 'ê',
      'Ã«': 'ë',
      'Ã­': 'í',
      'Ã¬': 'ì',
      'Ã®': 'î',
      'Ã¯': 'ï',
      'Ã³': 'ó',
      'Ã²': 'ò',
      'Ã´': 'ô',
      'Ãµ': 'õ',
      'Ã¶': 'ö',
      'Ãº': 'ú',
      'Ã¹': 'ù',
      'Ã»': 'û',
      'Ã¼': 'ü',
      'Ã§': 'ç',
      // Common double-encoded patterns
      'ÃƒÂ¡': 'á',
      'ÃƒÂ­': 'í',
      'ÃƒÂ§': 'ç',
    };

    fixes.forEach((from, to) {
      result = result.replaceAll(from, to);
    });
    return result;
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

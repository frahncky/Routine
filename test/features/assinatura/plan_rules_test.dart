import 'package:flutter_test/flutter_test.dart';
import 'package:routine/features/assinatura/plan_rules.dart';

void main() {
  group('PlanRules.normalize', () {
    test('returns gratis for null, empty, and unknown values', () {
      expect(PlanRules.normalize(null), PlanRules.gratis);
      expect(PlanRules.normalize(''), PlanRules.gratis);
      expect(PlanRules.normalize('   '), PlanRules.gratis);
      expect(PlanRules.normalize('qualquer-coisa'), PlanRules.gratis);
    });

    test('maps legacy free plan names to gratis', () {
      expect(PlanRules.normalize('gratis'), PlanRules.gratis);
      expect(PlanRules.normalize('gratuita'), PlanRules.gratis);
      expect(PlanRules.normalize('gratuito'), PlanRules.gratis);
      expect(PlanRules.normalize('free'), PlanRules.gratis);
    });

    test('maps legacy basic, plus and premium aliases', () {
      expect(PlanRules.normalize('basico'), PlanRules.basico);
      expect(PlanRules.normalize('individual'), PlanRules.basico);
      expect(PlanRules.normalize('plus'), PlanRules.plus);
      expect(PlanRules.normalize('intermediario'), PlanRules.plus);
      expect(PlanRules.normalize('intermediate'), PlanRules.plus);
      expect(PlanRules.normalize('premium'), PlanRules.premium);
      expect(PlanRules.normalize('familia'), PlanRules.premium);
      expect(PlanRules.normalize('vip'), PlanRules.premium);
      expect(PlanRules.normalize('pro'), PlanRules.premium);
    });

    test('normalizes accented and mojibake plan labels', () {
      expect(PlanRules.normalize('B\u00E1sico'), PlanRules.basico);
      expect(PlanRules.normalize('B\u00C3\u00A1sico'), PlanRules.basico);
      expect(
        PlanRules.normalize('B\u00C3\u0192\u00C2\u00A1sico'),
        PlanRules.basico,
      );
      expect(PlanRules.normalize('Intermedi\u00E1rio'), PlanRules.plus);
      expect(PlanRules.normalize('Fam\u00EDlia'), PlanRules.premium);
      expect(PlanRules.normalize('Fam\u00C3\u00ADlia'), PlanRules.premium);
      expect(
        PlanRules.normalize('Fam\u00C3\u0192\u00C2\u00ADlia'),
        PlanRules.premium,
      );
      expect(PlanRules.normalize('Premium!'), PlanRules.premium);
    });
  });

  group('PlanRules validity', () {
    test('accepts known aliases and rejects unknown labels', () {
      expect(PlanRules.isValid('gratis'), isTrue);
      expect(PlanRules.isValid('individual'), isTrue);
      expect(PlanRules.isValid('plus'), isTrue);
      expect(PlanRules.isValid('family'), isTrue);
      expect(PlanRules.isValid(''), isFalse);
      expect(PlanRules.isValid('   '), isFalse);
      expect(PlanRules.isValid('desconhecido'), isFalse);
    });

    test('displayName returns human-readable names', () {
      expect(PlanRules.displayName(PlanRules.gratis), 'Gr\u00E1tis');
      expect(PlanRules.displayName(PlanRules.basico), 'B\u00E1sico');
      expect(PlanRules.displayName(PlanRules.plus), 'Plus');
      expect(PlanRules.displayName(PlanRules.premium), 'Premium');
    });
  });

  group('PlanRules permissions', () {
    test('hasAds is true only for gratis', () {
      expect(PlanRules.hasAds(PlanRules.gratis), isTrue);
      expect(PlanRules.hasAds(PlanRules.basico), isFalse);
      expect(PlanRules.hasAds(PlanRules.plus), isFalse);
      expect(PlanRules.hasAds(PlanRules.premium), isFalse);
    });

    test('personal agenda only is true for gratis, basico and plus', () {
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.gratis), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.basico), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.plus), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.premium), isFalse);
    });

    test('full access is true only for premium', () {
      expect(PlanRules.hasFullAccess(PlanRules.gratis), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.basico), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.plus), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.premium), isTrue);
    });
  });
}

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

    test('maps legacy basic and premium aliases', () {
      expect(PlanRules.normalize('basico'), PlanRules.basico);
      expect(PlanRules.normalize('individual'), PlanRules.basico);
      expect(PlanRules.normalize('premium'), PlanRules.premium);
      expect(PlanRules.normalize('familia'), PlanRules.premium);
      expect(PlanRules.normalize('vip'), PlanRules.premium);
      expect(PlanRules.normalize('pro'), PlanRules.premium);
    });
  });

  group('PlanRules permissions', () {
    test('hasAds is true only for gratis', () {
      expect(PlanRules.hasAds(PlanRules.gratis), isTrue);
      expect(PlanRules.hasAds(PlanRules.basico), isFalse);
      expect(PlanRules.hasAds(PlanRules.premium), isFalse);
    });

    test('personal agenda only is true for gratis and basico', () {
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.gratis), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.basico), isTrue);
      expect(PlanRules.isPersonalAgendaOnly(PlanRules.premium), isFalse);
    });

    test('full access is true only for premium', () {
      expect(PlanRules.hasFullAccess(PlanRules.gratis), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.basico), isFalse);
      expect(PlanRules.hasFullAccess(PlanRules.premium), isTrue);
    });
  });
}

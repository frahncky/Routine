import 'package:flutter_test/flutter_test.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';

void main() {
  group('PlanAccess.effectivePlan', () {
    test('forces gratis for guests even when local cache says premium', () {
      expect(
        PlanAccess.effectivePlan(
          isSignedIn: false,
          storedPlan: PlanRules.premium,
        ),
        PlanRules.gratis,
      );
    });

    test('uses normalized stored plan for signed in users', () {
      expect(
        PlanAccess.effectivePlan(
          isSignedIn: true,
          storedPlan: 'Fam\u00EDlia',
        ),
        PlanRules.premium,
      );
    });
  });

  group('PlanAccess.requiresAccount', () {
    test('requires account only for paid plans', () {
      expect(PlanAccess.requiresAccount(PlanRules.gratis), isFalse);
      expect(PlanAccess.requiresAccount(PlanRules.basico), isTrue);
      expect(PlanAccess.requiresAccount(PlanRules.plus), isTrue);
      expect(PlanAccess.requiresAccount(PlanRules.premium), isTrue);
    });
  });

  group('PlanAccess.canUseCollaborativeFeatures', () {
    test('blocks collaborative features for guests', () {
      expect(
        PlanAccess.canUseCollaborativeFeatures(
          isSignedIn: false,
          storedPlan: PlanRules.premium,
        ),
        isFalse,
      );
    });

    test('allows collaborative features for signed in premium users', () {
      expect(
        PlanAccess.canUseCollaborativeFeatures(
          isSignedIn: true,
          storedPlan: PlanRules.premium,
        ),
        isTrue,
      );
    });
  });
}

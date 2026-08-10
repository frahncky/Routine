import 'package:flutter_test/flutter_test.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';

void main() {
  group('PlanAccess.effectivePlan', () {
    test('forces gratuito for guests even when local cache says colaborativo',
        () {
      expect(
        PlanAccess.effectivePlan(
          isSignedIn: false,
          storedPlan: PlanRules.colaborativo,
        ),
        PlanRules.gratuito,
      );
    });

    test('uses normalized stored plan for signed in users', () {
      expect(
        PlanAccess.effectivePlan(
          isSignedIn: true,
          storedPlan: 'Família',
        ),
        PlanRules.colaborativo,
      );
    });
  });

  group('PlanAccess.requiresAccount', () {
    test('requires account only for paid plans', () {
      expect(PlanAccess.requiresAccount(PlanRules.gratuito), isFalse);
      expect(PlanAccess.requiresAccount(PlanRules.basico), isTrue);
      expect(PlanAccess.requiresAccount(PlanRules.avancado), isTrue);
      expect(PlanAccess.requiresAccount(PlanRules.colaborativo), isTrue);
    });
  });

  group('PlanAccess.canUseCollaborativeFeatures', () {
    test('blocks collaborative features for guests', () {
      expect(
        PlanAccess.canUseCollaborativeFeatures(
          isSignedIn: false,
          storedPlan: PlanRules.colaborativo,
        ),
        isFalse,
      );
    });

    test('allows collaborative features for signed in colaborativo users',
        () {
      expect(
        PlanAccess.canUseCollaborativeFeatures(
          isSignedIn: true,
          storedPlan: PlanRules.colaborativo,
        ),
        isTrue,
      );
    });
  });

  group('PlanAccess.canUseCloudBackup', () {
    test('blocks cloud backup for guests', () {
      expect(
        PlanAccess.canUseCloudBackup(
          isSignedIn: false,
          storedPlan: PlanRules.avancado,
        ),
        isFalse,
      );
    });

    test('allows cloud backup for signed in avancado/colaborativo users', () {
      expect(
        PlanAccess.canUseCloudBackup(
          isSignedIn: true,
          storedPlan: PlanRules.avancado,
        ),
        isTrue,
      );
      expect(
        PlanAccess.canUseCloudBackup(
          isSignedIn: true,
          storedPlan: PlanRules.colaborativo,
        ),
        isTrue,
      );
    });

    test('blocks cloud backup for basico users', () {
      expect(
        PlanAccess.canUseCloudBackup(
          isSignedIn: true,
          storedPlan: PlanRules.basico,
        ),
        isFalse,
      );
    });
  });
}

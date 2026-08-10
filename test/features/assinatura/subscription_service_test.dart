import 'package:flutter_test/flutter_test.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/assinatura/subscription_service.dart';

void main() {
  group('SubscriptionService product mapping', () {
    test('maps paid plans to store product IDs (SKUs unchanged)', () {
      expect(
        SubscriptionService.productIdForPlan(PlanRules.basico),
        'routine_basico_monthly',
      );
      expect(
        SubscriptionService.productIdForPlan(PlanRules.avancado),
        'routine_plus_monthly',
      );
      expect(
        SubscriptionService.productIdForPlan(PlanRules.colaborativo),
        'routine_premium_monthly',
      );
    });

    test('does not require a product for free plan', () {
      expect(SubscriptionService.productIdForPlan(PlanRules.gratuito), isNull);
    });

    test('resolves plan from product ID', () {
      expect(
        SubscriptionService.planForProductId('routine_premium_monthly'),
        PlanRules.colaborativo,
      );
      expect(
        SubscriptionService.planForProductId('routine_plus_monthly'),
        PlanRules.avancado,
      );
      expect(SubscriptionService.planForProductId('unknown'), isNull);
    });
  });
}

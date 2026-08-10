import 'package:routine/features/assinatura/plan_rules.dart';

class PlanAccess {
  const PlanAccess._();

  static String effectivePlan({
    required bool isSignedIn,
    String? storedPlan,
  }) {
    if (!isSignedIn) return PlanRules.gratuito;
    return PlanRules.normalize(storedPlan);
  }

  static bool requiresAccount(String targetPlan) {
    return PlanRules.normalize(targetPlan) != PlanRules.gratuito;
  }

  static bool canUseCollaborativeFeatures({
    required bool isSignedIn,
    String? storedPlan,
  }) {
    final plan = effectivePlan(isSignedIn: isSignedIn, storedPlan: storedPlan);
    return PlanRules.hasFullAccess(plan);
  }

  static bool canUseCloudBackup({
    required bool isSignedIn,
    String? storedPlan,
  }) {
    final plan = effectivePlan(isSignedIn: isSignedIn, storedPlan: storedPlan);
    return PlanRules.hasCloudBackup(plan);
  }
}

/**
 * Espelha lib/features/assinatura/plan_rules.dart e subscription_service.dart
 * do lado do cliente. Qualquer mudança nos IDs de plano/produto precisa ser
 * replicada nos dois lados.
 */

export const PLAN_GRATUITO = 'gratuito';
export const PLAN_BASICO = 'basico';
export const PLAN_AVANCADO = 'avancado';
export const PLAN_COLABORATIVO = 'colaborativo';

export type PaidPlan =
  | typeof PLAN_BASICO
  | typeof PLAN_AVANCADO
  | typeof PLAN_COLABORATIVO;

export const PRODUCT_ID_TO_PLAN: Record<string, PaidPlan> = {
  routine_basico_monthly: PLAN_BASICO,
  routine_plus_monthly: PLAN_AVANCADO,
  routine_premium_monthly: PLAN_COLABORATIVO,
};

export function isPaidPlan(value: string): value is PaidPlan {
  return value === PLAN_BASICO || value === PLAN_AVANCADO || value === PLAN_COLABORATIVO;
}

export const IAP_SOURCE_GOOGLE_PLAY = 'google_play';
export const IAP_SOURCE_APP_STORE = 'app_store';

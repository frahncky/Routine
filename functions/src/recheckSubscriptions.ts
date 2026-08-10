import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { verifyGooglePlayPurchase } from './googlePlay';
import { verifyAppStorePurchase } from './appStore';
import { appleSharedSecret } from './validatePurchase';
import { IAP_SOURCE_GOOGLE_PLAY, IAP_SOURCE_APP_STORE, PLAN_GRATUITO } from './plans';
import type { ActiveEntitlement } from './types';

/**
 * validatePurchase só roda no momento da compra. Assinaturas do tipo
 * "auto-renovável" podem expirar, ser canceladas ou ter o pagamento
 * recusado depois disso sem que o app volte a escrever em
 * purchase_validations — por isso esta função roda periodicamente e
 * rebaixa para o plano gratuito quem não tem mais uma assinatura ativa na
 * loja.
 *
 * Isso é um recheck por polling, mais simples de operar do que integrar os
 * webhooks de cada loja (Real-time Developer Notifications do Google Play e
 * App Store Server Notifications V2 da Apple). Para um app pequeno, checar
 * 1x/dia é suficiente; para reagir a cancelamentos na hora, o próximo passo
 * seria adicionar esses webhooks.
 */
export const recheckSubscriptions = onSchedule(
  {
    schedule: 'every 24 hours',
    secrets: [appleSharedSecret],
  },
  async () => {
    const db = getFirestore();
    const snapshot = await db
      .collection('users')
      .where('typeAccount', 'in', ['basico', 'avancado', 'colaborativo'])
      .get();

    let downgraded = 0;
    let checked = 0;

    for (const doc of snapshot.docs) {
      const entitlement = doc.data().active_entitlement as
        | ActiveEntitlement
        | undefined;
      if (!entitlement) continue;
      checked++;

      try {
        const verification =
          entitlement.source === IAP_SOURCE_GOOGLE_PLAY
            ? await verifyGooglePlayPurchase({
                productId: entitlement.product_id,
                purchaseToken: entitlement.verification_ref,
              })
            : entitlement.source === IAP_SOURCE_APP_STORE
              ? await verifyAppStorePurchase({
                  productId: entitlement.product_id,
                  receiptData: entitlement.verification_ref,
                  sharedSecret: appleSharedSecret.value(),
                })
              : null;

        if (!verification) continue;

        if (verification.isActive) {
          if (verification.expiryTimeMillis !== entitlement.expiry_time_millis) {
            await doc.ref.update({
              'active_entitlement.expiry_time_millis': verification.expiryTimeMillis,
            });
          }
          continue;
        }

        await doc.ref.update({
          typeAccount: PLAN_GRATUITO,
          active_entitlement: FieldValue.delete(),
          updated_at: FieldValue.serverTimestamp(),
        });
        downgraded++;
        logger.info('Assinatura expirada/cancelada — plano rebaixado', {
          email: doc.id,
          reason: verification.reason,
        });
      } catch (error) {
        logger.error('Falha ao reverificar assinatura', { email: doc.id, error });
      }
    }

    logger.info('recheckSubscriptions concluído', { checked, downgraded });
  },
);

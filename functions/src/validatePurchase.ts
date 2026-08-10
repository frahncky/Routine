import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { defineSecret } from 'firebase-functions/params';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { verifyGooglePlayPurchase } from './googlePlay';
import { verifyAppStorePurchase } from './appStore';
import { PRODUCT_ID_TO_PLAN, IAP_SOURCE_GOOGLE_PLAY, IAP_SOURCE_APP_STORE } from './plans';
import type { ActiveEntitlement, PurchaseValidationDoc } from './types';

export const appleSharedSecret = defineSecret('APPLE_SHARED_SECRET');

/**
 * Gatilho principal da assinatura paga: o app cria/atualiza
 * purchase_validations/{id} com status "pending" assim que a loja confirma
 * uma compra (lib/features/assinatura/subscription_service.dart). Esta
 * função valida o recibo direto com a loja (nunca confia no cliente) e,
 * se válido, libera o plano em users/{email}.typeAccount usando
 * credenciais admin — o único caminho permitido pelas Firestore rules para
 * conceder um plano pago (veja firestore.rules).
 *
 * Usamos onDocumentWritten (não apenas onCreate) para que reenvios do
 * mesmo purchase_validations/{id} (ex.: app reabriu antes da validação
 * terminar) também disparem a validação. O guard `status !== 'pending'`
 * evita loop infinito, já que a própria função deixa de gravar 'pending'.
 */
export const validatePurchase = onDocumentWritten(
  {
    document: 'purchase_validations/{validationId}',
    secrets: [appleSharedSecret],
  },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;

    const data = after.data() as PurchaseValidationDoc;
    if (data.status !== 'pending') return;

    const ref = after.ref;

    try {
      const email = data.email?.trim().toLowerCase();
      if (!email || !data.uid) {
        logger.warn('purchase_validations sem email/uid válido', {
          docId: ref.id,
        });
        await ref.update({
          status: 'rejected',
          reason: 'missing_email_or_uid',
          updated_at: FieldValue.serverTimestamp(),
        });
        return;
      }

      const expectedPlan = PRODUCT_ID_TO_PLAN[data.product_id];
      if (!expectedPlan || expectedPlan !== data.target_plan) {
        logger.warn('product_id/target_plan não correspondem', {
          productId: data.product_id,
          targetPlan: data.target_plan,
        });
        await ref.update({
          status: 'rejected',
          reason: 'product_plan_mismatch',
          updated_at: FieldValue.serverTimestamp(),
        });
        return;
      }

      let verification;
      if (data.source === IAP_SOURCE_GOOGLE_PLAY) {
        verification = await verifyGooglePlayPurchase({
          productId: data.product_id,
          purchaseToken: data.server_verification_data,
        });
      } else if (data.source === IAP_SOURCE_APP_STORE) {
        verification = await verifyAppStorePurchase({
          productId: data.product_id,
          receiptData: data.server_verification_data,
          sharedSecret: appleSharedSecret.value(),
        });
      } else {
        await ref.update({
          status: 'rejected',
          reason: 'unknown_source',
          updated_at: FieldValue.serverTimestamp(),
        });
        return;
      }

      if (!verification.isActive) {
        await ref.update({
          status: 'rejected',
          reason: verification.reason ?? 'not_active',
          updated_at: FieldValue.serverTimestamp(),
        });
        return;
      }

      const entitlement: ActiveEntitlement = {
        plan: expectedPlan,
        source: data.source,
        product_id: data.product_id,
        verification_ref: data.server_verification_data,
        expiry_time_millis: verification.expiryTimeMillis,
        uid: data.uid,
      };

      const db = getFirestore();
      await db.collection('users').doc(email).set(
        {
          typeAccount: expectedPlan,
          active_entitlement: entitlement,
          updated_at: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await ref.update({
        status: 'validated',
        expiry_time_millis: verification.expiryTimeMillis,
        updated_at: FieldValue.serverTimestamp(),
      });

      logger.info('Plano liberado após validação de compra', {
        email,
        plan: expectedPlan,
      });
    } catch (error) {
      logger.error('Falha ao validar compra', error);
      await ref
        .update({
          status: 'error',
          reason: String(error),
          updated_at: FieldValue.serverTimestamp(),
        })
        .catch((updateError) =>
          logger.error('Falha ao gravar status de erro', updateError),
        );
    }
  },
);

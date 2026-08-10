import { google, androidpublisher_v3 } from 'googleapis';
import { logger } from 'firebase-functions/v2';
import type { VerificationResult } from './types';

const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME ?? 'com.routine.app';

let androidPublisherClient: androidpublisher_v3.Androidpublisher | null = null;

/**
 * Usa as credenciais padrão do ambiente (Application Default Credentials) —
 * a conta de serviço de runtime da Cloud Function. Essa conta precisa ser
 * vinculada no Google Play Console (Configurações > Acesso à API) com a
 * permissão "Visualizar dados financeiros" e "Gerenciar pedidos e
 * assinaturas". Veja functions/README.md.
 */
function getClient(): androidpublisher_v3.Androidpublisher {
  if (!androidPublisherClient) {
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });
    androidPublisherClient = google.androidpublisher({ version: 'v3', auth });
  }
  return androidPublisherClient;
}

const ACTIVE_SUBSCRIPTION_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

/**
 * Verifica uma assinatura do Google Play usando a Play Developer API v3
 * (purchases.subscriptionsv2), o endpoint recomendado pelo Google para
 * assinaturas (substitui purchases.subscriptions, hoje legado).
 */
export async function verifyGooglePlayPurchase(params: {
  productId: string;
  purchaseToken: string;
}): Promise<VerificationResult> {
  const { productId, purchaseToken } = params;
  const client = getClient();

  let response;
  try {
    response = await client.purchases.subscriptionsv2.get({
      packageName: PACKAGE_NAME,
      token: purchaseToken,
    });
  } catch (error) {
    logger.error('Falha ao consultar Google Play Developer API', error);
    return { isActive: false, expiryTimeMillis: 0, reason: 'google_play_api_error' };
  }

  const subscription = response.data;
  const subscriptionState = subscription.subscriptionState ?? 'UNKNOWN';

  const lineItem =
    subscription.lineItems?.find((item) => item.productId === productId) ??
    subscription.lineItems?.[0];
  const expiryTimeMillis = lineItem?.expiryTime
    ? new Date(lineItem.expiryTime).getTime()
    : 0;

  const isActive =
    ACTIVE_SUBSCRIPTION_STATES.has(subscriptionState) &&
    expiryTimeMillis > Date.now();

  // Assinaturas não reconhecidas em até 3 dias são reembolsadas
  // automaticamente pelo Google. A API subscriptionsv2 não tem um método de
  // "acknowledge" próprio — o reconhecimento continua sendo feito pelo
  // endpoint legado purchases.subscriptions.acknowledge.
  if (isActive && subscription.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
    try {
      await client.purchases.subscriptions.acknowledge({
        packageName: PACKAGE_NAME,
        subscriptionId: productId,
        token: purchaseToken,
      });
    } catch (error) {
      logger.warn('Falha ao reconhecer assinatura no Google Play', error);
    }
  }

  return {
    isActive,
    expiryTimeMillis,
    reason: isActive ? undefined : `subscriptionState=${subscriptionState}`,
  };
}

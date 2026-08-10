import { logger } from 'firebase-functions/v2';
import type { VerificationResult } from './types';

const PRODUCTION_URL = 'https://buy.itunes.apple.com/verifyReceipt';
const SANDBOX_URL = 'https://sandbox.itunes.apple.com/verifyReceipt';

// Apple retorna 21007 quando um recibo de sandbox é enviado ao endpoint de
// produção — nesse caso é preciso reenviar ao endpoint de sandbox.
const STATUS_SANDBOX_RECEIPT_ON_PRODUCTION = 21007;
const STATUS_OK = 0;

interface LatestReceiptInfo {
  product_id: string;
  expires_date_ms: string;
  transaction_id: string;
}

interface VerifyReceiptResponse {
  status: number;
  latest_receipt_info?: LatestReceiptInfo[];
}

async function callVerifyReceipt(
  url: string,
  receiptData: string,
  sharedSecret: string,
): Promise<VerifyReceiptResponse> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      'receipt-data': receiptData,
      password: sharedSecret,
      'exclude-old-transactions': true,
    }),
  });
  return (await res.json()) as VerifyReceiptResponse;
}

/**
 * Verifica um recibo da App Store pelo endpoint legado verifyReceipt.
 * Apple recomenda migrar para a App Store Server API (JWT + chave privada)
 * para novas integrações — veja functions/README.md para o motivo de termos
 * ficado com o verifyReceipt neste primeiro corte.
 */
export async function verifyAppStorePurchase(params: {
  productId: string;
  receiptData: string;
  sharedSecret: string;
}): Promise<VerificationResult> {
  const { productId, receiptData, sharedSecret } = params;

  let result: VerifyReceiptResponse;
  try {
    result = await callVerifyReceipt(PRODUCTION_URL, receiptData, sharedSecret);
    if (result.status === STATUS_SANDBOX_RECEIPT_ON_PRODUCTION) {
      result = await callVerifyReceipt(SANDBOX_URL, receiptData, sharedSecret);
    }
  } catch (error) {
    logger.error('Falha ao consultar verifyReceipt da Apple', error);
    return { isActive: false, expiryTimeMillis: 0, reason: 'app_store_api_error' };
  }

  if (result.status !== STATUS_OK) {
    return { isActive: false, expiryTimeMillis: 0, reason: `status=${result.status}` };
  }

  const entriesForProduct = (result.latest_receipt_info ?? []).filter(
    (entry) => entry.product_id === productId,
  );
  if (entriesForProduct.length === 0) {
    return { isActive: false, expiryTimeMillis: 0, reason: 'product_not_in_receipt' };
  }

  const expiryTimeMillis = Math.max(
    ...entriesForProduct.map((entry) => Number(entry.expires_date_ms)),
  );
  const isActive = expiryTimeMillis > Date.now();

  return {
    isActive,
    expiryTimeMillis,
    reason: isActive ? undefined : 'expired',
  };
}

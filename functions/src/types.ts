import type { Timestamp } from 'firebase-admin/firestore';

export type ValidationStatus = 'pending' | 'validated' | 'rejected' | 'error';

/** Formato do documento criado pelo cliente em purchase_validations/{id}. */
export interface PurchaseValidationDoc {
  uid: string;
  email: string;
  target_plan: string;
  product_id: string;
  purchase_id?: string | null;
  source: string;
  server_verification_data: string;
  local_verification_data?: string | null;
  status: ValidationStatus;
  created_at?: Timestamp;
  updated_at?: Timestamp;
  reason?: string;
}

export interface VerificationResult {
  isActive: boolean;
  /** Epoch millis em que o acesso concedido por esta compra deixa de valer. */
  expiryTimeMillis: number;
  reason?: string;
}

/** Guardado em users/{email}.active_entitlement para permitir reverificação periódica. */
export interface ActiveEntitlement {
  plan: string;
  source: string;
  product_id: string;
  verification_ref: string;
  expiry_time_millis: number;
  uid: string;
}

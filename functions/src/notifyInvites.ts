import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

interface InviteDoc {
  owner_email?: string;
  owner_name?: string;
  participant_email?: string;
  participant_name?: string;
  activity_title?: string;
  status?: string;
}

/**
 * Notifica por push quando um convite de atividade é criado (avisa o
 * convidado) ou respondido (avisa quem convidou). Best-effort: se o
 * destinatário não tiver token FCM registrado (nunca abriu o app logado,
 * ou desativou notificações), a função simplesmente não faz nada.
 */
export const notifyInvites = onDocumentWritten(
  'activity_invites/{inviteId}',
  async (event) => {
    const before = event.data?.before?.data() as InviteDoc | undefined;
    const after = event.data?.after?.data() as InviteDoc | undefined;
    if (!after) return;

    const statusBefore = before?.status?.toLowerCase();
    const statusAfter = after.status?.toLowerCase();

    if (!before && statusAfter === 'pending') {
      await _notify({
        toEmail: after.participant_email,
        title: 'Novo convite',
        body: `${after.owner_name ?? 'Alguém'} convidou você para "${after.activity_title ?? 'uma atividade'}"`,
        data: { type: 'invite_received', inviteId: event.params.inviteId },
      });
      return;
    }

    if (
      before &&
      statusBefore === 'pending' &&
      (statusAfter === 'accepted' || statusAfter === 'declined')
    ) {
      const verbo = statusAfter === 'accepted' ? 'aceitou' : 'recusou';
      await _notify({
        toEmail: after.owner_email,
        title: 'Resposta ao convite',
        body: `${after.participant_name ?? 'Alguém'} ${verbo} o convite para "${after.activity_title ?? 'uma atividade'}"`,
        data: { type: 'invite_responded', inviteId: event.params.inviteId },
      });
    }
  },
);

async function _notify(options: {
  toEmail?: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const email = options.toEmail?.trim().toLowerCase();
  if (!email) return;

  const db = getFirestore();
  const userRef = db.collection('users').doc(email);
  const userDoc = await userRef.get();
  const tokens = (userDoc.data()?.fcmTokens as string[] | undefined) ?? [];
  if (tokens.length === 0) return;

  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: options.title, body: options.body },
      data: options.data,
    });

    const invalidTokens: string[] = [];
    response.responses.forEach((result, index) => {
      const code = result.error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-argument'
      ) {
        invalidTokens.push(tokens[index]);
      }
    });

    if (invalidTokens.length > 0) {
      await userRef.update({
        fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      });
    }
  } catch (error) {
    logger.error('Falha ao enviar push de convite', { email, error });
  }
}

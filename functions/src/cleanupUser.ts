import { auth } from 'firebase-functions/v1';
import { logger } from 'firebase-functions/v2';
import { getFirestore } from 'firebase-admin/firestore';

/**
 * Disparado quando um usuário é excluído no Firebase Auth (seja pelo app,
 * pelo Console do Firebase ou por requisição web de exclusão de dados).
 *
 * Apaga em cascata todos os dados associados a esse usuário no Firestore:
 * - Documento users/{email} e suas subcoleções (backup_activities, backup_contacts, backup_contact_groups)
 * - Convites pendentes ou enviados pelo usuário em activity_invites
 */
export const cleanupUser = auth.user().onDelete(async (user) => {
  const email = user.email;
  const db = getFirestore();

  logger.info(`Iniciando exclusão de dados do usuário: uid=${user.uid}, email=${email}`);

  if (!email) {
    logger.warn(`Usuário ${user.uid} não possui e-mail cadastrado. Pulando limpeza de coleções.`);
    return;
  }

  try {
    const userDocRef = db.collection('users').doc(email);

    // 1. Limpar subcoleções de backup
    const subcollections = [
      'backup_activities',
      'backup_contacts',
      'backup_contact_groups',
    ];

    for (const subcol of subcollections) {
      const snap = await userDocRef.collection(subcol).get();
      if (!snap.empty) {
        const batch = db.batch();
        snap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        logger.info(`Removidos ${snap.size} documentos de users/${email}/${subcol}`);
      }
    }

    // 2. Apagar documento principal do usuário
    await userDocRef.delete();
    logger.info(`Documento users/${email} apagado com sucesso.`);

    // 3. Limpar convites onde o usuário era proprietário ou participante
    const ownerInvites = await db.collection('activity_invites').where('owner_email', '==', email).get();
    if (!ownerInvites.empty) {
      const batch = db.batch();
      ownerInvites.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      logger.info(`Removidos ${ownerInvites.size} convites criados por ${email}`);
    }

    const participantInvites = await db.collection('activity_invites').where('participant_email', '==', email).get();
    if (!participantInvites.empty) {
      const batch = db.batch();
      participantInvites.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      logger.info(`Removidos ${participantInvites.size} convites para ${email}`);
    }

    logger.info(`Limpeza de dados concluída com sucesso para o usuário ${email}`);
  } catch (error) {
    logger.error(`Erro ao limpar dados do usuário ${email}:`, error);
  }
});

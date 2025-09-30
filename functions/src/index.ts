import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

admin.initializeApp();

const allowedTypes = new Set(['information', 'reminder', 'urgent']);

interface SendAnnouncementPayload {
  type: string;
  title: string;
  message: string;
}

export const sendAdminAnnouncement = functions.https.onCall(
  async (
    data: SendAnnouncementPayload,
    context: functions.https.CallableContext,
  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required.',
      );
    }

    const isAdmin = context.auth.token?.isAdmin === true;
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only administrators can send announcements.',
      );
    }

    const type = String(data?.type ?? '');
    const title = String(data?.title ?? '').trim();
    const message = String(data?.message ?? '').trim();

    if (!allowedTypes.has(type)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Unknown announcement type.',
      );
    }

    if (!title || !message) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Title and message are required.',
      );
    }

    const payload: admin.messaging.Message = {
      topic: 'announcements',
      notification: {
        title: `[${type.toUpperCase()}] ${title}`,
        body: message,
      },
      data: {
        type,
      },
    };

    await admin.messaging().send(payload);

    return { ok: true };
  },
);

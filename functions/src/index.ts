import { initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { isStaleTokenError, shouldSendPush } from './cooldown';
import { CHANNEL_ID, TAG, buildCryPushText } from './messages';

initializeApp();

/**
 * Region of this function. Firestore triggers should run in (or next to) the
 * database location: check Firebase console -> Firestore -> location and set
 * e.g. 'europe-west1' for eur3 or 'us-central1' for nam5 before deploying.
 */
const REGION = 'us-central1';

/**
 * D2: a new cry alert in rooms/{roomId}/alerts/{alertId} -> high priority FCM
 * notification to the paired parent (rooms/{roomId}.viewerFcmToken), so it
 * arrives while the parent app is in the background, the screen is locked
 * or the app was closed.
 */
export const onCryAlertCreated = onDocumentCreated(
  { document: 'rooms/{roomId}/alerts/{alertId}', region: REGION },
  async (event) => {
    const { roomId, alertId } = event.params;
    const alert = event.data?.data() ?? {};
    const db = getFirestore();
    const roomRef = db.collection('rooms').doc(roomId);

    // Read token + apply the cooldown atomically (one push per minute).
    const target = await db.runTransaction(async (tx) => {
      const room = await tx.get(roomRef);
      if (!room.exists) return null;
      const data = room.data() ?? {};
      const token = data.viewerFcmToken;
      if (typeof token !== 'string' || token.length === 0) return null;
      const lastPushAt = data.lastPushAt instanceof Timestamp ? data.lastPushAt.toMillis() : null;
      if (!shouldSendPush(lastPushAt, Date.now())) return null;
      tx.update(roomRef, { lastPushAt: FieldValue.serverTimestamp() });
      return { token, locale: data.viewerLocale };
    });

    if (target === null) {
      logger.debug('No push sent (no token, room gone or cooldown)', { roomId, alertId });
      return;
    }

    const { title, body } = buildCryPushText(target.locale, alert.db);
    try {
      await getMessaging().send({
        token: target.token,
        notification: { title, body },
        data: { type: 'cry_alert', roomId, alertId },
        android: {
          priority: 'high',
          ttl: 60_000,
          notification: { channelId: CHANNEL_ID, tag: TAG, sound: 'default' },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'default' } },
        },
      });
      logger.info('Cry push sent', { roomId, alertId });
    } catch (error: unknown) {
      const code = (error as { code?: unknown })?.code;
      if (isStaleTokenError(code)) {
        logger.warn('Removing stale FCM token', { roomId, code });
        await roomRef.update({ viewerFcmToken: FieldValue.delete() }).catch(() => undefined);
        return;
      }
      logger.error('Cry push failed', { roomId, alertId, error });
      throw error; // let Cloud Functions retry/log
    }
  },
);

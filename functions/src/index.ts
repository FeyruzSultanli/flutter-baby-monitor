import { initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { BATTERY_PUSH_COOLDOWN_MS, PUSH_COOLDOWN_MS, isStaleTokenError, shouldSendPush } from './cooldown';
import { CHANNEL_ID, TAG, TAG_BATTERY, buildBatteryPushText, buildCryPushText } from './messages';

initializeApp();

/**
 * Region of this function. Firestore triggers should run in (or next to) the
 * database location: check Firebase console -> Firestore -> location and set
 * e.g. 'europe-west1' for eur3 or 'us-central1' for nam5 before deploying.
 *
 * The project's Firestore is in eur3 (Europe multi-region), so the function
 * runs in europe-west1, the region Firebase recommends for eur3.
 */
const REGION = 'europe-west1';

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
    // v2: low battery alerts have their own cooldown and notification tag.
    const isBattery = alert.type === 'battery';

    // Read token + apply the cooldown atomically (one push per minute).
    const target = await db.runTransaction(async (tx) => {
      const room = await tx.get(roomRef);
      if (!room.exists) return null;
      const data = room.data() ?? {};
      const token = data.viewerFcmToken;
      if (typeof token !== 'string' || token.length === 0) return null;
      // Separate windows: cry pushes every 60 s at most, battery pushes
      // every 30 min at most (a misbehaving client cannot flood the parent).
      const field = isBattery ? 'lastBatteryPushAt' : 'lastPushAt';
      const cooldown = isBattery ? BATTERY_PUSH_COOLDOWN_MS : PUSH_COOLDOWN_MS;
      const last = data[field] instanceof Timestamp ? (data[field] as Timestamp).toMillis() : null;
      if (!shouldSendPush(last, Date.now(), cooldown)) return null;
      tx.update(roomRef, { [field]: FieldValue.serverTimestamp() });
      return { token, locale: data.viewerLocale };
    });

    if (target === null) {
      logger.debug('No push sent (no token, room gone or cooldown)', { roomId, alertId });
      return;
    }

    const { title, body } = isBattery
      ? buildBatteryPushText(target.locale, alert.level)
      : buildCryPushText(target.locale, alert.db);
    const tag = isBattery ? TAG_BATTERY : TAG;

    // In the local Functions emulator there is no FCM emulator: never call the
    // real FCM API from tests, just record what would have been sent.
    if (process.env.FUNCTIONS_EMULATOR === 'true') {
      logger.info('EMULATOR: would send cry push', { roomId, alertId, title, body });
      const field = isBattery ? 'lastBatteryPushPreview' : 'lastPushPreview';
      await roomRef.update({ [field]: { title, body } }).catch(() => undefined);
      return;
    }

    try {
      await getMessaging().send({
        token: target.token,
        notification: { title, body },
        data: { type: isBattery ? 'battery_low' : 'cry_alert', roomId, alertId },
        android: {
          priority: 'high',
          ttl: isBattery ? 600_000 : 60_000,
          notification: { channelId: CHANNEL_ID, tag, sound: 'default' },
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

/**
 * Push texts and Android notification settings for cry alerts.
 * CHANNEL_ID and TAG must match lib/core/services/notification_service.dart
 * (the app shows local alerts with the same id/tag, so one replaces the other).
 */
export const CHANNEL_ID = 'baby_monitor_alerts';
export const TAG = 'cry_alert';

export type Locale = 'tr' | 'en';

const TEXTS: Record<Locale, { title: string; body: string; bodyWithDb: (db: string) => string }> = {
  tr: {
    title: 'Bebek ağlıyor',
    body: 'Bebek monitörü yüksek ses algıladı.',
    bodyWithDb: (db) => `Ses seviyesi: ${db} dB`,
  },
  en: {
    title: 'Baby is crying',
    body: 'The baby monitor detected a loud noise.',
    bodyWithDb: (db) => `Noise level: ${db} dB`,
  },
};

/** Parent's UI language from the room (`viewerLocale`); Turkish by default. */
export function normalizeLocale(value: unknown): Locale {
  return value === 'en' ? 'en' : 'tr';
}

export function buildCryPushText(locale: unknown, db: unknown): { title: string; body: string } {
  const t = TEXTS[normalizeLocale(locale)];
  const level = typeof db === 'number' && Number.isFinite(db) ? db.toFixed(1) : null;
  return { title: t.title, body: level === null ? t.body : t.bodyWithDb(level) };
}

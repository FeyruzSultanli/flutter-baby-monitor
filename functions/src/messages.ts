/**
 * Push texts and Android notification settings for cry alerts.
 * CHANNEL_ID and TAG must match lib/core/services/notification_service.dart
 * (the app shows local alerts with the same id/tag, so one replaces the other).
 */
export const CHANNEL_ID = 'baby_monitor_alerts';
export const TAG = 'cry_alert';
/** Low battery of the baby phone (Ninni v2 5.7); own notification slot. */
export const TAG_BATTERY = 'battery_low';

export type Locale = 'tr' | 'en' | 'az';

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
  az: {
    title: 'Körpə ağlayır',
    body: 'Körpə monitoru yüksək səs aşkarladı.',
    bodyWithDb: (db) => `Səs səviyyəsi: ${db} dB`,
  },
};

const BATTERY_TEXTS: Record<Locale, { title: string; body: (level: string) => string; bodyUnknown: string }> = {
  tr: {
    title: 'Bebek telefonunun pili azaldı',
    body: (level) => `Pil %${level}. Bebek telefonunu şarja takın.`,
    bodyUnknown: 'Bebek telefonunu şarja takın.',
  },
  en: {
    title: 'Baby phone battery is low',
    body: (level) => `Battery at ${level}%. Plug the baby phone into a charger.`,
    bodyUnknown: 'Plug the baby phone into a charger.',
  },
  az: {
    title: 'Körpə telefonunun batareyası azalıb',
    body: (level) => `Batareya %${level}. Körpə telefonunu şarj cihazına qoşun.`,
    bodyUnknown: 'Körpə telefonunu şarj cihazına qoşun.',
  },
};

/** Parent's UI language from the room (`viewerLocale`); Turkish by default. */
export function normalizeLocale(value: unknown): Locale {
  return value === 'en' || value === 'az' ? value : 'tr';
}

export function buildBatteryPushText(locale: unknown, level: unknown): { title: string; body: string } {
  const t = BATTERY_TEXTS[normalizeLocale(locale)];
  const valid = typeof level === 'number' && Number.isFinite(level);
  return { title: t.title, body: valid ? t.body(String(Math.round(level))) : t.bodyUnknown };
}

export function buildCryPushText(locale: unknown, db: unknown): { title: string; body: string } {
  const t = TEXTS[normalizeLocale(locale)];
  const level = typeof db === 'number' && Number.isFinite(db) ? db.toFixed(1) : null;
  return { title: t.title, body: level === null ? t.body : t.bodyWithDb(level) };
}

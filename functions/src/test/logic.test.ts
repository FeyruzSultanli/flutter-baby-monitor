import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';

import { BATTERY_PUSH_COOLDOWN_MS, PUSH_COOLDOWN_MS, isStaleTokenError, shouldSendPush } from '../cooldown';
import { CHANNEL_ID, TAG, TAG_BATTERY, buildBatteryPushText, buildCryPushText, normalizeLocale } from '../messages';

describe('cooldown', () => {
  const now = 1_000_000_000;

  it('sends the first push', () => {
    assert.equal(shouldSendPush(null, now), true);
    assert.equal(shouldSendPush(undefined, now), true);
  });

  it('blocks pushes inside the window and allows after it', () => {
    assert.equal(shouldSendPush(now - 10_000, now), false);
    assert.equal(shouldSendPush(now - PUSH_COOLDOWN_MS + 1, now), false);
    assert.equal(shouldSendPush(now - PUSH_COOLDOWN_MS, now), true);
  });

  it('does not block forever when lastPushAt is in the future', () => {
    assert.equal(shouldSendPush(now + 5_000, now), true);
  });

  it('recognizes stale token errors', () => {
    assert.equal(isStaleTokenError('messaging/registration-token-not-registered'), true);
    assert.equal(isStaleTokenError('messaging/invalid-registration-token'), true);
    assert.equal(isStaleTokenError('messaging/internal-error'), false);
    assert.equal(isStaleTokenError(undefined), false);
  });
});

describe('messages', () => {
  it('matches the app channel and tag', () => {
    assert.equal(CHANNEL_ID, 'baby_monitor_alerts');
    assert.equal(TAG, 'cry_alert');
  });

  it('defaults to Turkish', () => {
    assert.equal(normalizeLocale(undefined), 'tr');
    assert.equal(normalizeLocale('de'), 'tr');
    assert.equal(normalizeLocale('en'), 'en');
  });

  it('includes the noise level when present', () => {
    assert.deepEqual(buildCryPushText('tr', 72.345), {
      title: 'Bebek ağlıyor',
      body: 'Ses seviyesi: 72.3 dB',
    });
    assert.deepEqual(buildCryPushText('en', 60), {
      title: 'Baby is crying',
      body: 'Noise level: 60.0 dB',
    });
  });

  it('falls back to a generic body without a valid level', () => {
    assert.equal(buildCryPushText('en', undefined).body, 'The baby monitor detected a loud noise.');
    assert.equal(buildCryPushText('tr', Number.NaN).body, 'Bebek monitörü yüksek ses algıladı.');
    assert.equal(buildCryPushText('tr', '72').body, 'Bebek monitörü yüksek ses algıladı.');
  });
});

describe('v2 messages', () => {
  it('knows Azerbaijani', () => {
    assert.equal(normalizeLocale('az'), 'az');
    assert.equal(buildCryPushText('az', 70).title, 'Körpə ağlayır');
  });

  it('builds low battery texts with their own tag', () => {
    assert.equal(TAG_BATTERY, 'battery_low');
    assert.equal(buildBatteryPushText('tr', 12).body, 'Pil %12. Bebek telefonunu şarja takın.');
    assert.equal(buildBatteryPushText('en', 9.6).body, 'Battery at 10%. Plug the baby phone into a charger.');
    assert.equal(buildBatteryPushText('en', undefined).body, 'Plug the baby phone into a charger.');
  });
});

describe('battery cooldown', () => {
  it('allows one battery push per 30 minutes', () => {
    const now = 5_000_000_000;
    assert.equal(shouldSendPush(now - 10 * 60_000, now, BATTERY_PUSH_COOLDOWN_MS), false);
    assert.equal(shouldSendPush(now - BATTERY_PUSH_COOLDOWN_MS, now, BATTERY_PUSH_COOLDOWN_MS), true);
  });
});

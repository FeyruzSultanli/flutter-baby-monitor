/** Same window as the app's client-side cooldown (B05). */
export const PUSH_COOLDOWN_MS = 60_000;

/**
 * Server-side rate limit: at most one push per room per cooldown window,
 * even if clients write alerts more often.
 */
export function shouldSendPush(
  lastPushAtMs: number | null | undefined,
  nowMs: number,
  cooldownMs: number = PUSH_COOLDOWN_MS,
): boolean {
  if (lastPushAtMs == null) return true;
  if (lastPushAtMs > nowMs) return true; // clock oddity: do not block forever
  return nowMs - lastPushAtMs >= cooldownMs;
}

/** FCM error codes meaning the stored token will never work again. */
export function isStaleTokenError(code: unknown): boolean {
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument'
  );
}

// BABY side of the two-device end-to-end test. Run together with
// parent_test.dart on a second emulator via scripts/run_e2e.py.
//
// flutter test integration_test/baby_test.dart -d <serial> \
//   --dart-define=USE_FIREBASE_EMULATOR=true

import 'package:bebek_monitor_clean/core/debug/debug_hooks.dart';
import 'package:bebek_monitor_clean/core/pairing/room_code.dart';
import 'package:bebek_monitor_clean/main.dart' as app;
import 'package:bebek_monitor_clean/screens/v2/baby_night_view.dart';
import 'package:bebek_monitor_clean/theme/components/code_boxes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('baby device end-to-end', (tester) async {
    final db = EmulatorDb();
    app.main();

    // --- First start: intro, then the role screen (V2) ------------------------
    await passOnboarding(tester);
    screenshot('baby_01_first_start');
    result('baby_home_visible', true);

    final uid = await waitFor(() => FirebaseAuth.instance.currentUser?.uid,
        tester: tester, timeout: const Duration(seconds: 30));
    expect(uid, isNotNull, reason: 'anonymous sign-in on the Auth emulator');
    result('baby_anonymous_sign_in', true);

    // --- "Next to the baby": the room is created right away ------------------
    await tester.tap(find.byKey(const Key('roleBaby')));
    final room = await waitFor(() async {
      final rooms = await db.rooms();
      for (final r in rooms) {
        if (r['ownerUid'] == uid) return r;
      }
      return null;
    }, tester: tester, timeout: const Duration(seconds: 40));
    expect(room, isNotNull, reason: 'room document created');
    final code = room!['id'] as String;
    expect(RoomCode.isValid(code), isTrue, reason: 'new 8-char code format');
    result('room_code_valid_format', true);
    await pumpFor(tester, const Duration(seconds: 2));
    final shownCode = await pumpUntil(tester, () {
      final boxes = find.byType(CodeBoxes);
      return boxes.evaluate().isNotEmpty && tester.widget<CodeBoxes>(boxes.first).code == code;
    }, timeout: const Duration(seconds: 10));
    result('room_code_shown_formatted', shownCode);
    expect(room['expiresAt'], isA<DateTime>(),
        reason: 'expiresAt for TTL (D8)');
    screenshot('baby_02_room_code');
    log('ROOM_CODE=$code');
    // ignore: avoid_print
    print('E2E_BABY_READY');

    Future<Map<String, dynamic>?> roomNow() => db.get('rooms/$code');

    // --- Parent joins --------------------------------------------------------
    final session1 = await waitFor<String>(
        () async => (await roomNow())?['viewerSession'] as String?,
        tester: tester,
        timeout: const Duration(minutes: 12),
        step: const Duration(seconds: 1));
    expect(session1, isNotNull, reason: 'parent joined (viewerSession)');
    result('parent_joined_session', true);

    Future<bool> offerFor(String session) async {
      final offer = (await roomNow())?['offer'];
      return offer is Map && offer['session'] == session;
    }

    final offered1 = await pumpUntil(tester, () => offerFor(session1!),
        timeout: const Duration(seconds: 40));
    expect(offered1, isTrue,
        reason: 'baby sends an offer for the parent session (B08)');
    result('offer_for_session_1', true);

    // Real WebRTC state (UI), not the room's isPaired flag.
    final connected1 = await pumpUntil(tester, showsConnected,
        timeout: const Duration(seconds: 60));
    result('webrtc_connected_first_join', connected1);
    screenshot('baby_03_after_join');

    // --- Cry detection (fake cry, debug-only hook) ---------------------------
    await pumpFor(tester, const Duration(seconds: 3));

    // 1) A 1 s burst must not raise the alarm (2 s rule, D5).
    var burstAlarm = false;
    DebugHooks.fakeNoiseDb = 85;
    final burstStart = DateTime.now();
    await pumpUntil(tester, () async {
      if ((await roomNow())?['cryAlert'] == true) burstAlarm = true;
      if (DateTime.now().difference(burstStart) >=
          const Duration(milliseconds: 1000)) {
        DebugHooks.fakeNoiseDb = 30;
      }
      return DateTime.now().difference(burstStart) >=
          const Duration(seconds: 6);
    },
        timeout: const Duration(seconds: 8),
        step: const Duration(milliseconds: 200));
    final alertsAfterBurst = await db.list('rooms/$code/alerts');
    result('cry_1s_burst_no_alarm', !burstAlarm && alertsAfterBurst.isEmpty);
    expect(burstAlarm, isFalse, reason: '1 s burst must not alarm');
    expect(alertsAfterBurst, isEmpty);

    // 2) Sustained cry: alarm after ~2 s, then at most one alert per 60 s.
    final cryStart = DateTime.now();
    DebugHooks.fakeNoiseDb = 85;
    DateTime? alarmAt;
    await pumpUntil(tester, () async {
      if ((await roomNow())?['cryAlert'] == true) {
        alarmAt = DateTime.now();
        return true;
      }
      return false;
    },
        timeout: const Duration(seconds: 15),
        step: const Duration(milliseconds: 200));
    expect(alarmAt, isNotNull, reason: 'sustained cry raises the alarm');
    final delayMs = alarmAt!.difference(cryStart).inMilliseconds;
    result('cry_alarm_delay_ms', delayMs);
    expect(delayMs, greaterThanOrEqualTo(1900), reason: '2 s rule');
    expect(delayMs, lessThan(8000));

    await pumpFor(tester, const Duration(seconds: 8));
    final alertsEarly = await db.list('rooms/$code/alerts');
    result('cry_alerts_first_10s', alertsEarly.length);
    expect(alertsEarly.length, 1, reason: 'one alert at cry start');

    await pumpUntil(
        tester,
        () =>
            DateTime.now().difference(cryStart) >= const Duration(seconds: 50),
        timeout: const Duration(seconds: 60),
        step: const Duration(seconds: 1));
    final alertsAt50 = await db.list('rooms/$code/alerts');
    result('cry_alerts_at_50s', alertsAt50.length);
    expect(alertsAt50.length, 1,
        reason: 'no second alert inside the 60 s window (B05)');

    await pumpUntil(
        tester,
        () =>
            DateTime.now().difference(cryStart) >= const Duration(seconds: 70),
        timeout: const Duration(seconds: 30),
        step: const Duration(seconds: 1));
    final alertsAt70 = await db.list('rooms/$code/alerts');
    result('cry_alerts_at_70s', alertsAt70.length);
    expect(alertsAt70.length, 2,
        reason: 'next alert after 60 s while still crying');
    final firstAlert = alertsAt70.first;
    result('alert_doc_has_db_and_expiry',
        firstAlert['db'] is num && firstAlert['expiresAt'] is DateTime);

    DebugHooks.fakeNoiseDb = 30;
    final calmed = await pumpUntil(
        tester, () async => (await roomNow())?['cryAlert'] == false,
        timeout: const Duration(seconds: 10),
        step: const Duration(milliseconds: 300));
    result('cry_alarm_cleared', calmed);
    DebugHooks.fakeNoiseDb = null;
    screenshot('baby_04_after_cry');

    // Functions emulator: onCryAlertCreated ran (needs a parent push token).
    final pushed = await pumpUntil(
        tester, () async => (await roomNow())?['lastPushAt'] != null,
        timeout: const Duration(seconds: 20));
    result('function_ran_lastPushAt', pushed);
    final preview = (await roomNow())?['lastPushPreview'];
    result('function_push_preview',
        preview is Map ? '${preview['title']} | ${preview['body']}' : 'none');

    // --- Threshold set on the parent arrives here (D5) ----------------------
    final thresholdSynced = await pumpUntil(tester, () async {
      final t = (await roomNow())?['noiseThreshold'];
      return t is num && t >= 79.5;
    }, timeout: const Duration(minutes: 6), step: const Duration(seconds: 1));
    result('threshold_from_parent_in_room', thresholdSynced);
    final thresholdUi = await pumpUntil(tester, () {
      final label = find.byKey(const Key('thresholdLabel'));
      return label.evaluate().isNotEmpty &&
          (tester.widget<Text>(label).data ?? '').contains('80');
    }, timeout: const Duration(seconds: 15));
    result('threshold_from_parent_in_ui', thresholdUi);
    screenshot('baby_05_threshold_synced');

    // --- Parent leaves and rejoins the same code (B08) -----------------------
    final session2 = await waitFor<String>(() async {
      final s = (await roomNow())?['viewerSession'] as String?;
      return (s != null && s != session1) ? s : null;
    },
        tester: tester,
        timeout: const Duration(minutes: 6),
        step: const Duration(seconds: 1));
    result('rejoin_new_session', session2 != null);
    if (session2 != null) {
      final offered2 = await pumpUntil(tester, () => offerFor(session2),
          timeout: const Duration(seconds: 40));
      result('rejoin_offer_renewed', offered2);
      final connected2 = await pumpUntil(tester, showsConnected,
          timeout: const Duration(seconds: 60));
      result('webrtc_connected_after_rejoin', connected2);
    }

    // --- Connection drop on the parent -> automatic rejoin --------------------
    if (skipNetworkDrop) {
      result('auto_rejoin_new_session',
          'skipped (no airplane mode on this platform)');
    } else {
      final session3 = await waitFor<String>(() async {
        final s = (await roomNow())?['viewerSession'] as String?;
        return (s != null && s != session1 && s != session2) ? s : null;
      },
          tester: tester,
          timeout: const Duration(minutes: 8),
          step: const Duration(seconds: 1));
      result('auto_rejoin_new_session', session3 != null);
      if (session3 != null) {
        result(
            'auto_rejoin_offer_renewed',
            await pumpUntil(tester, () => offerFor(session3),
                timeout: const Duration(seconds: 40)));
      }
      screenshot('baby_06_after_reconnect');
    }

    // --- Parent leaves for good ----------------------------------------------
    final left = await pumpUntil(tester, () async {
      final r = await roomNow();
      return r != null &&
          r['viewerSession'] == null &&
          r['viewerFcmToken'] == null;
    }, timeout: const Duration(minutes: 12), step: const Duration(seconds: 1));
    result('parent_left_session_and_token_cleared', left);

    // --- Night mode (D1 stage 1) ------------------------------------------------
    // V2 5.5: the parent's night light test put this phone into night mode
    // (it stays dark when the light goes off, A32). Leave it first.
    Future<void> doubleTapNightView() async {
      final view = find.byKey(const Key('nightModeOverlay'));
      if (view.evaluate().isEmpty) return;
      await tester.tap(view);
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await tester.tap(view);
      await pumpFor(tester, const Duration(seconds: 1));
    }
    final byLight = find.byType(BabyNightView).evaluate().isNotEmpty;
    result('night_light_put_baby_in_night_mode', byLight);
    if (byLight) await doubleTapNightView();
    final nightButton = find.byKey(const Key('nightModeButton'));
    if (nightButton.evaluate().isNotEmpty) {
      await tester.tap(nightButton);
      await pumpFor(tester, const Duration(seconds: 1));
      final overlayShown = find.byType(BabyNightView).evaluate().isNotEmpty;
      result('night_mode_overlay_shown', overlayShown);
      screenshot('baby_07_night_mode');
      final overlay = find.byKey(const Key('nightModeOverlay'));
      if (overlay.evaluate().isNotEmpty) {
        // Real time between the taps: on a device a double tap needs more
        // than 40 ms (kDoubleTapMinTime) and less than 300 ms between them.
        await tester.tap(overlay);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await tester.tap(overlay);
        await pumpFor(tester, const Duration(seconds: 1));
      }
      result('night_mode_double_tap_exit',
          find.byType(BabyNightView).evaluate().isEmpty);
    } else {
      result(
          'night_mode_overlay_shown', 'button not found (no camera preview?)');
    }

    // --- Baby closes the room ------------------------------------------------------
    await tester.ensureVisible(find.byKey(const Key('disconnectButton')));
    await tester.tap(find.byKey(const Key('disconnectButton')));
    await pumpUntil(tester,
        () => find.byKey(const Key('confirmEndBroadcast')).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 5));
    await tester.tap(find.byKey(const Key('confirmEndBroadcast')));
    final deleted = await pumpUntil(
        tester, () async => (await roomNow()) == null,
        timeout: const Duration(seconds: 20));
    result('baby_disconnect_deletes_room', deleted);
    screenshot('baby_08_end');
    // ignore: avoid_print
    print('E2E_DONE');
  }, timeout: const Timeout(Duration(minutes: 45)));
}

// PARENT side of the two-device end-to-end test. Run together with
// baby_test.dart via scripts/run_e2e.py (start the baby first).
//
// flutter test integration_test/parent_test.dart -d <serial> \
//   --dart-define=USE_FIREBASE_EMULATOR=true

import 'package:bebek_monitor_clean/core/alert_history_service.dart';
import 'package:bebek_monitor_clean/core/firebase/emulator_config.dart';
import 'package:bebek_monitor_clean/core/pairing/room_code.dart';
import 'package:bebek_monitor_clean/firebase_options.dart';
import 'package:bebek_monitor_clean/main.dart' as app;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parent device end-to-end', (tester) async {
    final db = EmulatorDb();
    app.main();

    final homeVisible = await pumpUntil(
      tester,
      () => find.byKey(const Key('mainMenuButton')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 90),
    );
    expect(homeVisible, isTrue);
    final uid = await waitFor(() => FirebaseAuth.instance.currentUser?.uid,
        tester: tester, timeout: const Duration(seconds: 30));
    expect(uid, isNotNull);
    result('parent_anonymous_sign_in', true);

    // --- Switch to parent mode ----------------------------------------------
    await tester.tap(find.byKey(const Key('mainMenuButton')));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text(tr('parentMode')).last);
    await pumpFor(tester, const Duration(seconds: 2));
    screenshot('parent_01_parent_mode');

    Future<void> submitCode(String code) async {
      await tester.tap(find.byKey(const Key('mainMenuButton')));
      await pumpFor(tester, const Duration(milliseconds: 800));
      await tester.tap(find.text(tr('enterRoomCode')).last);
      final sheet = await pumpUntil(tester,
          () => find.byKey(const Key('roomCodeField')).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10));
      expect(sheet, isTrue, reason: 'join sheet open');
      await tester.enterText(find.byKey(const Key('roomCodeField')), code);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('joinRoomButton')));
    }

    Future<bool> snackbarShows(String text) =>
        pumpUntil(tester, () => find.text(text).evaluate().isNotEmpty,
            timeout: const Duration(seconds: 25));

    // --- Find the baby's room -------------------------------------------------
    final babyRoom = await waitFor(() async {
      for (final r in await db.rooms()) {
        if (r['ownerUid'] != uid &&
            r['viewerUid'] == null &&
            r['id'] != 'EXPD2345') return r;
      }
      return null;
    },
        tester: tester,
        timeout: const Duration(minutes: 10),
        step: const Duration(seconds: 2));
    expect(babyRoom, isNotNull, reason: 'baby created a room');
    final code = babyRoom!['id'] as String;

    // --- Wrong and expired codes (D3) -------------------------------------------
    await submitCode('ZZZZ2345');
    final wrongRejected = await snackbarShows(tr('roomUnavailable'));
    result('wrong_code_rejected', wrongRejected);
    screenshot('parent_02_wrong_code');
    expect(wrongRejected, isTrue);
    await pumpFor(tester, const Duration(seconds: 5)); // let the snackbar go

    await db.put('rooms/EXPD2345', {
      'roomCode': 'EXPD2345',
      'ownerUid': 'someone-else',
      'viewerUid': null,
      'createdAt': DateTime.now().subtract(const Duration(minutes: 11)),
      'expiresAt': DateTime.now().add(const Duration(hours: 1)),
      'isPaired': false,
      'viewerSession': null,
    });
    await submitCode('expd-2345');
    final expiredRejected = await snackbarShows(tr('roomUnavailable'));
    result('expired_code_rejected', expiredRejected);
    expect(expiredRejected, isTrue);
    await pumpFor(tester, const Duration(seconds: 5));

    // --- Join the baby's room (lower case, no dash) -----------------------------
    await submitCode(code.toLowerCase());
    final claimed = await pumpUntil(
        tester, () async => (await db.get('rooms/$code'))?['viewerUid'] == uid,
        timeout: const Duration(seconds: 30));
    result('parent_claimed_room', claimed);
    expect(claimed, isTrue);
    final connected = await pumpUntil(
        tester, () async => (await db.get('rooms/$code'))?['isPaired'] == true,
        timeout: const Duration(seconds: 75));
    result('parent_webrtc_connected', connected);
    await pumpFor(tester, const Duration(seconds: 3));
    screenshot('parent_03_joined');

    // --- A third device cannot get in (D3) --------------------------------------
    final intruderApp = await Firebase.initializeApp(
        name: 'intruder', options: DefaultFirebaseOptions.currentPlatform);
    final intruderAuth = FirebaseAuth.instanceFor(app: intruderApp);
    await intruderAuth.useAuthEmulator(firebaseEmulatorHost, authEmulatorPort);
    final intruderDb = FirebaseFirestore.instanceFor(app: intruderApp);
    intruderDb.useFirestoreEmulator(
        firebaseEmulatorHost, firestoreEmulatorPort);
    await intruderAuth.signInAnonymously();
    var claimDenied = false;
    var readDenied = false;
    try {
      await intruderDb.collection('rooms').doc(code).update({
        'viewerUid': intruderAuth.currentUser!.uid,
        'viewerSession': 'intruder',
        'isPaired': false,
      }).timeout(const Duration(seconds: 15));
    } on FirebaseException catch (e) {
      claimDenied = e.code == 'permission-denied';
    }
    try {
      await intruderDb
          .collection('rooms')
          .doc(code)
          .get()
          .timeout(const Duration(seconds: 15));
    } on FirebaseException catch (e) {
      readDenied = e.code == 'permission-denied';
    }
    final stillOurs = (await db.get('rooms/$code'))?['viewerUid'] == uid;
    result('third_device_claim_denied', claimDenied);
    result('third_device_read_denied', readDenied);
    result('room_still_paired_with_parent', stillOurs);
    expect(claimDenied && readDenied && stillOurs, isTrue);

    // --- Push token (D2) -----------------------------------------------------------
    final token = await pumpUntil(tester,
        () async => (await db.get('rooms/$code'))?['viewerFcmToken'] is String,
        timeout: const Duration(seconds: 30));
    result('fcm_token_stored_in_room', token);

    // --- Cry alarm from the baby: alert history, function -------------------------
    final twoAlerts = await pumpUntil(
        tester, () async => (await db.list('rooms/$code/alerts')).length >= 2,
        timeout: const Duration(minutes: 5), step: const Duration(seconds: 2));
    result('parent_saw_two_alerts', twoAlerts);
    await pumpFor(tester, const Duration(seconds: 5));
    final history = await AlertHistoryService().getAlerts();
    result('alert_history_entries', history.length);
    expect(history.length, inInclusiveRange(1, 3),
        reason: 'one history entry per 60 s cry window');
    result('alert_history_text_localized',
        history.isNotEmpty && history.first.message == tr('babyCryAlert'));
    screenshot('parent_04_after_cry');

    await tester.tap(find.byIcon(Icons.history));
    await pumpFor(tester, const Duration(seconds: 2));
    screenshot('parent_05_alert_history');
    await tester.pageBack();
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Threshold calibration from the parent (D5) -------------------------------
    await tester.tap(find.byKey(const Key('settingsButton')));
    await pumpFor(tester, const Duration(seconds: 1));
    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.drag(slider, const Offset(1000, 0));
    await pumpFor(tester, const Duration(seconds: 2));
    screenshot('parent_06_threshold');
    await tester.tapAt(const Offset(20, 60)); // close the sheet
    await pumpFor(tester, const Duration(seconds: 1));
    final thresholdWritten = await pumpUntil(tester, () async {
      final t = (await db.get('rooms/$code'))?['noiseThreshold'];
      return t is num && t >= 79.5;
    }, timeout: const Duration(seconds: 15));
    result('threshold_written_to_room', thresholdWritten);

    // --- Leave and rejoin the same code (B08) ---------------------------------------
    final sessionBefore = (await db.get('rooms/$code'))?['viewerSession'];
    await tester.ensureVisible(find.byKey(const Key('disconnectButton')));
    await tester.tap(find.byKey(const Key('disconnectButton')));
    final leftOk = await pumpUntil(tester, () async {
      final r = await db.get('rooms/$code');
      return r?['viewerSession'] == null && r?['viewerFcmToken'] == null;
    }, timeout: const Duration(seconds: 20));
    result('leave_clears_session_and_push_token', leftOk);
    await pumpFor(tester, const Duration(seconds: 3));
    await submitCode(RoomCode.format(code));
    final rejoined = await pumpUntil(tester, () async {
      final s = (await db.get('rooms/$code'))?['viewerSession'];
      return s != null && s != sessionBefore;
    }, timeout: const Duration(seconds: 30));
    result('rejoin_same_code', rejoined);
    final reconnected = await pumpUntil(
        tester, () async => (await db.get('rooms/$code'))?['isPaired'] == true,
        timeout: const Duration(seconds: 75));
    result('rejoin_webrtc_connected', reconnected);
    screenshot('parent_07_rejoined');

    // --- Connection drop -> automatic rejoin (B08/B36) -----------------------------
    // (Skipped where the runner cannot cut the network, e.g. iOS simulator.)
    if (skipNetworkDrop) {
      result('auto_rejoin_after_drop',
          'skipped (no airplane mode on this platform)');
    } else {
      final sessionBeforeDrop = (await db.get('rooms/$code'))?['viewerSession'];
      await hostAction('airplane_on', wait: const Duration(seconds: 3));
      await pumpFor(tester, const Duration(seconds: 25));
      screenshot('parent_08_offline');
      await hostAction('airplane_off', wait: const Duration(seconds: 3));
      final autoRejoined = await pumpUntil(tester, () async {
        try {
          final s = (await db.get('rooms/$code'))?['viewerSession'];
          return s != null && s != sessionBeforeDrop;
        } catch (_) {
          return false; // host emulator not reachable yet
        }
      }, timeout: const Duration(minutes: 4), step: const Duration(seconds: 2));
      result('auto_rejoin_after_drop', autoRejoined);
      screenshot('parent_09_after_drop');
    }

    // --- Settings: language and theme ------------------------------------------------
    await tester.tap(find.byKey(const Key('settingsButton')));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Türkçe'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text('English').last);
    await pumpFor(tester, const Duration(seconds: 1));
    result('language_switch_to_english',
        find.text(en('settings')).evaluate().isNotEmpty);
    await tester.tap(find.text(en('systemDefault')));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text(en('darkMode')).last);
    await pumpFor(tester, const Duration(seconds: 1));
    screenshot('parent_10_english_dark');
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    result('theme_dark_applied', theme.brightness == Brightness.dark);
    await tester.tap(find.text('English'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text('Türkçe').last);
    await pumpFor(tester, const Duration(seconds: 1));
    result('language_switch_back_to_turkish',
        find.text(tr('settings')).evaluate().isNotEmpty);
    await tester.tapAt(const Offset(20, 60));
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Recording and gallery ---------------------------------------------------------
    final record = find.byKey(const Key('recordButton'));
    if (record.evaluate().isNotEmpty) {
      await tester.ensureVisible(record);
      await tester.tap(record);
      await pumpFor(tester, const Duration(seconds: 6));
      screenshot('parent_11_recording');
      await tester.tap(record);
      await pumpFor(tester, const Duration(seconds: 3));
      result('recording_start_stop_no_crash', true);
    } else {
      result('recording_start_stop_no_crash', 'record button not shown');
    }
    await tester.tap(find.byIcon(Icons.video_library_rounded));
    await pumpFor(tester, const Duration(seconds: 3));
    screenshot('parent_12_gallery');
    result('gallery_opens', true);
    await tester.pageBack();
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Leave for good --------------------------------------------------------------------
    await tester.ensureVisible(find.byKey(const Key('disconnectButton')));
    await tester.tap(find.byKey(const Key('disconnectButton')));
    final finalLeave = await pumpUntil(tester,
        () async => (await db.get('rooms/$code'))?['viewerSession'] == null,
        timeout: const Duration(seconds: 20));
    result('parent_final_leave', finalLeave);
    screenshot('parent_13_end');
    // ignore: avoid_print
    print('E2E_DONE');
  }, timeout: const Timeout(Duration(minutes: 45)));
}

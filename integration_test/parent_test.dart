// PARENT side of the two-device end-to-end test. Run together with
// baby_test.dart via scripts/run_e2e.py (start the baby first).
//
// flutter test integration_test/parent_test.dart -d <serial> \
//   --dart-define=USE_FIREBASE_EMULATOR=true

import 'package:bebek_monitor_clean/core/alert_history_service.dart';
import 'package:bebek_monitor_clean/core/firebase/emulator_config.dart';
import 'package:bebek_monitor_clean/core/pairing/recent_room_store.dart';
import 'package:bebek_monitor_clean/core/pairing/room_code.dart';
import 'package:bebek_monitor_clean/firebase_options.dart';
import 'package:bebek_monitor_clean/main.dart' as app;
import 'package:bebek_monitor_clean/screens/video_gallery_screen.dart';
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

    await passOnboarding(tester);
    final uid = await waitFor(() => FirebaseAuth.instance.currentUser?.uid,
        tester: tester, timeout: const Duration(seconds: 30));
    expect(uid, isNotNull);
    result('parent_anonymous_sign_in', true);

    // --- "With me": the join screen ----------------------------------------
    await tester.tap(find.byKey(const Key('roleParent')));
    await pumpFor(tester, const Duration(seconds: 2));
    screenshot('parent_01_parent_mode');

    Future<void> submitCode(String code) async {
      final screen = await pumpUntil(tester,
          () => find.byKey(const Key('roomCodeField')).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 15));
      expect(screen, isTrue, reason: 'join screen visible');
      await tester.enterText(find.byKey(const Key('roomCodeField')), code);
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('joinRoomButton')));
    }

    // V2: a cry opens the full-screen alarm; acknowledge it ("Tamam").
    Future<bool> dismissCryAlarm() async {
      final ok = find.byKey(const Key('cryOk'));
      if (ok.evaluate().isEmpty) return false;
      await tester.tap(ok);
      await pumpFor(tester, const Duration(milliseconds: 800));
      return true;
    }

    Future<bool> snackbarShows(String text) =>
        pumpUntil(tester, () => find.text(text).evaluate().isNotEmpty,
            timeout: const Duration(seconds: 25));

    // --- Find the baby's room -------------------------------------------------
    final babyRoom = await waitFor(() async {
      for (final r in await db.rooms()) {
        if (r['ownerUid'] != uid &&
            r['viewerUid'] == null &&
            r['id'] != 'EXPD2345') {
          return r;
        }
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
    // Real WebRTC state (UI), not the room's isPaired flag.
    final connected = await pumpUntil(tester, showsConnected,
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
    result('cry_alarm_screen_shown',
        find.byKey(const Key('cryAlertView')).evaluate().isNotEmpty);
    screenshot('parent_04a_cry_alarm');
    await dismissCryAlarm();
    await pumpFor(tester, const Duration(seconds: 5));
    final history = await AlertHistoryService().getAlerts();
    result('alert_history_entries', history.length);
    expect(history.length, inInclusiveRange(1, 3),
        reason: 'one history entry per 60 s cry window');
    result('alert_history_text_localized',
        history.isNotEmpty && history.first.message == tr('babyCryAlert'));
    screenshot('parent_04_after_cry');

    await dismissCryAlarm();
    await tester.tap(find.byKey(const Key('historyButton')));
    await pumpFor(tester, const Duration(seconds: 2));
    screenshot('parent_05_alert_history');
    await goBack(tester);
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Threshold calibration from the parent (D5) -------------------------------
    await tester.tap(find.byKey(const Key('settingsButton')));
    await pumpFor(tester, const Duration(seconds: 1));
    final slider = find.byKey(const Key('thresholdSlider'));
    await pumpUntil(tester, () => slider.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10));
    await tester.ensureVisible(slider);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.drag(slider, const Offset(1000, 0));
    await pumpFor(tester, const Duration(seconds: 2));
    screenshot('parent_06_threshold');
    await goBack(tester); // close settings
    await pumpFor(tester, const Duration(seconds: 1));
    final thresholdWritten = await pumpUntil(tester, () async {
      final t = (await db.get('rooms/$code'))?['noiseThreshold'];
      return t is num && t >= 79.5;
    }, timeout: const Duration(seconds: 15));
    result('threshold_written_to_room', thresholdWritten);

    // --- Leave and rejoin the same code (B08) ---------------------------------------
    final sessionBefore = (await db.get('rooms/$code'))?['viewerSession'];
    await tapLiveMenuDisconnect(tester);
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
    final reconnected = await pumpUntil(tester, showsConnected,
        timeout: const Duration(seconds: 75));
    result('rejoin_webrtc_connected', reconnected);
    screenshot('parent_07_rejoined');

    // --- V2 phase 3: recent room, lullaby and night light, talk button --------------
    result('recent_room_remembered', await pumpUntil(tester, () async {
      final rooms = await RecentRoomStore().load();
      return rooms.isNotEmpty && rooms.first.code == code;
    }, timeout: const Duration(seconds: 10)));
    result('talk_button_enabled', await pumpUntil(tester, () {
      final talk = find.byKey(const Key('talkButton'));
      if (talk.evaluate().isEmpty) return false;
      return tester.widget<GestureDetector>(talk).onTapDown != null;
    }, timeout: const Duration(seconds: 15)));
    await tester.tap(find.byKey(const Key('lullabyButton')));
    await pumpUntil(tester, () => find.byKey(const Key('soothe_white')).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10));
    await pumpFor(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('soothe_white')));
    final sootheInRoom = await pumpUntil(tester, () async {
      final soothe = (await db.get('rooms/$code'))?['soothe'];
      return soothe is Map && soothe['track'] == 'white';
    }, timeout: const Duration(seconds: 15));
    result('lullaby_requested_in_room', sootheInRoom);
    await tester.tap(find.byKey(const Key('nightLightSwitch')));
    final lightInRoom = await pumpUntil(tester, () async {
      final light = (await db.get('rooms/$code'))?['nightLight'];
      return light is Map && light['on'] == true;
    }, timeout: const Duration(seconds: 15));
    result('night_light_requested_in_room', lightInRoom);
    screenshot('parent_07a_lullaby');
    await pumpFor(tester, const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('soothe_white'))); // stop
    await tester.tap(find.byKey(const Key('nightLightSwitch'))); // off
    final stopped = await pumpUntil(tester, () async {
      final r = await db.get('rooms/$code');
      final soothe = r?['soothe'];
      final light = r?['nightLight'];
      return soothe is Map && soothe['track'] == null && light is Map && light['on'] == false;
    }, timeout: const Duration(seconds: 15));
    result('lullaby_and_light_stopped', stopped);
    await goBack(tester); // close the sheet
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Connection drop -> automatic rejoin (B08/B36) -----------------------------
    // (Skipped where the runner cannot cut the network, e.g. iOS simulator.)
    if (skipNetworkDrop) {
      result('auto_rejoin_after_drop',
          'skipped (no airplane mode on this platform)');
    } else {
      final sessionBeforeDrop = (await db.get('rooms/$code'))?['viewerSession'];
      await hostAction('airplane_on', wait: const Duration(seconds: 3));
      // V2 5.6: the connection lost alarm appears while the network is down.
      final lostShown = await pumpUntil(
          tester, () => find.byKey(const Key('connectionLostView')).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 25));
      result('connection_lost_alarm_shown', lostShown);
      await pumpFor(tester, const Duration(seconds: 3));
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
      final lostCleared = await pumpUntil(
          tester, () => find.byKey(const Key('connectionLostView')).evaluate().isEmpty,
          timeout: const Duration(seconds: 90));
      result('connection_lost_alarm_cleared_after_reconnect', lostCleared);
      screenshot('parent_09_after_drop');
    }

    // --- Settings: language and theme ------------------------------------------------
    await dismissCryAlarm();
    await tester.tap(find.byKey(const Key('settingsButton')));
    final settingsOpen = await pumpUntil(
        tester, () => find.byKey(const Key('thresholdSlider')).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20));
    expect(settingsOpen, isTrue, reason: 'settings screen open');
    Future<void> pickRow(String rowKey, String option) async {
      final row = find.byKey(Key(rowKey));
      await tester.dragUntilVisible(row, find.byType(ListView), const Offset(0, -250));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(row);
      await pumpUntil(tester, () => find.text(option).evaluate().isNotEmpty,
          timeout: const Duration(seconds: 10));
      await pumpFor(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text(option).last);
      await pumpFor(tester, const Duration(seconds: 1));
    }
    await pickRow('languageRow', 'English');
    result('language_switch_to_english',
        find.text(en('language')).evaluate().isNotEmpty);
    await pickRow('themeRow', en('themeDark'));
    screenshot('parent_10_english_dark');
    final theme = Theme.of(tester.element(find.byKey(const Key('languageRow'))));
    result('theme_dark_applied', theme.brightness == Brightness.dark);
    await pickRow('languageRow', 'Türkçe');
    result('language_switch_back_to_turkish',
        find.text(tr('language')).evaluate().isNotEmpty);
    await goBack(tester);
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
    await pumpFor(tester, const Duration(seconds: 2)); // let a snackbar settle
    await tester.tap(find.byKey(const Key('settingsButton')));
    await pumpUntil(tester, () => find.byType(ListView).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10));
    await pumpFor(tester, const Duration(seconds: 1));
    final galleryRow = find.byKey(const Key('galleryButton'));
    await tester.dragUntilVisible(galleryRow, find.byType(ListView), const Offset(0, -250));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(galleryRow);
    final galleryOpen = await pumpUntil(
        tester, () => find.byType(VideoGalleryScreen).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10));
    await pumpFor(tester, const Duration(seconds: 2));
    screenshot('parent_12_gallery');
    result('gallery_opens', galleryOpen);
    await goBack(tester); // gallery
    await pumpFor(tester, const Duration(seconds: 1));
    await goBack(tester); // settings
    await pumpFor(tester, const Duration(seconds: 1));

    // --- Leave for good --------------------------------------------------------------------
    await tapLiveMenuDisconnect(tester);
    final finalLeave = await pumpUntil(tester,
        () async => (await db.get('rooms/$code'))?['viewerSession'] == null,
        timeout: const Duration(seconds: 20));
    result('parent_final_leave', finalLeave);
    screenshot('parent_13_end');
    // ignore: avoid_print
    print('E2E_DONE');
  }, timeout: const Timeout(Duration(minutes: 45)));
}

/// V2.1 §4: "Disconnect" moved into the live screen's top-right menu.
Future<void> tapLiveMenuDisconnect(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('liveMenuButton')));
  await pumpUntil(tester, () => find.byKey(const Key('disconnectButton')).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 5));
  await tester.tap(find.byKey(const Key('disconnectButton')));
}

// Checks the iOS push chain up to the APNs token on a simulator or iPhone:
// APNs registration -> APNs token in Firebase Messaging -> FCM token.
//
//   flutter test integration_test/push_token_test.dart -d <device>
//
// Simulators (Apple silicon, iOS 16+) get APNs tokens too when the app has
// the aps-environment entitlement. The FCM token step talks to Firebase's
// token service (the same call the app makes for a parent).

import 'package:bebek_monitor_clean/core/services/push_registration.dart';
import 'package:bebek_monitor_clean/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('APNs token reaches Firebase Messaging, then an FCM token',
      (tester) async {
    expect(defaultTargetPlatform, TargetPlatform.iOS);
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final messaging = FirebaseMessaging.instance;

    Future<String?> waitForApns(Duration timeout) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        final token = await messaging.getAPNSToken();
        if (token != null) return token;
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)));
      }
      return null;
    }

    // 1. Without our registration call: does the plugin register by itself?
    final withoutCall = await waitForApns(const Duration(seconds: 8));
    // ignore: avoid_print
    print('PUSH_CHAIN apns_without_app_call=${withoutCall != null}');

    // 2. With the app's registration (what NotificationService does on iOS).
    final apns = await PushRegistration.ensureApnsToken(
        timeout: const Duration(seconds: 15));
    // ignore: avoid_print
    print('PUSH_CHAIN apns_after_app_call=${apns != null} '
        'registration=${await PushRegistration.apnsStatus()}');
    expect(apns, isNotNull, reason: 'APNs token set in Firebase Messaging');

    String? fcm;
    Object? fcmError;
    try {
      fcm = await messaging.getToken();
    } catch (e) {
      fcmError = e;
    }
    // ignore: avoid_print
    print('PUSH_CHAIN fcm_token=${fcm != null && fcm.isNotEmpty} '
        'error=${fcmError ?? '-'}');
  });
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the phone has a network (V2.1 §3), from the `ninni/network`
/// platform channel (Android ConnectivityManager, iOS NWPathMonitor).
///
/// Starts as "online" and stays online when the channel is missing (tests,
/// desktop), so a missing channel never blocks the app.
class NetworkStatus extends ChangeNotifier {
  NetworkStatus._();
  static final NetworkStatus instance = NetworkStatus._();

  static const EventChannel _channel = EventChannel('ninni/network');

  StreamSubscription<dynamic>? _sub;
  bool _online = true;
  DateTime? _offlineSince;

  bool get online => _online;
  DateTime? get offlineSince => _offlineSince;

  /// Starts listening (idempotent).
  void start() {
    if (_sub != null || kIsWeb) return;
    try {
      _sub = _channel.receiveBroadcastStream().listen(
        (dynamic value) => _set(value != false),
        onError: (Object e) => debugPrint('Network status error: $e'),
      );
    } catch (e) {
      debugPrint('Network status unavailable: $e');
    }
  }

  void _set(bool online) {
    if (online == _online) return;
    _online = online;
    _offlineSince = online ? null : DateTime.now();
    debugPrint('NETDIAG online=$online');
    notifyListeners();
  }

  /// Tests and demo scenes.
  @visibleForTesting
  void debugSet(bool online) => _set(online);
}

import '../enums/connection_status.dart';

/// Parent side: decides when the link to the baby phone counts as lost
/// (V2 5.6). Pure logic; the caller feeds it status changes and "media
/// arrived" ticks and calls [evaluate] about once a second.
///
/// Lost when, during an active session that was connected at least once:
/// - the connection failed, or
/// - it has not been connected for [disconnectGrace] (WebRTC
///   `disconnected` / Nearby disconnect), or
/// - it is connected but no frame/audio arrived for [mediaTimeout].
/// Recovers by itself once connected again and media flows.
class ConnectionWatchdog {
  ConnectionWatchdog({
    this.mediaTimeout = const Duration(seconds: 20),
    this.disconnectGrace = const Duration(seconds: 5),
  });

  final Duration mediaTimeout;
  final Duration disconnectGrace;

  bool _active = false;
  bool _everConnected = false;
  ConnectionStatus _status = ConnectionStatus.DISCONNECTED;
  DateTime? _notConnectedSince;
  DateTime? _connectedAt;
  DateTime? _lastMedia;
  bool _lost = false;
  DateTime? _lostSince;

  bool get isActive => _active;
  bool get isLost => _lost;

  /// When the current loss started (null while not lost).
  DateTime? get lostSince => _lostSince;

  /// Starts watching a session (parent joined / started discovery).
  void start() {
    _active = true;
    _everConnected = false;
    _status = ConnectionStatus.CONNECTING;
    _notConnectedSince = null;
    _connectedAt = null;
    _lastMedia = null;
    _lost = false;
    _lostSince = null;
  }

  /// The user ended the session: never alarm afterwards.
  void stop() {
    _active = false;
    _lost = false;
    _lostSince = null;
  }

  void onStatus(ConnectionStatus status, DateTime now) {
    if (status == _status) return;
    _status = status;
    if (status == ConnectionStatus.CONNECTED) {
      _everConnected = true;
      _connectedAt = now;
      _notConnectedSince = null;
    } else {
      _notConnectedSince ??= now;
    }
  }

  /// A video frame or audio data arrived from the baby.
  void onMedia(DateTime now) {
    _lastMedia = now;
  }

  /// Returns true if the lost state changed.
  bool evaluate(DateTime now) {
    final lost = _computeLost(now);
    if (lost == _lost) return false;
    _lost = lost;
    _lostSince = lost ? now : null;
    return true;
  }

  bool _computeLost(DateTime now) {
    if (!_active || !_everConnected) return false;
    if (_status == ConnectionStatus.FAILED) return true;
    if (_status != ConnectionStatus.CONNECTED) {
      final since = _notConnectedSince;
      return since != null && now.difference(since) >= disconnectGrace;
    }
    // Connected: media must keep flowing. Before the first media after a
    // (re)connect, count from the connect time.
    final connectedAt = _connectedAt ?? now;
    final media = _lastMedia;
    final last = (media == null || media.isBefore(connectedAt)) ? connectedAt : media;
    return now.difference(last) >= mediaTimeout;
  }
}

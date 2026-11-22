import 'package:flutter/foundation.dart';

/// Live diagnostics for real-device debugging (V2.1 §1, §2): what the cry
/// detection measures and sends, what the parent receives, and the talk
/// channel. Filled by MonitorController about once a second; shown on the
/// hidden diagnostics screen (Settings: tap the version 5 times) and logged
/// as one CRYDIAG / TALKDIAG line per second.
class MonitorDiag {
  // Common
  String role = '-';
  String mode = 'online';
  String connection = '-';
  bool online = true;

  // Baby: cry detection
  /// Where the dB comes from: webrtc (call), record (standby), fake (E2E),
  /// nearby (offline) or none.
  String source = 'none';
  double? rawLevel; // WebRTC audioLevel 0..1
  double? rmsLevel; // WebRTC energy RMS 0..1
  double? db; // value fed to the detector
  double? threshold; // effective threshold (lullaby adjustment included)
  int overMs = 0; // how long the level has been above the threshold
  bool alarm = false;
  bool talkSuppressed = false;
  String write = '-'; // last cry state write: ok / error code
  int? writeMs; // latency of that write
  DateTime? writeAt;
  int writesOk = 0;
  int writesFailed = 0;
  bool standbyMic = false;

  // Parent: received cry state
  bool cryAlert = false;
  double? cryDb;
  int? cryAgeMs; // parent clock - server cryUpdated (includes clock skew)
  bool cryFresh = false;
  bool alarmShown = false;

  // Audio flow (both)
  int? audioBytesSent;
  int? audioBytesReceived;
  double? remoteLevel;
  double? rttMs;
  String quality = '-';

  // Talk channel
  bool canTalk = false;
  bool talking = false;
  String micPermission = '-';
  bool talkFlowing = false; // parent: our audio bytes are growing
  bool hearingParent = false; // baby: parent's audio bytes are growing
  String talkVia = 'none';
  String? offerAudio;
  String? answerAudio;
  String? replaceTrack;
  String? talkMic;
  String? audioSession;
  String? speaker;

  /// Native audio route (ninni/device audioRoute), refreshed on the screen.
  Map<String, Object?> route = const {};

  static String _f(double? v, [int digits = 1]) => v == null ? '-' : v.toStringAsFixed(digits);

  /// One CRYDIAG line (plan V2.1 §1 format).
  String cryLine() {
    if (role == 'baby') {
      return 'CRYDIAG role=baby src=$source raw=${_f(rawLevel, 3)} rms=${_f(rmsLevel, 3)} '
          'db=${_f(db)} thr=${_f(threshold)} over=$overMs alarm=$alarm '
          'write=$write${writeMs == null ? '' : '(${writeMs}ms)'} ok=$writesOk err=$writesFailed '
          'talkMute=$talkSuppressed bytesOut=${audioBytesSent ?? '-'} net=${online ? 'up' : 'down'}';
    }
    return 'CRYDIAG role=parent cryAlert=$cryAlert cryDb=${_f(cryDb)} age=${cryAgeMs ?? '-'} '
        'fresh=$cryFresh alarm=$alarmShown level=${_f(db)} bytesIn=${audioBytesReceived ?? '-'} '
        'rtt=${_f(rttMs, 0)} q=$quality net=${online ? 'up' : 'down'}';
  }

  /// One TALKDIAG line (V2.1 §2).
  String talkLine() {
    if (role == 'baby') {
      return 'TALKDIAG role=baby hearing=$hearingParent bytesIn=${audioBytesReceived ?? '-'} '
          'level=${_f(remoteLevel, 3)} offer=$offerAudio answer=$answerAudio '
          'speaker=$speaker session=$audioSession';
    }
    return 'TALKDIAG role=parent canTalk=$canTalk talking=$talking perm=$micPermission '
        'via=$talkVia answer=$answerAudio replace=$replaceTrack mic=$talkMic '
        'flowing=$talkFlowing bytesOut=${audioBytesSent ?? '-'} level=${_f(rawLevel, 3)}';
  }

  /// Everything as "key: value" rows (diagnostics screen, copy button).
  List<(String, String)> rows() => [
        ('role', role),
        ('mode', mode),
        ('connection', connection),
        ('network', online ? 'online' : 'offline'),
        if (role == 'baby') ...[
          ('dB source', source),
          ('audioLevel (raw)', _f(rawLevel, 3)),
          ('energy RMS', _f(rmsLevel, 3)),
          ('dB', _f(db)),
          ('threshold', _f(threshold)),
          ('above threshold', '$overMs ms'),
          ('alarm', '$alarm'),
          ('talk mutes detection', '$talkSuppressed'),
          ('standby mic (record)', '$standbyMic'),
          ('last cry write', '$write${writeMs == null ? '' : ' (${writeMs}ms)'}'),
          ('writes ok / failed', '$writesOk / $writesFailed'),
          ('hearing parent', '$hearingParent'),
        ] else ...[
          ('room cryAlert', '$cryAlert'),
          ('room cryDb', _f(cryDb)),
          ('cry state age', cryAgeMs == null ? '-' : '$cryAgeMs ms'),
          ('fresh', '$cryFresh'),
          ('alarm shown', '$alarmShown'),
          ('received level', _f(db)),
          ('talk: can talk', '$canTalk'),
          ('talk: talking', '$talking'),
          ('talk: mic permission', micPermission),
          ('talk: audio flowing', '$talkFlowing'),
          ('talk: own level', _f(rawLevel, 3)),
          ('talk: transceiver via', talkVia),
          ('talk: replaceTrack', replaceTrack ?? '-'),
          ('talk: microphone', talkMic ?? '-'),
        ],
        ('offer audio', offerAudio ?? '-'),
        ('answer audio', answerAudio ?? '-'),
        ('audio bytes sent', '${audioBytesSent ?? '-'}'),
        ('audio bytes received', '${audioBytesReceived ?? '-'}'),
        ('received audioLevel', _f(remoteLevel, 3)),
        ('RTT', rttMs == null ? '-' : '${rttMs!.round()} ms'),
        ('quality', quality),
        ('iOS audio session', audioSession ?? '-'),
        ('speakerphone', speaker ?? '-'),
        for (final e in route.entries) ('route.${e.key}', '${e.value}'),
      ];

  String asText() => rows().map((r) => '${r.$1}: ${r.$2}').join('\n');
}

/// Listenable wrapper so only the diagnostics screen rebuilds.
class MonitorDiagNotifier extends ChangeNotifier {
  final MonitorDiag value = MonitorDiag();
  void changed() => notifyListeners();
}

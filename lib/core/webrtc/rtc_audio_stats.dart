import 'dart:math';

/// One `getStats()` result reduced to what the monitor needs (V2.1 §1, §2):
/// audio levels for cry detection and the talk button, audio byte counters
/// (is sound really flowing?), and RTT / packet loss for the connection
/// quality pill. Pure, so it can be tested with recorded stats.
class RtcStatsSnapshot {
  const RtcStatsSnapshot({
    this.localLevel,
    this.localEnergy,
    this.localDuration,
    this.remoteLevel,
    this.remoteEnergy,
    this.remoteDuration,
    this.audioBytesSent,
    this.audioPacketsSent,
    this.audioBytesReceived,
    this.audioPacketsReceived,
    this.inboundBytes,
    this.videoFramesDecoded,
    this.rttMs,
    this.packetsLost,
    this.packetsReceived,
  });

  /// `media-source` (or legacy local `track`) audioLevel, 0..1.
  final double? localLevel;

  /// `media-source` totalAudioEnergy / totalSamplesDuration (seconds).
  final double? localEnergy;
  final double? localDuration;

  /// `inbound-rtp` audio audioLevel, 0..1.
  final double? remoteLevel;
  final double? remoteEnergy;
  final double? remoteDuration;

  /// `outbound-rtp` audio.
  final int? audioBytesSent;
  final int? audioPacketsSent;

  /// `inbound-rtp` audio.
  final int? audioBytesReceived;
  final int? audioPacketsReceived;

  /// All `inbound-rtp` bytes (video + audio), for the connection watchdog.
  final int? inboundBytes;
  final int? videoFramesDecoded;

  /// Selected candidate pair currentRoundTripTime (or remote-inbound-rtp
  /// roundTripTime) in milliseconds.
  final double? rttMs;

  /// Inbound RTP packets lost / received (all kinds).
  final int? packetsLost;
  final int? packetsReceived;

  static const empty = RtcStatsSnapshot();

  /// [reports]: `(type, values)` of every StatsReport.
  static RtcStatsSnapshot parse(Iterable<(String, Map<dynamic, dynamic>)> reports) {
    double? localLevel, localEnergy, localDuration;
    double? remoteLevel, remoteEnergy, remoteDuration;
    int? bytesSent, packetsSent, bytesReceived, packetsReceived, inbound, frames;
    double? rtt, remoteInboundRtt;
    int? lost, received;
    String? selectedPairId;
    final pairs = <String, Map<dynamic, dynamic>>{};

    for (final (type, v) in reports) {
      final kind = v['kind'] ?? v['mediaType'];
      switch (type) {
        case 'media-source':
          if (kind == 'audio') {
            localLevel ??= _d(v['audioLevel']);
            localEnergy ??= _d(v['totalAudioEnergy']);
            localDuration ??= _d(v['totalSamplesDuration']);
          }
        case 'track':
          // Legacy stats (older libwebrtc builds).
          if (kind == 'audio') {
            if (v['remoteSource'] == true) {
              remoteLevel ??= _d(v['audioLevel']);
            } else {
              localLevel ??= _d(v['audioLevel']);
              localEnergy ??= _d(v['totalAudioEnergy']);
              localDuration ??= _d(v['totalSamplesDuration']);
            }
          }
        case 'outbound-rtp':
          if (kind == 'audio') {
            bytesSent = (bytesSent ?? 0) + (_i(v['bytesSent']) ?? 0);
            packetsSent = (packetsSent ?? 0) + (_i(v['packetsSent']) ?? 0);
          }
        case 'inbound-rtp':
          final b = _i(v['bytesReceived']);
          if (b != null) inbound = (inbound ?? 0) + b;
          final l = _i(v['packetsLost']);
          if (l != null) lost = (lost ?? 0) + max(0, l);
          final r = _i(v['packetsReceived']);
          if (r != null) received = (received ?? 0) + r;
          if (kind == 'audio') {
            remoteLevel ??= _d(v['audioLevel']);
            remoteEnergy ??= _d(v['totalAudioEnergy']);
            remoteDuration ??= _d(v['totalSamplesDuration']);
            if (b != null) bytesReceived = (bytesReceived ?? 0) + b;
            if (r != null) packetsReceived = (packetsReceived ?? 0) + r;
          } else if (kind == 'video') {
            frames ??= _i(v['framesDecoded'] ?? v['framesReceived']);
          }
        case 'remote-inbound-rtp':
          remoteInboundRtt ??= _d(v['roundTripTime']);
        case 'transport':
          selectedPairId ??= v['selectedCandidatePairId'] as String?;
        case 'candidate-pair':
          final id = v['id'] as String?;
          if (id != null) pairs[id] = v;
          final nominated = v['nominated'] == true || v['selected'] == true;
          if (nominated && v['state'] == 'succeeded') {
            rtt ??= _d(v['currentRoundTripTime']);
          }
      }
    }
    if (selectedPairId != null && pairs[selectedPairId] != null) {
      rtt = _d(pairs[selectedPairId]!['currentRoundTripTime']) ?? rtt;
    }
    rtt ??= remoteInboundRtt;
    return RtcStatsSnapshot(
      localLevel: localLevel,
      localEnergy: localEnergy,
      localDuration: localDuration,
      remoteLevel: remoteLevel,
      remoteEnergy: remoteEnergy,
      remoteDuration: remoteDuration,
      audioBytesSent: bytesSent,
      audioPacketsSent: packetsSent,
      audioBytesReceived: bytesReceived,
      audioPacketsReceived: packetsReceived,
      inboundBytes: inbound,
      videoFramesDecoded: frames,
      rttMs: rtt == null ? null : rtt * 1000,
      packetsLost: lost,
      packetsReceived: received,
    );
  }

  static double? _d(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _i(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// RMS level (0..1) from the growth of `totalAudioEnergy` over
/// `totalSamplesDuration` between two stats samples. The W3C stats spec
/// recommends this over `audioLevel`: it averages the whole interval instead
/// of a short peak, and still works where `audioLevel` stays 0 (V2.1 §1).
class EnergyLevelMeter {
  double? _energy;
  double? _duration;

  /// Feeds the cumulative counters; returns the interval's RMS level or null
  /// (first sample, counters missing, reset, or no new samples).
  double? update(double? energy, double? duration) {
    if (energy == null || duration == null) return null;
    final prevE = _energy;
    final prevD = _duration;
    _energy = energy;
    _duration = duration;
    if (prevE == null || prevD == null) return null;
    final dE = energy - prevE;
    final dT = duration - prevD;
    if (dT <= 0 || dE < 0) return null;
    return sqrt(dE / dT).clamp(0.0, 1.0);
  }

  void reset() {
    _energy = null;
    _duration = null;
  }
}

/// Counter that tells whether bytes are still flowing (talk button: "the
/// baby hears you", baby side: "the parent is talking").
class ByteFlow {
  int? _last;
  DateTime? _lastGrowth;

  void update(int? bytes, DateTime now) {
    if (bytes == null) return;
    final last = _last;
    if (last != null && bytes > last) _lastGrowth = now;
    _last = bytes;
  }

  bool flowing(DateTime now, {Duration within = const Duration(milliseconds: 1500)}) {
    final g = _lastGrowth;
    return g != null && now.difference(g) <= within;
  }

  int? get total => _last;

  void reset() {
    _last = null;
    _lastGrowth = null;
  }
}

enum ConnectionQuality { good, fair, poor }

/// Connection quality pill on the parent's live screen (V2.1 §4) from real
/// RTT and the packet loss of the last interval.
class ConnectionQualityMeter {
  int? _lost;
  int? _received;
  double _lossEwma = 0;

  ConnectionQuality? _quality;
  ConnectionQuality? get quality => _quality;

  ConnectionQuality? update(RtcStatsSnapshot s) {
    final lost = s.packetsLost;
    final received = s.packetsReceived;
    if (lost != null && received != null && _lost != null && _received != null) {
      final dl = lost - _lost!;
      final dr = received - _received!;
      if (dr + dl > 0 && dl >= 0) {
        final loss = dl / (dr + dl);
        _lossEwma = _lossEwma * 0.7 + loss * 0.3;
      }
    }
    _lost = lost;
    _received = received;
    final rtt = s.rttMs;
    if (rtt == null && received == null) return _quality;
    _quality = classify(rttMs: rtt, loss: _lossEwma);
    return _quality;
  }

  static ConnectionQuality classify({double? rttMs, double loss = 0}) {
    final r = rttMs ?? 0;
    if (r > 600 || loss > 0.08) return ConnectionQuality.poor;
    if (r > 250 || loss > 0.02) return ConnectionQuality.fair;
    return ConnectionQuality.good;
  }

  void reset() {
    _lost = null;
    _received = null;
    _lossEwma = 0;
    _quality = null;
  }
}

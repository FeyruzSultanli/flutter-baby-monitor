import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../enums/connection_status.dart';
import '../pairing/pairing_service.dart';
import 'signaling_interface.dart';

/// Owns RTCPeerConnection, local/remote renderers and signaling wiring.
///
/// Session protocol (B08): every parent join writes a new `viewerSession` to
/// the room. The baby keeps its camera/microphone stream for the whole
/// broadcast, but builds a fresh peer connection and a fresh offer for each
/// session ([onViewerSessionChanged]). The parent answers only the offer of
/// its own session ([startAsParent]). This way a parent can leave and join
/// the same room again, and stale offers/answers/candidates are ignored.
class WebRTCService {
  WebRTCService({
    required SignalingInterface signalingService,
    PairingService? pairingService,
    this.onStatusChanged,
    this.onError,
    this.beforeBabyCall,
    this.onBabyStandby,
  })  : _signalingService = signalingService,
        _pairingService = pairingService;

  /// Baby side: awaited before a peer for a parent session is built. WebRTC
  /// opens the microphone once that call is set up, so another microphone
  /// reader (the standby noise meter) must be stopped here.
  final Future<void> Function()? beforeBabyCall;

  /// Baby side: called after a standby peer (no parent / call lost) was
  /// built. WebRTC does not capture audio in standby (its audio level stays
  /// 0), so cry detection needs its own microphone reader then.
  final void Function()? onBabyStandby;

  /// How long a `disconnected` peer may take to recover before it counts as
  /// failed (B36). Short Wi-Fi hiccups usually recover within a few seconds.
  static const Duration disconnectGrace = Duration(seconds: 10);

  final SignalingInterface _signalingService;
  final PairingService? _pairingService;
  final void Function(ConnectionStatus status)? onStatusChanged;
  final void Function(String message)? onError;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  StreamSubscription<RTCSessionDescription?>? _answerSub;
  StreamSubscription<RTCSessionDescription?>? _offerSub;
  StreamSubscription<RTCIceCandidate>? _remoteCandidateSub;

  ConnectionStatus _status = ConnectionStatus.DISCONNECTED;
  Timer? _disconnectTimer;
  // Parent: no offer for our session within this time counts as failed, so
  // the automatic rejoin (with backoff) takes over.
  static const Duration offerTimeout = Duration(seconds: 20);
  Timer? _offerTimer;

  // Baby side
  String? _roomCode;
  String? _babySession;
  bool _isBaby = false;
  // True while the baby's peer belongs to a parent session (a call); false
  // in standby.
  bool _babyInCall = false;
  Future<void> _babyNegotiation = Future.value();
  // Incremented by startAsBaby/startAsParent/hangUp; an in-flight negotiation
  // of an older generation abandons its peer instead of installing it.
  int _generation = 0;
  // Remote candidates received before the remote description (B64).
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionApplied = false;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> dispose() async {
    await hangUp();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }

  void _setStatus(ConnectionStatus status) {
    _status = status;
    onStatusChanged?.call(status);
  }

  void _reportError(String message, [Object? error]) {
    debugPrint('WebRTC error: $message ${error ?? ''}');
    onError?.call(message);
    _setStatus(ConnectionStatus.FAILED);
  }

  /// Closes the peer connection and its signaling subscriptions, but keeps
  /// the local camera/microphone stream.
  Future<void> _closePeer() async {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    _offerTimer?.cancel();
    _offerTimer = null;
    _pendingRemoteCandidates.clear();
    _remoteDescriptionApplied = false;
    await _remoteCandidateSub?.cancel();
    await _answerSub?.cancel();
    await _offerSub?.cancel();
    _remoteCandidateSub = null;
    _answerSub = null;
    _offerSub = null;
    final pc = _peerConnection;
    _peerConnection = null;
    await pc?.close();
    await pc?.dispose();
  }

  Future<void> _ensurePeerClosed() async {
    await _closePeer();
    await _localStream?.dispose();
    _localStream = null;
  }

  Map<String, dynamic> get _iceServers => {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

  Future<RTCPeerConnection> _createPeerConnection() {
    final config = _iceServers;
    const constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };
    return createPeerConnection(config, constraints);
  }

  Future<MediaStream> _createLocalStream({String facingMode = 'environment'}) async {
    try {
      return await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': facingMode,
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 30},
        },
      });
    } catch (e) {
      // The iOS simulator has no camera. In debug builds on the simulator only,
      // fall back to an audio-only stream so signaling, the peer connection
      // and the audio path can still be tested (flutter_webrtc has no
      // synthetic video source on iOS). Real devices are unaffected.
      if (_isDebugIosSimulator) {
        debugPrint('No camera on the iOS simulator, using audio only (debug): $e');
        return navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      }
      rethrow;
    }
  }

  static bool get _isDebugIosSimulator =>
      kDebugMode &&
      !kIsWeb &&
      Platform.isIOS &&
      Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

  Future<double?> getAudioLevel() async {
    if (_peerConnection == null) return null;
    try {
      final stats = await _peerConnection!.getStats();
      for (var report in stats) {
        // Check for media-source (standard) or track (some implementations)
        if ((report.type == 'media-source' || report.type == 'track') &&
            report.values['kind'] == 'audio' &&
            report.values['audioLevel'] != null) {
          final val = report.values['audioLevel'];
          if (val is num) return val.toDouble();
        }
      }
    } catch (e) {
      debugPrint('getStats error: $e');
    }
    return null;
  }

  /// Handles a peer connection state change. A `disconnected` peer gets
  /// [disconnectGrace] to recover before it counts as failed (B36).
  void _onPeerState(RTCPeerConnectionState state, String roomCode) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        _setStatus(ConnectionStatus.CONNECTED);
        final pairing = _pairingService;
        if (pairing != null) {
          unawaited(pairing.setPaired(roomCode, true).catchError(
              (Object e) => debugPrint('setPaired failed: $e')));
        }
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _setStatus(ConnectionStatus.CONNECTING);
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(disconnectGrace, () => _onPeerLost());
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _disconnectTimer?.cancel();
        _disconnectTimer = null;
        _onPeerLost();
        break;
      default:
        break;
    }
  }

  void _onPeerLost() {
    if (_isBaby) {
      // The baby just waits: the parent rejoins with a new session, which
      // triggers a fresh offer.
      _setStatus(ConnectionStatus.CONNECTING);
      _babyCallLost();
    } else {
      _setStatus(ConnectionStatus.FAILED);
    }
  }

  /// Baby side: the call failed (e.g. the parent's app was closed). There is
  /// no ICE restart, so the peer cannot recover; the parent comes back with
  /// a new session. Replace it with a standby peer so WebRTC releases the
  /// microphone and the standby noise meter can keep detecting cries (for
  /// push notifications) meanwhile. [_babySession] is kept, so further room
  /// snapshots with the old session do not start a new offer.
  void _babyCallLost() {
    final generation = _generation;
    _babyNegotiation = _babyNegotiation.then((_) async {
      if (generation != _generation || !_isBaby || !_babyInCall) return;
      final roomCode = _roomCode;
      if (roomCode == null || _localStream == null) return;
      try {
        await _closePeer();
        // Standby candidates must not be written under the old session.
        _signalingService.session = null;
        if (generation != _generation) return;
        await _buildBabyPeer(roomCode, session: null, generation: generation);
      } catch (e) {
        debugPrint('Standby after lost call failed: $e');
      }
    });
  }

  /// Baby side: opens the camera/microphone and the signaling channel. The
  /// first offer is created once a parent joins (a viewer session appears),
  /// see [onViewerSessionChanged].
  Future<void> startAsBaby(String roomCode, {String facingMode = 'environment'}) async {
    try {
      _setStatus(ConnectionStatus.CONNECTING);
      _generation++;
      await _ensurePeerClosed();
      _isBaby = true;
      _roomCode = roomCode;
      _babySession = null;
      _signalingService.session = null;

      // Connect signaling
      await _signalingService.connect(roomCode);

      _localStream = await _createLocalStream(facingMode: facingMode);
      localRenderer.srcObject = _localStream;

      // A standby peer with the local tracks keeps audio level stats (cry
      // detection) available before a parent joins.
      await _buildBabyPeer(roomCode, session: null, generation: _generation);
    } catch (e) {
      _reportError('Teklif oluşturulamadı: $e', e);
      rethrow;
    }
  }

  /// Baby side: a parent joined (new [session]) or left (null). Builds a new
  /// peer connection and, for a non-null session, sends a new offer. Calls are
  /// serialized; repeated calls with the same session are ignored.
  Future<void> onViewerSessionChanged(String? session) {
    final generation = _generation;
    _babyNegotiation = _babyNegotiation.then((_) async {
      if (generation != _generation) return;
      final roomCode = _roomCode;
      if (!_isBaby || roomCode == null || _localStream == null) return;
      if (session == _babySession) return;
      _babySession = session;
      try {
        await _closePeer();
        _signalingService.session = session;
        if (session != null) {
          // Old candidates would only be filtered out; remove them anyway.
          await _signalingService.clearCandidates();
        }
        if (generation != _generation) return;
        _setStatus(ConnectionStatus.CONNECTING);
        await _buildBabyPeer(roomCode, session: session, generation: generation);
      } catch (e) {
        if (generation != _generation) {
          // Cancelled by hangUp()/a new start: the closed peer threw; not an error.
          debugPrint('Abandoned baby negotiation: $e');
          return;
        }
        // Let the next room snapshot with this session try again.
        _babySession = null;
        _reportError('Teklif oluşturulamadı: $e', e);
      }
    });
    return _babyNegotiation;
  }

  Future<void> _buildBabyPeer(
    String roomCode, {
    required String? session,
    required int generation,
  }) async {
    final localStream = _localStream;
    if (localStream == null) return;

    if (session != null) {
      // Release other microphone readers before WebRTC starts capturing.
      final hook = beforeBabyCall;
      if (hook != null) {
        try {
          // Bounded: a microphone that does not stop must not block the call.
          await hook().timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('beforeBabyCall failed: $e');
        }
      }
      if (generation != _generation) return;
    }
    _babyInCall = session != null;

    final pc = await _createPeerConnection();
    if (generation != _generation) {
      // hangUp() or a new start happened meanwhile
      await pc.close();
      await pc.dispose();
      return;
    }
    _peerConnection = pc;

    for (final track in localStream.getTracks()) {
      await pc.addTrack(track, localStream);
    }

    pc.onIceCandidate = (candidate) {
      _signalingService.sendCandidate(candidate);
    };

    pc.onConnectionState = (state) {
      if (!identical(_peerConnection, pc)) return; // a newer peer replaced it
      _onPeerState(state, roomCode);
    };

    if (session == null) {
      // Standby (no parent yet): a local description creates the senders.
      // Nothing is sent; candidates without a session are not written.
      // WebRTC does not capture audio before a call is set up (its audio
      // level stays 0, measured on iOS), so the app runs its own noise meter
      // in standby (onBabyStandby).
      final standbyOffer = await pc.createOffer();
      if (generation != _generation || !identical(_peerConnection, pc)) return;
      await pc.setLocalDescription(standbyOffer);
      onBabyStandby?.call();
      return;
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signalingService.sendOffer(offer);
    if (generation != _generation || !identical(_peerConnection, pc)) return;

    _answerSub = _signalingService.onAnswer.listen(
      (answer) async {
        if (!identical(_peerConnection, pc)) return;
        final existingRemote = await pc.getRemoteDescription();
        if (existingRemote != null) return;
        await pc.setRemoteDescription(answer);
        await _flushPendingCandidates(pc);
      },
      onError: (e) => _reportError('Yanıta ulaşılamadı: $e'),
    );

    _remoteCandidateSub = _signalingService.onCandidate.listen(
      (candidate) => unawaited(_addRemoteCandidate(pc, candidate)),
      onError: (e) => _reportError('ICE candidate okunamadı: $e'),
    );
  }

  /// Remote ICE candidates can arrive before the remote description is set
  /// (the parent's candidates reach the baby before its answer is applied).
  /// addCandidate then fails ("remote description was null"; an uncaught
  /// error on iOS), so such candidates are queued and added afterwards (B64).
  Future<void> _addRemoteCandidate(RTCPeerConnection pc, RTCIceCandidate candidate) async {
    if (!identical(_peerConnection, pc)) return;
    // Synchronous flag (no await between the check and queuing), set right
    // after setRemoteDescription and before the queue is flushed.
    if (!_remoteDescriptionApplied) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    try {
      await pc.addCandidate(candidate);
    } catch (e) {
      debugPrint('addCandidate failed: $e');
    }
  }

  Future<void> _flushPendingCandidates(RTCPeerConnection pc) async {
    if (!identical(_peerConnection, pc)) return;
    _remoteDescriptionApplied = true;
    final pending = List<RTCIceCandidate>.of(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in pending) {
      if (!identical(_peerConnection, pc)) return;
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('addCandidate (queued) failed: $e');
      }
    }
  }

  /// Parent side: joins [roomCode] as viewer [session] and answers the baby's
  /// offer for that session.
  Future<void> startAsParent(String roomCode, {required String session}) async {
    try {
      _setStatus(ConnectionStatus.CONNECTING);
      final generation = ++_generation;
      await _ensurePeerClosed();
      _isBaby = false;
      _signalingService.session = session;
      remoteRenderer.srcObject = null;

      // Connect signaling
      await _signalingService.connect(roomCode);
      if (generation != _generation) return; // hangUp()/another start meanwhile

      final pc = await _createPeerConnection();
      if (generation != _generation) {
        await pc.close();
        await pc.dispose();
        return;
      }
      _peerConnection = pc;

      pc.onIceCandidate = (candidate) {
        _signalingService.sendCandidate(candidate);
      };

      pc.onConnectionState = (state) {
        if (!identical(_peerConnection, pc)) return;
        _onPeerState(state, roomCode);
      };

      pc.onTrack = (event) {
        debugPrint('WebRTC: onTrack received. Streams: ${event.streams.length}');
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
        }
        // CONNECTED comes from the peer connection state, not from the track
        // (a track arrives before ICE connects).
      };

      // Wait for the offer of our session
      _offerSub = _signalingService.onOffer.listen((offer) async {
         if (!identical(_peerConnection, pc)) return;
         // The room snapshot repeats the offer on every update; answer once.
         if (await pc.getRemoteDescription() != null) return;

         await pc.setRemoteDescription(offer);
         await _flushPendingCandidates(pc);

         // Explicitly request video/audio
         const constraints = {
            'mandatory': {
              'OfferToReceiveAudio': true,
              'OfferToReceiveVideo': true,
            },
            'optional': [],
          };

         final answer = await pc.createAnswer(constraints);
         await pc.setLocalDescription(answer);
         await _signalingService.sendAnswer(answer);
      }, onError: (e) => _reportError('Teklif alınamadı: $e'));

      _remoteCandidateSub = _signalingService.onCandidate.listen(
        (candidate) => unawaited(_addRemoteCandidate(pc, candidate)),
        onError: (e) => _reportError('ICE candidate okunamadı: $e'),
      );

      _offerTimer = Timer(offerTimeout, () async {
        if (!identical(_peerConnection, pc)) return;
        if (await pc.getRemoteDescription() == null) {
          debugPrint('No offer for session $session within ${offerTimeout.inSeconds} s');
          _setStatus(ConnectionStatus.FAILED);
        }
      });
    } catch (e) {
      _reportError('Bağlantı kurulamadı: $e', e);
      rethrow;
    }
  }

  /// Disconnects and resets renderers.
  Future<void> hangUp() async {
    _setStatus(ConnectionStatus.DISCONNECTED);
    // Do not wait for an in-flight negotiation (a Firestore write may never
    // complete while offline); bumping the generation makes it abandon its peer.
    _generation++;
    _isBaby = false;
    _roomCode = null;
    _babySession = null;
    await _ensurePeerClosed();
    _signalingService.session = null;
    await _signalingService.disconnect();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  Future<void> switchCamera(String roomCode,
      {required String facingMode, bool remoteRequest = false}) async {
    if (_peerConnection == null || _localStream == null) {
      throw Exception('Aktif kamera akışı bulunamadı.');
    }

    final newStream = await _createLocalStream(facingMode: facingMode);
    final videoTrack =
        newStream.getVideoTracks().isNotEmpty ? newStream.getVideoTracks().first : null;
    final audioTrack =
        newStream.getAudioTracks().isNotEmpty ? newStream.getAudioTracks().first : null;

    if (videoTrack == null) {
      await newStream.dispose();
      throw Exception('Yeni kamera akışı oluşturulamadı.');
    }

    final senders = await _peerConnection!.getSenders();
    for (final sender in senders) {
      final kind = sender.track?.kind;
      if (kind == 'video') {
        await sender.replaceTrack(videoTrack);
      } else if (kind == 'audio' && audioTrack != null) {
        await sender.replaceTrack(audioTrack);
      }
    }

    localRenderer.srcObject = newStream;
    await _localStream?.dispose();
    _localStream = newStream;
    _setStatus(ConnectionStatus.CONNECTED);
    if (!remoteRequest && _pairingService != null) {
      await _pairingService.setFacing(roomCode, facingMode);
    }
    if (_pairingService != null) {
      await _pairingService.setPaired(roomCode, true);
    }
  }

  ConnectionStatus get status => _status;
}

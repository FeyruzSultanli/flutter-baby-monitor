import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../enums/connection_status.dart';
import '../pairing/pairing_service.dart';
import 'signaling_interface.dart';

/// Owns RTCPeerConnection, local/remote renderers and signaling wiring.
class WebRTCService {
  WebRTCService({
    required SignalingInterface signalingService,
    PairingService? pairingService,
    this.onStatusChanged,
    this.onError,
  })  : _signalingService = signalingService,
        _pairingService = pairingService;

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

  Future<void> _ensurePeerClosed() async {
    await _remoteCandidateSub?.cancel();
    await _answerSub?.cancel();
    await _offerSub?.cancel();
    _remoteCandidateSub = null;
    _answerSub = null;
    _offerSub = null;
    await _localStream?.dispose();
    _localStream = null;
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _peerConnection = null;
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

  Future<MediaStream> _createLocalStream({String facingMode = 'environment'}) {
    return navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': facingMode,
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 30},
      },
    });
  }

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

  /// Offerer side (baby).
  Future<void> startAsBaby(String roomCode, {String facingMode = 'environment'}) async {
    try {
      _setStatus(ConnectionStatus.CONNECTING);
      await _ensurePeerClosed();
      
      // Connect signaling
      await _signalingService.connect(roomCode);

      _peerConnection = await _createPeerConnection();
      _localStream = await _createLocalStream(facingMode: facingMode);
      localRenderer.srcObject = _localStream;

      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      _peerConnection!.onIceCandidate = (candidate) {
        _signalingService.sendCandidate(candidate);
      };

      _peerConnection!.onIceConnectionState = (state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _reportError('Bağlantı hatası (ICE failed)');
        }
      };

      _peerConnection!.onConnectionState = (state) async {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _setStatus(ConnectionStatus.CONNECTED);
          if (_pairingService != null) {
            await _pairingService.setPaired(roomCode, true);
          }
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _setStatus(ConnectionStatus.FAILED);
        }
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
        }
        _setStatus(ConnectionStatus.CONNECTED);
      };

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      await _signalingService.sendOffer(offer);

      _answerSub = _signalingService.onAnswer.listen(
        (answer) async {
          final existingRemote = await _peerConnection?.getRemoteDescription();
          if (existingRemote != null) return;
          await _peerConnection?.setRemoteDescription(answer);
        },
        onError: (e) => _reportError('Yanıta ulaşılamadı: $e'),
      );

      _remoteCandidateSub = _signalingService.onCandidate.listen(
        (candidate) {
          _peerConnection?.addCandidate(candidate);
        },
        onError: (e) => _reportError('ICE candidate okunamadı: $e'),
      );
    } catch (e) {
      _reportError('Teklif oluşturulamadı: $e', e);
      rethrow;
    }
  }

  /// Answerer side (parent).
  Future<void> startAsParent(String roomCode) async {
    try {
      _setStatus(ConnectionStatus.CONNECTING);
      await _ensurePeerClosed();
      
      // Connect signaling
      await _signalingService.connect(roomCode);

      _peerConnection = await _createPeerConnection();

      _peerConnection!.onIceCandidate = (candidate) {
        _signalingService.sendCandidate(candidate);
      };

      _peerConnection!.onConnectionState = (state) async {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _setStatus(ConnectionStatus.CONNECTED);
          if (_pairingService != null) {
            await _pairingService.setPaired(roomCode, true);
          }
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _setStatus(ConnectionStatus.FAILED);
        }
      };

      _peerConnection!.onTrack = (event) {
        debugPrint('WebRTC: onTrack received. Streams: ${event.streams.length}');
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
          // Force a notify if needed, though srcObject setter should do it.
        }
        _setStatus(ConnectionStatus.CONNECTED);
      };

      // Wait for offer
      _offerSub = _signalingService.onOffer.listen((offer) async {
         // Check if we already have a remote description to avoid race conditions
         if (await _peerConnection?.getRemoteDescription() != null) return;
         
         await _peerConnection!.setRemoteDescription(offer);
         
         // Explicitly request video/audio
         const constraints = {
            'mandatory': {
              'OfferToReceiveAudio': true,
              'OfferToReceiveVideo': true,
            },
            'optional': [],
          };
         
         final answer = await _peerConnection!.createAnswer(constraints);
         await _peerConnection!.setLocalDescription(answer);
         await _signalingService.sendAnswer(answer);
      }, onError: (e) => _reportError('Teklif alınamadı: $e'));

      _remoteCandidateSub = _signalingService.onCandidate.listen(
        (candidate) {
          _peerConnection?.addCandidate(candidate);
        },
        onError: (e) => _reportError('ICE candidate okunamadı: $e'),
      );
    } catch (e) {
      _reportError('Bağlantı kurulamadı: $e', e);
      rethrow;
    }
  }

  /// Disconnects and resets renderers.
  Future<void> hangUp() async {
    _setStatus(ConnectionStatus.DISCONNECTED);
    await _ensurePeerClosed();
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

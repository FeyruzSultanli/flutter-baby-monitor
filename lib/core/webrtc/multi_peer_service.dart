import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../enums/connection_status.dart';
import 'signaling_interface.dart';

/// Tek bir bebek kamerasının bağlantısını yöneten sınıf.
class PeerConnectionManager {
  final String roomId;
  final SignalingInterface signalingService;
  final VoidCallback onStatusChanged;
  final Function(String) onError;

  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  
  StreamSubscription? _offerSub;
  StreamSubscription? _candidateSub;
  
  ConnectionStatus status = ConnectionStatus.DISCONNECTED;
  
  PeerConnectionManager({
    required this.roomId,
    required this.signalingService,
    required this.onStatusChanged,
    required this.onError,
  });

  Future<void> initialize() async {
    await remoteRenderer.initialize();
  }

  Future<void> connect() async {
    try {
      status = ConnectionStatus.CONNECTING;
      onStatusChanged();

      // Sinyal servisine bağlan
      await signalingService.connect(roomId);
      
      // Peer Connection oluştur
      _peerConnection = await createPeerConnection({
        'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}],
        'sdpSemantics': 'unified-plan',
      });

      _peerConnection!.onIceCandidate = (candidate) {
        signalingService.sendCandidate(candidate);
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
          status = ConnectionStatus.CONNECTED;
          onStatusChanged();
        }
      };
      
      _peerConnection!.onConnectionState = (state) {
         if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
             state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
           status = ConnectionStatus.FAILED;
           onStatusChanged();
         } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
           status = ConnectionStatus.CONNECTED;
           onStatusChanged();
         }
      };

      // Offer dinle (Ebeveyn tarafı Answerer olduğu için Offer bekler)
      _offerSub = signalingService.onOffer.listen((offer) async {
        if (_peerConnection == null) return;
        
        await _peerConnection!.setRemoteDescription(offer);
        
        // Video/Ses alma isteği
        final constraints = {
            'mandatory': {
              'OfferToReceiveAudio': true,
              'OfferToReceiveVideo': true,
            },
            'optional': [],
        };

        final answer = await _peerConnection!.createAnswer(constraints);
        await _peerConnection!.setLocalDescription(answer);
        await signalingService.sendAnswer(answer);
      });

      // ICE Candidate dinle
      _candidateSub = signalingService.onCandidate.listen((candidate) {
        _peerConnection?.addCandidate(candidate);
      });

    } catch (e) {
      onError(e.toString());
      status = ConnectionStatus.FAILED;
      onStatusChanged();
    }
  }

  /// Aktif/Pasif durumuna göre stream'i yönetir.
  void setActive(bool isActive) {
    final stream = remoteRenderer.srcObject;
    if (stream != null) {
      // Ses ve Görüntü tracklerini aç/kapat
      // isActive = true -> Ses/Görüntü açık
      // isActive = false -> Ses/Görüntü kapalı (Mute)
      stream.getAudioTracks().forEach((track) => track.enabled = isActive);
      // Görüntüyü de kapatmak isterseniz:
      // stream.getVideoTracks().forEach((track) => track.enabled = isActive);
      
      // Not: Video track'i kapatmak bazen siyah ekran kalmasına neden olabilir, 
      // sadece sesi kapatmak (mute) genellikle yeterlidir.
    }
  }

  Future<void> dispose() async {
    await _offerSub?.cancel();
    await _candidateSub?.cancel();
    await signalingService.disconnect();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    await remoteRenderer.dispose();
  }
}

/// Birden fazla bebek kamerasını yöneten servis.
class MultiPeerService extends ChangeNotifier {
  // Her yeni bağlantı için yeni bir SignalingInterface örneği üreten fonksiyon
  final SignalingInterface Function() signalingFactory;
  
  // RoomID -> Manager eşleşmesi
  final Map<String, PeerConnectionManager> _peers = {};
  
  String? _activeRoomId;

  MultiPeerService({required this.signalingFactory});

  Map<String, PeerConnectionManager> get peers => _peers;
  String? get activeRoomId => _activeRoomId;

  /// Yeni bir bebek kamerası ekler ve bağlanır.
  Future<void> addPeer(String roomId) async {
    if (_peers.containsKey(roomId)) return;

    final signaling = signalingFactory();
    final manager = PeerConnectionManager(
      roomId: roomId,
      signalingService: signaling,
      onStatusChanged: () => notifyListeners(),
      onError: (msg) => debugPrint("Error in $roomId: $msg"),
    );

    await manager.initialize();
    _peers[roomId] = manager;
    
    // Eğer ilk eklenen kameraysa aktif yap
    if (_activeRoomId == null) {
      _activeRoomId = roomId;
    }

    // Bağlantıyı başlat
    await manager.connect();
    
    // Aktiflik durumlarını güncelle
    _updateActiveStates();
    notifyListeners();
  }

  /// Bir kamerayı listeden çıkarır ve bağlantıyı keser.
  Future<void> removePeer(String roomId) async {
    final manager = _peers.remove(roomId);
    if (manager != null) {
      await manager.dispose();
    }
    
    // Eğer aktif olan silindiyse, başkasını aktif yap
    if (_activeRoomId == roomId) {
      _activeRoomId = _peers.keys.isNotEmpty ? _peers.keys.first : null;
      _updateActiveStates();
    }
    notifyListeners();
  }

  /// Ekranda gösterilecek aktif kamerayı seçer.
  void setActivePeer(String roomId) {
    if (_peers.containsKey(roomId)) {
      _activeRoomId = roomId;
      _updateActiveStates();
      notifyListeners();
    }
  }

  /// Tüm peer'ların mute/unmute durumunu günceller.
  void _updateActiveStates() {
    _peers.forEach((id, manager) {
      // Sadece aktif olanın sesi/görüntüsü açık olsun
      manager.setActive(id == _activeRoomId);
    });
  }
  
  @override
  void dispose() {
    for (var manager in _peers.values) {
      manager.dispose();
    }
    super.dispose();
  }
}

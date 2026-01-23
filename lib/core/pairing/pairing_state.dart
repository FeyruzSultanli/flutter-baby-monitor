import '../enums/connection_status.dart';
import '../../models/video_settings.dart';

// Simple pairing state snapshot kept in UI.
class PairingState {
  PairingState({
    required this.roomCode,
    this.isPaired = false,
    this.errorMessage,
    this.status = ConnectionStatus.DISCONNECTED,
    this.facingMode = 'environment',
    this.cryAlert = false,
    this.cryDecibel,
    this.cryUpdatedAt,
    this.videoSettings = const VideoSettings(),
  });

  final String roomCode;
  final bool isPaired;
  final String? errorMessage;
  final ConnectionStatus status;
  final String facingMode;
  final bool cryAlert;
  final double? cryDecibel;
  final DateTime? cryUpdatedAt;
  final VideoSettings videoSettings;

  PairingState copyWith({
    bool? isPaired,
    String? errorMessage,
    ConnectionStatus? status,
    String? facingMode,
    bool? cryAlert,
    double? cryDecibel,
    DateTime? cryUpdatedAt,
    VideoSettings? videoSettings,
  }) {
    return PairingState(
      roomCode: roomCode,
      isPaired: isPaired ?? this.isPaired,
      errorMessage: errorMessage,
      status: status ?? this.status,
      facingMode: facingMode ?? this.facingMode,
      cryAlert: cryAlert ?? this.cryAlert,
      cryDecibel: cryDecibel ?? this.cryDecibel,
      cryUpdatedAt: cryUpdatedAt ?? this.cryUpdatedAt,
      videoSettings: videoSettings ?? this.videoSettings,
    );
  }
}

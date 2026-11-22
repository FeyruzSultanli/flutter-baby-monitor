import '../enums/connection_status.dart';
import '../../models/video_settings.dart';
import '../monitor/battery_alert.dart';

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
    this.noiseThreshold,
    this.viewerSession,
    this.battery,
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
  /// Cry threshold used by the baby device (shared between both devices so
  /// it can be calibrated from the parent; D5). Null if not stored yet.
  final double? noiseThreshold;
  /// Session id of the currently joined parent; null when no parent is in
  /// the room (B08).
  final String? viewerSession;
  /// Baby phone battery as written by the baby (V2 5.7); null if unknown.
  final BabyBattery? battery;

  PairingState copyWith({
    bool? isPaired,
    String? errorMessage,
    ConnectionStatus? status,
    String? facingMode,
    bool? cryAlert,
    double? cryDecibel,
    DateTime? cryUpdatedAt,
    VideoSettings? videoSettings,
    double? noiseThreshold,
    String? viewerSession,
    BabyBattery? battery,
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
      noiseThreshold: noiseThreshold ?? this.noiseThreshold,
      viewerSession: viewerSession ?? this.viewerSession,
      battery: battery ?? this.battery,
    );
  }
}

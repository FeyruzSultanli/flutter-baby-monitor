import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../l10n/app_localizations.dart';

class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({
    super.key,
    required this.controller,
    required this.initializing,
    required this.hasPermission,
    required this.message,
    this.webrtcRenderer,
    this.mirrorWebRtc = false,
    this.offlineImage,
    this.isRecording = false,
    this.onRecordToggle,
  });

  final CameraController? controller;
  final bool initializing;
  final bool hasPermission;
  final String? message;
  final RTCVideoRenderer? webrtcRenderer;
  final bool mirrorWebRtc;
  final Uint8List? offlineImage;
  final bool isRecording;
  final VoidCallback? onRecordToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasWebRtc = webrtcRenderer?.srcObject != null;
    final canShowCamera = controller != null && controller!.value.isInitialized;
    final hasOfflineImage = offlineImage != null;
    final canShow = hasWebRtc || canShowCamera || hasOfflineImage;

    return Container(
      color: Colors.black,
      child: Center(
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            () {
              if (initializing) {
                return _Loading(message: l10n.cameraInitializing);
              }
              if (!hasPermission && !hasWebRtc && !hasOfflineImage) {
                return _PermissionHelp(message: message);
              }
              if (!canShow) {
                return _EmptyPreview(message: message);
              }
              
              if (hasOfflineImage) {
                return SizedBox.expand(
                  child: Image.memory(
                    offlineImage!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                );
              }

              if (hasWebRtc) {
                return SizedBox.expand(
                  child: RTCVideoView(
                    webrtcRenderer!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: mirrorWebRtc,
                  ),
                );
              }
              
              return SizedBox.expand(
                child: CameraPreview(controller!),
              );
            }(),
            if (canShow && onRecordToggle != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton.small(
                  heroTag: 'record_btn_card',
                  onPressed: onRecordToggle,
                  backgroundColor: isRecording ? Colors.red : Colors.white,
                  child: Icon(
                    isRecording ? Icons.stop : Icons.videocam,
                    color: isRecording ? Colors.white : Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(message ?? l10n.loading),
      ],
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.photo_camera_front_outlined, size: 48),
        const SizedBox(height: 12),
        Text(
          message ?? l10n.previewNotReady,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PermissionHelp extends StatelessWidget {
  const _PermissionHelp({this.message});
  final String? message;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 48),
        const SizedBox(height: 12),
        Text(message ?? l10n.cameraPermissionRequired, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: openAppSettings,
          child: Text(l10n.openAppSettings),
        ),
      ],
    );
  }
}

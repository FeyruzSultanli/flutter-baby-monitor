import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../l10n/app_localizations.dart';

class FullscreenView extends StatelessWidget {
  const FullscreenView({
    super.key,
    required this.canShowPreview,
    required this.controller,
    required this.webrtcRenderer,
    required this.mirrorWebRtc,
    required this.overlayActive,
    required this.onExit,
    this.offlineImage,
    this.isRecording = false,
    this.onRecordToggle,
  });

  final bool canShowPreview;
  final CameraController? controller;
  final RTCVideoRenderer? webrtcRenderer;
  final bool mirrorWebRtc;
  final bool overlayActive;
  final VoidCallback onExit;
  final Uint8List? offlineImage;
  final bool isRecording;
  final VoidCallback? onRecordToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final double overlayPadding =
        MediaQuery.of(context).size.width < 360 ? 12 : 16;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: () {
                if (canShowPreview && controller != null) {
                  return AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: CameraPreview(controller!),
                  );
                }
                if (canShowPreview && offlineImage != null) {
                  return AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Image.memory(
                      offlineImage!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  );
                }
                if (canShowPreview && webrtcRenderer?.srcObject != null) {
                  final aspect = (webrtcRenderer!.videoWidth > 0 &&
                          webrtcRenderer!.videoHeight > 0)
                      ? webrtcRenderer!.videoWidth / webrtcRenderer!.videoHeight
                      : 3 / 4;
                  return AspectRatio(
                    aspectRatio: aspect,
                    child: RTCVideoView(
                      webrtcRenderer!,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      mirror: mirrorWebRtc,
                    ),
                  );
                }
                return Text(
                  l10n.cameraNotReady,
                  style: const TextStyle(color: Colors.white),
                );
              }(),
            ),
            Positioned(
              top: overlayPadding,
              left: overlayPadding,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onExit,
              ),
            ),
            if (onRecordToggle != null)
              Positioned(
                top: overlayPadding,
                right: overlayPadding,
                child: FloatingActionButton.small(
                  heroTag: 'record_btn_fullscreen',
                  onPressed: onRecordToggle,
                  backgroundColor: isRecording ? Colors.red : Colors.white,
                  child: Icon(
                    isRecording ? Icons.stop : Icons.videocam,
                    color: isRecording ? Colors.white : Colors.black,
                  ),
                ),
              ),
            if (overlayActive)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.babyMightBeCrying,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

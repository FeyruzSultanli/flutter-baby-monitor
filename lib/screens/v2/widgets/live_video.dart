import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../../../features/monitor/monitor_controller.dart';
import '../../../theme/tokens.dart';
import 'demo_video_art.dart';

/// The baby's picture: own camera on the baby phone (WebRTC renderer online,
/// camera preview offline), the received stream on the parent phone (WebRTC
/// online, JPEG frames offline). Falls back to [placeholder].
class LiveVideo extends StatelessWidget {
  const LiveVideo({
    super.key,
    required this.placeholder,
    this.fit = BoxFit.cover,
  });

  final Widget placeholder;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MonitorController>();
    final objectFit = fit == BoxFit.contain
        ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
        : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    Widget? video;
    if (c.isBaby) {
      final renderer = c.localRenderer;
      final camera = c.cameraController;
      if (renderer != null && c.hasLocalVideo) {
        video = RTCVideoView(renderer, objectFit: objectFit, mirror: c.frontCamera);
      } else if (camera != null && camera.value.isInitialized) {
        video = FittedBox(
          fit: fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: camera.value.previewSize?.height ?? 480,
            height: camera.value.previewSize?.width ?? 640,
            child: CameraPreview(camera),
          ),
        );
      }
    } else {
      final renderer = c.remoteRenderer;
      if (c.isOffline) {
        video = ValueListenableBuilder(
          valueListenable: c.offlineFrame,
          builder: (context, bytes, _) => bytes == null
              ? placeholder
              : Image.memory(bytes, gaplessPlayback: true, fit: fit, width: double.infinity, height: double.infinity),
        );
      } else if (renderer != null && c.hasRemoteVideo) {
        video = RTCVideoView(renderer, objectFit: objectFit);
      }
    }
    return ColoredBox(
      color: NinniColors.nightVideo,
      child: video ?? (c.isDemo ? const DemoVideoArt() : placeholder),
    );
  }
}

/// Centered label (and optional spinner) on the video placeholder.
class VideoPlaceholder extends StatelessWidget {
  const VideoPlaceholder({super.key, required this.label, this.busy = false, this.icon});

  final String label;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: NinniColors.primarySoftOnNight),
              )
            else if (icon != null)
              Icon(icon, size: 32, color: NinniColors.onNightMuted),
            const SizedBox(height: 12),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: NinniType.label.copyWith(color: NinniColors.onNightMuted, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

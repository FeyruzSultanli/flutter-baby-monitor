import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class StatusChipsRow extends StatelessWidget {
  const StatusChipsRow({
    super.key,
    required this.canShowPreview,
    required this.previewPaused,
    required this.listeningNoise,
    required this.noiseAlert,
    required this.currentDecibel,
    required this.alertController,
  });

  final bool canShowPreview;
  final bool previewPaused;
  final bool listeningNoise;
  final bool noiseAlert;
  final double currentDecibel;
  final AnimationController alertController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final Widget alertBadge = ScaleTransition(
      key: const ValueKey('alert'),
      scale: alertController,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
            const SizedBox(width: 4),
            Text(
              '${l10n.highNoise}: ${currentDecibel.toStringAsFixed(0)} dB',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          icon: canShowPreview
              ? (previewPaused
                  ? Icons.pause_circle_outline
                  : Icons.videocam_outlined)
              : Icons.videocam_off_outlined,
          label: canShowPreview
              ? (previewPaused ? l10n.cameraPaused : l10n.cameraOn)
              : l10n.cameraOff,
          color: canShowPreview ? scheme.primary : scheme.outline,
        ),
        StatusChip(
          icon: listeningNoise
              ? Icons.hearing_outlined
              : Icons.hearing_disabled_outlined,
          label: listeningNoise ? l10n.audioMonitoringOn : l10n.audioMonitoringOff,
          color: listeningNoise ? scheme.secondary : scheme.outline,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: noiseAlert
              ? alertBadge
              : const SizedBox.shrink(
                  key: ValueKey('empty'),
                ),
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: onColor),
          ),
        ],
      ),
    );
  }
}

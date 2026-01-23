import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class NoiseLevelBar extends StatelessWidget {
  const NoiseLevelBar({
    super.key,
    required this.currentDb,
    required this.thresholdDb,
    required this.listening,
  });

  final double currentDb;
  final double thresholdDb;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final normalized = (currentDb / 90.0).clamp(0.0, 1.0);
    final isHigh = currentDb >= thresholdDb;
    final bool isCompact = MediaQuery.of(context).size.width < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.noiseLevel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            Text(
              listening ? '${currentDb.toStringAsFixed(1)} dB' : l10n.passive,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: listening
                    ? (isHigh ? scheme.error : scheme.primary)
                    : scheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: listening ? normalized : 0,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              isHigh ? scheme.error : scheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${l10n.threshold}: ${thresholdDb.toStringAsFixed(0)} dB',
          style: TextStyle(
            fontSize: 11,
            color: scheme.outline,
          ),
        ),
      ],
    );
  }
}

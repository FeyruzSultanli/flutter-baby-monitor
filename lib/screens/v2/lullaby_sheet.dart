import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/audio/soothe.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';

Future<void> showLullabySheet(BuildContext context) =>
    showNinniSheet<void>(context, (_) => const LullabySheet(), night: true);

/// Parent: lullaby / white noise and night light on the baby phone (mockup
/// Lullaby, V2 5.4 / 5.5).
class LullabySheet extends StatefulWidget {
  const LullabySheet({super.key});

  @override
  State<LullabySheet> createState() => _LullabySheetState();
}

class _LullabySheetState extends State<LullabySheet> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _left(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final soothe = c.soothe;
    final now = DateTime.now();
    final playing = soothe.isPlayingAt(now) ? soothe.track : null;
    final light = c.nightLight;

    String subtitle(SootheTrack t) {
      if (playing == t) {
        final ends = soothe.endsAt;
        return ends == null ? l10n.playingNow : '${l10n.playingNow} · ${_left(ends.difference(now))}';
      }
      return switch (t) {
        SootheTrack.whiteNoise => l10n.sootheWhiteSub,
        SootheTrack.rain => l10n.sootheRainSub,
        SootheTrack.heartbeat => l10n.sootheHeartSub,
        SootheTrack.dandini => l10n.sootheDandiniSub,
      };
    }

    String title(SootheTrack t) => switch (t) {
          SootheTrack.whiteNoise => l10n.sootheWhite,
          SootheTrack.rain => l10n.sootheRain,
          SootheTrack.heartbeat => l10n.sootheHeart,
          SootheTrack.dandini => l10n.sootheDandini,
        };

    final timers = <(Duration?, String)>[
      (const Duration(minutes: 15), l10n.minutesShort.replaceAll('{m}', '15')),
      (const Duration(minutes: 30), l10n.minutesShort.replaceAll('{m}', '30')),
      (const Duration(minutes: 60), l10n.minutesShort.replaceAll('{m}', '60')),
      (null, l10n.continuous),
    ];

    return BottomSheetFrame(
      title: l10n.lullabyTitle,
      closeLabel: l10n.close,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Two tiles per row that grow with the text size (no fixed aspect
          // ratio: large text must not overflow, V2 phase 4).
          for (var row = 0; row < SootheTrack.values.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = row; i < row + 2; i++) ...[
                    if (i > row) const SizedBox(width: 10),
                    Expanded(
                      child: _TrackTile(
                        key: Key('soothe_${SootheTrack.values[i].id}'),
                        title: title(SootheTrack.values[i]),
                        subtitle: subtitle(SootheTrack.values[i]),
                        selected: playing == SootheTrack.values[i],
                        onTap: () => playing == SootheTrack.values[i]
                            ? c.stopSoothe()
                            : c.playSoothe(SootheTrack.values[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(l10n.volumeOnBaby.toUpperCase(),
                    style: NinniType.label.copyWith(color: NinniColors.onNightMuted)),
              ),
              Text('%${(c.sootheVolume * 100).round()}',
                  style: NinniType.numeric(NinniType.label.copyWith(color: NinniColors.onNightMuted))),
            ],
          ),
          Slider(
            key: const Key('sootheVolume'),
            value: c.sootheVolume,
            padding: const EdgeInsets.symmetric(vertical: 14),
            semanticFormatterCallback: (v) => '%${(v * 100).round()}',
            onChanged: c.setSootheVolume,
          ),
          Row(
            children: [
              for (var i = 0; i < timers.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TimerChip(
                    label: timers[i].$2,
                    selected: c.sootheTimer == timers[i].$1,
                    onTap: () => c.setSootheTimer(timers[i].$1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: NinniColors.nightLine),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.nightLight, style: NinniType.body.copyWith(fontWeight: FontWeight.w800, color: NinniColors.onNight)),
                    const SizedBox(height: 2),
                    Text(l10n.nightLightSub,
                        style: NinniType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: NinniColors.onNightMuted)),
                  ],
                ),
              ),
              NinniSwitch(
                key: const Key('nightLightSwitch'),
                value: light.on,
                semanticLabel: l10n.nightLight,
                onChanged: (v) => c.setNightLight(on: v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.lightColor,
            child: Row(
              children: [
                for (final color in NightLightColor.values) ...[
                  _ColorDot(
                    color: color.color,
                    label: switch (color) {
                      NightLightColor.amber => l10n.colorAmber,
                      NightLightColor.pink => l10n.colorPink,
                      NightLightColor.purple => l10n.colorPurple,
                      NightLightColor.blue => l10n.colorBlue,
                    },
                    selected: light.color == color,
                    onTap: () => c.setNightLight(color: color, on: true),
                  ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({super.key, required this.title, required this.subtitle, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: NinniColors.night700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NinniRadii.r18),
          side: selected ? const BorderSide(color: NinniColors.primaryGlow, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(NinniRadii.r18),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: NinniColors.onNight)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NinniType.numeric(NinniType.caption.copyWith(
                        color: selected ? NinniColors.primarySoftOnNight : NinniColors.onNightMuted))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? NinniColors.white : NinniColors.night700,
        borderRadius: BorderRadius.circular(NinniRadii.r12),
        child: InkWell(
          borderRadius: BorderRadius.circular(NinniRadii.r12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: NinniSpace.touch),
            alignment: Alignment.center,
            child: Text(label,
                maxLines: 1,
                style: NinniType.label.copyWith(
                    letterSpacing: 0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? NinniColors.ink : NinniColors.onNightSoft)),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.label, required this.selected, required this.onTap});
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected ? Border.all(color: NinniColors.white, width: 3) : null,
          ),
        ),
      ),
    );
  }
}

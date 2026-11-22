import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';

/// Parent: full-screen cry alarm (mockup CryAlert). Apricot, rings spreading
/// out, sound + vibration (controller). Stays until the parent reacts.
class CryAlertView extends StatefulWidget {
  const CryAlertView({super.key, required this.onOpenVideo});

  final VoidCallback onOpenVideo;

  @override
  State<CryAlertView> createState() => _CryAlertViewState();
}

class _CryAlertViewState extends State<CryAlertView> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final started = c.cryStartedAt ?? DateTime.now();
    final seconds = DateTime.now().difference(started).inSeconds;
    final db = c.cryPeakDb;
    final details = [
      DateFormat.Hm().format(started),
      if (db != null) '${db.round()} dB',
      if (c.babyCrying)
        l10n.cryingForSeconds.replaceAll('{s}', '$seconds')
      else
        l10n.cryStopped,
    ].join(' · ');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Material(
        key: const Key('cryAlertView'),
        color: NinniColors.apricot,
        child: ScreenFrame(
          gap: 22,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          crossAxisAlignment: CrossAxisAlignment.center,
          items: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: NinniColors.apricotSoftOnNight,
                  borderRadius: BorderRadius.circular(NinniRadii.pill),
                ),
                child: Text(
                  '${c.roomName ?? l10n.defaultRoomName} · ${l10n.now}',
                  style: NinniType.label.copyWith(letterSpacing: 0, color: NinniColors.onApricot),
                ),
              ),
            ),
            const SizedBox(height: 40),
            AlarmRings(
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(color: NinniColors.onApricot, shape: BoxShape.circle),
                child: const Icon(Icons.volume_up_rounded, size: 44, color: NinniColors.apricotSoftOnNight),
              ),
            ),
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                l10n.babyCryingShort,
                textAlign: TextAlign.center,
                style: NinniType.display.copyWith(fontSize: 40, height: 1.05, letterSpacing: -1.2, color: NinniColors.onApricot),
              ),
            ),
            Text(
              details,
              textAlign: TextAlign.center,
              style: NinniType.numeric(NinniType.body.copyWith(fontWeight: FontWeight.w600, color: NinniColors.onApricot)),
            ),
          ],
          footer: [
            NinniButton(
              key: const Key('cryOpenVideo'),
              label: l10n.openVideo,
              icon: Icons.visibility_outlined,
              background: NinniColors.onApricot,
              foreground: NinniColors.white,
              onPressed: () {
                c.acknowledgeCryAlarm();
                widget.onOpenVideo();
              },
            ),
            Row(
              children: [
                Expanded(
                  child: NinniButton(
                    key: const Key('crySnooze'),
                    label: l10n.snooze5,
                    height: 54,
                    variant: NinniButtonVariant.secondary,
                    background: NinniColors.apricotSoftOnNight,
                    foreground: NinniColors.onApricot,
                    borderColor: Colors.transparent,
                    onPressed: () => c.snoozeCryAlarm(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NinniButton(
                    key: const Key('cryOk'),
                    label: l10n.ok,
                    height: 54,
                    variant: NinniButtonVariant.secondary,
                    background: Colors.transparent,
                    foreground: NinniColors.onApricot,
                    borderColor: NinniColors.onApricot,
                    onPressed: c.acknowledgeCryAlarm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Parent: the link to the baby phone is lost (mockup ConnectionLost, V2
/// 5.6). Always dark; closes by itself when the connection is back.
class ConnectionLostView extends StatefulWidget {
  const ConnectionLostView({super.key});

  @override
  State<ConnectionLostView> createState() => _ConnectionLostViewState();
}

class _ConnectionLostViewState extends State<ConnectionLostView> with SingleTickerProviderStateMixin {
  Timer? _tick;
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final since = c.connectionLostSince ?? DateTime.now();
    final seconds = DateTime.now().difference(since).inSeconds.clamp(0, 359999);
    final battery = c.remoteBatteryLevel;
    final checks = [
      if (battery != null) l10n.checkCharger.replaceAll('{level}', '$battery'),
      l10n.checkWifi,
      l10n.checkAppOpen,
    ];
    return NightTheme(
      child: Material(
        key: const Key('connectionLostView'),
        color: NinniColors.night900,
        child: ScreenFrame(
          gap: 22,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          items: [
            const SizedBox(height: 36),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: NinniColors.amberTileOnNight,
                  borderRadius: BorderRadius.circular(NinniRadii.r28),
                ),
                child: const Icon(Icons.wifi_off_rounded, color: NinniColors.amber, size: 44),
              ),
            ),
            Semantics(
              liveRegion: true,
              child: ScreenHeading(
                title: l10n.connectionLostTitle,
                subtitle: l10n.connectionLostBody.replaceAll('{seconds}', '$seconds'),
                style: NinniType.display,
              ),
            ),
            SectionCard(
              radius: NinniRadii.r18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  RotationTransition(
                    turns: _spin,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        value: 0.75,
                        strokeWidth: 2.4,
                        strokeCap: StrokeCap.round,
                        color: NinniColors.primarySoftOnNight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.reconnecting,
                        style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w600, color: NinniColors.onNight)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(l10n.checkBabyPhone, padding: EdgeInsets.zero),
                const SizedBox(height: 10),
                for (final item in checks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('•  $item',
                        style: NinniType.bodySm.copyWith(color: NinniColors.onNightList, height: 1.4)),
                  ),
              ],
            ),
          ],
          footer: [
            NinniButton(
              key: const Key('connectionLostRetry'),
              label: l10n.tryAgain,
              background: NinniColors.amber,
              foreground: NinniColors.onAmber,
              onPressed: c.retryConnection,
            ),
            NinniButton(
              key: const Key('connectionLostSilence'),
              label: l10n.silenceAlarm,
              variant: NinniButtonVariant.secondary,
              foreground: NinniColors.onNightSoft,
              onPressed: c.connectionAlarmSilenced ? null : c.silenceConnectionAlarm,
            ),
            // Not in the mockup: a way out when the baby phone is gone for
            // good (DECISIONS A20).
            Center(
              child: TextButton(
                key: const Key('connectionLostDisconnect'),
                style: TextButton.styleFrom(foregroundColor: NinniColors.onNightMuted),
                onPressed: c.disconnect,
                child: Text(l10n.disconnect),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

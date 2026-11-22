import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/audio/soothe.dart';
import '../../core/pairing/pairing_service.dart';
import '../../core/pairing/room_code.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';
import 'baby_night_view.dart';
import 'widgets/live_video.dart';

/// Baby: give the room a name (shown on the parent phone, V2 5.2).
Future<void> renameRoom(BuildContext context, MonitorController c) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: c.roomName ?? l10n.defaultRoomName);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => NightTheme(
      child: AlertDialog(
        title: Text(l10n.roomNameTitle),
        content: TextField(
          key: const Key('roomNameField'),
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.sentences,
          style: NinniType.body.copyWith(color: NinniColors.onNight),
          decoration: InputDecoration(hintText: l10n.defaultRoomName, counterText: ''),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l10n.save)),
        ],
      ),
    ),
  );
  controller.dispose();
  if (name != null) await c.setRoomName(name);
}

class _RoomNameRow extends StatelessWidget {
  const _RoomNameRow({required this.name, required this.onRename});
  final String? name;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${l10n.roomNameTitle}: ${name ?? l10n.defaultRoomName}',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('roomNameRow'),
        borderRadius: BorderRadius.circular(NinniRadii.r14),
        onTap: onRename,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: NinniSpace.touch),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined, size: 16, color: NinniColors.onNightMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${l10n.roomNameTitle}: '),
                    TextSpan(
                      text: name ?? l10n.defaultRoomName,
                      style: const TextStyle(color: NinniColors.onNight, fontWeight: FontWeight.w700),
                    ),
                  ]),
                  style: NinniType.label
                      .copyWith(letterSpacing: 0, fontWeight: FontWeight.w600, color: NinniColors.onNightMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmEndBroadcast(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => NightTheme(
      child: AlertDialog(
        title: Text(l10n.endBroadcastTitle),
        content: Text(l10n.endBroadcastBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            key: const Key('confirmEndBroadcast'),
            style: TextButton.styleFrom(foregroundColor: NinniColors.apricotSoftOnNight),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.endBroadcast),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// Baby phone, before a parent connected: the room code to enter on the
/// parent phone (mockup BabyPairing). Offline: waiting for a nearby parent.
class BabyPairingScreen extends StatefulWidget {
  const BabyPairingScreen({super.key});

  @override
  State<BabyPairingScreen> createState() => _BabyPairingScreenState();
}

class _BabyPairingScreenState extends State<BabyPairingScreen> {
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

  Future<void> _back(MonitorController c) async {
    if (c.isActive && !await confirmEndBroadcast(context)) return;
    await c.leaveRole();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final code = c.roomCode;
    final createdAt = c.roomCreatedAt;
    final remaining = createdAt == null ? null : PairingService.claimWindow - DateTime.now().difference(createdAt);
    final expired = remaining != null && remaining <= Duration.zero;

    final children = <Widget>[
      Row(
        children: [
          NinniIconButton(
            key: const Key('backButton'),
            icon: Icons.chevron_left_rounded,
            tooltip: l10n.back,
            onPressed: () => _back(c),
          ),
          const Spacer(),
          StatusPill(label: l10n.babyDevice, leading: const BassinetIcon(size: 16)),
          const Spacer(),
          const SizedBox(width: NinniSpace.touch),
        ],
      ),
    ];

    if (c.isOffline) {
      children.addAll([
        ScreenHeading(
            title: l10n.offlineBabyTitle, subtitle: l10n.offlineBabyBody, style: NinniType.h1.copyWith(fontSize: 28)),
      ]);
    } else {
      children.addAll([
        ScreenHeading(
          title: l10n.babyPairingTitle,
          subtitle: l10n.babyPairingSubtitleQr,
          style: NinniType.h1.copyWith(fontSize: 28, letterSpacing: -0.7),
        ),
        SectionCard(
          key: const Key('roomCodeCard'),
          radius: NinniRadii.r28,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              if (code != null && !expired) ...[
                CodeBoxes.display(code: code),
                const SizedBox(height: 18),
                Semantics(
                  label: l10n.qrSemantic,
                  child: Container(
                    key: const Key('roomQr'),
                    width: 168,
                    height: 168,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NinniColors.cream50,
                      borderRadius: BorderRadius.circular(NinniRadii.r20),
                    ),
                    child: QrImageView(
                      data: RoomCode.joinUri(code),
                      padding: EdgeInsets.zero,
                      backgroundColor: NinniColors.cream50,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: NinniColors.night900),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square, color: NinniColors.night900),
                    ),
                  ),
                ),
              ] else if (c.pairingBusy || (code == null && c.pairingError == null))
                const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              else
                Text(
                  expired ? l10n.codeExpired : (c.pairingError ?? l10n.error),
                  textAlign: TextAlign.center,
                  style: NinniType.bodySm.copyWith(color: NinniColors.apricotSoftOnNight),
                ),
              const SizedBox(height: 18),
              if (code != null && !expired && remaining != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18, color: NinniColors.onNightMuted),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.codeValidFor.replaceAll('{time}', _mmss(remaining)),
                        style: NinniType.numeric(NinniType.label
                            .copyWith(letterSpacing: 0, fontWeight: FontWeight.w600, color: NinniColors.onNightMuted)),
                      ),
                    ),
                  ],
                )
              else if (!c.pairingBusy)
                NinniButton(
                  key: const Key('newCodeButton'),
                  label: l10n.newCode,
                  icon: Icons.refresh_rounded,
                  variant: NinniButtonVariant.secondary,
                  onPressed: c.startBroadcast,
                ),
              const SizedBox(height: 6),
              _RoomNameRow(name: c.roomName, onRename: () => renameRoom(context, c)),
            ],
          ),
        ),
        if (code != null && !expired)
          Row(
            children: [
              Expanded(
                child: NinniButton(
                  label: l10n.share,
                  icon: Icons.ios_share_rounded,
                  height: 56,
                  fontSize: 16,
                  onPressed: () => _share(context, code),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NinniButton(
                  label: l10n.copy,
                  icon: Icons.content_copy_rounded,
                  height: 56,
                  fontSize: 16,
                  variant: NinniButtonVariant.secondary,
                  onPressed: () => _copy(context, code),
                ),
              ),
            ],
          ),
      ]);
    }

    return NightTheme(
      child: Scaffold(
        backgroundColor: NinniColors.night900,
        body: NightSky(
            starStrength: 0.5,
            child: ScreenFrame(
              gap: 20,
              items: children,
              footer: [
                SectionCard(
                  radius: NinniRadii.r20,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const PulseDot(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.waitingForParent,
                                style:
                                    NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: NinniColors.onNight)),
                            const SizedBox(height: 2),
                            Text(
                              c.hasLocalVideo || (c.cameraController?.value.isInitialized ?? false)
                                  ? l10n.cameraMicReady
                                  : l10n.cameraPreparing,
                              style: NinniType.caption
                                  .copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: NinniColors.onNightMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )),
      ),
    );
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _share(BuildContext context, String code) async {
    final l10n = AppLocalizations.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(text: l10n.shareCodeText.replaceAll('{code}', RoomCode.format(code))),
      );
    } catch (e) {
      debugPrint('Share failed: $e');
    }
  }

  Future<void> _copy(BuildContext context, String code) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: RoomCode.format(code)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.copied)));
  }
}

/// Pills with the room code on the right (mockup); with large text the
/// code moves to its own line and the pills wrap (V2 phase 4).
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.pills, this.trailing});
  final List<Widget> pills;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(10) > 12.5;
    final code = trailing == null
        ? null
        : Text(
            trailing!,
            style: NinniType.numeric(NinniType.label
                .copyWith(letterSpacing: 0, fontWeight: FontWeight.w600, color: NinniColors.onNightMuted)),
          );
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: pills),
          if (code != null) ...[const SizedBox(height: 8), code],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Flexible(child: pills[i]),
        ],
        const SizedBox(width: 8),
        if (code != null) Expanded(child: Align(alignment: Alignment.centerRight, child: code)),
      ],
    );
  }
}

/// Baby phone while broadcasting (mockup BabyLive).
class BabyLiveScreen extends StatelessWidget {
  const BabyLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final connected = c.isConnected;
    final media = MediaQuery.of(context);
    final cameraHeight = (media.size.height * 0.24).clamp(150.0, 230.0);

    Future<void> end() async {
      if (await confirmEndBroadcast(context)) await c.leaveRole();
    }

    final quality = switch (c.videoSettings.quality) {
      'LOW' => l10n.qualitySaver,
      'HIGH' => l10n.qualitySharp,
      _ => l10n.qualityBalanced,
    };

    final screen = Scaffold(
      backgroundColor: NinniColors.night900,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(end());
        },
        child: NightSky(
          // Fainter stars on the baby side (V2.1 §4.3).
          starStrength: 0.5,
          child: ScreenFrame(
            gap: 14,
            padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 12, NinniSpace.screen, 16),
            items: [
              _BabyHeader(controller: c),
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  height: cameraHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: LiveVideo(
                          placeholder: VideoPlaceholder(label: l10n.cameraPreview, busy: c.cameraInitializing),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 80,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x0012142B), Color(0xD912142B)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(top: 12, left: 12, child: LiveBadge(label: l10n.live, height: 26)),
                      Positioned(
                        left: 14,
                        right: 64,
                        bottom: 14,
                        child: Text(
                          '${c.frontCamera ? l10n.cameraFront : l10n.cameraBack} · $quality',
                          style: NinniType.label.copyWith(letterSpacing: 0, color: NinniColors.onNight),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 4,
                        child: NinniIconButton(
                          key: const Key('switchCameraButton'),
                          icon: Icons.cameraswitch_outlined,
                          tooltip: l10n.switchCamera,
                          background: NinniColors.night900.withValues(alpha: 0.7),
                          foreground: NinniColors.white,
                          onPressed: c.switchCamera,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _BabySoundCard(controller: c),
              _BabyStatusBoxes(controller: c),
              if (Theme.of(context).platform == TargetPlatform.iOS)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18, color: NinniColors.onNightMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.iosKeepOpenHint,
                          style: NinniType.caption.copyWith(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: NinniColors.onNightMuted)),
                    ),
                  ],
                ),
            ],
            footer: [
              NinniButton(
                key: const Key('nightModeButton'),
                label: l10n.enterNightMode,
                icon: Icons.dark_mode_outlined,
                height: 62,
                onPressed: c.enterNightMode,
              ),
              Center(
                child: TextButton(
                  key: const Key('disconnectButton'),
                  onPressed: end,
                  style: TextButton.styleFrom(
                    foregroundColor: NinniColors.apricotSoftOnNight,
                    minimumSize: const Size(160, 44),
                    textStyle: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: Text(l10n.endBroadcast),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Night mode replaces the screen: no video preview or meter keeps
    // drawing underneath (battery/heat on the baby phone, V2 phase 4).
    return NightTheme(
      child: c.nightMode
          ? BabyNightView(
              parentConnected: connected,
              lightColor: c.nightLightColor,
              onExit: c.exitNightMode,
            )
          : screen,
    );
  }
}

/// "3 sa 08 dk" / "12 dk" since [since].
String formatElapsed(AppLocalizations l10n, Duration d) {
  final m = d.inMinutes;
  if (m < 60) return l10n.durationM.replaceAll('{m}', '$m');
  return l10n.durationHm.replaceAll('{h}', '${m ~/ 60}').replaceAll('{m}', (m % 60).toString().padLeft(2, '0'));
}

/// Text that refreshes every 30 s (elapsed times in headers).
class TickingText extends StatefulWidget {
  const TickingText({super.key, required this.builder, required this.style});
  final String Function(DateTime now) builder;
  final TextStyle style;

  @override
  State<TickingText> createState() => _TickingTextState();
}

class _TickingTextState extends State<TickingText> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.builder(DateTime.now()), style: NinniType.numeric(widget.style));
}

class _BabyHeader extends StatelessWidget {
  const _BabyHeader({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final connected = c.isConnected;
    final since = c.roomCreatedAt;
    final battery = '%${c.batteryLevel}';
    return Row(
      children: [
        const AppIcon(size: 34, painter: AppIconPainter(background: NinniColors.night700)),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            button: true,
            label: '${l10n.roomNameTitle}: ${c.roomName ?? l10n.defaultRoomName}',
            excludeSemantics: true,
            child: InkWell(
              key: const Key('roomNameRow'),
              borderRadius: BorderRadius.circular(NinniRadii.r12),
              onTap: () => renameRoom(context, c),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: NinniSpace.touch),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.roomName ?? l10n.defaultRoomName,
                        style: NinniType.title.copyWith(color: NinniColors.onNight)),
                    if (since != null)
                      TickingText(
                        builder: (now) =>
                            l10n.onAirFor.replaceAll('{time}', formatElapsed(l10n, now.difference(since))),
                        style: NinniType.caption.copyWith(color: NinniColors.onNightMuted),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Narrow phones (Huawei RNE-L01, long AZ names): the link pill shows
        // only its dot, with the full label for screen readers (V2.1 §4.2).
        if (MediaQuery.sizeOf(context).width < 380 && (c.roomName ?? l10n.defaultRoomName).length > 9)
          Semantics(
            key: Key(connected ? 'linkConnected' : 'linkNotConnected'),
            label: connected ? l10n.parentConnected : l10n.parentWaiting,
            excludeSemantics: true,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: connected ? NinniColors.mintPillOnNight : NinniColors.night800,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: connected ? NinniColors.mint : NinniColors.onNightMuted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )
        else
          StatusPill(
            key: Key(connected ? 'linkConnected' : 'linkNotConnected'),
            label: connected ? l10n.linkShortOk : l10n.linkShortWait,
            semanticLabel: connected ? l10n.parentConnected : l10n.parentWaiting,
            tone: connected ? PillTone.mint : PillTone.neutral,
          ),
        const SizedBox(width: 6),
        StatusPill(
          label: battery,
          semanticLabel: c.batteryCharging
              ? l10n.batteryCharging.replaceAll('{level}', '${c.batteryLevel}')
              : l10n.batteryPercent.replaceAll('{level}', '${c.batteryLevel}'),
          icon: c.batteryCharging ? Icons.bolt_rounded : Icons.battery_std_rounded,
          dot: false,
        ),
      ],
    );
  }
}

/// Ring gauge + last hour chart (mockup BabyLive21).
class _BabySoundCard extends StatelessWidget {
  const _BabySoundCard({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final threshold = c.noiseThreshold;
    final listening = c.listeningNoise || c.isOffline;
    return SectionCard(
      radius: NinniRadii.r24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Only the gauge and the level word follow the live level (A35).
          ValueListenableBuilder<double>(
            valueListenable: c.level,
            builder: (context, db, _) => Semantics(
              label: '${db.round()} dB',
              excludeSemantics: true,
              child: RepaintBoundary(child: RingGauge(db: db, threshold: threshold, active: listening)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<double>(
                        valueListenable: c.level,
                        builder: (context, db, _) {
                          final word = !listening
                              ? l10n.levelOff
                              : db >= threshold
                                  ? l10n.levelLoud
                                  : (db >= threshold - 12 ? l10n.levelActive : l10n.levelQuiet);
                          return Text(word, style: NinniType.title.copyWith(fontSize: 18, color: NinniColors.onNight));
                        },
                      ),
                    ),
                    Text(
                      '${l10n.thresholdShort} ${threshold.round()}',
                      key: const Key('thresholdLabel'),
                      style: NinniType.numeric(NinniType.caption
                          .copyWith(fontWeight: FontWeight.w700, color: NinniColors.apricotSoftOnNight)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: c.historyRevision,
                  builder: (context, _, __) => RepaintBoundary(
                    child: MinuteBars(values: c.noiseLastHour, threshold: threshold),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: c.historyRevision,
                  builder: (context, _, __) {
                    final n = c.alarmsLastHour;
                    final last = c.lastBabyAlarmAt;
                    return Row(
                      children: [
                        Expanded(
                          child: Text(l10n.lastHour,
                              style: NinniType.caption.copyWith(fontSize: 11, color: NinniColors.onNightMuted)),
                        ),
                        Text(
                          n == 0 || last == null
                              ? l10n.noAlarmsShort
                              : l10n.alarmsAt
                                  .replaceAll('{n}', '$n')
                                  .replaceAll('{time}', DateFormat.Hm().format(last)),
                          style: NinniType.numeric(
                              NinniType.caption.copyWith(fontSize: 11, color: NinniColors.onNightMuted)),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parent / lullaby / light boxes.
class _BabyStatusBoxes extends StatelessWidget {
  const _BabyStatusBoxes({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final soothe = c.soothe;
    final playing = soothe.isPlayingAt(DateTime.now()) && soothe.track != null;
    final track = !playing
        ? l10n.stateOff
        : switch (soothe.track!) {
            SootheTrack.whiteNoise => l10n.sootheWhite,
            SootheTrack.rain => l10n.sootheRain,
            SootheTrack.heartbeat => l10n.sootheHeart,
            SootheTrack.dandini => l10n.sootheDandini,
          };
    final light = c.nightLight;
    final lightText = !light.on
        ? l10n.stateOff
        : switch (light.color) {
            NightLightColor.amber => l10n.colorAmber,
            NightLightColor.pink => l10n.colorPink,
            NightLightColor.purple => l10n.colorPurple,
            NightLightColor.blue => l10n.colorBlue,
          };
    Widget box(IconData icon, Color iconColor, String label, String value) => Expanded(
          child: Semantics(
            label: '$label: $value',
            excludeSemantics: true,
            child: SectionCard(
              radius: NinniRadii.r18,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(height: 6),
                  Text(label, style: NinniType.caption.copyWith(color: NinniColors.onNightMuted)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: NinniType.bodySm.copyWith(
                          fontSize: 14, height: 1.25, fontWeight: FontWeight.w800, color: NinniColors.onNight)),
                ],
              ),
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          box(Icons.smartphone_rounded, NinniColors.mintOnNight, l10n.boxParent,
              c.isConnected ? l10n.boxParentOn : l10n.boxParentOff),
          const SizedBox(width: 10),
          box(Icons.music_note_rounded, NinniColors.primarySoftOnNight, l10n.boxLullaby, track),
          const SizedBox(width: 10),
          box(Icons.lightbulb_outline_rounded, light.on ? light.color.color : NinniColors.lightAmber, l10n.boxLight,
              lightText),
        ],
      ),
    );
  }
}

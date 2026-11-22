import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/pairing/recent_room_store.dart';
import '../../core/pairing/room_code.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';
import '../../core/webrtc/rtc_audio_stats.dart';
import '../video_gallery_screen.dart';
import 'alert_history_v2_screen.dart';
import 'baby_screens.dart' show TickingText, formatElapsed;
import 'lullaby_sheet.dart';
import 'qr_scan_screen.dart';
import 'settings_screen.dart';
import 'widgets/live_video.dart';

/// Parent phone: enter the 8 character code (mockup ParentJoin). Offline:
/// look for a nearby baby phone instead.
class ParentJoinScreen extends StatefulWidget {
  const ParentJoinScreen({super.key});

  @override
  State<ParentJoinScreen> createState() => _ParentJoinScreenState();
}

class _ParentJoinScreenState extends State<ParentJoinScreen> {
  final TextEditingController _code = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _complete => RoomCode.isValid(RoomCode.normalize(_code.text));

  Future<void> _join(MonitorController c) async {
    if (!_complete) return;
    _focus.unfocus();
    await c.joinRoom(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final p = NinniPalette.of(context);
    final error = c.pairingError;

    return Scaffold(
      body: ThemedSky(
          child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(c.leaveRole());
        },
        child: ScreenFrame(
          gap: 24,
          items: [
            TopBar(backLabel: l10n.back, onBack: c.leaveRole),
            if (c.isOffline) ...[
              ScreenHeading(title: l10n.offlineParentTitle, subtitle: l10n.offlineParentBody),
              _NearbyList(controller: c),
            ] else ...[
              ScreenHeading(title: l10n.joinTitle, subtitle: l10n.joinSubtitle),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(l10n.roomCode, padding: EdgeInsets.zero),
                  const SizedBox(height: 10),
                  CodeBoxes.input(
                    controller: _code,
                    focusNode: _focus,
                    fieldKey: const Key('roomCodeField'),
                    semanticLabel: l10n.roomCode,
                    onSubmitted: (_) => _join(c),
                  ),
                  const SizedBox(height: 24),
                  NinniButton(
                    key: const Key('scanQrButton'),
                    label: l10n.scanQr,
                    icon: Icons.qr_code_scanner_rounded,
                    variant: NinniButtonVariant.secondary,
                    onPressed: () async {
                      final code = await Navigator.of(context).push<String>(
                        MaterialPageRoute(builder: (_) => const QrScanScreen()),
                      );
                      if (code == null || !mounted) return;
                      _code.text = code;
                      await _join(c);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(error,
                          key: const Key('joinError'),
                          style: NinniType.bodySm.copyWith(fontSize: 14, color: p.apricotText)),
                    ),
                  ],
                ],
              ),
              if (c.recentRooms.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(l10n.recentRoom, padding: EdgeInsets.zero),
                    const SizedBox(height: 10),
                    _RecentRoomCard(
                      room: c.recentRooms.first,
                      busy: c.pairingBusy,
                      onTap: () => c.joinRoom(c.recentRooms.first.code),
                    ),
                  ],
                ),
            ],
          ],
          footer: [
            if (!c.isOffline)
              NinniButton(
                key: const Key('joinRoomButton'),
                label: l10n.connect,
                busy: c.pairingBusy,
                onPressed: _complete && c.firebaseReady ? () => _join(c) : null,
              ),
          ],
        ),
      )),
    );
  }
}

class _RecentRoomCard extends StatelessWidget {
  const _RecentRoomCard({required this.room, required this.busy, required this.onTap});
  final RecentRoom room;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = NinniPalette.of(context);
    final now = DateTime.now();
    final day = DateTime(room.joinedAt.year, room.joinedAt.month, room.joinedAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final time = DateFormat.Hm().format(room.joinedAt);
    final when = day == today
        ? '${l10n.today} $time'
        : day == today.subtract(const Duration(days: 1))
            ? '${l10n.yesterdayLower} $time'
            : DateFormat('d MMM HH:mm', l10n.locale.languageCode).format(room.joinedAt);
    return SectionCard(
      key: const Key('recentRoomCard'),
      radius: NinniRadii.r20,
      padding: const EdgeInsets.all(14),
      onTap: busy ? null : onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: NinniColors.night900, borderRadius: BorderRadius.circular(NinniRadii.r14)),
            child: const Center(child: BassinetIcon(size: 24, color: NinniColors.cream50)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name ?? l10n.defaultRoomName,
                    style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 2),
                Text('${RoomCode.format(room.code)} · $when',
                    style: NinniType.numeric(
                        NinniType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: p.textMuted))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(l10n.reconnect,
              style: NinniType.bodySm.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: p.accentText)),
        ],
      ),
    );
  }
}

class _NearbyList extends StatelessWidget {
  const _NearbyList({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = NinniPalette.of(context);
    final c = controller;
    final devices = c.discoveredEndpoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!c.discovering)
          NinniButton(
            key: const Key('joinRoomButton'),
            label: l10n.searchNearby,
            icon: Icons.wifi_find_rounded,
            onPressed: c.startDiscovery,
          )
        else ...[
          Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.searching, style: NinniType.bodySm.copyWith(color: p.textMuted))),
              TextButton(onPressed: c.stopDiscovery, child: Text(l10n.cancel)),
            ],
          ),
          const SizedBox(height: 12),
          for (final d in devices) ...[
            SectionCard(
              radius: NinniRadii.r20,
              padding: const EdgeInsets.all(14),
              onTap: () => c.connectToEndpoint(d['id']!, d['name'] ?? ''),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        BoxDecoration(color: NinniColors.night900, borderRadius: BorderRadius.circular(NinniRadii.r14)),
                    child: const Center(child: BassinetIcon(size: 24, color: NinniColors.cream50)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(d['name'] ?? l10n.unknownDevice,
                        style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                  ),
                  Text(l10n.connect,
                      style: NinniType.bodySm.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: p.accentText)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

/// Parent phone while watching (mockup ParentLive). Always dark.
class ParentLiveScreen extends StatelessWidget {
  const ParentLiveScreen({super.key});

  static Future<void> confirmDisconnect(BuildContext context, MonitorController c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => NightTheme(
        child: AlertDialog(
          title: Text(l10n.disconnectTitle),
          content: Text(l10n.disconnectBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            TextButton(
              key: const Key('confirmDisconnect'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.disconnect),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await c.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final connected = c.isConnected;
    final media = MediaQuery.of(context);
    final videoHeight = (media.size.height * 0.42).clamp(230.0, 440.0) + media.padding.top * 0.5;
    final battery = c.remoteBatteryLevel;
    final since = c.connectedSince;
    final quality = c.connectionQuality;
    final (qLabel, qColor) = !connected
        ? (l10n.connecting, NinniColors.onNightSoft)
        : switch (quality) {
            ConnectionQuality.poor => (l10n.qualityPoor, NinniColors.apricotSoftOnNight),
            ConnectionQuality.fair => (l10n.qualityFair, NinniColors.amber),
            _ => (l10n.qualityGood, NinniColors.mintOnNight),
          };

    return NightTheme(
      child: Scaffold(
        backgroundColor: NinniColors.night900,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(confirmDisconnect(context, c));
          },
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: videoHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(
                              child: LiveVideo(
                                placeholder: VideoPlaceholder(
                                  label: connected ? l10n.liveView : l10n.connecting,
                                  busy: !connected,
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              height: 130,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xD912142B), Color(0x0012142B)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 120,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0x0012142B), NinniColors.night900],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: media.padding.top + 8,
                              left: 16,
                              right: 8,
                              child: Row(
                                children: [
                                  NinniIconButton(
                                    key: const Key('backButton'),
                                    icon: Icons.chevron_left_rounded,
                                    tooltip: l10n.back,
                                    background: NinniColors.night900.withValues(alpha: 0.6),
                                    foreground: NinniColors.white,
                                    onPressed: () => confirmDisconnect(context, c),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.roomName ?? l10n.defaultRoomName,
                                            style: NinniType.title.copyWith(color: NinniColors.onNight)),
                                        if (since != null)
                                          TickingText(
                                            builder: (now) => l10n.watchingFor
                                                .replaceAll('{time}', formatElapsed(l10n, now.difference(since))),
                                            style: NinniType.caption.copyWith(color: NinniColors.onNightSoft),
                                          )
                                        else if (c.roomCode != null)
                                          Text(RoomCode.format(c.roomCode!),
                                              style: NinniType.numeric(
                                                  NinniType.caption.copyWith(color: NinniColors.onNightSoft))),
                                      ],
                                    ),
                                  ),
                                  if (connected) ...[
                                    const SizedBox(width: 8),
                                    LiveBadge(label: l10n.live, height: 28),
                                  ],
                                  _LiveMenu(controller: c),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  Semantics(
                                    label: connected
                                        ? l10n.connectionQualityLabel.replaceAll('{q}', qLabel)
                                        : l10n.connecting,
                                    excludeSemantics: true,
                                    child: _VideoPill(
                                      key: Key(connected ? 'linkConnected' : 'linkNotConnected'),
                                      icon: Icons.signal_cellular_alt_rounded,
                                      color: qColor,
                                      label: qLabel,
                                      pulse: !connected,
                                    ),
                                  ),
                                  if (battery != null) ...[
                                    const SizedBox(width: 8),
                                    Semantics(
                                      label: l10n.babyBatteryLabel.replaceAll('{level}', '$battery'),
                                      excludeSemantics: true,
                                      child: _VideoPill(
                                        icon: c.remoteBatteryCharging ? Icons.bolt_rounded : Icons.battery_std_rounded,
                                        color: battery <= 15 ? NinniColors.amber : NinniColors.onNightSoft,
                                        label: '%$battery',
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  NinniIconButton(
                                    key: const Key('fullscreenButton'),
                                    icon: Icons.fullscreen_rounded,
                                    tooltip: l10n.fullscreen,
                                    background: NinniColors.night900.withValues(alpha: 0.7),
                                    foreground: NinniColors.white,
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(builder: (_) => const FullscreenLiveScreen()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.fromLTRB(NinniSpace.screen, 4, NinniSpace.screen, 20 + media.padding.bottom),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: NinniSpace.maxContentWidth),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (c.showBatteryWarning) ...[
                                    _BatteryWarning(level: battery, onClose: c.dismissBatteryWarning),
                                    const SizedBox(height: 16),
                                  ],
                                  c.talking ? _TalkCard(controller: c) : _SoundCard(controller: c),
                                  const SizedBox(height: 16),
                                  _ControlsRow(controller: c),
                                  const Spacer(),
                                  const SizedBox(height: 16),
                                  _SmallButtons(controller: c),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Bars for demo screenshots (no audio).
const List<double> demoWave = [
  0.18,
  0.3,
  0.22,
  0.42,
  0.35,
  0.5,
  0.28,
  0.2,
  0.33,
  0.46,
  0.6,
  0.38,
  0.24,
  0.3,
  0.2,
  0.26,
  0.4,
  0.32,
  0.22,
  0.18,
  0.28,
  0.44,
  0.52,
  0.36,
  0.25,
  0.3,
  0.2,
  0.34,
  0.48,
  0.4,
  0.27,
  0.22,
  0.3,
  0.24,
  0.2,
  0.26,
];

/// Pill over the video (quality, battery).
class _VideoPill extends StatelessWidget {
  const _VideoPill({super.key, required this.icon, required this.color, required this.label, this.pulse = false});
  final IconData icon;
  final Color color;
  final String label;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: NinniColors.night900.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(NinniRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) const PulseDot(size: 8, color: NinniColors.onNightSoft) else Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: NinniType.numeric(NinniType.caption.copyWith(fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }
}

/// Top-right menu: "Disconnect" lives here so it is not tapped by accident
/// (V2.1 §4).
class _LiveMenu extends StatelessWidget {
  const _LiveMenu({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      key: const Key('liveMenuButton'),
      tooltip: l10n.moreActions,
      icon: const Icon(Icons.more_vert_rounded, color: NinniColors.white),
      color: NinniColors.night800,
      onSelected: (v) {
        if (v == 'disconnect') unawaited(controller.disconnect());
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          key: const Key('disconnectButton'),
          value: 'disconnect',
          child: Row(
            children: [
              const Icon(Icons.link_off_rounded, color: NinniColors.apricotSoftOnNight),
              const SizedBox(width: 12),
              Text(l10n.disconnect,
                  style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: NinniColors.onNight)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Baby is calm" card: live 36-bar wave from the received audio, alarms
/// tonight and the history link.
class _SoundCard extends StatelessWidget {
  const _SoundCard({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final last = c.lastAlertAt;
    final n = c.tonightAlarmCount;
    final alarmsText = n == 0
        ? l10n.tonightNone
        : [
            l10n.tonightAlarms.replaceAll('{n}', '$n'),
            if (last != null) l10n.lastShort.replaceAll('{time}', DateFormat.Hm().format(last)),
          ].join(' · ');
    return SectionCard(
      key: const Key('soundCard'),
      radius: NinniRadii.r22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: c.level,
            builder: (context, db, _) {
              final status = c.noiseAlert
                  ? l10n.babyCryingShort
                  : (db >= c.noiseThreshold - 12 ? l10n.babyRestless : l10n.babyCalm);
              return Semantics(
                liveRegion: c.noiseAlert,
                label: '$status, ${db.round()} dB',
                excludeSemantics: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(status,
                          style: NinniType.title
                              .copyWith(color: c.noiseAlert ? NinniColors.apricotSoftOnNight : NinniColors.onNight)),
                    ),
                    CountText(db.round(),
                        duration: const Duration(milliseconds: 250),
                        style: NinniType.title.copyWith(color: NinniColors.onNight)),
                    Text(' dB', style: NinniType.caption.copyWith(fontSize: 13, color: NinniColors.onNightMuted)),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          LiveWave(
            level: c.level,
            color: c.noiseAlert ? NinniColors.apricot : NinniColors.mint,
            active: c.isConnected,
            initial: c.isDemo ? demoWave : null,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(alarmsText,
                    style: NinniType.numeric(NinniType.caption.copyWith(color: NinniColors.onNightMuted))),
              ),
              TextButton(
                key: const Key('historyButton'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AlertHistoryV2Screen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: NinniColors.primarySoftOnNight,
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: NinniType.caption.copyWith(fontWeight: FontWeight.w700),
                ),
                child: Text(l10n.historyLink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// While the talk button is held (B76): whether the voice really leaves the
/// phone, with the real outgoing level as a wave.
class _TalkCard extends StatefulWidget {
  const _TalkCard({required this.controller});
  final MonitorController controller;

  @override
  State<_TalkCard> createState() => _TalkCardState();
}

class _TalkCardState extends State<_TalkCard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = widget.controller;
    final started = c.talkStartedAt;
    final waited = started == null ? Duration.zero : DateTime.now().difference(started);
    final (text, color, icon) = c.talkFlowing
        ? (l10n.talkBabyHears, NinniColors.mintOnNight, Icons.hearing_rounded)
        : waited > const Duration(milliseconds: 2500)
            ? (l10n.talkNotReaching, NinniColors.amber, Icons.warning_amber_rounded)
            : (l10n.talkStarting, NinniColors.onNightSoft, Icons.mic_rounded);
    return SectionCard(
      key: const Key('talkCard'),
      radius: NinniRadii.r22,
      color: const Color(0xFF23245A),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: NinniType.title.copyWith(color: color))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LiveWave(
            level: c.talkLevel,
            initial: c.isDemo ? demoWave : null,
            linear: true,
            color: NinniColors.primaryGlow,
            active: true,
          ),
          const SizedBox(height: 10),
          Text(l10n.talkingNow, style: NinniType.caption.copyWith(color: NinniColors.onNightMuted)),
        ],
      ),
    );
  }
}

/// Lullaby (60) — hold to talk (84, rings) — light (60), like a call screen.
class _ControlsRow extends StatelessWidget {
  const _ControlsRow({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final light = c.nightLight;
    final sootheOn = c.soothe.isPlayingAt(DateTime.now());
    Widget round({
      required Key key,
      required double size,
      required Color bg,
      required Widget icon,
      required String label,
      required String semantics,
      VoidCallback? onTap,
      bool selected = false,
    }) =>
        Semantics(
          button: true,
          selected: selected,
          label: semantics,
          excludeSemantics: true,
          child: InkResponse(
            key: key,
            onTap: onTap,
            radius: size / 2 + 8,
            child: SizedBox(
              width: 96,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: NinniColors.primaryGlow, width: 2) : null,
                    ),
                    child: Center(child: icon),
                  ),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: NinniType.caption.copyWith(fontWeight: FontWeight.w700, color: NinniColors.onNightSoft)),
                ],
              ),
            ),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: round(
            key: const Key('lullabyButton'),
            size: 60,
            bg: NinniColors.nightVideo,
            icon: const Icon(Icons.music_note_rounded, color: NinniColors.white),
            label: l10n.lullabyShort,
            semantics: l10n.lullabyShort,
            selected: sootheOn,
            onTap: () => showLullabySheet(context),
          ),
        ),
        _TalkButton(controller: c),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: round(
            key: const Key('nightLightButton'),
            size: 60,
            bg: light.on ? NinniColors.lightTileOn : NinniColors.nightVideo,
            icon: Icon(Icons.lightbulb_outline_rounded, color: light.on ? light.color.color : NinniColors.onNightSoft),
            label: light.on ? l10n.lightOn : l10n.lightOff,
            semantics: light.on ? l10n.lightOn : l10n.lightOff,
            selected: light.on,
            onTap: c.isConnected || c.isDemo ? () => c.setNightLight(on: !light.on) : null,
          ),
        ),
      ],
    );
  }
}

/// Record / switch / recordings / settings.
class _SmallButtons extends StatelessWidget {
  const _SmallButtons({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    Widget small(Key key, Widget icon, String label, VoidCallback? onTap, {bool active = false}) => Expanded(
          child: Semantics(
            button: true,
            enabled: onTap != null,
            selected: active,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: active ? NinniColors.night700 : NinniColors.night800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: NinniColors.nightCardLine),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: key,
                onTap: onTap,
                child: SizedBox(
                  height: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(opacity: onTap == null ? 0.45 : 1, child: icon),
                      const SizedBox(height: 4),
                      Text(label,
                          maxLines: 1,
                          style: NinniType.caption
                              .copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: NinniColors.onNight)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        small(const Key('recordButton'), _RecordIcon(recording: c.isRecording),
            c.isRecording ? l10n.stopRecordingShort : l10n.record, c.toggleRecording,
            active: c.isRecording),
        const SizedBox(width: 8),
        small(
            const Key('switchCameraButton'),
            const Icon(Icons.cameraswitch_outlined, size: 18, color: NinniColors.white),
            l10n.switchShort,
            c.isConnected ? c.switchCamera : null),
        const SizedBox(width: 8),
        small(
            const Key('recordingsButton'),
            const Icon(Icons.video_library_outlined, size: 18, color: NinniColors.white),
            l10n.recordings,
            () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VideoGalleryScreen()))),
        const SizedBox(width: 8),
        small(
            const Key('settingsButton'),
            const Icon(Icons.tune_rounded, size: 18, color: NinniColors.white),
            l10n.settings,
            () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()))),
      ],
    );
  }
}

/// "Hold to talk" (V2 5.3, V2.1 §4): 84 px circle with rings while talking.
class _TalkButton extends StatelessWidget {
  const _TalkButton({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final enabled = c.canTalk;
    final talking = c.talking;
    return Semantics(
      button: true,
      enabled: enabled,
      label: talking ? l10n.talkingNow : l10n.holdToTalk,
      hint: l10n.holdToTalkHint,
      excludeSemantics: true,
      // Screen readers cannot hold: a double tap toggles talking for them.
      onTap: enabled ? () => talking ? c.stopTalking() : c.startTalking() : null,
      child: GestureDetector(
        key: const Key('talkButton'),
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => c.startTalking() : null,
        onTapUp: enabled ? (_) => c.stopTalking() : null,
        onTapCancel: enabled ? c.stopTalking : null,
        child: SizedBox(
          width: 112,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TalkRings(
                active: talking,
                size: 84,
                child: AnimatedScale(
                  scale: talking ? 0.94 : 1,
                  duration: NinniDurations.fast,
                  child: AnimatedContainer(
                    duration: NinniDurations.fast,
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !enabled
                          ? NinniColors.primary.withValues(alpha: 0.45)
                          : (talking ? NinniColors.primaryGlow : NinniColors.primary),
                    ),
                    child:
                        Icon(talking ? Icons.mic_rounded : Icons.mic_none_rounded, size: 34, color: NinniColors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.talkShort,
                  textAlign: TextAlign.center,
                  style: NinniType.caption.copyWith(fontWeight: FontWeight.w700, color: NinniColors.onNight)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordIcon extends StatelessWidget {
  const _RecordIcon({required this.recording});
  final bool recording;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: NinniColors.apricot, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: NinniColors.apricot,
          shape: recording ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: recording ? BorderRadius.circular(2) : null,
        ),
      ),
    );
  }
}

class _BatteryWarning extends StatelessWidget {
  const _BatteryWarning({required this.level, required this.onClose});
  final int? level;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('batteryWarning'),
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        decoration: BoxDecoration(color: NinniColors.amber, borderRadius: BorderRadius.circular(NinniRadii.r18)),
        child: Row(
          children: [
            const Icon(Icons.battery_alert_rounded, color: NinniColors.onAmber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.batteryLowTitle,
                      style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w800, color: NinniColors.onAmber)),
                  Text(l10n.batteryLowBody.replaceAll('{level}', '${level ?? '?'}'),
                      style: NinniType.caption.copyWith(fontSize: 13, color: NinniColors.onAmber)),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.dismiss,
              color: NinniColors.onAmber,
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen video (parent), landscape friendly.
class FullscreenLiveScreen extends StatelessWidget {
  const FullscreenLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    return NightTheme(
      child: Scaffold(
        backgroundColor: NinniColors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            LiveVideo(
              fit: BoxFit.contain,
              placeholder: VideoPlaceholder(label: l10n.connecting, busy: true),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NinniIconButton(
                      icon: Icons.fullscreen_exit_rounded,
                      tooltip: l10n.close,
                      background: NinniColors.night900,
                      foreground: NinniColors.white,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (c.isConnected) LiveBadge(label: l10n.live, height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
import 'alert_history_v2_screen.dart';
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
      body: PopScope(
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
      ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 2),
                Text('${RoomCode.format(room.code)} · $when',
                    style: NinniType.numeric(NinniType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: p.textMuted))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(l10n.reconnect, style: NinniType.bodySm.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: p.accentText)),
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
                    decoration: BoxDecoration(color: NinniColors.night900, borderRadius: BorderRadius.circular(NinniRadii.r14)),
                    child: const Center(child: BassinetIcon(size: 24, color: NinniColors.cream50)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(d['name'] ?? l10n.unknownDevice,
                        style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                  ),
                  Text(l10n.connect, style: NinniType.bodySm.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: p.accentText)),
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

  Future<void> _confirmDisconnect(BuildContext context, MonitorController c) async {
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
    final videoHeight = (media.size.height * 0.48).clamp(240.0, 460.0);
    final code = c.roomCode;
    final battery = c.remoteBatteryLevel;
    final last = c.lastAlertAt;

    return NightTheme(
      child: Scaffold(
        backgroundColor: NinniColors.night900,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmDisconnect(context, c));
          },
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      child: SizedBox(
                        height: videoHeight + media.padding.top,
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
                            Positioned(
                              top: media.padding.top + 12,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  NinniIconButton(
                                    key: const Key('backButton'),
                                    icon: Icons.chevron_left_rounded,
                                    tooltip: l10n.back,
                                    background: NinniColors.night900,
                                    foreground: NinniColors.white,
                                    onPressed: () => _confirmDisconnect(context, c),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: NinniColors.night900,
                                        borderRadius: BorderRadius.circular(NinniRadii.r14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(c.roomName ?? l10n.defaultRoomName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w800, color: NinniColors.onNight)),
                                          if (code != null)
                                            Text(RoomCode.format(code),
                                                style: NinniType.numeric(NinniType.caption.copyWith(color: NinniColors.onNightMuted))),
                                        ],
                                      ),
                                    ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (connected) LiveBadge(label: l10n.live, height: 30),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  StatusPill(
                                    key: Key(connected ? 'linkConnected' : 'linkNotConnected'),
                                    label: connected ? l10n.linkGood : l10n.connecting,
                                    tone: connected ? PillTone.mint : PillTone.neutral,
                                    height: 30,
                                    onVideo: true,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: battery == null
                                          ? const SizedBox.shrink()
                                          : StatusPill(
                                              label: l10n.babyDeviceBatteryShort.replaceAll('{level}', '$battery'),
                                              dot: false,
                                              height: 30,
                                              onVideo: true,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  NinniIconButton(
                                    key: const Key('fullscreenButton'),
                                    icon: Icons.fullscreen_rounded,
                                    tooltip: l10n.fullscreen,
                                    size: 40,
                                    radius: NinniRadii.r12,
                                    background: NinniColors.night900,
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
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(NinniSpace.screen, 18, NinniSpace.screen, 24 + media.padding.bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (c.showBatteryWarning) ...[
                            _BatteryWarning(level: battery, onClose: c.dismissBatteryWarning),
                            const SizedBox(height: 16),
                          ],
                          SectionCard(
                            radius: NinniRadii.r22,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Only the bars and the level text follow the
                                // live level (~10 Hz, V2 §4 / phase 4).
                                Expanded(
                                  child: ValueListenableBuilder<double>(
                                    valueListenable: c.level,
                                    builder: (context, db, _) {
                                      final calmText = c.noiseAlert
                                          ? l10n.babyCryingShort
                                          : (db >= c.noiseThreshold - 12 ? l10n.babyStirring : l10n.babyCalm);
                                      final detail = [
                                        '${db.round()} dB',
                                        if (last != null)
                                          l10n.lastAlarmAt.replaceAll('{time}', DateFormat.Hm().format(last)),
                                      ].join(' · ');
                                      return Row(
                                        children: [
                                          RepaintBoundary(
                                            child: SoundBars(
                                              db: db,
                                              color: c.noiseAlert ? NinniColors.apricot : NinniColors.mint,
                                              active: connected,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Semantics(
                                              liveRegion: c.noiseAlert,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(calmText, style: NinniType.title.copyWith(color: NinniColors.onNight)),
                                                  const SizedBox(height: 2),
                                                  Text(detail,
                                                      style: NinniType.numeric(NinniType.caption.copyWith(
                                                          fontSize: 13, fontWeight: FontWeight.w500, color: NinniColors.onNightMuted))),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                TextButton(
                                  key: const Key('historyButton'),
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => const AlertHistoryV2Screen()),
                                  ),
                                  style: TextButton.styleFrom(foregroundColor: NinniColors.primarySoftOnNight),
                                  child: Text(l10n.history),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!c.isOffline) ...[
                            _TalkButton(controller: c),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: IconTile(
                                  key: const Key('lullabyButton'),
                                  label: l10n.lullabyShort,
                                  icon: Icons.music_note_rounded,
                                  active: c.soothe.isPlayingAt(DateTime.now()) || c.nightLight.on,
                                  onTap: () => showLullabySheet(context),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: IconTile(
                                  key: const Key('recordButton'),
                                  label: c.isRecording ? l10n.stopRecordingShort : l10n.record,
                                  active: c.isRecording,
                                  iconWidget: _RecordIcon(recording: c.isRecording),
                                  onTap: c.toggleRecording,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: IconTile(
                                  key: const Key('switchCameraButton'),
                                  label: l10n.switchShort,
                                  icon: Icons.cameraswitch_outlined,
                                  onTap: connected ? c.switchCamera : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: IconTile(
                                  key: const Key('settingsButton'),
                                  label: l10n.settings,
                                  icon: Icons.tune_rounded,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          NinniButton(
                            key: const Key('disconnectButton'),
                            label: l10n.disconnect,
                            variant: NinniButtonVariant.secondary,
                            foreground: NinniColors.onNightSoft,
                            onPressed: c.disconnect,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Hold to talk to the baby" (V2 5.3).
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
        onTapDown: enabled ? (_) => c.startTalking() : null,
        onTapUp: enabled ? (_) => c.stopTalking() : null,
        onTapCancel: enabled ? c.stopTalking : null,
        child: AnimatedScale(
          scale: talking ? 0.97 : 1,
          duration: NinniDurations.fast,
          child: AnimatedContainer(
            duration: NinniDurations.fast,
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: !enabled
                  ? NinniColors.primary.withValues(alpha: 0.45)
                  : (talking ? NinniColors.primaryGlow : NinniColors.primary),
              borderRadius: BorderRadius.circular(NinniRadii.r22),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(talking ? Icons.mic_rounded : Icons.mic_none_rounded, color: NinniColors.white),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    talking ? l10n.talkingNow : l10n.holdToTalk,
                    textAlign: TextAlign.center,
                    style: NinniType.body.copyWith(fontWeight: FontWeight.w800, color: NinniColors.white),
                  ),
                ),
              ],
            ),
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
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: NinniColors.apricot, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 10,
        height: 10,
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

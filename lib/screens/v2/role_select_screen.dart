import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/enums/device_role.dart';
import '../../core/pairing/recent_room_store.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';
import 'settings_screen.dart';

/// Home (mockup Home21, V2.1 §4): replaces the role selection. A night
/// illustration with a greeting for the time of day, one tap to watch the
/// last room again, "Baby phone" / "New room", and rotating tips. Always
/// dark.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  static String greeting(AppLocalizations l10n, DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return l10n.greetMorning;
    if (h >= 12 && h < 18) return l10n.greetDay;
    if (h >= 18 && h < 22) return l10n.greetEvening;
    return l10n.greetNight;
  }

  static String lastSeen(AppLocalizations l10n, DateTime at, DateTime now) {
    final day = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final time = DateFormat.Hm().format(at);
    if (day == today) return '${l10n.today.toLowerCase()} $time';
    if (day == today.subtract(const Duration(days: 1))) return '${l10n.yesterdayLower} $time';
    return DateFormat('d MMM HH:mm', l10n.locale.languageCode).format(at);
  }

  Future<void> _watchRecent(MonitorController c, RecentRoom room) async {
    await c.selectRole(DeviceRole.PARENT);
    await c.joinRoom(room.code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final media = MediaQuery.of(context);
    final recent = c.recentRooms.isEmpty ? null : c.recentRooms.first;
    final artHeight = (media.size.height * 0.36).clamp(200.0, 330.0) + media.padding.top * 0.3;

    return NightTheme(
      child: Scaffold(
        backgroundColor: NinniColors.night900,
        body: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: artHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          HomeIllustration(height: artHeight),
                          Positioned(
                            left: NinniSpace.screen,
                            right: 72,
                            top: media.padding.top + 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ninni',
                                    style: NinniType.label
                                        .copyWith(fontSize: 14, letterSpacing: 0, color: NinniColors.onNightSoft)),
                                const SizedBox(height: 4),
                                Semantics(
                                  header: true,
                                  child: Text(greeting(l10n, DateTime.now()),
                                      style: NinniType.h1.copyWith(color: NinniColors.onNight)),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 16,
                            top: (artHeight * 0.42).clamp(media.padding.top + 8, double.infinity),
                            child: NinniIconButton(
                              key: const Key('settingsButton'),
                              icon: Icons.tune_rounded,
                              tooltip: l10n.settings,
                              background: NinniColors.night900.withValues(alpha: 0.5),
                              foreground: NinniColors.white,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.fromLTRB(NinniSpace.screen, 8, NinniSpace.screen, 24 + media.padding.bottom),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: NinniSpace.maxContentWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (recent != null && !c.isOffline) ...[
                                  _WatchCard(
                                    subtitle: l10n.homeWatchLast
                                        .replaceAll('{when}', lastSeen(l10n, recent.joinedAt, DateTime.now())),
                                    title: recent.name == null || recent.name!.isEmpty
                                        ? l10n.homeWatchTitle
                                        : '${l10n.homeWatchTitle} · ${recent.name}',
                                    onTap: c.pairingBusy ? null : () => unawaited(_watchRecent(c, recent)),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _RoleTile(
                                          key: const Key('roleBaby'),
                                          icon: const BassinetIcon(size: 24, color: NinniColors.cream50),
                                          title: l10n.homeBabyTitle,
                                          body: l10n.homeBabyBody,
                                          onTap: c.pairingBusy ? null : () => c.selectRole(DeviceRole.BABY),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _RoleTile(
                                          key: const Key('roleParent'),
                                          icon: const Icon(Icons.qr_code_scanner_rounded,
                                              size: 24, color: NinniColors.primarySoftOnNight),
                                          title: l10n.homeNewTitle,
                                          body: l10n.homeNewBody,
                                          onTap: c.pairingBusy ? null : () => c.selectRole(DeviceRole.PARENT),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (MonitorController.offlineSupported) ...[
                                  const SizedBox(height: 14),
                                  _OfflineRow(value: c.isOffline, onChanged: (v) => c.setOfflineMode(v)),
                                ],
                                const Spacer(),
                                const SizedBox(height: 16),
                                const _TipCard(),
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
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: SectionCard(
        key: const Key('watchRecentButton'),
        color: NinniColors.primary,
        radius: NinniRadii.r22,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: NinniColors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.visibility_outlined, color: NinniColors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          NinniType.body.copyWith(fontWeight: FontWeight.w800, height: 1.3, color: NinniColors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          NinniType.numeric(NinniType.caption.copyWith(fontSize: 13, color: const Color(0xFFDCDCFF)))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: NinniColors.white),
          ],
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({super.key, required this.icon, required this.title, required this.body, required this.onTap});
  final Widget icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: SectionCard(
        radius: NinniRadii.r22,
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: NinniColors.night700, borderRadius: BorderRadius.circular(NinniRadii.r14)),
              child: Center(child: icon),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: NinniType.body.copyWith(fontWeight: FontWeight.w800, height: 1.3, color: NinniColors.onNight)),
            const SizedBox(height: 4),
            Text(body,
                style: NinniType.caption
                    .copyWith(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500, color: NinniColors.onNightMuted)),
          ],
        ),
      ),
    );
  }
}

/// 5–6 real tips, one at a time, changing every 8 s.
class _TipCard extends StatefulWidget {
  const _TipCard();

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = DateTime.now().minute % 6;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) setState(() => _index = (_index + 1) % 6);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tips = [
      l10n.tip1,
      l10n.tip2,
      l10n.tip3,
      l10n.tip4,
      l10n.tip5,
      defaultTargetPlatform == TargetPlatform.android ? l10n.tip6Android : l10n.tip6Ios,
    ];
    final reduce = MediaQuery.of(context).disableAnimations;
    return Container(
      key: const Key('tipCard'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NinniColors.tipBg,
        borderRadius: BorderRadius.circular(NinniRadii.r18),
        border: Border.all(color: NinniColors.nightLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, size: 22, color: NinniColors.lightAmber),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduce ? Duration.zero : NinniDurations.medium,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topLeft, children: [...previous, if (current != null) current]),
              child: Text.rich(
                key: ValueKey(_index),
                TextSpan(children: [
                  TextSpan(
                      text: '${l10n.tipLabel} ',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: NinniColors.onNight)),
                  TextSpan(text: tips[_index]),
                ]),
                style: NinniType.caption
                    .copyWith(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: NinniColors.onNightSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineRow extends StatelessWidget {
  const _OfflineRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('offlineRow'),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: NinniColors.night800,
        borderRadius: BorderRadius.circular(NinniRadii.r18),
        border: Border.all(color: NinniColors.nightCardLine),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: NinniColors.onNightMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l10n.noInternet} '),
                TextSpan(
                    text: l10n.offlineModeShort,
                    style: const TextStyle(color: NinniColors.onNight, fontWeight: FontWeight.w800)),
                TextSpan(text: ' ${l10n.androidOnly}'),
              ]),
              style: NinniType.bodySm.copyWith(fontSize: 14, color: NinniColors.onNightMuted),
            ),
          ),
          NinniSwitch(
            key: const Key('modeToggleButton'),
            value: value,
            onChanged: onChanged,
            semanticLabel: l10n.offlineModeShort,
          ),
        ],
      ),
    );
  }
}

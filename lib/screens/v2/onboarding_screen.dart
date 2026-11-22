import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/hybrid_notification_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';

/// First-run introduction (mockups Onboard1–3). Shown once; Settings →
/// "Show the intro again" brings it back.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const String prefsKey = 'onboardingDone';

  static Future<bool> isDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setDone(bool done) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, done);
    } catch (e) {
      debugPrint('Saving onboarding state failed: $e');
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(page, duration: NinniDurations.medium, curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    await OnboardingScreen.setDone(true);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return NightTheme(
      child: Scaffold(
        backgroundColor: NinniColors.night900,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: PageView(
            controller: _pages,
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              _WelcomePage(page: _page, onNext: () => _go(1)),
              _StepsPage(page: _page, onNext: () => _go(2), onSkip: () => _go(2)),
              _PermissionsPage(page: _page, onDone: _finish),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.pageOf.replaceAll('{n}', '${index + 1}').replaceAll('{total}', '3'),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              AnimatedContainer(
                duration: NinniDurations.medium,
                width: i == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index ? NinniColors.white : NinniColors.nightDot,
                  borderRadius: BorderRadius.circular(NinniRadii.pill),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.page, required this.onNext});
  final int page;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        const Positioned.fill(child: Starfield()),
        ScreenFrame(
          gap: 0,
          crossAxisAlignment: CrossAxisAlignment.center,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          items: [
            const SizedBox(height: 56),
            const BreathingMoon(size: 200),
            const SizedBox(height: 48),
            ScreenHeading(
              title: l10n.onboardTitle1,
              subtitle: l10n.onboardBody1,
              style: NinniType.display,
              textAlign: TextAlign.center,
            ),
          ],
          footer: [
            const Center(child: _PageDots(index: 0)),
            const SizedBox(height: 10),
            NinniButton(key: const Key('onboardingNext'), label: l10n.letsStart, onPressed: onNext),
          ],
        ),
      ],
    );
  }
}

class _StepsPage extends StatelessWidget {
  const _StepsPage({required this.page, required this.onNext, required this.onSkip});
  final int page;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      (l10n.onboardStep1Title, l10n.onboardStep1Body),
      (l10n.onboardStep2Title, l10n.onboardStep2Body),
      (l10n.onboardStep3Title, l10n.onboardStep3Body),
    ];
    return ScreenFrame(
      gap: 28,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      items: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(foregroundColor: NinniColors.onNightMuted),
            child: Text(l10n.skip),
          ),
        ),
        const _TwoPhones(),
        ScreenHeading(title: l10n.onboardTitle2),
        Column(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: NinniColors.night700,
                      borderRadius: BorderRadius.circular(NinniRadii.r12),
                    ),
                    child: Text('${i + 1}',
                        style: NinniType.numeric(NinniType.body
                            .copyWith(fontWeight: FontWeight.w800, color: NinniColors.onNight))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1,
                            style: NinniType.body.copyWith(fontWeight: FontWeight.w700, color: NinniColors.onNight)),
                        const SizedBox(height: 3),
                        Text(steps[i].$2,
                            style: NinniType.bodySm.copyWith(fontSize: 14, color: NinniColors.onNightMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
      footer: [
        const Center(child: _PageDots(index: 1)),
        const SizedBox(height: 10),
        NinniButton(key: const Key('onboardingNext'), label: l10n.continueLabel, onPressed: onNext),
      ],
    );
  }
}

/// Baby phone → parent phone with a flowing dashed line.
class _TwoPhones extends StatefulWidget {
  const _TwoPhones();

  @override
  State<_TwoPhones> createState() => _TwoPhonesState();
}

class _TwoPhonesState extends State<_TwoPhones> with SingleTickerProviderStateMixin {
  late final AnimationController _flow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _flow.stop();
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  Widget _phone({required bool night, IconData? icon, required String label}) {
    return Container(
      width: 96,
      height: 170,
      decoration: BoxDecoration(
        color: night ? NinniColors.night800 : NinniColors.cream50,
        borderRadius: BorderRadius.circular(NinniRadii.r22),
        border: night ? Border.all(color: NinniColors.nightLine, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon == null)
            const BassinetIcon(size: 36, color: NinniColors.cream50)
          else
            Icon(icon, size: 36, color: night ? NinniColors.cream50 : NinniColors.primary),
          const SizedBox(height: 10),
          Text(label,
              style: NinniType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: night ? NinniColors.onNightSoft : NinniColors.ink)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        height: 180,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _phone(night: true, label: l10n.babyShort),
              SizedBox(
                width: 90,
                height: 20,
                child: AnimatedBuilder(
                  animation: _flow,
                  builder: (context, _) => CustomPaint(painter: _DashPainter(_flow.value)),
                ),
              ),
              _phone(night: false, icon: Icons.visibility_outlined, label: l10n.youShort),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = NinniColors.apricot
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 6.0;
    const gap = 6.0;
    final y = size.height / 2;
    var x = 4 + (t * (dash + gap) * 2) % (dash + gap) - (dash + gap);
    while (x < size.width - 4) {
      final a = x.clamp(4.0, size.width - 4);
      final b = (x + dash).clamp(4.0, size.width - 4);
      if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.t != t;
}

enum _PermState { unknown, granted, denied, permanentlyDenied, later }

class _PermissionsPage extends StatefulWidget {
  const _PermissionsPage({required this.page, required this.onDone});
  final int page;
  final Future<void> Function() onDone;

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage> with WidgetsBindingObserver {
  final Map<String, _PermState> _state = {};
  bool get _android => Theme.of(context).platform == TargetPlatform.android;

  static List<Permission> _nearbyPermissions() => [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings: show the new state.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  static _PermState _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) return _PermState.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return _PermState.permanentlyDenied;
    if (s.isDenied) return _PermState.unknown;
    return _PermState.denied;
  }

  Future<void> _refresh() async {
    try {
      final camera = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final notif = await Permission.notification.status;
      final nearby = <PermissionStatus>[];
      for (final p in _nearbyPermissions()) {
        nearby.add(await p.status);
      }
      if (!mounted) return;
      setState(() {
        _state['camera'] = _map(camera);
        _state['mic'] = _map(mic);
        _state['notif'] = _map(notif);
        if (_state['nearby'] != _PermState.later) {
          _state['nearby'] =
              nearby.every((s) => s.isGranted) ? _PermState.granted : _PermState.unknown;
        }
      });
    } catch (e) {
      debugPrint('Permission status failed: $e');
    }
  }

  Future<void> _request(String id) async {
    final current = _state[id];
    if (current == _PermState.permanentlyDenied) {
      await openAppSettings();
      return;
    }
    try {
      switch (id) {
        case 'camera':
          await Permission.camera.request();
        case 'mic':
          await Permission.microphone.request();
        case 'notif':
          await HybridNotificationManager().requestPermission();
        case 'nearby':
          await _nearbyPermissions().request();
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
    await _refresh();
    if (_state[id] == _PermState.unknown) {
      // Asked and refused (the OS may not ask again).
      setState(() => _state[id] = _PermState.denied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <(String, IconData, String, String, bool)>[
      ('camera', Icons.videocam_outlined, l10n.permCamera, l10n.permCameraWhy, false),
      ('mic', Icons.mic_none_rounded, l10n.permMic, l10n.permMicWhy, false),
      ('notif', Icons.notifications_none_rounded, l10n.permNotifications, l10n.permNotificationsWhy, false),
      if (_android) ('nearby', Icons.wifi_rounded, l10n.permNearby, l10n.permNearbyWhy, true),
    ];
    return ScreenFrame(
      gap: 22,
      padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 40, NinniSpace.screen, 24),
      items: [
        ScreenHeading(title: l10n.onboardTitle3, subtitle: l10n.onboardBody3),
        Column(
          children: [
            for (final (id, icon, title, why, optional) in rows) ...[
              _PermissionRow(
                key: Key('perm_$id'),
                icon: icon,
                title: title,
                why: why,
                state: _state[id] ?? _PermState.unknown,
                optional: optional,
                onRequest: () => _request(id),
                onLater: () => setState(() => _state[id] = _PermState.later),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: NinniColors.infoBg,
            borderRadius: BorderRadius.circular(NinniRadii.r18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, color: NinniColors.infoIcon, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.privacyNote,
                    style: NinniType.caption.copyWith(
                        fontSize: 13, height: 1.5, fontWeight: FontWeight.w500, color: NinniColors.infoText)),
              ),
            ],
          ),
        ),
      ],
      footer: [
        const Center(child: _PageDots(index: 2)),
        const SizedBox(height: 10),
        NinniButton(key: const Key('onboardingDone'), label: l10n.imReady, onPressed: widget.onDone),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.why,
    required this.state,
    required this.optional,
    required this.onRequest,
    required this.onLater,
  });

  final IconData icon;
  final String title;
  final String why;
  final _PermState state;
  final bool optional;
  final VoidCallback onRequest;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget trailing;
    switch (state) {
      case _PermState.granted:
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 16, color: NinniColors.mintOnNight),
            const SizedBox(width: 6),
            Text(l10n.granted,
                style: NinniType.label.copyWith(letterSpacing: 0, color: NinniColors.mintOnNight)),
          ],
        );
      case _PermState.later:
        trailing = Text(l10n.later, style: NinniType.label.copyWith(letterSpacing: 0, color: NinniColors.onNightMuted));
      case _PermState.permanentlyDenied:
      case _PermState.denied:
        trailing = _SmallButton(label: l10n.openSettings, onTap: openAppSettingsSafe, filled: false);
      case _PermState.unknown:
        // Optional permissions get the quieter outlined button (DECISIONS A25).
        trailing = _SmallButton(label: l10n.allow, onTap: onRequest, filled: !optional);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NinniColors.night800,
        borderRadius: BorderRadius.circular(NinniRadii.r20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NinniColors.night700,
              borderRadius: BorderRadius.circular(NinniRadii.r14),
            ),
            child: Icon(icon, color: NinniColors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: NinniColors.onNight)),
                const SizedBox(height: 2),
                Text(why,
                    style: NinniType.caption.copyWith(
                        fontSize: 13, fontWeight: FontWeight.w500, color: NinniColors.onNightMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  static void openAppSettingsSafe() => unawaited(openAppSettings());
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.filled = true});
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: filled ? NinniColors.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NinniRadii.r12),
          side: filled ? BorderSide.none : const BorderSide(color: NinniColors.nightLine, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(NinniRadii.r12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: NinniSpace.touch, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(label,
                style: NinniType.label.copyWith(
                    letterSpacing: 0, color: filled ? NinniColors.white : NinniColors.onNightSoft)),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_keys.dart';
import '../../core/enums/device_role.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../theme/tokens.dart';
import 'alarm_views.dart';
import 'baby_screens.dart';
import 'onboarding_screen.dart';
import 'parent_screens.dart';
import 'role_select_screen.dart';

enum MonitorStage { roleSelect, babyPairing, babyLive, parentJoin, parentLive }

MonitorStage stageOf(MonitorController c) {
  switch (c.role) {
    case null:
      return MonitorStage.roleSelect;
    case DeviceRole.BABY:
      return c.isActive && c.parentEverConnected ? MonitorStage.babyLive : MonitorStage.babyPairing;
    case DeviceRole.PARENT:
      return c.isActive ? MonitorStage.parentLive : MonitorStage.parentJoin;
  }
}

/// First screen: the intro on the first launch, then the monitor.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    unawaited(OnboardingScreen.isDone().then((done) {
      if (mounted) setState(() => _onboardingDone = done);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final done = _onboardingDone;
    if (done == null) {
      // Same color as the native splash while the flag loads.
      return const ColoredBox(color: NinniColors.night900);
    }
    return PageTransitionSwitcher(
      duration: NinniDurations.medium,
      transitionBuilder: (child, primary, secondary) =>
          FadeThroughTransition(animation: primary, secondaryAnimation: secondary, child: child),
      child: done
          ? const MonitorShell(key: ValueKey('shell'))
          : OnboardingScreen(
              key: const ValueKey('onboarding'),
              onDone: () => setState(() => _onboardingDone = true),
            ),
    );
  }
}

/// Shows the screen for the current stage; stage changes cross-fade.
class MonitorShell extends StatelessWidget {
  const MonitorShell({super.key});

  @override
  Widget build(BuildContext context) {
    final stage = context.select<MonitorController, MonitorStage>(stageOf);
    final Widget page = switch (stage) {
      MonitorStage.roleSelect => const RoleSelectScreen(key: ValueKey('roleSelect')),
      MonitorStage.babyPairing => const BabyPairingScreen(key: ValueKey('babyPairing')),
      MonitorStage.babyLive => const BabyLiveScreen(key: ValueKey('babyLive')),
      MonitorStage.parentJoin => const ParentJoinScreen(key: ValueKey('parentJoin')),
      MonitorStage.parentLive => const ParentLiveScreen(key: ValueKey('parentLive')),
    };
    final reduce = MediaQuery.of(context).disableAnimations;
    return PageTransitionSwitcher(
      duration: reduce ? Duration.zero : NinniDurations.medium,
      transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
        animation: primary,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Colors.transparent,
        child: child,
      ),
      child: page,
    );
  }
}

/// Parent alarms above every route (MaterialApp.builder): the cry alarm and
/// the connection lost screen.
class MonitorOverlays extends StatelessWidget {
  const MonitorOverlays({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MonitorController>();
    final overlay = c.connectionLost
        ? const ConnectionLostView(key: ValueKey('lost'))
        : c.cryAlarmVisible
            ? CryAlertView(
                key: const ValueKey('cry'),
                onOpenVideo: () => rootNavigatorKey.currentState?.popUntil((r) => r.isFirst),
              )
            : null;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: NinniDurations.medium,
            child: overlay ?? const SizedBox.shrink(key: ValueKey('none')),
          ),
        ),
      ],
    );
  }
}

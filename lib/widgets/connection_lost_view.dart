import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Parent: full-screen "connection lost" alarm (V2 5.6, mockup
/// ConnectionLost). Always dark. Closes by itself when the connection is
/// back (the parent removes it).
class ConnectionLostView extends StatefulWidget {
  const ConnectionLostView({
    super.key,
    required this.lostSince,
    required this.onRetry,
    required this.onSilence,
    required this.alarmSilenced,
    required this.onDisconnect,
    this.lastBatteryLevel,
  });

  final DateTime lostSince;
  final VoidCallback onRetry;
  final VoidCallback onSilence;
  final bool alarmSilenced;
  final VoidCallback onDisconnect;
  final int? lastBatteryLevel;

  @override
  State<ConnectionLostView> createState() => _ConnectionLostViewState();
}

class _ConnectionLostViewState extends State<ConnectionLostView>
    with SingleTickerProviderStateMixin {
  late final Timer _ticker;
  late final AnimationController _spin;

  static const _night900 = Color(0xFF12142B);
  static const _night800 = Color(0xFF1C1F3D);
  static const _nightLine = Color(0xFF2E3260);
  static const _amber = Color(0xFFFFC46B);
  static const _onAmber = Color(0xFF2A1D06);
  static const _amberTile = Color(0xFF3A2C12);
  static const _muted = Color(0xFFC4C7E3);
  static const _list = Color(0xFFE1E3F5);
  static const _label = Color(0xFFA9ADCF);
  static const _primarySoftText = Color(0xFFB9B9FF);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
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
    _ticker.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = DateTime.now().difference(widget.lostSince).inSeconds.clamp(0, 359999);
    final battery = widget.lastBatteryLevel;
    return Material(
      key: const Key('connectionLostView'),
      color: _night900,
      child: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _amberTile,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(Icons.wifi_off_rounded, color: _amber, size: 44),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        l10n.connectionLostTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.connectionLostBody.replaceAll('{seconds}', '$seconds'),
                      style: const TextStyle(color: _muted, fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _night800,
                        borderRadius: BorderRadius.circular(18),
                      ),
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
                                color: _primarySoftText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.reconnecting,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.checkBabyPhone,
                      style: const TextStyle(
                          color: _label, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 10),
                    for (final item in [
                      if (battery != null) l10n.checkCharger.replaceAll('{level}', '$battery'),
                      l10n.checkWifi,
                      l10n.checkAppOpen,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('•  $item',
                            style: const TextStyle(color: _list, fontSize: 15, height: 1.4)),
                      ),
                    const Spacer(),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 60,
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('connectionLostRetry'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _amber,
                          foregroundColor: _onAmber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        onPressed: widget.onRetry,
                        child: Text(l10n.tryAgain),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: OutlinedButton(
                        key: const Key('connectionLostSilence'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _muted,
                          side: const BorderSide(color: _nightLine, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        onPressed: widget.alarmSilenced ? null : widget.onSilence,
                        child: Text(l10n.silenceAlarm),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Not in the mockup: a way out when the baby phone is
                    // gone for good (otherwise this screen cannot be left).
                    Center(
                      child: TextButton(
                        key: const Key('connectionLostDisconnect'),
                        style: TextButton.styleFrom(
                          foregroundColor: _label,
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: widget.onDisconnect,
                        child: Text(l10n.disconnect),
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

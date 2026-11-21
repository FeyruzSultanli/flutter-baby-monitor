import 'dart:async';

import 'package:flutter/material.dart';

import '../core/enums/connection_status.dart';
import '../l10n/app_localizations.dart';

/// Full-screen black layer for the baby device's night mode (D1-a).
///
/// The screen stays on (wakelock) at minimum brightness while the stream keeps
/// running underneath. All touches are absorbed; a double tap or the back
/// button leaves night mode. A short hint is shown on entry and after a single
/// tap, then fades out. A dim dot shows the connection state.
class NightModeOverlay extends StatefulWidget {
  const NightModeOverlay({
    super.key,
    required this.status,
    required this.onExit,
  });

  final ConnectionStatus status;
  final VoidCallback onExit;

  @override
  State<NightModeOverlay> createState() => _NightModeOverlayState();
}

class _NightModeOverlayState extends State<NightModeOverlay> {
  static const Duration _hintDuration = Duration(seconds: 4);

  bool _hintVisible = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHintHide();
  }

  void _scheduleHintHide() {
    _hintTimer?.cancel();
    _hintTimer = Timer(_hintDuration, () {
      if (mounted) setState(() => _hintVisible = false);
    });
  }

  void _showHint() {
    setState(() => _hintVisible = true);
    _scheduleHintHide();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  Color _dotColor() {
    switch (widget.status) {
      case ConnectionStatus.CONNECTED:
        return Colors.green;
      case ConnectionStatus.CONNECTING:
        return Colors.orange;
      case ConnectionStatus.FAILED:
        return Colors.red;
      case ConnectionStatus.DISCONNECTED:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      // Back leaves night mode instead of the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExit();
      },
      child: GestureDetector(
        key: const Key('nightModeOverlay'),
        behavior: HitTestBehavior.opaque,
        onTap: _showHint,
        onDoubleTap: widget.onExit,
        child: ColoredBox(
          color: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  right: 12,
                  child: Opacity(
                    opacity: 0.35,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _dotColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedOpacity(
                    opacity: _hintVisible ? 0.6 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dark_mode, color: Colors.white54, size: 32),
                          const SizedBox(height: 12),
                          Text(
                            l10n.nightModeExitHint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.nightModeKeepAppOpen,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
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

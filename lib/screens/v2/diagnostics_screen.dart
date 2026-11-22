import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';

/// Hidden diagnostics screen (V2.1 §1, §2): Settings → tap the version row
/// 5 times. Shows the live cry detection values, the last Firestore write,
/// audio bytes in/out, the talk channel and the native audio route, for
/// finding real-device bugs together with the CRYDIAG/TALKDIAG log lines.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Timer? _routeTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshRoute());
    _routeTimer = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_refreshRoute()));
  }

  Future<void> _refreshRoute() async {
    final c = context.read<MonitorController>();
    final route = await c.audioRoute();
    if (!mounted) return;
    c.diag.value.route = route;
    c.diag.changed();
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.read<MonitorController>();
    final p = NinniPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c.diag,
          builder: (context, _) {
            final d = c.diag.value;
            return ListView(
              key: const Key('diagList'),
              padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 16, NinniSpace.screen, 32),
              children: [
                TopBar(
                  backLabel: l10n.back,
                  title: l10n.diagTitle,
                  trailing: NinniIconButton(
                    key: const Key('diagCopy'),
                    icon: Icons.copy_rounded,
                    tooltip: l10n.diagCopy,
                    onPressed: () {
                      unawaited(Clipboard.setData(ClipboardData(text: '${d.cryLine()}\n${d.talkLine()}\n${d.asText()}')));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.diagCopied)));
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.diagHint, style: NinniType.caption.copyWith(color: p.textMuted, fontSize: 13)),
                const SizedBox(height: 16),
                SectionCard(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    '${d.cryLine()}\n\n${d.talkLine()}',
                    style: NinniType.numeric(NinniType.caption.copyWith(color: p.text, fontFamily: 'monospace', fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    children: [
                      for (final (k, v) in d.rows())
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(k, style: NinniType.caption.copyWith(color: p.textMuted)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: Text(
                                  v,
                                  textAlign: TextAlign.end,
                                  style: NinniType.numeric(NinniType.caption.copyWith(color: p.text, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

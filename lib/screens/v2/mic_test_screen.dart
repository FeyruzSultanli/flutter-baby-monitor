import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/audio/pcm_microphone.dart';
import '../../core/enums/device_role.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';

/// "Test the microphone" (V2.1 §1): live dB bar with the alarm threshold,
/// so parents can set the threshold for their own room.
///
/// - Baby phone broadcasting: shows the level the cry detection really uses
///   (WebRTC during a call, the standby meter otherwise); no second
///   microphone reader is opened.
/// - Parent phone in a session: shows the level received from the baby.
/// - Otherwise: opens this phone's microphone just for the test.
class MicTestScreen extends StatefulWidget {
  const MicTestScreen({super.key, this.useOwnMicrophone});

  /// Tests: force (false) or skip the own microphone decision.
  final bool? useOwnMicrophone;

  @override
  State<MicTestScreen> createState() => _MicTestScreenState();
}

class _MicTestScreenState extends State<MicTestScreen> {
  final ValueNotifier<double> _ownLevel = ValueNotifier<double>(0);
  final PcmMicrophone _mic = PcmMicrophone();
  StreamSubscription<Uint8List>? _sub;
  Timer? _tick;
  final PeakDbTracker _peak = PeakDbTracker();
  bool _ownMic = false;
  bool _micFailed = false;
  double _max = 0;
  DateTime _maxAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final c = context.read<MonitorController>();
    _ownMic = widget.useOwnMicrophone ?? (!c.isActive && !c.isDemo);
    if (_ownMic) unawaited(_startMic());
  }

  Future<void> _startMic() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) throw StateError('permission ${status.name}');
      final stream = await _mic.start();
      if (!mounted) {
        await _mic.stop();
        return;
      }
      _sub = stream.listen(_peak.addChunk, onError: (Object e) {
        debugPrint('Mic test error: $e');
        if (mounted) setState(() => _micFailed = true);
      });
      _tick = Timer.periodic(const Duration(milliseconds: 150), (_) {
        final db = _peak.take();
        if (db != null) _ownLevel.value = db;
      });
    } catch (e) {
      debugPrint('Mic test unavailable: $e');
      if (mounted) setState(() => _micFailed = true);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_sub?.cancel());
    if (_ownMic) unawaited(_mic.stop().catchError((Object e) => debugPrint('Mic test stop: $e')));
    _ownLevel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final p = NinniPalette.of(context);
    final ValueListenable<double> level = _ownMic ? _ownLevel : c.level;
    final source =
        _ownMic ? l10n.micTestOwn : (c.role == DeviceRole.PARENT ? l10n.micTestFromBaby : l10n.micTestInCall);
    return Scaffold(
      body: ThemedSky(
          child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 16, NinniSpace.screen, 32),
          children: [
            TopBar(backLabel: l10n.back, title: l10n.micTestTitle),
            const SizedBox(height: 16),
            SectionCard(
              padding: const EdgeInsets.all(18),
              child: ValueListenableBuilder<double>(
                valueListenable: level,
                builder: (context, db, _) {
                  final now = DateTime.now();
                  if (db >= _max || now.difference(_maxAt) > const Duration(seconds: 10)) {
                    _max = db;
                    _maxAt = now;
                  }
                  final over = db >= c.noiseThreshold;
                  return Semantics(
                    liveRegion: true,
                    label: '${db.round()} dB, ${over ? l10n.micTestOver : l10n.micTestUnder}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(source, style: NinniType.caption.copyWith(color: p.textMuted)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _micFailed ? '--' : '${db.round()}',
                              key: const Key('micTestDb'),
                              style: NinniType.numeric(NinniType.display.copyWith(color: p.text, fontSize: 48)),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('dB', style: NinniType.label.copyWith(color: p.textMuted)),
                            ),
                            const Spacer(),
                            StatusPill(
                              label: over ? l10n.micTestOver : l10n.micTestUnder,
                              tone: over ? PillTone.apricot : PillTone.mint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LevelMeter(db: _micFailed ? 0 : db, thresholdDb: c.noiseThreshold),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text('${l10n.micTestPeak}: ${math.max(_max, db).round()} dB',
                                  style: NinniType.numeric(NinniType.caption.copyWith(color: p.textMuted))),
                            ),
                            Text('${l10n.thresholdShort} ${c.noiseThreshold.round()}',
                                style: NinniType.numeric(
                                    NinniType.caption.copyWith(color: p.apricotText, fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_micFailed) ...[
              const SizedBox(height: 12),
              Text(l10n.micTestNoMic, style: NinniType.bodySm.copyWith(color: p.apricotText)),
            ],
            const SizedBox(height: 16),
            SectionCard(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.sensitivity,
                            style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                      ),
                      Text('${c.noiseThreshold.round()} dB',
                          style: NinniType.numeric(
                              NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.accentText))),
                    ],
                  ),
                  Slider(
                    key: const Key('micTestThreshold'),
                    min: 40,
                    max: 80,
                    divisions: 40,
                    value: c.noiseThreshold.clamp(40, 80),
                    label: '${c.noiseThreshold.round()} dB',
                    semanticFormatterCallback: (v) => '${v.round()} dB',
                    onChanged: c.setNoiseThreshold,
                  ),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.moreSensitive, style: NinniType.caption.copyWith(color: p.textMuted))),
                      Text(l10n.lessSensitive, style: NinniType.caption.copyWith(color: p.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.micTestHint, style: NinniType.bodySm.copyWith(color: p.textSoft)),
          ],
        ),
      )),
    );
  }
}

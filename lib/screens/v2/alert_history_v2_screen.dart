import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/alert_history_service.dart';
import '../../core/alerts/night_summary.dart';
import '../../l10n/app_localizations.dart';
import '../../models/alert_model.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';

/// Alert history with the nightly summary (mockup AlertHistory, V2 5.9).
/// Follows the system theme.
class AlertHistoryV2Screen extends StatefulWidget {
  const AlertHistoryV2Screen({super.key, this.service});

  /// For tests and screenshots; the app uses the shared history.
  final AlertHistoryService? service;

  @override
  State<AlertHistoryV2Screen> createState() => _AlertHistoryV2ScreenState();
}

class _AlertHistoryV2ScreenState extends State<AlertHistoryV2Screen> {
  HistoryRange _range = HistoryRange.tonight;
  List<AlertModel>? _alerts;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final alerts = await (widget.service ?? AlertHistoryService()).getAlerts();
    if (mounted) setState(() => _alerts = List.of(alerts));
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearHistoryTitle),
        content: Text(l10n.clearHistoryBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            key: const Key('confirmClearHistory'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await (widget.service ?? AlertHistoryService()).clearHistory();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = NinniPalette.of(context);
    final alerts = _alerts;
    final summary = alerts == null ? null : NightSummary.of(alerts, windowFor(_range, DateTime.now()));
    final rangeLabel = switch (_range) {
      HistoryRange.tonight => l10n.tonight,
      HistoryRange.yesterday => l10n.yesterday,
      HistoryRange.week => l10n.last7Days,
    };

    return Scaffold(
      body: ThemedSky(
          child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NinniSpace.maxContentWidth),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 16, NinniSpace.screen, 0),
                  sliver: SliverList.list(children: [
                    TopBar(
                      backLabel: l10n.back,
                      title: l10n.alertHistory,
                      trailing: (alerts?.isNotEmpty ?? false)
                          ? NinniIconButton(
                              key: const Key('clearHistoryButton'),
                              icon: Icons.delete_outline_rounded,
                              tooltip: l10n.clear,
                              onPressed: _clear,
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    _SummaryCard(title: rangeLabel, summary: summary),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (r, label) in [
                            (HistoryRange.tonight, l10n.tonight),
                            (HistoryRange.yesterday, l10n.yesterday),
                            (HistoryRange.week, l10n.last7Days),
                          ]) ...[
                            NinniChip(label: label, selected: _range == r, onTap: () => setState(() => _range = r)),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
                if (summary == null)
                  const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
                else if (summary.events.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: NinniSpace.screen, vertical: 24),
                      child: Column(
                        children: [
                          // V2.1 §4: a small moon instead of an empty list.
                          const SizedBox(
                            width: 96,
                            height: 96,
                            child: BreathingMoon(size: 96),
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.calmNight,
                              key: const Key('historyEmpty'),
                              textAlign: TextAlign.center,
                              style: NinniType.title.copyWith(color: p.text)),
                          const SizedBox(height: 4),
                          Text(l10n.calmNightBody,
                              textAlign: TextAlign.center, style: NinniType.bodySm.copyWith(color: p.textMuted)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 0, NinniSpace.screen, 24),
                    sliver: SliverList.separated(
                      itemCount: summary.events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _EventTile(alert: summary.events[i], showDate: _range == HistoryRange.week),
                    ),
                  ),
              ],
            ),
          ),
        ),
      )),
    );
  }
}

String formatDurationShort(AppLocalizations l10n, Duration d) {
  if (d.inHours >= 1) {
    final m = d.inMinutes % 60;
    return m == 0
        ? l10n.hoursShort.replaceAll('{h}', '${d.inHours}')
        : l10n.hoursMinutesShort.replaceAll('{h}', '${d.inHours}').replaceAll('{m}', '$m');
  }
  if (d.inMinutes >= 1) {
    final s = d.inSeconds % 60;
    return s == 0 || d.inMinutes >= 10
        ? l10n.minutesShort.replaceAll('{m}', '${d.inMinutes}')
        : l10n.minutesSecondsShort.replaceAll('{m}', '${d.inMinutes}').replaceAll('{s}', '$s');
  }
  return l10n.secondsShort.replaceAll('{s}', '${d.inSeconds}');
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.summary});
  final String title;
  final NightSummary? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = summary;
    Widget stat(String value, String label) => Expanded(
          child: Semantics(
            label: '$value $label',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: int.tryParse(value) != null
                      ? CountText(int.parse(value),
                          style: NinniType.h1.copyWith(fontSize: 28, color: NinniColors.onNight))
                      : Text(value,
                          style: NinniType.numeric(NinniType.h1.copyWith(fontSize: 28, color: NinniColors.onNight))),
                ),
                const SizedBox(height: 2),
                Text(label,
                    style: NinniType.caption
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: NinniColors.onNightSoft)),
              ],
            ),
          ),
        );
    return Container(
      key: const Key('nightSummary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NinniColors.night900,
        borderRadius: BorderRadius.circular(NinniRadii.r24),
        border: Border.all(color: NinniColors.nightCardLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: NinniType.label.copyWith(color: NinniColors.onNightMuted)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat(s == null ? '–' : '${s.alarms}', l10n.alarmsLabel),
              const SizedBox(width: 10),
              stat(s == null ? '–' : formatDurationShort(l10n, s.totalCry), l10n.totalCryLabel),
              const SizedBox(width: 10),
              stat(s == null ? '–' : formatDurationShort(l10n, s.longestQuiet), l10n.longestQuietLabel),
            ],
          ),
          const SizedBox(height: 18),
          Text(l10n.byHour, style: NinniType.caption.copyWith(color: NinniColors.onNightMuted)),
          const SizedBox(height: 10),
          Semantics(
            label: l10n.byHour,
            child: HourBars(
              key: const Key('hourBars'),
              counts: s == null ? List<int>.filled(10, 0) : hourlyCounts(s.events),
              labels: const ['21', '', '23', '', '01', '', '03', '', '05', ''],
              height: 56,
              barColor: NinniColors.apricot,
              emptyColor: NinniColors.night700,
              labelStyle: NinniType.numeric(NinniType.caption.copyWith(fontSize: 11, color: NinniColors.onNightMuted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.alert, required this.showDate});
  final AlertModel alert;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = NinniPalette.of(context);
    final d = alert.duration;
    final short = d != null && d < shortNoiseLimit;
    final title = short ? l10n.shortNoise : l10n.cry;
    final detail = [
      if (alert.decibel != null) '${alert.decibel!.round()} dB',
      if (d != null) formatDurationShort(l10n, d),
    ].join(' · ');
    final time = showDate
        ? DateFormat('d MMM HH:mm', l10n.locale.languageCode).format(alert.timestamp)
        : DateFormat.Hm().format(alert.timestamp);
    return SectionCard(
      radius: NinniRadii.r20,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: short ? p.primarySoftBg : (p.isNight ? NinniColors.apricotLineOnNight : NinniColors.apricotSoft),
              borderRadius: BorderRadius.circular(NinniRadii.r14),
            ),
            child: Icon(
              short ? Icons.show_chart_rounded : Icons.volume_up_rounded,
              size: 22,
              color: short ? p.accentText : p.apricotText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail,
                      style: NinniType.numeric(
                          NinniType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: p.textMuted))),
                ],
              ],
            ),
          ),
          Text(time, style: NinniType.numeric(NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text))),
        ],
      ),
    );
  }
}

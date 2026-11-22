import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums/device_role.dart';
import '../../core/pairing/room_code.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/video_settings.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';
import '../video_gallery_screen.dart';
import 'diagnostics_screen.dart';
import 'mic_test_screen.dart';
import 'onboarding_screen.dart';

/// Settings (mockup Settings). Follows the system theme.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<(String, String)> languages = [
    ('tr', 'Türkçe'),
    ('en', 'English'),
    ('az', 'Azərbaycanca'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final theme = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    final p = NinniPalette.of(context);
    final isParent = c.role == DeviceRole.PARENT;
    final quality = c.videoSettings.quality;

    final languageName =
        languages.firstWhere((l) => l.$1 == language.locale.languageCode, orElse: () => languages.first).$2;
    final themeName = switch (theme.mode) {
      ThemeMode.system => l10n.themeAuto,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };

    Widget card(List<Widget> rows) => SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: rows),
        );

    return Scaffold(
      body: ThemedSky(
          child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NinniSpace.maxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 16, NinniSpace.screen, 32),
              children: [
                TopBar(backLabel: l10n.back, title: l10n.settings),
                const SizedBox(height: 18),
                if (c.role != null) ...[
                  _RoomCard(controller: c),
                  const SizedBox(height: 18),
                ],
                SectionLabel(l10n.sectionAlarm),
                const SizedBox(height: 8),
                card([
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                                key: const Key('thresholdValue'),
                                style: NinniType.numeric(NinniType.bodySm
                                    .copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: p.accentText))),
                          ],
                        ),
                        Slider(
                          key: const Key('thresholdSlider'),
                          min: 40,
                          max: 80,
                          divisions: 40,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          value: c.noiseThreshold.clamp(40, 80),
                          label: '${c.noiseThreshold.round()} dB',
                          semanticFormatterCallback: (v) => '${v.round()} dB',
                          onChanged: c.setNoiseThreshold,
                        ),
                        Row(
                          children: [
                            Expanded(
                                child: Text(l10n.moreSensitive, style: NinniType.caption.copyWith(color: p.textMuted))),
                            Text(l10n.lessSensitive, style: NinniType.caption.copyWith(color: p.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SettingsRow(
                    key: const Key('micTestRow'),
                    leading: const SettingsIcon(Icons.mic_none_rounded, color: NinniColors.apricot),
                    title: l10n.micTestTitle,
                    subtitle: l10n.micTestSubtitle,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const MicTestScreen()),
                    ),
                  ),
                  SettingsRow(
                      leading: const SettingsIcon(Icons.timer_outlined, color: NinniColors.amber),
                      title: l10n.alarmDuration,
                      subtitle: l10n.alarmDurationSub,
                      value: l10n.secondsShort.replaceAll('{s}', '2')),
                  SettingsRow(
                      leading: const SettingsIcon(Icons.notifications_none_rounded, color: NinniColors.primaryGlow),
                      title: l10n.notifyInterval,
                      subtitle: l10n.notifyIntervalSub,
                      value: l10n.perMinute,
                      divider: false),
                ]),
                const SizedBox(height: 18),
                SectionLabel(l10n.sectionVideo),
                const SizedBox(height: 8),
                card([
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.quality,
                            style: NinniType.bodySm.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                        const SizedBox(height: 12),
                        SegmentedControl<String>(
                          key: const Key('qualityControl'),
                          options: [
                            ('LOW', l10n.qualitySaver),
                            ('MEDIUM', l10n.qualityBalanced),
                            ('HIGH', l10n.qualitySharp),
                          ],
                          selected: quality,
                          onChanged: (q) => c.setVideoSettings(VideoSettings(fps: c.videoSettings.fps, quality: q)),
                        ),
                      ],
                    ),
                  ),
                  SettingsRow(
                    leading: const SettingsIcon(Icons.dark_mode_outlined, color: NinniColors.lightPurple),
                    title: l10n.autoNightMode,
                    subtitle: l10n.autoNightModeShort,
                    divider: isParent,
                    trailing: NinniSwitch(
                      key: const Key('autoNightSwitch'),
                      value: c.autoNightMode,
                      onChanged: c.setAutoNightMode,
                      semanticLabel: l10n.autoNightMode,
                    ),
                  ),
                  if (isParent)
                    SettingsRow(
                      leading: const SettingsIcon(Icons.headphones_rounded, color: NinniColors.mint),
                      title: l10n.backgroundListening,
                      subtitle: l10n.backgroundListeningSubtitle,
                      divider: false,
                      trailing: NinniSwitch(
                        key: const Key('backgroundListeningSwitch'),
                        value: c.backgroundListening,
                        onChanged: c.setBackgroundListening,
                        semanticLabel: l10n.backgroundListening,
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                SectionLabel(l10n.sectionApp),
                const SizedBox(height: 8),
                card([
                  SettingsRow(
                    key: const Key('languageRow'),
                    leading: const SettingsIcon(Icons.translate_rounded, color: NinniColors.lightBlue),
                    title: l10n.language,
                    value: languageName,
                    showChevron: true,
                    onTap: () => _pick<String>(
                      context,
                      title: l10n.language,
                      options: [for (final (code, name) in languages) (code, name)],
                      selected: language.locale.languageCode,
                      onSelected: (code) => language.setLocale(Locale(code)),
                    ),
                  ),
                  SettingsRow(
                    key: const Key('themeRow'),
                    leading: const SettingsIcon(Icons.palette_outlined, color: NinniColors.lightPink),
                    title: l10n.theme,
                    value: themeName,
                    showChevron: true,
                    onTap: () => _pick<ThemeMode>(
                      context,
                      title: l10n.theme,
                      options: [
                        (ThemeMode.system, l10n.themeAuto),
                        (ThemeMode.light, l10n.themeLight),
                        (ThemeMode.dark, l10n.themeDark),
                      ],
                      selected: theme.mode,
                      onSelected: theme.setThemeMode,
                    ),
                  ),
                  SettingsRow(
                    key: const Key('galleryButton'),
                    leading: const SettingsIcon(Icons.video_library_outlined, color: NinniColors.apricot),
                    title: l10n.recordings,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const VideoGalleryScreen()),
                    ),
                  ),
                  SettingsRow(
                    key: const Key('replayIntroRow'),
                    leading: const SettingsIcon(Icons.replay_rounded, color: NinniColors.mint),
                    title: l10n.replayIntro,
                    divider: false,
                    onTap: () async {
                      await OnboardingScreen.setDone(false);
                      if (!context.mounted) return;
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (ctx) => OnboardingScreen(onDone: () => Navigator.of(ctx).pop()),
                      ));
                    },
                  ),
                ]),
                const SizedBox(height: 18),
                SectionLabel(l10n.sectionAbout),
                const SizedBox(height: 8),
                card([
                  const _VersionRow(),
                  SettingsRow(
                    leading: const SettingsIcon(Icons.description_outlined, color: NinniColors.onNightMuted),
                    title: l10n.licenses,
                    divider: false,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Ninni',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Padding(padding: EdgeInsets.all(12), child: AppIcon(size: 56)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(l10n.privacyNote,
                    textAlign: TextAlign.center, style: NinniType.caption.copyWith(color: p.textMuted)),
              ],
            ),
          ),
        ),
      )),
    );
  }

  static Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required List<(T, String)> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    final l10n = AppLocalizations.of(context);
    return showNinniSheet<void>(context, (ctx) {
      final p = NinniPalette.of(ctx);
      return BottomSheetFrame(
        title: title,
        closeLabel: l10n.close,
        child: Column(
          children: [
            for (final (value, label) in options)
              Semantics(
                selected: value == selected,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  key: Key('option_$label'),
                  minTileHeight: 52,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(label, style: NinniType.body.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                  trailing: value == selected ? const Icon(Icons.check_rounded, color: NinniColors.primary) : null,
                  onTap: () {
                    onSelected(value);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// "Ninni 1.0.0" row; 5 taps within 3 s open the hidden diagnostics screen
/// (V2.1 §1).
class _VersionRow extends StatefulWidget {
  const _VersionRow();

  static const String version = '1.0.0';

  @override
  State<_VersionRow> createState() => _VersionRowState();
}

class _VersionRowState extends State<_VersionRow> {
  int _taps = 0;
  DateTime? _first;

  void _onTap() {
    final now = DateTime.now();
    if (_first == null || now.difference(_first!) > const Duration(seconds: 3)) {
      _first = now;
      _taps = 0;
    }
    if (++_taps >= 5) {
      _taps = 0;
      _first = null;
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsRow(
      key: const Key('versionRow'),
      leading: const SettingsIcon(Icons.info_outline_rounded, color: NinniColors.primaryGlow),
      title: 'Ninni',
      subtitle: l10n.appTagline,
      value: '${l10n.version} ${_VersionRow.version}',
      showChevron: false,
      onTap: _onTap,
    );
  }
}

/// Room card at the top of the settings (V2.1 §4): name, code and the
/// connected device. Always dark, like the summary cards.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = controller;
    final code = c.roomCode;
    final device = c.role == DeviceRole.BABY ? l10n.deviceParentPhone : l10n.deviceBabyPhone;
    return Container(
      key: const Key('settingsRoomCard'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NinniColors.night900,
        borderRadius: BorderRadius.circular(NinniRadii.r22),
        border: Border.all(color: NinniColors.nightCardLine),
      ),
      child: Row(
        children: [
          const AppIcon(size: 44, painter: AppIconPainter(background: NinniColors.night700)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.roomName ?? l10n.defaultRoomName, style: NinniType.title.copyWith(color: NinniColors.onNight)),
                if (code != null) ...[
                  const SizedBox(height: 2),
                  Text(RoomCode.format(code),
                      style:
                          NinniType.numeric(NinniType.caption.copyWith(fontSize: 13, color: NinniColors.onNightSoft))),
                ],
                const SizedBox(height: 4),
                Text(
                  c.isConnected ? l10n.roomCardDevices.replaceAll('{device}', device) : l10n.roomCardNone,
                  style: NinniType.caption
                      .copyWith(color: c.isConnected ? NinniColors.mintOnNight : NinniColors.onNightMuted),
                ),
              ],
            ),
          ),
          if (c.isConnected) const PulseDot(size: 10, color: NinniColors.mint),
        ],
      ),
    );
  }
}

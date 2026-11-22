import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/video_settings.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.noiseThreshold,
    required this.keepScreenOn,
    required this.onNoiseThresholdChanged,
    required this.onKeepScreenOnChanged,
    this.isOfflineMode = false,
    this.onOfflineModeChanged,
    this.videoSettings,
    this.onVideoSettingsChanged,
    this.autoNightMode = false,
    this.onAutoNightModeChanged,
    this.backgroundListening = true,
    this.onBackgroundListeningChanged,
  });

  final double noiseThreshold;
  final bool keepScreenOn;
  final ValueChanged<double> onNoiseThresholdChanged;
  final ValueChanged<bool> onKeepScreenOnChanged;
  final bool isOfflineMode;
  final ValueChanged<bool>? onOfflineModeChanged;
  final VideoSettings? videoSettings;
  final ValueChanged<VideoSettings>? onVideoSettingsChanged;
  final bool autoNightMode;
  final ValueChanged<bool>? onAutoNightModeChanged;
  final bool backgroundListening;
  final ValueChanged<bool>? onBackgroundListeningChanged;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late double _sliderValue;
  late bool _localKeepScreenOn;
  late bool _localAutoNightMode;
  late bool _localBackgroundListening;
  late VideoSettings _localVideoSettings;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.noiseThreshold;
    _localKeepScreenOn = widget.keepScreenOn;
    _localAutoNightMode = widget.autoNightMode;
    _localBackgroundListening = widget.backgroundListening;
    _localVideoSettings = widget.videoSettings ?? const VideoSettings();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settings,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                )),
            const SizedBox(height: 16),

            // -------------------------- TEMA KISMI --------------------------
            Text(
              l10n.theme,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            DropdownButton<ThemeMode>(
              isExpanded: true,
              value: themeProvider.mode,
              items: [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text(l10n.systemDefault),
                ),
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(l10n.lightMode),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(l10n.darkMode),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                themeProvider.setThemeMode(v);
              },
            ),

            // -------------------------- DİL KISMI --------------------------
            const SizedBox(height: 20),
            Text(
              l10n.language,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            DropdownButton<Locale>(
              isExpanded: true,
              value: languageProvider.locale,
              items: const [
                DropdownMenuItem(
                  value: Locale('tr'),
                  child: Text('Türkçe'),
                ),
                DropdownMenuItem(
                  value: Locale('en'),
                  child: Text('English'),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                languageProvider.setLocale(v);
              },
            ),

            const SizedBox(height: 20),
            if (widget.onOfflineModeChanged != null) ...[
              // Offline mode uses Nearby Connections, which exists only on
              // Android: on other platforms explain instead of offering it.
              if (defaultTargetPlatform == TargetPlatform.android)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.offlineMode),
                  subtitle: Text(l10n.offlineModeSubtitle),
                  value: widget.isOfflineMode,
                  onChanged: widget.onOfflineModeChanged,
                )
              else
                ListTile(
                  key: const Key('offlineUnavailableTile'),
                  contentPadding: EdgeInsets.zero,
                  enabled: false,
                  leading: const Icon(Icons.wifi_off_rounded),
                  title: Text(l10n.offlineMode),
                  subtitle: Text(l10n.offlineAndroidOnly),
                ),
              const Divider(),
            ],

            // -------------------------- VIDEO AYARLARI --------------------------
            if (widget.onVideoSettingsChanged != null) ...[
              Text(
                l10n.videoSettings,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.frameRate),
                        DropdownButton<int>(
                          isExpanded: true,
                          value: _localVideoSettings.fps,
                          items: [
                            DropdownMenuItem(value: 15, child: Text('15 FPS (${l10n.low})')),
                            DropdownMenuItem(value: 30, child: Text('30 FPS (${l10n.medium})')),
                            DropdownMenuItem(value: 60, child: Text('60 FPS (${l10n.high})')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _localVideoSettings = _localVideoSettings.copyWith(fps: v);
                            });
                            widget.onVideoSettingsChanged!(_localVideoSettings);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.resolution),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: _localVideoSettings.quality,
                          items: [
                            DropdownMenuItem(value: 'LOW', child: Text(l10n.low)),
                            DropdownMenuItem(value: 'MEDIUM', child: Text(l10n.medium)),
                            DropdownMenuItem(value: 'HIGH', child: Text(l10n.high)),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _localVideoSettings = _localVideoSettings.copyWith(quality: v);
                            });
                            widget.onVideoSettingsChanged!(_localVideoSettings);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(),
            ],

            // -------------------------- SES EŞİĞİ --------------------------
            Text(
              l10n.noiseThreshold,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('40 dB'),
                Text('${_sliderValue.toStringAsFixed(0)} dB'),
                const Text('80 dB'),
              ],
            ),
            Slider(
              min: 40,
              max: 80,
              divisions: 40,
              value: _sliderValue,
              label: '${_sliderValue.toStringAsFixed(0)} dB',
              onChanged: (v) {
                setState(() => _sliderValue = v);
                widget.onNoiseThresholdChanged(v);
              },
            ),

            // -------------------------- EKRAN AÇIK TUTMA --------------------------
            SwitchListTile(
              title: Text(l10n.keepScreenOn),
              subtitle: Text(l10n.keepScreenOnSubtitle),
              value: _localKeepScreenOn,
              onChanged: (v) {
                setState(() => _localKeepScreenOn = v);
                widget.onKeepScreenOnChanged(v);
              },
            ),

            // -------------------------- GECE MODU --------------------------
            if (widget.onAutoNightModeChanged != null)
              SwitchListTile(
                title: Text(l10n.autoNightMode),
                subtitle: Text(l10n.autoNightModeSubtitle),
                value: _localAutoNightMode,
                onChanged: (v) {
                  setState(() => _localAutoNightMode = v);
                  widget.onAutoNightModeChanged!(v);
                },
              ),

            // -------------------------- ARKA PLANDA DİNLEME --------------------------
            if (widget.onBackgroundListeningChanged != null)
              SwitchListTile(
                key: const Key('backgroundListeningSwitch'),
                title: Text(l10n.backgroundListening),
                subtitle: Text(l10n.backgroundListeningSubtitle),
                value: _localBackgroundListening,
                onChanged: (v) {
                  setState(() => _localBackgroundListening = v);
                  widget.onBackgroundListeningChanged!(v);
                },
              ),
          ],
        ),
      ),
    );
  }
}
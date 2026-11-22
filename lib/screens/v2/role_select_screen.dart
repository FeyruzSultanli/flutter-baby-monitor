import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/enums/device_role.dart';
import '../../features/monitor/monitor_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';
import 'settings_screen.dart';

/// "Where will this phone be?" (mockup RoleSelect). Follows the system
/// theme (light/dark menu screen).
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.watch<MonitorController>();
    final p = NinniPalette.of(context);
    return Scaffold(
      body: ScreenFrame(
        gap: 28,
        padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 24, NinniSpace.screen, 24),
        items: [
          Row(
            children: [
              NinniWordmark(color: p.text),
              const Spacer(),
              NinniIconButton(
                key: const Key('settingsButton'),
                icon: Icons.settings_outlined,
                tooltip: l10n.settings,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          ScreenHeading(
            title: l10n.roleTitle,
            subtitle: l10n.roleSubtitle,
            style: NinniType.h1.copyWith(fontSize: 32, letterSpacing: -0.9),
          ),
          _RoleCard(
            key: const Key('roleBaby'),
            night: true,
            iconWidget: const BassinetIcon(size: 30, color: NinniColors.cream50),
            title: l10n.roleBabyTitle,
            body: l10n.roleBabyBody,
            onTap: c.pairingBusy ? null : () => c.selectRole(DeviceRole.BABY),
          ),
          _RoleCard(
            key: const Key('roleParent'),
            night: false,
            icon: Icons.phonelink_ring_outlined,
            title: l10n.roleParentTitle,
            body: l10n.roleParentBody,
            onTap: c.pairingBusy ? null : () => c.selectRole(DeviceRole.PARENT),
          ),
        ],
        footer: [
          if (MonitorController.offlineSupported)
            _OfflineRow(
              value: c.isOffline,
              onChanged: (v) => c.setOfflineMode(v),
            ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    super.key,
    required this.night,
    this.icon,
    this.iconWidget,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool night;
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    // The baby card is always night; the parent card follows the theme.
    final bg = night ? NinniColors.night900 : p.surface;
    final fg = night ? NinniColors.onNight : p.text;
    final muted = night ? NinniColors.onNightSoft : p.textMuted;
    final tileBg = night ? NinniColors.night700 : p.primarySoftBg;
    final tileFg = night ? NinniColors.cream50 : NinniColors.primary;
    final darkOnDark = night && p.isNight;
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: SectionCard(
        radius: NinniRadii.r28,
        padding: const EdgeInsets.all(22),
        color: darkOnDark ? NinniColors.night800 : bg,
        border: !night,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(NinniRadii.r18)),
                  child: Center(child: iconWidget ?? Icon(icon, size: 30, color: tileFg)),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded,
                    color: night ? NinniColors.onNightMuted : const Color(0xFF8A8EAE)),
              ],
            ),
            const SizedBox(height: 18),
            Text(title,
                style: NinniType.h2.copyWith(fontSize: 22, letterSpacing: -0.4, color: fg)),
            const SizedBox(height: 6),
            Text(body, style: NinniType.bodySm.copyWith(color: muted)),
          ],
        ),
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
    final p = NinniPalette.of(context);
    return Container(
      key: const Key('offlineRow'),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(NinniRadii.r18)),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: p.textMuted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l10n.noInternet} '),
                TextSpan(text: l10n.offlineModeShort, style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                TextSpan(text: ' ${l10n.androidOnly}'),
              ]),
              style: NinniType.bodySm.copyWith(fontSize: 14, color: p.textMuted),
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

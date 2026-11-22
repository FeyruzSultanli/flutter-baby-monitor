import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/tokens.dart';

/// V2.1 §3: amber strip at the top of every screen while the phone has no
/// network. The app retries by itself when the network comes back; on
/// Android it points to the offline (Nearby) mode.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.showOfflineModeHint});

  /// Defaults to Android only (offline mode does not exist on iOS).
  final bool? showOfflineModeHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hint = showOfflineModeHint ?? defaultTargetPlatform == TargetPlatform.android;
    final body = hint ? '${l10n.offlineBannerBody} ${l10n.offlineBannerAndroid}' : l10n.offlineBannerBody;
    return Semantics(
      liveRegion: true,
      container: true,
      label: '${l10n.offlineBannerTitle}. $body',
      excludeSemantics: true,
      child: Material(
        color: NinniColors.amber,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(NinniSpace.screen, 10, NinniSpace.screen, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.wifi_off_rounded, size: 20, color: NinniColors.onAmber),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${l10n.offlineBannerTitle}. ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: body),
                    ]),
                    style: NinniType.caption.copyWith(color: NinniColors.onAmber, fontSize: 13),
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

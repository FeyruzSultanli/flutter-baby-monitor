import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/pairing/room_code.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/components/components.dart';
import '../../theme/tokens.dart';

/// Parent: scans the QR code on the baby phone (V2 5.1). Returns the room
/// code, or null. Without camera permission it explains how to type the code.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  /// Room code in a scanned value (`ninni://join?code=…`), or null.
  static String? codeFrom(String? raw) {
    if (raw == null || !raw.startsWith('ninni://join')) return null;
    final code = RoomCode.sanitizeInput(raw).code;
    return RoomCode.isValid(code) ? code : null;
  }

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  bool _wrongCode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = QrScanScreen.codeFrom(barcode.rawValue);
      if (code != null) {
        _done = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(code);
        return;
      }
    }
    if (!_wrongCode) setState(() => _wrongCode = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NightTheme(
      child: Scaffold(
        backgroundColor: NinniColors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _NoCamera(
                permission: error.errorCode == MobileScannerErrorCode.permissionDenied,
              ),
            ),
            // Viewfinder
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(NinniRadii.r28),
                    border: Border.all(color: NinniColors.white, width: 3),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(NinniSpace.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        NinniIconButton(
                          icon: Icons.close_rounded,
                          tooltip: l10n.close,
                          background: NinniColors.night900,
                          foreground: NinniColors.white,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NinniColors.night900.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(NinniRadii.r18),
                      ),
                      child: Text(
                        _wrongCode ? l10n.qrNotNinni : l10n.qrScanHint,
                        textAlign: TextAlign.center,
                        style: NinniType.bodySm.copyWith(color: NinniColors.onNight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCamera extends StatelessWidget {
  const _NoCamera({required this.permission});
  final bool permission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: NinniColors.night900,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 44, color: NinniColors.onNightMuted),
              const SizedBox(height: 16),
              Text(
                permission ? l10n.qrNoCameraPermission : l10n.qrCameraUnavailable,
                textAlign: TextAlign.center,
                style: NinniType.bodySm.copyWith(color: NinniColors.onNightSoft),
              ),
              if (permission) ...[
                const SizedBox(height: 20),
                NinniButton(
                  label: l10n.openSettings,
                  expand: false,
                  variant: NinniButtonVariant.secondary,
                  onPressed: () => openAppSettings(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

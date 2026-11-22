import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/pairing/room_code.dart';
import '../app_theme.dart';
import '../tokens.dart';

/// 8 character room code as 4 + 4 boxes with a dash in between.
///
/// Display mode (baby, night): read-only boxes. Input mode (parent): a hidden
/// text field drives the boxes; pasting works, letters become upper case and
/// look-alike characters (0, O, 1, I) are rejected with a short shake. The
/// boxes bounce once when the code is complete.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes.display({super.key, required String this.code})
      : controller = null,
        focusNode = null,
        onChanged = null,
        onSubmitted = null,
        fieldKey = null,
        semanticLabel = null;

  const CodeBoxes.input({
    super.key,
    required TextEditingController this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.fieldKey,
    this.semanticLabel,
  }) : code = null;

  final String? code;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;
  final String? semanticLabel;

  bool get isInput => controller != null;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> with TickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late final AnimationController _bounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  String _last = '';

  @override
  void initState() {
    super.initState();
    if (widget.isInput) {
      _last = widget.controller!.text;
      widget.controller!.addListener(_onText);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _shake.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  void _onText() {
    final text = widget.controller!.text;
    if (text == _last) return;
    final wasComplete = _last.length == RoomCode.length;
    _last = text;
    setState(() {});
    if (text.length == RoomCode.length && !wasComplete) {
      _animate(_bounce);
      HapticFeedback.lightImpact();
    }
  }

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _animate(AnimationController c) {
    if (_reduceMotion) return;
    c.forward(from: 0);
  }

  void _rejected() {
    _animate(_shake);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final p = NinniPalette.of(context);
    final code = widget.isInput ? widget.controller!.text : widget.code!;
    final chars = RoomCode.normalize(code).split('');
    final focused = widget.isInput && _focus.hasFocus;
    final active = math.min(chars.length, RoomCode.length - 1);

    {
      // 8 boxes + 6 small gaps + the dash; FittedBox shrinks the row on
      // narrow screens (iPhone SE). No LayoutBuilder: screens measure
      // intrinsic heights.
      final display = !widget.isInput;
      const scale = 1.0;
      final w = (display ? 34.0 : 36.0) * scale;
      final h = (display ? 48.0 : 52.0) * scale;
      final gap = display ? 6.0 : 5.0;

      Widget box(int i) {
        final ch = i < chars.length ? chars[i] : '';
        final isActive = focused && i == active && chars.length < RoomCode.length ||
            focused && chars.length == RoomCode.length && i == RoomCode.length - 1;
        final bg = display ? NinniColors.night700 : (p.isNight ? NinniColors.night800 : NinniColors.white);
        final border = display
            ? null
            : Border.all(
                color: isActive ? NinniColors.primary : p.line,
                width: isActive ? 2 : 1.5,
              );
        return Container(
          width: w,
          height: h,
          margin: EdgeInsets.only(right: (i == 3 || i == 7) ? 0 : gap * scale),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular((display ? 10 : 12) * scale),
            border: border,
          ),
          alignment: Alignment.center,
          child: ch.isEmpty
              ? (isActive
                  ? _Caret(height: 24 * scale)
                  : const SizedBox.shrink())
              : Text(
                  ch,
                  style: NinniType.numeric(TextStyle(
                    fontFamily: NinniType.family,
                    fontSize: (display ? 26 : 24) * scale,
                    fontWeight: FontWeight.w800,
                    color: display ? NinniColors.onNight : p.text,
                    height: 1,
                  )),
                ),
        );
      }

      final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++) box(i),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: (display ? 10 : 8) * scale),
            child: Container(
              width: 10 * scale,
              height: 3,
              decoration: BoxDecoration(
                color: display ? NinniColors.inkMuted : NinniColors.creamLineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          for (var i = 4; i < 8; i++) box(i),
        ],
      );

      final animatedRow = AnimatedBuilder(
        animation: Listenable.merge([_shake, _bounce]),
        builder: (context, child) {
          final dx = math.sin(_shake.value * math.pi * 6) * 8 * (1 - _shake.value);
          final s = 1 + math.sin(_bounce.value * math.pi) * 0.04;
          return Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: s, child: child),
          );
        },
        child: row,
      );
      final animated = FittedBox(fit: BoxFit.scaleDown, child: animatedRow);

      if (display) {
        return Semantics(
          label: RoomCode.format(RoomCode.normalize(code)).split('').join(' '),
          child: ExcludeSemantics(child: animated),
        );
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The hidden text field is the accessible control.
        excludeFromSemantics: true,
        onTap: () => _focus.requestFocus(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            animated,
            // The real input: invisible, on top so taps and the keyboard work.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                // Screen readers still reach the field (it is the control).
                alwaysIncludeSemantics: true,
                child: TextField(
                  key: widget.fieldKey,
                  controller: widget.controller,
                  focusNode: _focus,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  textCapitalization: TextCapitalization.characters,
                  showCursor: false,
                  enableInteractiveSelection: true,
                  maxLength: null,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    labelText: widget.semanticLabel,
                  ),
                  inputFormatters: [_RoomCodeFormatter(onRejected: _rejected)],
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _Caret extends StatefulWidget {
  const _Caret({required this.height});
  final double height;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _blink.value = 1;
      _blink.stop();
    } else if (!_blink.isAnimating) {
      _blink.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _blink,
      child: Container(width: 2, height: widget.height, color: NinniColors.primary),
    );
  }
}

/// Keeps only valid room code characters (upper case), at most 8; accepts
/// pasted `ABCD-EF23` or `ninni://join?code=…`. Calls [onRejected] when the
/// input contained characters that are not allowed.
class _RoomCodeFormatter extends TextInputFormatter {
  _RoomCodeFormatter({required this.onRejected});
  final VoidCallback onRejected;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final result = RoomCode.sanitizeInput(newValue.text);
    if (result.rejected) onRejected();
    final text = result.code;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

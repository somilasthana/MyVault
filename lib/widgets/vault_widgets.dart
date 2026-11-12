import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvault/theme/vault_theme.dart';

class AnimeBackdrop extends StatelessWidget {
  const AnimeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _AnimePainter(),
      child: SizedBox.expand(),
    );
  }
}

class _AnimePainter extends CustomPainter {
  const _AnimePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = VaultColors.cream);

    void blob(Offset center, double radius, Color color) {
      canvas.drawCircle(center, radius, Paint()..color = color);
    }

    blob(
      Offset(size.width * -0.04, size.height * 0.08),
      130,
      const Color(0xFFFFB7D5),
    );
    blob(
      Offset(size.width * 1.02, size.height * 0.04),
      96,
      const Color(0xFF9AEEFF),
    );
    blob(
      Offset(size.width * 0.92, size.height * 0.94),
      120,
      const Color(0xFFFFF1A8),
    );
    blob(
      Offset(size.width * 0.02, size.height * 0.82),
      78,
      const Color(0xFFE3D7FF),
    );

    _star(
      canvas,
      Offset(size.width * 0.16, size.height * 0.07),
      10,
      VaultColors.lemon,
    );
    _star(
      canvas,
      Offset(size.width * 0.9, size.height * 0.16),
      8,
      VaultColors.pink,
    );
    _star(
      canvas,
      Offset(size.width * 0.08, size.height * 0.93),
      8,
      VaultColors.cyan,
    );
    _star(
      canvas,
      Offset(size.width * 0.94, size.height * 0.86),
      9,
      VaultColors.grape,
    );
  }

  void _star(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final pointRadius = i.isEven ? radius : radius * 0.42;
      final point = Offset(
        center.dx + math.cos(angle) * pointRadius,
        center.dy + math.sin(angle) * pointRadius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = VaultColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.drawer,
    this.scaffoldKey,
    super.key,
  });

  final Widget child;
  final Widget? drawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      drawerEnableOpenDragGesture: drawer != null,
      body: Stack(
        children: [
          const Positioned.fill(child: AnimeBackdrop()),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class VaultMascot extends StatelessWidget {
  const VaultMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 118,
      height: 108,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            top: 12,
            right: 6,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: VaultColors.ink,
                borderRadius: BorderRadius.all(Radius.circular(34)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 14,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF9BC4),
                    Color(0xFFFF4F93),
                    Color(0xFFB388FF),
                  ],
                ),
                borderRadius: BorderRadius.all(Radius.circular(34)),
                border: Border.fromBorderSide(
                  BorderSide(color: VaultColors.ink, width: 3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [_Eye(), SizedBox(width: 16), _Eye()],
                  ),
                  SizedBox(height: 8),
                  _Smile(),
                ],
              ),
            ),
          ),
          Positioned(right: -2, top: -8, child: _Spark()),
        ],
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VaultColors.ink, width: 2),
      ),
      alignment: const Alignment(0, 0.35),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: VaultColors.ink,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Smile extends StatelessWidget {
  const _Smile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 10,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VaultColors.ink, width: 3)),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VaultColors.lemon,
        shape: BoxShape.circle,
        border: Border.all(color: VaultColors.ink, width: 2),
      ),
      child: const Text(
        '★',
        style: TextStyle(fontSize: 14, height: 1, color: VaultColors.ink),
      ),
    );
  }
}

class StickerButton extends StatelessWidget {
  const StickerButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.background = VaultColors.pink,
    this.foreground = Colors.white,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      height: 66,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned(
            left: 5,
            top: 6,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: VaultColors.ink,
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            right: 5,
            bottom: 6,
            child: Material(
              color: enabled ? background : VaultColors.blush,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: VaultColors.ink, width: 3),
              ),
              child: InkWell(
                onTap: enabled ? onPressed : null,
                borderRadius: BorderRadius.circular(22),
                child: Center(
                  child: busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: foreground,
                          ),
                        )
                      : Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: enabled ? foreground : VaultColors.ink,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StickerIconButton extends StatelessWidget {
  const StickerIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          children: [
            const Positioned(
              left: 4,
              top: 4,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: VaultColors.ink,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 4,
              bottom: 4,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: VaultColors.ink, width: 2.5),
                ),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(16),
                  child: Icon(icon, color: VaultColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VaultField extends StatelessWidget {
  const VaultField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.onToggleObscure,
    this.error,
    this.helper,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.allowSuggestions = true,
    this.showTooltip = 'Show password',
    this.hideTooltip = 'Hide password',
    super.key,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final String? error;
  final String? helper;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool allowSuggestions;
  final String showTooltip;
  final String hideTooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: VaultColors.grape,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: fieldKey,
          controller: controller,
          obscureText: obscure,
          obscuringCharacter: '*',
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: allowSuggestions && !obscure,
          cursorColor: VaultColors.pink,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: VaultColors.ink,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            errorText: error,
            hintText: label,
            hintStyle: const TextStyle(color: Color(0xFFB89BC4), fontSize: 16),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    tooltip: obscure ? showTooltip : hideTooltip,
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: VaultColors.ink,
                    ),
                  ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: _border(VaultColors.ink),
            focusedBorder: _border(VaultColors.pink),
            errorBorder: _border(VaultColors.pinkDeep),
            focusedErrorBorder: _border(VaultColors.pinkDeep),
          ),
        ),
        if (helper != null && error == null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6E5684),
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: 2.5),
    );
  }
}

Future<void> copyVaultValue(
  BuildContext context,
  String value,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: VaultColors.grape,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

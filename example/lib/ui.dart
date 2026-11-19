import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'catalog.dart';

/// Brand colours of the demo.
abstract final class Brand {
  static const bg = Color(0xff0b0b14);
  static const surface = Color(0xff161624);
  static const pink = Color(0xffff4d8d);
  static const orange = Color(0xffff9a3c);
  static const violet = Color(0xff7c5cff);
  static const cyan = Color(0xff38d6ff);
  static const gradient = LinearGradient(
    colors: [pink, orange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// A slowly drifting aurora: stands in for the live video behind the gifts, so their transparency is obvious.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(painter: _AuroraPainter(_c.value)),
    ),
  );
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff120a24),
    );
    final blobs = [
      (const Color(0xffff2e7e), 0.0, 0.55),
      (const Color(0xff6a3cff), 2.1, 0.65),
      (const Color(0xff00b4d8), 4.2, 0.5),
      (const Color(0xffff8a3d), 1.0, 0.4),
    ];
    for (final (color, phase, r) in blobs) {
      final a = t * 2 * math.pi + phase;
      final center = Offset(
        size.width * (0.5 + 0.35 * math.cos(a)),
        size.height * (0.45 + 0.3 * math.sin(a * 0.8)),
      );
      final radius = size.longestSide * r;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

/// Frosted glass panel.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 20,
    this.opacity = 0.12,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: child,
      ),
    ),
  );
}

/// Format label: SVGA / GIF / WebP / PAG.
class FormatBadge extends StatelessWidget {
  const FormatBadge(this.format, {super.key, this.small = false});
  final String format;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = formatColor(format);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 8,
        vertical: small ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        format,
        style: TextStyle(
          color: c,
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// The round gradient icon of a gift.
class GiftIcon extends StatelessWidget {
  const GiftIcon(this.gift, {super.key, this.size = 52});
  final Gift gift;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: gift.colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: gift.colors.last.withValues(alpha: 0.45),
          blurRadius: size * 0.35,
        ),
      ],
    ),
    child: Text(gift.emoji, style: TextStyle(fontSize: size * 0.48)),
  );
}

/// Transparency grid, like an image editor.
class CheckerPainter extends CustomPainter {
  const CheckerPainter({this.cell = 12});
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final a = Paint()..color = const Color(0xff2a2a3a);
    final b = Paint()..color = const Color(0xff1e1e2c);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final odd = ((x / cell).floor() + (y / cell).floor()).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), odd ? a : b);
      }
    }
  }

  @override
  bool shouldRepaint(CheckerPainter old) => old.cell != cell;
}

/// A small rounded label with an icon.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.white70),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Gradient call-to-action button.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = Brand.gradient,
    this.height = 48,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? 0.5 : 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: Brand.pink.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              // widthFactor 1: as wide as its label (a parent can still stretch it, e.g. SizedBox(width: double.infinity)).
              child: Center(
                widthFactor: 1,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  child: IconTheme.merge(
                    data: const IconThemeData(color: Colors.white),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One option of a [PillSegmented]: a short label or an icon.
typedef PillOption<T> = ({
  T value,
  String? label,
  IconData? icon,
  String tooltip,
});

/// A compact segmented control: a small caption over a pill track whose selected option slides into a gradient.
/// Labels stay on one line and shrink to fit, so narrow phones and large fonts never break them.
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.caption,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final String caption;
  final List<PillOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 4),
        child: Text(
          caption.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: Colors.white38,
          ),
        ),
      ),
      Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            for (final o in options)
              Expanded(
                child: Tooltip(
                  message: o.tooltip,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(o.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        gradient: o.value == selected ? Brand.gradient : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: o.icon != null
                            ? Icon(
                                o.icon,
                                size: 18,
                                color: o.value == selected
                                    ? Colors.white
                                    : Colors.white60,
                              )
                            : Text(
                                o.label ?? '',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: o.value == selected
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

/// Section heading used in the Studio.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: Brand.gradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

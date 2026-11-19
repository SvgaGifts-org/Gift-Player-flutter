import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One gift of the demo catalogue.
class Gift {
  const Gift({
    required this.name,
    required this.format,
    required this.source,
    required this.emoji,
    required this.colors,
    required this.coins,
    this.fullScreen = false,
    this.tag,
  });

  final String name;
  final String format;

  /// What `load()` / `queue.add()` take: an `asset:` string here, a URL in a real app, or bytes.
  final Object source;
  final String emoji;
  final List<Color> colors;

  /// Price shown in the gift drawer (decoration only).
  final int coins;

  /// Big full-screen effect (portrait 750 x 1334) rather than a small badge.
  final bool fullScreen;

  /// A short highlight, e.g. "Your photo".
  final String? tag;
}

/// The gifts shown in the demo. To try your own, drop files into `assets/gifts/` and add an entry.
const List<Gift> catalog = [
  Gift(
    name: 'Birthday Cake',
    format: 'SVGA',
    source: 'asset:assets/gifts/birthday-cake.svga',
    emoji: '🎂',
    colors: [Color(0xffff5f6d), Color(0xffffc371)],
    coins: 9999,
    fullScreen: true,
    tag: 'Your photo',
  ),
  Gift(
    name: 'Diamond Badge',
    format: 'SVGA',
    source: 'asset:assets/gifts/diamond-badge.svga',
    emoji: '💎',
    colors: [Color(0xff7f00ff), Color(0xffe100ff)],
    coins: 4999,
  ),
  Gift(
    name: 'Crown Frame',
    format: 'SVGA',
    source: 'asset:assets/gifts/crown-frame.svga',
    emoji: '👑',
    colors: [Color(0xfff7b733), Color(0xfffc4a1a)],
    coins: 999,
  ),
  Gift(
    name: 'Sweet Kiss',
    format: 'SVGA',
    source: 'asset:assets/gifts/sweet-kiss.svga',
    emoji: '💋',
    colors: [Color(0xffff0099), Color(0xffff6fb5)],
    coins: 1999,
    fullScreen: true,
  ),
];

Gift? giftForSource(Object src) {
  for (final g in catalog) {
    if (identical(g.source, src) || g.source == src) return g;
  }
  return null;
}

/// Colour per format, used by the small badges.
Color formatColor(String format) => switch (format) {
  'SVGA' => const Color(0xffff7a59),
  'GIF' => const Color(0xff3ddc97),
  'WebP' => const Color(0xff4cc9f0),
  'PAG' => const Color(0xffb388ff),
  _ => Colors.grey,
};

/// A round avatar (gradient + initials) drawn in code, used to fill avatar layers such as `sender_avatar`.
Future<ui.Image> makeAvatar(String name, {int size = 256}) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final s = size.toDouble();
  final hue = (name.codeUnits.fold<int>(7, (a, b) => a * 31 + b) % 360)
      .toDouble();
  final rect = Rect.fromLTWH(0, 0, s, s);
  c.clipPath(Path()..addOval(rect)); // round, so it looks right in any layer
  c.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HSLColor.fromAHSL(1, hue, 0.75, 0.55).toColor(),
          HSLColor.fromAHSL(1, (hue + 50) % 360, 0.8, 0.45).toColor(),
        ],
      ).createShader(rect),
  );
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final initials = words
      .take(2)
      .map((w) => w.characters.first.toUpperCase())
      .join();
  final tp = TextPainter(
    text: TextSpan(
      text: initials.isEmpty ? '?' : initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: s * 0.42,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, Offset((s - tp.width) / 2, (s - tp.height) / 2));
  return rec.endRecording().toImage(size, size);
}

String compactNumber(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
  return '$n';
}

final math.Random rng = math.Random();

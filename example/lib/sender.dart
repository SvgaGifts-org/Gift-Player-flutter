import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gift_player_flutter/gift_player_flutter.dart';

import 'catalog.dart';
import 'ui.dart';

/// Who is sending gifts from this phone.
abstract final class Sender {
  static final ValueNotifier<String> name = ValueNotifier('Alex');
}

/// Generated avatars, one per name (kept for the app's lifetime: the player never disposes a `ui.Image` it is given).
abstract final class Avatars {
  static final Map<String, Future<ui.Image>> _cache = {};
  static Future<ui.Image> of(String name) => _cache[name] ??= makeAvatar(name);
}

/// Personalises a gift for [who]: their photo in its `sender_avatar` layer.
Future<Replacements?> replacementsFor(Gift gift, String who) async {
  switch (gift.tag) {
    case 'Your photo':
      return {
        'sender_avatar': Replacement.image(
          await Avatars.of(who),
          options: const GiftImageOptions(fit: GiftImageFit.cover),
        ),
      };
  }
  return null;
}

/// Round avatar of [name].
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name, this.size = 32});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image>(
    future: Avatars.of(name),
    builder: (_, s) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: s.hasData
            ? RawImage(image: s.data, fit: BoxFit.cover)
            : const ColoredBox(color: Brand.violet),
      ),
    ),
  );
}

/// "Sending as Alex ✎": tap to change the name used for replacements.
class SenderChip extends StatelessWidget {
  const SenderChip({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: Sender.name,
    builder: (_, name, _) => InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => editSenderName(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarCircle(name: name, size: 26),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_rounded, size: 14, color: Colors.white54),
          ],
        ),
      ),
    ),
  );
}

Future<void> editSenderName(BuildContext context) async {
  final ctl = TextEditingController(text: Sender.name.value);
  final v = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: ctl,
        autofocus: true,
        maxLength: 18,
        decoration: const InputDecoration(
          helperText: 'Shown inside personalised gifts (Birthday Cake)',
        ),
        onSubmitted: (s) => Navigator.pop(c, s),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctl.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (v != null && v.trim().isNotEmpty) Sender.name.value = v.trim();
}

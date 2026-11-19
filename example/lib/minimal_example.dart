import 'package:flutter/material.dart';
import 'package:gift_player_flutter/gift_player_flutter.dart';

/// The smallest useful integration, without the demo UI: a declarative view that loads, plays once and calls back.
class MinimalExample extends StatelessWidget {
  const MinimalExample({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    height: 300,
    child: GiftPlayerView(
      src:
          'asset:assets/gifts/crown-frame.svga', // or https://…, file://…, or bytes
      onEnd: () => debugPrint('gift finished'),
    ),
  );
}

/// The same with the imperative API and a live-stream queue.
class MinimalQueueExample extends StatefulWidget {
  const MinimalQueueExample({super.key});

  @override
  State<MinimalQueueExample> createState() => _MinimalQueueExampleState();
}

class _MinimalQueueExampleState extends State<MinimalQueueExample> {
  final GiftQueueController _room = GiftQueueController();

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      GiftPlayerSurface(player: _room.player),
      Align(
        alignment: Alignment.bottomCenter,
        child: FilledButton(
          onPressed: () =>
              _room.queue.add('asset:assets/gifts/sweet-kiss.svga'),
          child: const Text('Send'),
        ),
      ),
    ],
  );
}

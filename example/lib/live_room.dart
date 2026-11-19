import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gift_player_flutter/gift_player_flutter.dart';

import 'catalog.dart';
import 'sender.dart';
import 'ui.dart';

/// A mock live-stream room: gifts from you and from simulated viewers go through a [GiftQueue] and play over the "video".
class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key});

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _FeedLine {
  _FeedLine(this.who, this.text, {this.color, this.gift});
  final String who;
  final String text;
  final Color? color;
  final Gift? gift;
  final int id = _nextId++;
  static int _nextId = 0;
}

const _viewers = [
  'Aarav',
  'Diya',
  'Kabir',
  'Meera',
  'Zoya',
  'Vihaan',
  'Anaya',
  'Ishaan',
];
const _chat = [
  'wow 🔥🔥',
  'hello from Surat 👋',
  'this effect is so smooth',
  'combo!!',
  '❤️❤️❤️',
  'who sent that? 😍',
  'GG',
  'play it again',
  'so clean on my phone',
];

class _LiveRoomPageState extends State<LiveRoomPage> {
  // The whole live-stream integration: one controller (player + queue), one surface, add() per gift.
  final GiftQueueController _room = GiftQueueController(
    queueOptions: const GiftQueueOptions(
      maxLength: 80,
      preloadAhead: 2,
      coalesce: true,
    ),
  );
  final List<void Function()> _offs = [];
  final List<_FeedLine> _feed = [];
  final Map<String, String> _lastSender =
      {}; // gift source identity -> who sent it last
  ({Gift gift, int count, String who, int id})? _combo;
  Timer? _chatTimer;
  int _likes = 12400;

  @override
  void initState() {
    super.initState();
    final q = _room.queue;
    _offs.addAll([
      q.onItemStart.listen((i) {
        final g = giftForSource(i.src);
        if (g == null) return;
        setState(
          () => _combo = (
            gift: g,
            count: i.count,
            who: _lastSender[g.name] ?? 'Someone',
            id: i.id,
          ),
        );
      }),
      q.onItemEnd.listen((_) => setState(() => _combo = null)),
      q.onItemError.listen(
        (e) => _post(
          'System',
          '${giftForSource(e.item.src)?.name ?? 'Gift'} failed: ${e.error.code.id}',
          color: Colors.redAccent,
        ),
      ),
      q.onItemDropped.listen(
        (e) => _post(
          'System',
          '${giftForSource(e.item.src)?.name ?? 'Gift'} dropped (${e.reason.name})',
          color: Colors.white54,
        ),
      ),
    ]);
    _chatTimer = Timer.periodic(const Duration(milliseconds: 3800), (_) {
      _post(
        _viewers[rng.nextInt(_viewers.length)],
        _chat[rng.nextInt(_chat.length)],
      );
      setState(() => _likes += rng.nextInt(40));
    });
    for (final v in _viewers) {
      Avatars.of(v); // warm up, so simulated gifts carry their sender's photo
    }
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    for (final o in _offs) {
      o();
    }
    _room.dispose();
    super.dispose();
  }

  void _post(String who, String text, {Color? color, Gift? gift}) {
    if (!mounted) return;
    setState(() {
      _feed.add(_FeedLine(who, text, color: color, gift: gift));
      if (_feed.length > 6) _feed.removeAt(0);
    });
  }

  /// Sends [count] x [gift] from [who]; identical sends merge into one combo (coalesce).
  Future<void> _send(
    Gift gift,
    int count,
    String who, {
    bool vip = false,
  }) async {
    final replacements = await replacementsFor(gift, who);
    _lastSender[gift.name] = who;
    for (var i = 0; i < count; i++) {
      _room.queue.add(
        gift.source,
        priority: vip ? 5 : 0,
        replacements: replacements,
        loops: 1,
      );
    }
    _post(
      who,
      'sent ${gift.name}${count > 1 ? ' ×$count' : ''}${vip ? '  ⚡VIP' : ''}',
      gift: gift,
    );
  }

  void _busyRoom() {
    _post(
      'System',
      '🔥 20 gifts are flying in from viewers…',
      color: Brand.orange,
    );
    for (var i = 0; i < 20; i++) {
      final g = catalog[rng.nextInt(catalog.length)];
      _send(g, 1, _viewers[rng.nextInt(_viewers.length)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AuroraBackground(),
        if (_combo == null)
          const _VideoHint(), // hidden while a gift plays over it
        GiftPlayerSurface(player: _room.player),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 8),
                _statsRow(),
                const Spacer(),
                if (_combo != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _comboBanner(_combo!),
                  ),
                const SizedBox(height: 10),
                _feedView(),
                const SizedBox(height: 10),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // The host card takes what is left and ellipsizes; the badges on the right keep their size.
      Flexible(
        flex: 3,
        child: Glass(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
          radius: 30,
          opacity: 0.1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Brand.gradient,
                ),
                child: const Text('🎤', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SvgaGifts Live',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '❤ ${compactNumber(_likes)} likes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Shrinks (never overflows) when the screen is narrow or the font is large.
      Flexible(
        flex: 2,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LiveBadge(),
                  const SizedBox(width: 8),
                  Pill(
                    icon: Icons.visibility_rounded,
                    text: compactNumber(2300 + _likes ~/ 100),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _statsRow() => ValueListenableBuilder<GiftQueueState>(
    valueListenable: _room.stats,
    builder: (_, s, _) => Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          Pill(
            icon: Icons.hourglass_top_rounded,
            text: 'Waiting ${s.pending}',
            color: Brand.cyan,
          ),
          Pill(
            icon: Icons.check_circle_rounded,
            text: 'Played ${s.played}',
            color: const Color(0xff3ddc97),
          ),
          if (s.dropped + s.failed > 0)
            Pill(
              icon: Icons.warning_amber_rounded,
              text: '${s.dropped + s.failed}',
              color: Brand.orange,
            ),
        ],
      ),
    ),
  );

  Widget _comboBanner(({Gift gift, int count, String who, int id}) c) =>
      TweenAnimationBuilder<double>(
        key: ValueKey(c.id),
        tween: Tween(begin: -1, end: 0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, v, child) =>
            Transform.translate(offset: Offset(v * 260, 0), child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: LinearGradient(
              colors: [
                c.gift.colors.first.withValues(alpha: 0.85),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarCircle(name: c.who, size: 38),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.who,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'sent ${c.gift.name}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              GiftIcon(c.gift, size: 40),
              if (c.count > 1) ...[
                const SizedBox(width: 6),
                TweenAnimationBuilder<double>(
                  key: ValueKey('${c.id}-${c.count}'),
                  tween: Tween(begin: 1.8, end: 1),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xffffe259), Color(0xffffa751)],
                    ).createShader(r),
                    child: Text(
                      '×${c.count}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _feedView() => SizedBox(
    height: 168,
    child: ShaderMask(
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.white],
        stops: [0, 0.3],
      ).createShader(r),
      blendMode: BlendMode.dstIn,
      child: ListView(
        reverse: true,
        padding: EdgeInsets.zero,
        children: [
          for (final l in _feed.reversed)
            Align(
              key: ValueKey(l.id),
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${l.who}  ',
                          style: TextStyle(
                            color: l.gift != null ? Brand.orange : Brand.cyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: l.text,
                          style: TextStyle(color: l.color ?? Colors.white),
                        ),
                        if (l.gift != null)
                          TextSpan(text: '  ${l.gift!.emoji}'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _bottomBar() => Row(
    children: [
      Expanded(
        child: Glass(
          radius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          opacity: 0.1,
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: Colors.white60,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Say something…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      _roundButton(
        icon: Icons.local_fire_department_rounded,
        tooltip: 'Busy room: 20 gifts from viewers',
        onTap: _busyRoom,
        gradient: const LinearGradient(
          colors: [Color(0xffff512f), Color(0xffdd2476)],
        ),
      ),
      const SizedBox(width: 8),
      _roundButton(
        icon: Icons.card_giftcard_rounded,
        tooltip: 'Send a gift',
        onTap: _openDrawer,
        gradient: Brand.gradient,
        size: 54,
      ),
    ],
  );

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Gradient gradient,
    double size = 46,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: gradient),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    ),
  );

  void _openDrawer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => GiftDrawer(
        onSend: (g, n, vip) => _send(g, n, Sender.name.value, vip: vip),
      ),
    );
  }
}

/// The gift drawer: pick a gift, a quantity and VIP, then send.
class GiftDrawer extends StatefulWidget {
  const GiftDrawer({super.key, required this.onSend});
  final void Function(Gift gift, int count, bool vip) onSend;

  @override
  State<GiftDrawer> createState() => _GiftDrawerState();
}

class _GiftDrawerState extends State<GiftDrawer> {
  Gift _gift = catalog.first;
  int _count = 1;
  bool _vip = false;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(maxHeight: h * 0.72),
          color: Brand.surface.withValues(alpha: 0.88),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Send a gift',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SenderChip(),
                    ],
                  ),
                ),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: catalog.length,
                    itemBuilder: (_, i) => _tile(catalog[i]),
                  ),
                ),
                const Divider(height: 18, color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      // The chips wrap onto a second line on narrow screens or with large fonts.
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final n in const [1, 10, 66, 99])
                              ChoiceChip(
                                label: Text('×$n'),
                                selected: _count == n,
                                onSelected: (_) => setState(() => _count = n),
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'VIP',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Tooltip(
                        message: 'VIP gifts jump ahead of everything waiting',
                        child: Switch(
                          value: _vip,
                          onChanged: (v) => setState(() => _vip = v),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      gradient: LinearGradient(colors: _gift.colors),
                      onPressed: () {
                        widget.onSend(_gift, _count, _vip);
                        Navigator.pop(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _gift.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Send ${_gift.name}${_count > 1 ? ' ×$_count' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '🪙 ${compactNumber(_gift.coins * _count)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileContent(Gift g, bool selected) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedScale(
        scale: selected ? 1.12 : 1,
        duration: const Duration(milliseconds: 180),
        child: GiftIcon(g, size: 44),
      ),
      const SizedBox(height: 6),
      SizedBox(
        width:
            76, // fixed, so long names ellipsize instead of shrinking the whole tile
        child: Text(
          g.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ),
      Text(
        '🪙 ${compactNumber(g.coins)}',
        style: const TextStyle(fontSize: 10.5, color: Colors.white60),
      ),
      const SizedBox(height: 3),
      FormatBadge(g.format, small: true),
    ],
  );

  Widget _tile(Gift g) {
    final selected = identical(g, _gift);
    return GestureDetector(
      onTap: () => setState(() => _gift = g),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? g.colors.first.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected ? g.colors.first : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // scaleDown: with a large system font the tile's content shrinks instead of overflowing.
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _tileContent(g, selected),
                ),
              ),
            ),
            if (g.tag != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    gradient: Brand.gradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    g.tag!,
                    style: const TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xffff2e55),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _c,
          child: const CircleAvatar(radius: 3.5, backgroundColor: Colors.white),
        ),
        const SizedBox(width: 6),
        const Text(
          'LIVE',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class _VideoHint extends StatelessWidget {
  const _VideoHint();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.videocam_rounded,
          size: 46,
          color: Colors.white.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 6),
        Text(
          'your live video plays here\ngifts are drawn on top, with transparency',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.18),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

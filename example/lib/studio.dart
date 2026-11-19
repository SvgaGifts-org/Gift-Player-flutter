import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gift_player_flutter/gift_player_flutter.dart';

import 'catalog.dart';
import 'sender.dart';
import 'ui.dart';

/// Inspect one gift: play it on a transparency grid, scrub its frames, edit its layers, watch the caches.
class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

enum _Backdrop { checker, dark, light, aurora }

class _StudioPageState extends State<StudioPage> {
  final GiftPlayer _player = GiftPlayer();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final List<void Function()> _offs = [];
  Gift _gift = catalog.first;
  GiftInfo? _info;
  int? _loadMs;
  bool _loading = false;
  bool _playing = false;
  bool _ended = false; // the gift finished and was cleared from the stage
  bool _dragging = false;
  int _loops = 0; // 0 = forever
  ContentMode _mode = ContentMode.aspectFit;
  _Backdrop _backdrop = _Backdrop.checker;
  bool _showAllKeys = false;
  final Map<String, String> _edited =
      {}; // key -> what was done ("text", "photo", "hidden")
  int _diskBytes = 0;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _offs.addAll([
      _player.onFrame.listen((f) {
        if (!_dragging) _frame.value = f;
      }),
      _player.onStart.listen((_) => setState(() => _playing = true)),
      _player.onEnd.listen(
        (_) => setState(() {
          _playing = false;
          _ended = true;
        }),
      ),
      _player.onError.listen((e) {
        if (e.code != GiftErrorCode.aborted) {
          _snack('${e.code.id}: ${e.message}');
        }
      }),
    ]);
    _statsTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshStats(),
    );
    _refreshStats();
    _open(_gift);
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    for (final o in _offs) {
      o();
    }
    _player.destroy();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    final d = await GiftPlayer.getDiskCache()?.sizeInBytes() ?? 0;
    if (mounted) setState(() => _diskBytes = d);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _open(Gift g) async {
    setState(() {
      _gift = g;
      _loading = true;
      _ended = false;
      _edited.clear();
      _showAllKeys = false;
    });
    final sw = Stopwatch()..start();
    try {
      final info = await _player.load(
        g.source,
        options: LoadOptions(loops: _loops),
      );
      if (!mounted) return;
      setState(() {
        _info = info;
        _loadMs = sw.elapsedMilliseconds;
        _loading = false;
        _frame.value = 0;
      });
      unawaited(_player.play().catchError((Object _) {}));
    } on GiftPlayerError catch (e) {
      if (e.code == GiftErrorCode.aborted) return;
      setState(() => _loading = false);
      _snack('${g.name}: ${e.code.id}');
    }
  }

  /// "< 1 ms" when the gift came from the memory cache.
  String get _loadLabel => (_loadMs ?? 0) < 1 ? '< 1 ms' : '$_loadMs ms';

  void _togglePlay() {
    if (_info == null) return;
    if (_playing) {
      _player.pause();
      setState(() => _playing = false);
    } else if (_frame.value >= _info!.frameCount - 1 ||
        !(_player.current != null)) {
      _open(_gift);
    } else {
      _player.resume();
      setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea: scrolled content is clipped below the status bar instead of running under the clock.
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ShaderMask(
                      shaderCallback: (r) => Brand.gradient.createShader(r),
                      child: const Text(
                        'Gift Studio',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SenderChip(),
            ],
          ),
          const Text(
            'Inspect a gift, scrub it frame by frame and personalise its layers.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          _picker(),
          const SizedBox(height: 12),
          _stage(),
          const SizedBox(height: 10),
          _transport(),
          const SectionTitle('Details'),
          _details(),
          SectionTitle(
            'Editable layers',
            trailing: _info == null
                ? null
                : Text(
                    '${_info!.editableKeys.length}',
                    style: const TextStyle(color: Colors.white54),
                  ),
          ),
          _layers(),
          const SectionTitle('Caches'),
          _caches(),
        ],
      ),
    );
  }

  // Icon (60) + gap + one line of text that grows with the system font size.
  Widget _picker() => SizedBox(
    height: 72 + MediaQuery.textScalerOf(context).scale(11) * 1.5,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: catalog.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final g = catalog[i];
        final sel = identical(g, _gift);
        return GestureDetector(
          onTap: () => _open(g),
          child: SizedBox(
            width: 70,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? g.colors.first : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: GiftIcon(g, size: 50),
                ),
                const SizedBox(height: 4),
                Text(
                  g.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _stage() {
    final backdrop = switch (_backdrop) {
      _Backdrop.checker => const CustomPaint(painter: CheckerPainter()),
      _Backdrop.dark => const ColoredBox(color: Color(0xff050508)),
      _Backdrop.light => const ColoredBox(color: Color(0xfff2f2f7)),
      _Backdrop.aurora => const AuroraBackground(),
    };
    return AspectRatio(
      aspectRatio: _gift.fullScreen ? 3 / 4 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            backdrop,
            GiftPlayerSurface(player: _player),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_ended && !_loading)
              Center(
                child: GradientButton(
                  onPressed: () => _open(_gift),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.replay_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Play again'),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  FormatBadge(_gift.format),
                  const SizedBox(width: 6),
                  if (_loadMs != null && !_loading)
                    Pill(
                      icon: Icons.bolt_rounded,
                      text: _loadLabel,
                      color: _loadMs! < 30
                          ? const Color(0xff3ddc97)
                          : Brand.orange,
                    ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Glass(
                padding: const EdgeInsets.all(2),
                radius: 14,
                opacity: 0.08,
                child: Row(
                  children: [
                    for (final (b, icon, tip) in [
                      (
                        _Backdrop.checker,
                        Icons.grid_on_rounded,
                        'Transparency grid',
                      ),
                      (_Backdrop.dark, Icons.dark_mode_rounded, 'Dark'),
                      (_Backdrop.light, Icons.light_mode_rounded, 'Light'),
                      (
                        _Backdrop.aurora,
                        Icons.auto_awesome_rounded,
                        'Video-like',
                      ),
                    ])
                      IconButton(
                        tooltip: tip,
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        color: _backdrop == b ? Brand.orange : Colors.white60,
                        onPressed: () => setState(() => _backdrop = b),
                        icon: Icon(icon),
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

  Widget _transport() {
    final frames = _info?.frameCount ?? 1;
    return Glass(
      opacity: 0.06,
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: _info == null ? null : _togglePlay,
                style: IconButton.styleFrom(backgroundColor: Brand.pink),
                icon: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Replay',
                onPressed: () => _open(_gift),
                icon: const Icon(Icons.replay_rounded),
              ),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (_, f, _) => Slider(
                    value: f.clamp(0, frames - 1).toDouble(),
                    max: (frames - 1).clamp(1, 1 << 20).toDouble(),
                    onChangeStart: (_) {
                      _dragging = true;
                      _player.pause();
                      setState(() => _playing = false);
                    },
                    onChanged: (v) {
                      _frame.value = v.round();
                      _player.seek(v.round());
                    },
                    onChangeEnd: (_) => _dragging = false,
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (_, f, _) => SizedBox(
                  width: 64,
                  child: Text(
                    '${f + 1} / $frames',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 6),
              Expanded(
                child: PillSegmented<int>(
                  caption: 'Repeat',
                  options: const [
                    (value: 1, label: '1×', icon: null, tooltip: 'Play once'),
                    (
                      value: 3,
                      label: '3×',
                      icon: null,
                      tooltip: 'Play 3 times',
                    ),
                    (
                      value: 0,
                      label: null,
                      icon: Icons.all_inclusive_rounded,
                      tooltip: 'Loop forever',
                    ),
                  ],
                  selected: _loops,
                  onChanged: (v) {
                    setState(() => _loops = v);
                    _open(_gift);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillSegmented<ContentMode>(
                  caption: 'Size',
                  options: const [
                    (
                      value: ContentMode.aspectFit,
                      label: 'Fit',
                      icon: null,
                      tooltip: 'Whole gift visible (aspectFit)',
                    ),
                    (
                      value: ContentMode.aspectFill,
                      label: 'Crop',
                      icon: null,
                      tooltip: 'Fill the box, crop the edges (aspectFill)',
                    ),
                    (
                      value: ContentMode.fill,
                      label: 'Full',
                      icon: null,
                      tooltip: 'Stretch to the box (fill)',
                    ),
                  ],
                  selected: _mode,
                  onChanged: (m) {
                    setState(() => _mode = m);
                    _player.setContentMode(m);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _details() {
    final i = _info;
    String fps() => i == null || i.durationMs <= 0
        ? '–'
        : (i.frameCount * 1000 / i.durationMs).toStringAsFixed(0);
    final items = [
      ('Format', i?.format.name.toUpperCase() ?? '–', Icons.category_rounded),
      (
        'Canvas',
        i == null ? '–' : '${i.width.toInt()} × ${i.height.toInt()}',
        Icons.aspect_ratio_rounded,
      ),
      (
        'Frames',
        i == null ? '–' : '${i.frameCount} @ ${fps()} fps',
        Icons.movie_filter_rounded,
      ),
      (
        'Duration',
        i == null ? '–' : '${(i.durationMs / 1000).toStringAsFixed(2)} s',
        Icons.timer_rounded,
      ),
      ('Load', _loadMs == null ? '–' : _loadLabel, Icons.bolt_rounded),
      (
        'Layers',
        i == null ? '–' : '${i.editableKeys.length} editable',
        Icons.layers_rounded,
      ),
    ];
    // Rows of three tiles that size to their content (no fixed aspect ratio), so large system fonts never overflow.
    Widget tile((String, String, IconData) item) {
      final (label, value, icon) = item;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Brand.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Brand.orange),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < items.length; r += 3)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = r; i < r + 3 && i < items.length; i++) ...[
                    if (i > r) const SizedBox(width: 8),
                    Expanded(child: tile(items[i])),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Layers with a meaningful name (not the generic `img_12` / `psd_3010` of design tools) come first.
  static bool _named(String key) =>
      !RegExp(r'^(img|psd|image)_?\d+$', caseSensitive: false).hasMatch(key);

  Widget _layers() {
    final keys = [
      ...?_info?.editableKeys,
    ]..sort((a, b) => (_named(a.key) ? 0 : 1).compareTo(_named(b.key) ? 0 : 1));
    if (keys.isEmpty) {
      return const _Hint(
        'This gift has no editable layers (GIF and WebP never do).',
      );
    }
    final shown = _showAllKeys ? keys : keys.take(5).toList();
    return Column(
      children: [
        for (final k in shown) _layerRow(k),
        if (keys.length > shown.length)
          TextButton.icon(
            onPressed: () => setState(() => _showAllKeys = true),
            icon: const Icon(Icons.expand_more_rounded),
            label: Text('Show all ${keys.length} layers'),
          ),
      ],
    );
  }

  Widget _layerRow(EditableKey k) {
    final done = _edited[k.key];
    final icon = switch (k.type) {
      'text' => Icons.text_fields_rounded,
      'image' => Icons.image_rounded,
      _ => Icons.category_outlined,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done != null
              ? Brand.orange.withValues(alpha: 0.6)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: _named(k.key) ? Brand.orange : Colors.white38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  k.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  done == null ? k.type : '${k.type} · $done',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          if (k.type == 'text')
            _action(Icons.edit_rounded, 'Your name', () {
              _player.setText(k.key, Sender.name.value);
              setState(() => _edited[k.key] = 'text: ${Sender.name.value}');
            }),
          if (k.type == 'image')
            _action(Icons.account_circle_rounded, 'Your photo', () async {
              await _player.setImage(
                k.key,
                await Avatars.of(Sender.name.value),
                options: const GiftImageOptions(fit: GiftImageFit.cover),
              );
              setState(() => _edited[k.key] = 'photo');
            }),
          _action(Icons.visibility_off_rounded, 'Hide', () {
            _player.setHidden(k.key, true);
            setState(() => _edited[k.key] = 'hidden');
          }),
          if (done != null)
            _action(Icons.restart_alt_rounded, 'Reset', () {
              _player.clearReplacement(k.key);
              setState(() => _edited.remove(k.key));
            }),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String tip, VoidCallback onTap) => IconButton(
    tooltip: tip,
    visualDensity: VisualDensity.compact,
    iconSize: 20,
    onPressed: onTap,
    icon: Icon(icon),
  );

  Widget _caches() {
    final mem = GiftPlayer.getCache().stats;
    String mb(int b) => '${(b / 1048576).toStringAsFixed(1)} MB';
    Widget tile(
      String title,
      String value,
      String sub,
      IconData icon,
      Color color,
      VoidCallback onClear,
    ) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.22), Brand.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onClear, child: const Text('Clear')),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            tile(
              'Memory',
              mb(mem.bytes),
              '${mem.entries} gifts · ${mem.hits} hits',
              Icons.memory_rounded,
              Brand.cyan,
              () {
                GiftPlayer.getCache().clear();
                setState(() {});
              },
            ),
            const SizedBox(width: 10),
            tile(
              'Disk',
              mb(_diskBytes),
              'downloaded gifts',
              Icons.sd_storage_rounded,
              Brand.violet,
              () async {
                await GiftPlayer.getDiskCache()?.clear();
                await _refreshStats();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        const _Hint(
          'A gift you open again comes from memory in about 1 ms. Gifts from a URL are also kept on disk, so after the app restarts they load without the network.',
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

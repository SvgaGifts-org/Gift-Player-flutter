import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Default size limit of the disk cache: 100 MB of gift files.
const int defaultDiskCacheBytes = 100 * 1024 * 1024;

/// Default time a cached gift file is kept after it was last used: 7 days.
const Duration defaultDiskCacheMaxAge = Duration(days: 7);

/// Keeps downloaded gift files (the encoded bytes, any format) on the device, so a gift fetched once is read from disk instead of
/// the network after the app restarts. Only HTTP(S) sources are stored: files and assets are already on the device, and bytes
/// handed to `load()` are not cached at all.
///
/// A file is stored only after it was parsed and decoded successfully, so an error page served with status 200 never ends up in
/// the cache, and an entry that turns out to be unreadable later is deleted and fetched again. Every method swallows I/O errors:
/// a failing disk cache only means the gift is downloaded.
///
/// The default cache lives in `<system temp>/gift_player_flutter` (the app's cache directory on Android, `tmp/` on iOS), which the
/// operating system may clear when storage runs low. Configure or replace it with `GiftPlayer.setDiskCache`.
class GiftDiskCache {
  GiftDiskCache({
    Directory? directory,
    this.maxBytes = defaultDiskCacheBytes,
    this.maxAge = defaultDiskCacheMaxAge,
  }) : _directoryOverride = directory;

  /// Total size the cache is trimmed to after a write (least recently used files go first).
  final int maxBytes;

  /// Files not used for this long are deleted.
  final Duration maxAge;

  final Directory? _directoryOverride;
  Future<Directory?>? _opening;
  Future<void>? _trimming;
  bool _trimAgain = false;

  static const String _suffix = '.gift';
  static const List<int> _magic = [0x47, 0x50, 0x44, 0x43]; // "GPDC"
  static const int _formatVersion = 1;

  /// Last-used times are refreshed at most this often, so reading a popular gift does not write to the disk every time.
  static const Duration _touchInterval = Duration(hours: 1);

  /// The directory, created on first use; null when it cannot be created (the cache then does nothing).
  Future<Directory?> directory() => _opening ??= () async {
    final dir =
        _directoryOverride ??
        Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}gift_player_flutter',
        );
    try {
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }();

  /// The cached bytes for [url], or null when absent, expired or unreadable.
  Future<Uint8List?> read(String url) async {
    final dir = await directory();
    if (dir == null) return null;
    final file = File(_pathFor(dir, url));
    try {
      final stat = await file.stat();
      if (stat.type == FileSystemEntityType.notFound) return null;
      final now = DateTime.now();
      if (now.difference(stat.modified) > maxAge) {
        await _deleteQuietly(file);
        return null;
      }
      final raw = await file.readAsBytes();
      final payload = _unwrap(raw, url);
      if (payload == null) {
        // Corrupt, or another URL with the same file name (then it is a miss, and the other URL's file is left alone).
        if (!_hasHeader(raw)) await _deleteQuietly(file);
        return null;
      }
      if (now.difference(stat.modified) > _touchInterval) {
        unawaited(file.setLastModified(now).catchError((Object _) {}));
      }
      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Stores [bytes] for [url] (atomically: readers never see half a file), then trims the cache in the background.
  Future<void> write(String url, Uint8List bytes) async {
    final dir = await directory();
    if (dir == null) return;
    final path = _pathFor(dir, url);
    final tmp = File(
      '$path.${Random().nextInt(1 << 32).toRadixString(16)}.tmp',
    );
    try {
      final urlBytes = utf8.encode(url);
      final header = ByteData(9)
        ..setUint8(0, _magic[0])
        ..setUint8(1, _magic[1])
        ..setUint8(2, _magic[2])
        ..setUint8(3, _magic[3])
        ..setUint8(4, _formatVersion)
        ..setUint32(5, urlBytes.length);
      final sink = tmp.openWrite();
      sink
        ..add(header.buffer.asUint8List())
        ..add(urlBytes)
        ..add(bytes);
      await sink.close();
      await tmp.rename(path);
    } catch (_) {
      await _deleteQuietly(tmp);
      return;
    }
    unawaited(trim());
  }

  /// Deletes the entry for [url].
  Future<void> remove(String url) async {
    final dir = await directory();
    if (dir == null) return;
    await _deleteQuietly(File(_pathFor(dir, url)));
  }

  /// Deletes every cached file.
  Future<void> clear() async {
    final dir = await directory();
    if (dir == null) return;
    try {
      await for (final e in dir.list()) {
        if (e is File) await _deleteQuietly(e);
      }
    } catch (_) {}
  }

  /// Total size of the cached files, in bytes.
  Future<int> sizeInBytes() async {
    var total = 0;
    for (final e in await _entries()) {
      total += e.size;
    }
    return total;
  }

  /// Deletes expired files, then the least recently used ones until the cache fits [maxBytes]. Runs after every write.
  /// A call made while a trim is running makes that trim run once more, and completes when it is done.
  Future<void> trim() {
    final running = _trimming;
    if (running != null) {
      _trimAgain = true;
      return running;
    }
    return _trimming = () async {
      try {
        do {
          _trimAgain = false;
          await _trimOnce();
        } while (_trimAgain);
      } finally {
        _trimming = null;
      }
    }();
  }

  Future<void> _trimOnce() async {
    final dir = await directory();
    if (dir == null) return;
    final now = DateTime.now();
    // Temporary files of writes that never finished (the app was killed mid-write).
    try {
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.tmp')) {
          final stat = await e.stat();
          if (now.difference(stat.modified) > const Duration(hours: 1)) {
            await _deleteQuietly(e);
          }
        }
      }
    } catch (_) {}
    final entries = await _entries();
    var total = 0;
    final kept = <_Entry>[];
    for (final e in entries) {
      if (now.difference(e.modified) > maxAge) {
        await _deleteQuietly(e.file);
      } else {
        kept.add(e);
        total += e.size;
      }
    }
    if (total <= maxBytes) return;
    kept.sort((a, b) => a.modified.compareTo(b.modified)); // oldest first
    for (final e in kept) {
      if (total <= maxBytes) break;
      await _deleteQuietly(e.file);
      total -= e.size;
    }
  }

  Future<List<_Entry>> _entries() async {
    final dir = await directory();
    if (dir == null) return const [];
    final out = <_Entry>[];
    try {
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith(_suffix)) continue;
        try {
          final stat = await e.stat();
          out.add(_Entry(e, stat.size, stat.modified));
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  static String _pathFor(Directory dir, String url) =>
      '${dir.path}${Platform.pathSeparator}${fileNameFor(url)}$_suffix';

  /// File name for [url]: two 32-bit FNV-1a hashes. A collision is harmless because each file also stores its URL.
  static String fileNameFor(String url) {
    var a = 0x811c9dc5;
    var b = 0x01000193 ^ 0x5bd1e995;
    for (final c in utf8.encode(url)) {
      a = ((a ^ c) * 0x01000193) & 0xffffffff;
      b = ((b ^ c) * 0x01000193) & 0xffffffff;
    }
    return a.toRadixString(16).padLeft(8, '0') +
        b.toRadixString(16).padLeft(8, '0');
  }

  static bool _hasHeader(Uint8List raw) {
    if (raw.length < 9) return false;
    for (var i = 0; i < 4; i++) {
      if (raw[i] != _magic[i]) return false;
    }
    return raw[4] == _formatVersion;
  }

  /// The payload of a cache file if it is well-formed and stores [url].
  static Uint8List? _unwrap(Uint8List raw, String url) {
    if (!_hasHeader(raw)) return null;
    final n = ByteData.sublistView(raw).getUint32(5);
    if (9 + n > raw.length) return null;
    final stored = utf8.decode(
      Uint8List.sublistView(raw, 9, 9 + n),
      allowMalformed: true,
    );
    if (stored != url) return null;
    return Uint8List.sublistView(raw, 9 + n);
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      await f.delete();
    } catch (_) {}
  }
}

class _Entry {
  _Entry(this.file, this.size, this.modified);
  final File file;
  final int size;
  final DateTime modified;
}

GiftDiskCache? _diskCache = GiftDiskCache();

/// The disk cache used for gifts fetched over HTTP(S), or null when disabled.
GiftDiskCache? getDiskCache() => _diskCache;

/// Replaces the disk cache; pass null to turn disk caching off.
void setDiskCache(GiftDiskCache? cache) => _diskCache = cache;

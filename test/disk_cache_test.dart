import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gift_player_flutter/gift_player_flutter.dart';
import 'package:gift_player_flutter/src/asset.dart'
    show acquireGift, parsesOffThread, isolateThresholdBytes;
import 'package:gift_player_flutter/src/source.dart'
    show fetchBytes, debugResetHttpClient;

import 'helpers/synthetic.dart';

/// A local HTTP server whose answer per path is set by the test; it counts requests and the client ports it saw.
class _Server {
  late HttpServer _s;
  final Map<String, (int, List<int>)> routes = {};
  final Map<String, int> hits = {};
  final Set<int> clientPorts = {};
  Completer<void>? hold; // when set, requests wait for it before answering

  String url(String path) => 'http://127.0.0.1:${_s.port}$path';

  Future<void> start() async {
    _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _s.listen((req) async {
      hits[req.uri.path] = (hits[req.uri.path] ?? 0) + 1;
      clientPorts.add(req.connectionInfo!.remotePort);
      if (hold != null) await hold!.future;
      final r = routes[req.uri.path] ?? (404, 'not found'.codeUnits);
      try {
        req.response.statusCode = r.$1;
        req.response.add(r.$2);
        await req.response.close();
      } catch (_) {}
    });
  }

  Future<void> stop() => _s.close(force: true);
}

Future<Uint8List?> _waitForEntry(GiftDiskCache c, String url) async {
  for (var i = 0; i < 100; i++) {
    final b = await c.read(url);
    if (b != null) return b;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return null;
}

void main() {
  late Directory tmp;
  late GiftDiskCache disk;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('gift_disk_test');
    disk = GiftDiskCache(directory: tmp);
    GiftPlayer.setDiskCache(disk);
    debugResetHttpClient();
  });

  tearDown(() async {
    GiftPlayer.setDiskCache(GiftDiskCache());
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('GiftDiskCache', () {
    test('stores and reads back bytes per URL', () async {
      final a = Uint8List.fromList(List.generate(1000, (i) => i % 251));
      await disk.write('https://cdn/a.svga', a);
      expect(await disk.read('https://cdn/a.svga'), a);
      expect(await disk.read('https://cdn/b.svga'), isNull);
      expect(await disk.sizeInBytes(), greaterThan(1000));
    });

    test(
      'a file stored for another URL under the same name is a miss and is kept',
      () async {
        await disk.write('https://cdn/a.svga', Uint8List.fromList([1, 2, 3]));
        final name = GiftDiskCache.fileNameFor('https://cdn/a.svga');
        final other = File(
          '${tmp.path}/${GiftDiskCache.fileNameFor('https://cdn/b.svga')}.gift',
        );
        await File(
          '${tmp.path}/$name.gift',
        ).copy(other.path); // simulate a hash collision
        expect(await disk.read('https://cdn/b.svga'), isNull);
        expect(other.existsSync(), isTrue);
      },
    );

    test('corrupt files are misses and are deleted', () async {
      final f = File(
        '${tmp.path}/${GiftDiskCache.fileNameFor('https://cdn/x')}.gift',
      );
      await f.writeAsBytes([9, 9, 9, 9, 9, 9, 9, 9, 9, 9]);
      expect(await disk.read('https://cdn/x'), isNull);
      expect(f.existsSync(), isFalse);
    });

    test('entries unused for longer than maxAge expire', () async {
      final c = GiftDiskCache(directory: tmp, maxAge: const Duration(days: 1));
      await c.write('https://cdn/old', Uint8List.fromList([1]));
      final f = File(
        '${tmp.path}/${GiftDiskCache.fileNameFor('https://cdn/old')}.gift',
      );
      await f.setLastModified(DateTime.now().subtract(const Duration(days: 2)));
      expect(await c.read('https://cdn/old'), isNull);
      expect(f.existsSync(), isFalse);
    });

    test('trim keeps the most recently used files within maxBytes', () async {
      final c = GiftDiskCache(directory: tmp, maxBytes: 2500);
      final kb = Uint8List(1000);
      for (final (i, name) in ['a', 'b', 'c'].indexed) {
        await c.write('https://cdn/$name', kb);
        final f = File(
          '${tmp.path}/${GiftDiskCache.fileNameFor('https://cdn/$name')}.gift',
        );
        await f.setLastModified(
          DateTime.now().subtract(Duration(minutes: 10 - i)),
        );
      }
      await c.trim();
      expect(await c.read('https://cdn/a'), isNull); // the oldest went
      expect(await c.read('https://cdn/b'), isNotNull);
      expect(await c.read('https://cdn/c'), isNotNull);
      expect(await c.sizeInBytes(), lessThanOrEqualTo(2500));
    });

    test('clear removes everything', () async {
      await disk.write('https://cdn/a', Uint8List(10));
      await disk.clear();
      expect(await disk.read('https://cdn/a'), isNull);
      expect(await disk.sizeInBytes(), 0);
    });
  });

  group('loading through the disk cache', () {
    late _Server server;
    final gif = gifOf([10, 10]);

    setUp(() async {
      server = _Server();
      await server.start();
    });
    tearDown(() => server.stop());

    test(
      'a downloaded gift is stored and used after a restart (new memory cache) without the network',
      () async {
        server.routes['/a.gif'] = (200, gif);
        final url = server.url('/a.gif');
        (await acquireGift(AssetCache<LoadedGift>(), url)).release();
        expect(server.hits['/a.gif'], 1);
        expect(await _waitForEntry(disk, url), gif);

        final lease = await acquireGift(
          AssetCache<LoadedGift>(),
          url,
        ); // "restart": empty memory cache
        expect(lease.gift.info.format, GiftFormat.gif);
        lease.release();
        expect(server.hits['/a.gif'], 1);
      },
    );

    test('HTTP errors and files that do not parse are not stored', () async {
      server.routes['/page.svga'] = (200, '<html>error page</html>'.codeUnits);
      await expectLater(
        acquireGift(AssetCache<LoadedGift>(), server.url('/missing.gif')),
        throwsA(
          isA<GiftPlayerError>().having(
            (e) => e.code,
            'code',
            GiftErrorCode.network,
          ),
        ),
      );
      await expectLater(
        acquireGift(AssetCache<LoadedGift>(), server.url('/page.svga')),
        throwsA(
          isA<GiftPlayerError>().having(
            (e) => e.code,
            'code',
            GiftErrorCode.unsupportedFormat,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(await disk.sizeInBytes(), 0);
    });

    test(
      'a stored copy that no longer parses is replaced by a fresh download',
      () async {
        server.routes['/a.gif'] = (200, gif);
        final url = server.url('/a.gif');
        await disk.write(
          url,
          Uint8List.fromList('garbage that is no gift'.codeUnits),
        );
        final lease = await acquireGift(AssetCache<LoadedGift>(), url);
        expect(lease.gift.info.format, GiftFormat.gif);
        lease.release();
        expect(server.hits['/a.gif'], 1);
        expect(await _waitForEntry(disk, url), gif);
      },
    );

    test('setDiskCache(null) turns it off', () async {
      GiftPlayer.setDiskCache(null);
      server.routes['/a.gif'] = (200, gif);
      final url = server.url('/a.gif');
      (await acquireGift(AssetCache<LoadedGift>(), url)).release();
      (await acquireGift(AssetCache<LoadedGift>(), url)).release();
      expect(server.hits['/a.gif'], 2);
      expect(await disk.sizeInBytes(), 0);
    });
  });

  group('fetchBytes (shared client)', () {
    late _Server server;
    setUp(() async {
      server = _Server();
      await server.start();
      server.routes['/a'] = (200, [1, 2, 3]);
    });
    tearDown(() => server.stop());

    test('consecutive fetches reuse one connection', () async {
      expect(await fetchBytes(server.url('/a')), [1, 2, 3]);
      expect(await fetchBytes(server.url('/a')), [1, 2, 3]);
      expect(await fetchBytes(server.url('/a')), [1, 2, 3]);
      expect(server.hits['/a'], 3);
      expect(server.clientPorts.length, 1);
    });

    test(
      'aborting cancels that request only; the client keeps working',
      () async {
        server.hold = Completer<void>();
        final ctl = AbortController();
        final pending = fetchBytes(server.url('/a'), signal: ctl.signal);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final sw = Stopwatch()..start();
        ctl.abort();
        await expectLater(
          pending,
          throwsA(
            isA<GiftPlayerError>().having(
              (e) => e.code,
              'code',
              GiftErrorCode.aborted,
            ),
          ),
        );
        expect(sw.elapsedMilliseconds, lessThan(1000));
        server.hold!.complete();
        server.hold = null;
        expect(await fetchBytes(server.url('/a')), [1, 2, 3]);
      },
    );

    test('an already aborted signal fails without a request', () async {
      final ctl = AbortController()..abort();
      await expectLater(
        fetchBytes(server.url('/a'), signal: ctl.signal),
        throwsA(
          isA<GiftPlayerError>().having(
            (e) => e.code,
            'code',
            GiftErrorCode.aborted,
          ),
        ),
      );
      expect(server.hits['/a'], isNull);
    });
  });

  group('which files are parsed off the UI thread', () {
    test('GIF, WebP and PAG never (their header is enough); SVGA from 4 KB', () {
      final bigGif = Uint8List(100000)..setAll(0, gifOf([10]));
      expect(parsesOffThread(bigGif), isFalse);
      final bigPag = Uint8List(100000)..setAll(0, 'PAG'.codeUnits);
      expect(parsesOffThread(bigPag), isFalse);
      final webp = webpAnimOf([100]);
      expect(parsesOffThread(Uint8List(100000)..setAll(0, webp)), isFalse);

      final smallSvga = svga2(frames: 1, sprites: []);
      expect(smallSvga.length, lessThan(isolateThresholdBytes));
      expect(parsesOffThread(smallSvga), isFalse);
      // A 5 KB SVGA (zlib) goes off-thread although it is far below the old 64 KB limit.
      final svga5k = Uint8List(5 * 1024)..setAll(0, smallSvga);
      expect(parsesOffThread(svga5k), isTrue);
    });
  });
}

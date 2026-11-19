import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'abort.dart';
import 'detect.dart';
import 'errors.dart';

/// Where a gift file comes from. A plain `String` works too: `http(s)://...`, `file://...`, `asset:path/in/bundle.svga`, or
/// `scheme:ref` for a scheme taught with `registerResolver`. A `Uint8List` is accepted as the file itself.
sealed class GiftSource {
  const GiftSource();

  /// A file fetched over HTTP(S).
  const factory GiftSource.url(String url) = GiftUrlSource;

  /// A file on the device.
  const factory GiftSource.file(String path) = GiftFileSource;

  /// A Flutter asset (declared in the app's `pubspec.yaml`).
  const factory GiftSource.asset(String name) = GiftAssetSource;

  /// The file's bytes. Not cached (like `ArrayBuffer` / `Blob` in the web package).
  factory GiftSource.bytes(Uint8List bytes) = GiftBytesSource;

  /// Normalises what the API accepts: a [GiftSource], a `String`, or `Uint8List` / `ByteBuffer` / `ByteData`.
  static GiftSource from(Object src) {
    if (src is GiftSource) return src;
    if (src is String) return _fromString(src);
    if (src is Uint8List) return GiftBytesSource(src);
    if (src is ByteData) {
      return GiftBytesSource(
        src.buffer.asUint8List(src.offsetInBytes, src.lengthInBytes),
      );
    }
    if (src is ByteBuffer) return GiftBytesSource(src.asUint8List());
    throw GiftPlayerError(
      GiftErrorCode.invalidInput,
      'Source must be a URL string, a GiftSource, or Uint8List bytes (got ${src.runtimeType}).',
    );
  }

  static GiftSource _fromString(String s) {
    final lower = s.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return GiftUrlSource(s);
    }
    if (lower.startsWith('file://')) {
      return GiftFileSource(Uri.parse(s).toFilePath());
    }
    if (lower.startsWith('asset:')) return GiftAssetSource(s.substring(6));
    if (s.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(s)) {
      return GiftFileSource(s);
    }
    throw GiftPlayerError(
      GiftErrorCode.invalidInput,
      'Cannot tell what "$s" is: use http(s)://, file://, asset:, or a scheme registered with registerResolver.',
    );
  }
}

class GiftUrlSource extends GiftSource {
  const GiftUrlSource(this.url);
  final String url;
}

class GiftFileSource extends GiftSource {
  const GiftFileSource(this.path);
  final String path;
}

class GiftAssetSource extends GiftSource {
  const GiftAssetSource(this.name);
  final String name;
}

class GiftBytesSource extends GiftSource {
  GiftBytesSource(this.bytes);
  final Uint8List bytes;
}

/// Reads [src] fully. URLs are fetched; a fetch is cancelled when [signal] aborts.
Future<Uint8List> readSource(Object src, {AbortSignal? signal}) async {
  final s = GiftSource.from(src);
  signal?.throwIfAborted();
  switch (s) {
    case GiftBytesSource():
      return s.bytes;
    case GiftAssetSource():
      try {
        final data = await rootBundle.load(s.name);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } catch (cause) {
        throw GiftPlayerError(
          GiftErrorCode.network,
          'Failed to read asset ${s.name}',
          cause: cause,
        );
      }
    case GiftFileSource():
      try {
        return await File(s.path).readAsBytes();
      } catch (cause) {
        throw GiftPlayerError(
          GiftErrorCode.network,
          'Failed to read file ${s.path}',
          cause: cause,
        );
      }
    case GiftUrlSource():
      return fetchBytes(s.url, signal: signal);
  }
}

/// Time allowed to open a connection.
const Duration fetchConnectTimeout = Duration(seconds: 20);

/// Longest wait for the response headers, or between two chunks of the body.
const Duration fetchReadTimeout = Duration(seconds: 30);

HttpClient? _sharedClient;

/// One client for every fetch, so consecutive gifts from the same CDN reuse the open (keep-alive) connection instead of paying a
/// new TCP + TLS handshake each time.
HttpClient _client() => _sharedClient ??= HttpClient()
  ..connectionTimeout = fetchConnectTimeout
  ..idleTimeout = const Duration(seconds: 30);

/// Closes the shared client; the next fetch creates a new one (picking up the current `HttpOverrides`). For tests.
@visibleForTesting
void debugResetHttpClient() {
  _sharedClient?.close(force: true);
  _sharedClient = null;
}

/// HTTP GET into memory through the shared client. Aborting cancels this request only.
Future<Uint8List> fetchBytes(String url, {AbortSignal? signal}) async {
  signal?.throwIfAborted();
  HttpClientRequest? request;
  var cancelled = false;
  final abortedNow = Completer<Never>();
  abortedNow.future.ignore();
  final off = signal?.onAbort(() {
    cancelled = true;
    request?.abort();
    if (!abortedNow.isCompleted) {
      abortedNow.completeError(
        GiftPlayerError(GiftErrorCode.aborted, 'The load was aborted.'),
      );
    }
  });
  GiftPlayerError abortedOr(Object cause, String what) =>
      cancelled || (signal?.aborted ?? false)
      ? GiftPlayerError(
          GiftErrorCode.aborted,
          'The load was aborted.',
          cause: cause,
        )
      : GiftPlayerError(GiftErrorCode.network, what, cause: cause);
  try {
    final HttpClientResponse res;
    try {
      final opening = _client().getUrl(Uri.parse(url));
      // A request that opens after the abort is cancelled right away.
      opening.then((r) {
        if (cancelled) r.abort();
      }, onError: (Object _) {});
      final req = request = await Future.any<HttpClientRequest>([
        opening,
        abortedNow.future,
      ]);
      res = await Future.any<HttpClientResponse>([
        req.close().timeout(fetchReadTimeout),
        abortedNow.future,
      ]);
    } catch (cause) {
      throw abortedOr(cause, 'Failed to fetch $url');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // Read the body to the end so the connection can be reused.
      await res.drain<void>().timeout(fetchReadTimeout).catchError((_) {});
      throw GiftPlayerError(
        GiftErrorCode.network,
        'Failed to fetch $url: HTTP ${res.statusCode}',
      );
    }
    try {
      final b = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(fetchReadTimeout)) {
        if (cancelled) break;
        b.add(chunk);
      }
      if (cancelled) {
        throw GiftPlayerError(GiftErrorCode.aborted, 'The load was aborted.');
      }
      return b.takeBytes();
    } on GiftPlayerError {
      rethrow;
    } catch (cause) {
      throw abortedOr(cause, 'Failed to read $url');
    }
  } finally {
    off?.call();
  }
}

/// Reads [src] (URL / file / asset / bytes) and detects its format from magic bytes.
Future<FormatInfo> detectSource(Object src, {AbortSignal? signal}) async =>
    detectFormat(await readSource(src, signal: signal));

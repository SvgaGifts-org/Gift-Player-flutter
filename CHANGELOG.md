# Changelog

## 0.1.1

* Removed old brand name from docs, example app and native ids (Android package and iOS bundle id are now `com.giftplayer.*`).

## 0.1.0

First release of `gift_player_flutter`: play SVGA, GIF, WebP and PAG gifts on Android and iOS.

* SVGA 1.x / 2.x (parsed and drawn in Dart: shapes, mattes, clip paths, text and image replacement), GIF, animated and static WebP
  (platform codec), PAG (native libpag 4.5.85 rendered into a Flutter texture).
* `GiftPlayer`, `GiftQueue`, `AssetCache`, resolvers, `preload`, typed errors, events.
* Widgets: `GiftPlayerView`, `GiftPlayerSurface`, `GiftQueueController`.
* **Disk cache** for gifts fetched over HTTP(S): `GiftDiskCache` (default 100 MB, 7 days, LRU), on by default;
  `GiftPlayer.setDiskCache` / `getDiskCache`. A gift seen before is not downloaded again after the app restarts. Files are stored
  only after they loaded successfully; a stored copy that no longer parses is replaced by a fresh download.
* **One shared HTTP client** for all downloads, so consecutive gifts reuse the open connection. Aborting cancels only that request.
  20 s connect timeout and 30 s read timeout.
* **SVGA parsing off the UI thread from 4 KB**. GIF, WebP and PAG are recognised from their header and do not start an isolate.

Known limitation: the iOS plugin has not been compiled or run on a device yet (Android has: SVGA, GIF, WebP and PAG play on a real phone).

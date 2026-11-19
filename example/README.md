# gift_player_flutter example

A two-tab demo app.

* **Live room**: a mock live stream. Gifts are sent from a drawer (quantity ×1 / ×10 / ×66 / ×99, VIP priority) or by simulated viewers (🔥 *Busy room* = 20 gifts at once). They go through a `GiftQueue` and play full-screen with transparency over the "video". Identical sends merge into one **×N combo**. A chat feed and live counters show what the queue does. Personalised gifts carry the sender: *Birthday Cake* puts the sender's photo in its `sender_avatar` layer. Tap the name chip to change the sender.
* **Studio**: inspect one gift. It plays on a transparency grid (or dark, light, or video-like backdrops), with a frame scrubber, loops (1× / 3× / ∞) and content mode (Fit / Crop / Full). Details show format, canvas, frames and fps, duration and load time. **Editable layers** lists every replaceable layer, named layers first; put your name or photo in a layer, hide it, or reset it. **Caches** shows the memory cache and the disk cache, each with a Clear button.

```sh
cd example
flutter pub get
flutter run            # Android device/emulator or iOS simulator
```

The integration itself is small: see `lib/minimal_example.dart` (a `GiftPlayerView`, and a `GiftQueueController` with a surface and `queue.add`). Everything else in `lib/` is demo UI: `live_room.dart`, `studio.dart`, `catalog.dart` (the gift list), `sender.dart` (name, avatar, replacements) and `ui.dart` (shared widgets).

## Gifts

| Gift | File | Notes |
|---|---|---|
| Birthday Cake | `assets/gifts/birthday-cake.svga` | 750×1334, 6 s; `sender_avatar` image layer |
| Diamond Badge | `assets/gifts/diamond-badge.svga` | 750×750, 5 s, 52 images |
| Crown Frame | `assets/gifts/crown-frame.svga` | 400×400 avatar frame, 4 s |
| Sweet Kiss | `assets/gifts/sweet-kiss.svga` | 750×1334, 3.3 s |
To use your own gifts, put the files in `assets/gifts/` (the folder is already declared in `pubspec.yaml`) and add an entry to `catalog` in `lib/catalog.dart`. The `source` can be `'asset:assets/gifts/<file>'`, a `https://` URL, or bytes. GIF, WebP and PAG files play the same way.

## Test files

`assets/test/` holds files used only by `integration_test/` (they are not in the demo): `rotating-earth.gif` (CC BY-SA 3.0, by Marvel, Wikimedia Commons, based on a NASA Visible Earth image: https://commons.wikimedia.org/wiki/File:Rotating_earth_(large).gif) and `like.pag`, `replacement.pag` (from https://github.com/Tencent/libpag `assets/`, Apache-2.0, Copyright (C) Tencent).

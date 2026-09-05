# pussy-patrol

A quick joke game.

## Deployment

1. In Godot, export the **Web** preset to `exports/html/game.html`.
2. Run `./scripts/publish-pages.sh`
3. Commit and push `docs/`.

GitHub Pages serves `docs/` on the `main` branch (Settings → Pages → Deploy from
a branch). The script rebuilds `docs/` from scratch each time and preserves
`CNAME` and `.nojekyll`.

## How the engine binary is delivered

The Godot 4.7 web release template is a **38 MB** `game.wasm`, and that download
is the whole load time. It ships pre-compressed:

| file | bytes | notes |
| --- | --- | --- |
| `game.wasm` (raw) | 39,513,091 | never published |
| `game.wasm.gz` | 10,054,510 | what browsers download |
| `game.pck` | 2,924,720 | downloads in parallel |

`scripts/publish-pages.sh` gzips the wasm and inlines `scripts/wasm-loader.js`
into the page `<head>`. That loader inflates the binary in the browser with
`DecompressionStream`, starts the wasm and pck downloads during HTML parse
rather than waiting for `game.js`, and keeps the body a stream so
`WebAssembly.instantiateStreaming` compiles while bytes are still arriving.

### Why not Brotli

Brotli compresses this binary to 6.9 MB, 3.1 MB better than gzip, so it is
tempting. It does not work here:

* **No browser can decompress Brotli from JavaScript.** `DecompressionStream`
  accepts only `gzip`, `deflate` and `deflate-raw`. `new
  DecompressionStream('brotli')` throws `TypeError: Unsupported compression
  format` in current Chrome, and there is no shipping implementation elsewhere.
* **Brotli only works as a transport encoding**, which needs the server to send
  `Content-Encoding: br`. GitHub Pages does not let us set response headers.

Two ways to get the 3.1 MB back, neither of which is a repo change:

* Add a **Cloudflare Compression Rule** (the domain is already proxied through
  Cloudflare) forcing Brotli for `application/wasm`, then publish the plain
  `game.wasm` and delete the loader. Cloudflare's on-the-fly Brotli is a lower
  quality level than `brotli -Z`, so expect roughly 8 MB rather than 6.9 MB.
* Install `zopfli` (`brew install zopfli`). The publish script picks it up
  automatically and writes a ~4% smaller gzip stream that every browser already
  decodes. It is far slower than `gzip -9`, so expect the publish step to take
  minutes instead of seconds.

## Repeat visits

The PWA service worker caches the boot files, so a second visit reads the wasm
from Cache Storage and issues no network requests at all. Measured locally:
2.3 s first load, 0.95 s afterwards.

Cross-origin isolation is switched **off** in the export preset
(`progressive_web_app/ensure_cross_origin_isolation_headers=false`). It only
buys `SharedArrayBuffer`, which is useless with `variant/thread_support=false`,
and it made the service worker intercept and re-wrap every single response.

If a stale worker sticks around after a deploy, hard-refresh once or unregister
it under DevTools → Application → Service Workers.

## Ideas not applied

* **A custom engine build is the only large win left.** 34.5 MB of the 38 MB
  wasm is the code section: stock Godot with 3D and every module compiled in.
  Building the web template with `scons platform=web target=template_release
  disable_3d=yes` plus `module_*_enabled=no` for what the game does not use can
  roughly halve it. Needs the Godot source and emsdk.
* **Audio dominates the pck.** `Coffee_Shop_Focus_FULL_SONG.mp3` is 2.2 MB and
  `gameover.wav` is 416 KB, out of a 2.9 MB pack. Re-encoding the music at a
  lower bitrate and the sound effect as Ogg Vorbis would cut most of it. Left
  alone because it trades away audio quality.
* **`exports/` is committed.** Every export adds a fresh 38 MB `game.wasm` blob
  to git history, which is most of why `.git` is already 100 MB. Only `docs/` is
  actually published. To stop it: add `exports/` to `.gitignore` and run
  `git rm -r --cached exports`.
* **`config/icon` does not resolve at runtime.** The exported build logs
  `Unrecognized UID: "uid://cb6etcdw6avi0"` on every start. Harmless on web,
  where the tab icon comes from the HTML, but it is two red lines in the console.

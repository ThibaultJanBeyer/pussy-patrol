#!/usr/bin/env bash
# Publish the Godot Web export in exports/html/ to docs/, which GitHub Pages serves.
#
# What this does beyond a plain copy:
#   * pre-compresses game.wasm to game.wasm.gz (38 MB -> ~10 MB on the wire)
#   * inlines scripts/wasm-loader.js, which inflates it in the browser and
#     starts the wasm + pck downloads during HTML parse
#   * rewrites the favicon / PWA icons and the splash image
#   * points the service worker at the compressed wasm
#   * preserves CNAME and .nojekyll
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/exports/html"
DEST="$ROOT/docs"
LOADER="$ROOT/scripts/wasm-loader.js"
ICON="$ROOT/art/web/icon.png"
SPLASH="$ROOT/art/web/social.png"

die() { echo "$*" >&2; exit 1; }

[[ -f "$SRC/game.html" ]] || die "No web export in $SRC. In Godot, export the Web preset to exports/html/game.html first."
compgen -G "$SRC/game.wasm" > /dev/null || die "Export is incomplete: $SRC/game.wasm is missing."
compgen -G "$SRC/game.pck"  > /dev/null || die "Export is incomplete: $SRC/game.pck is missing."
[[ -f "$LOADER" ]] || die "Missing loader: $LOADER"
[[ -f "$ICON"   ]] || die "Missing game icon: $ICON"
[[ -f "$SPLASH" ]] || die "Missing splash image: $SPLASH"
command -v sips  >/dev/null || die "sips is required to resize the PWA icons (macOS)."
command -v gzip  >/dev/null || die "gzip is required."

# docs/ is rebuilt from scratch; carry the two files Pages needs but Godot never exports.
CNAME=""
if [[ -f "$DEST/CNAME" ]]; then
  CNAME="$(cat "$DEST/CNAME")"
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SRC"/. "$DEST"/

# Godot re-imports anything sitting under the project directory, so the export
# folder collects editor sidecars. They are not part of the site.
find "$DEST" -name '*.import' -delete
find "$DEST" -name '.DS_Store' -delete

cp "$DEST/game.html" "$DEST/index.html"

# Favicon and PWA icons from art/web/icon.png; loading + share splash from social.png.
cp "$ICON" "$DEST/game.icon.png"
cp "$ICON" "$DEST/game.apple-touch-icon.png"
sips -z 144 144 "$ICON" --out "$DEST/game.144x144.png" >/dev/null
sips -z 180 180 "$ICON" --out "$DEST/game.180x180.png" >/dev/null
sips -z 512 512 "$ICON" --out "$DEST/game.512x512.png" >/dev/null
cp "$SPLASH" "$DEST/game.png"

# GitHub Pages cannot serve a Content-Encoding we choose, so the wasm ships
# pre-compressed and scripts/wasm-loader.js inflates it with DecompressionStream.
# Only gzip works: no browser implements DecompressionStream('brotli').
# zopfli, if installed, writes a ~4% smaller but identical-to-decode gzip stream.
echo "Compressing game.wasm ..."
if command -v zopfli >/dev/null; then
  zopfli --gzip -c "$DEST/game.wasm" > "$DEST/game.wasm.gz"
else
  gzip -9 -c "$DEST/game.wasm" > "$DEST/game.wasm.gz"
fi
rm -f "$DEST/game.wasm"

touch "$DEST/.nojekyll"
if [[ -n "$CNAME" ]]; then
  printf '%s\n' "$CNAME" > "$DEST/CNAME"
fi

python3 - "$DEST" "$LOADER" <<'PY'
from pathlib import Path
import json
import re
import sys

dest = Path(sys.argv[1])
loader = Path(sys.argv[2]).read_text().rstrip("\n")

# Inline the loader at the end of <head> so the wasm and pck downloads start
# during HTML parse, before game.js is even requested.
block = "\t\t<script>\n" + loader + "\n\t\t</script>\n\t"

for name in ("game.html", "index.html"):
    path = dest / name
    text = path.read_text()
    if "wasm-loader" not in text:
        text = text.replace("</head>", block + "</head>", 1)
    path.write_text(text)

manifest = dest / "game.manifest.json"
if manifest.exists():
    data = json.loads(manifest.read_text())
    data["start_url"] = "./index.html"
    data["icons"] = [
        {"src": "game.144x144.png", "sizes": "144x144", "type": "image/png", "purpose": "any"},
        {"src": "game.180x180.png", "sizes": "180x180", "type": "image/png", "purpose": "any"},
        {"src": "game.512x512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"},
    ]
    manifest.write_text(json.dumps(data, separators=(",", ":")))

# The service worker caches the boot files so a repeat visit skips the network
# entirely. It has to be told the real filenames we ended up publishing.
sw = dest / "game.service.worker.js"
if sw.exists():
    text = sw.read_text()

    def patch(const, fn):
        def sub(match):
            names = [n.strip().strip('"') for n in match.group(1).split(",") if n.strip()]
            return "const " + const + " = [" + ",".join(f'"{n}"' for n in fn(names)) + "]"

        return re.subn(r"const " + const + r" = \[([^\]]*)\]", sub, text, count=1)

    def cached(names):
        # game.html is published as index.html; the icons come from art/web/.
        names = [n for n in names if n != "game.html"]
        for extra in ("game.png", "game.144x144.png", "game.180x180.png", "game.512x512.png"):
            if extra not in names:
                names.append(extra)
        return ["index.html"] + [n for n in names if n != "index.html"]

    def cacheable(names):
        names = ["game.wasm.gz" if n == "game.wasm" else n for n in names]
        if "game.wasm.gz" not in names:
            names.append("game.wasm.gz")
        return names

    for const, fn in (("CACHED_FILES", cached), ("CACHEABLE_FILES", cacheable)):
        text, n = patch(const, fn)
        if n == 0:
            print(f"warning: could not patch {const} in the service worker", file=sys.stderr)
    sw.write_text(text)
PY

raw=$(stat -f%z "$SRC/game.wasm")
gz=$(stat -f%z "$DEST/game.wasm.gz")
echo
echo "Published $SRC -> $DEST"
echo "  game.wasm.gz  $(du -h "$DEST/game.wasm.gz" | cut -f1) on the wire (from $(du -h "$SRC/game.wasm" | cut -f1), $((gz * 100 / raw))%)"
echo "  game.pck      $(du -h "$DEST/game.pck" | cut -f1)"
echo
echo "GitHub Pages: Settings -> Pages -> Deploy from a branch -> main -> /docs"
echo "Then commit and push docs/."

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/exports/html"
DEST="$ROOT/docs"
ICON="$ROOT/art/web/icon.png"
SPLASH="$ROOT/art/web/social.png"

if [[ ! -f "$SRC/game.html" && ! -f "$SRC/index.html" ]]; then
  echo "No web export in $SRC." >&2
  echo "In Godot, export the Web preset to exports/html/game.html first." >&2
  exit 1
fi

if ! compgen -G "$SRC"/*.wasm > /dev/null || ! compgen -G "$SRC"/*.pck > /dev/null; then
  echo "Export is incomplete: $SRC is missing .wasm or .pck." >&2
  exit 1
fi

if [[ ! -f "$ICON" ]]; then
  echo "Missing game icon: $ICON" >&2
  exit 1
fi

if [[ ! -f "$SPLASH" ]]; then
  echo "Missing splash image: $SPLASH" >&2
  exit 1
fi

CNAME=""
if [[ -f "$DEST/CNAME" ]]; then
  CNAME="$(cat "$DEST/CNAME")"
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SRC"/. "$DEST"/

# Drop editor import sidecars that sometimes land in the export folder.
find "$DEST" -name '*.import' -delete

if [[ -f "$DEST/game.html" ]]; then
  cp "$DEST/game.html" "$DEST/index.html"
fi

# Favicon + PWA icons from art/web/icon.png; loading splash from social.png.
cp "$ICON" "$DEST/game.icon.png"
cp "$ICON" "$DEST/game.apple-touch-icon.png"
sips -z 144 144 "$ICON" --out "$DEST/game.144x144.png" >/dev/null
sips -z 180 180 "$ICON" --out "$DEST/game.180x180.png" >/dev/null
sips -z 512 512 "$ICON" --out "$DEST/game.512x512.png" >/dev/null
cp "$SPLASH" "$DEST/game.png"

touch "$DEST/.nojekyll"

if [[ -n "$CNAME" ]]; then
  printf '%s\n' "$CNAME" > "$DEST/CNAME"
fi

python3 - "$DEST" <<'PY'
from pathlib import Path
import json
import re
import sys

dest = Path(sys.argv[1])

manifest_path = dest / "game.manifest.json"
if manifest_path.exists():
    data = json.loads(manifest_path.read_text())
    data["start_url"] = "./index.html"
    data["icons"] = [
        {"src": "game.144x144.png", "sizes": "144x144", "type": "image/png", "purpose": "any"},
        {"src": "game.180x180.png", "sizes": "180x180", "type": "image/png", "purpose": "any"},
        {"src": "game.512x512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"},
    ]
    manifest_path.write_text(json.dumps(data, separators=(",", ":")))

sw_path = dest / "game.service.worker.js"
if sw_path.exists():
    text = sw_path.read_text()

    def patch_cached(match: re.Match[str]) -> str:
        entries = [item.strip().strip('"') for item in match.group(1).split(",") if item.strip()]
        entries = [name for name in entries if name != "game.html"]
        if "index.html" not in entries:
            entries.insert(0, "index.html")
        return "const CACHED_FILES = [" + ",".join(f'"{name}"' for name in entries) + "]"

    text, count = re.subn(
        r"const CACHED_FILES = \[([^\]]*)\]",
        patch_cached,
        text,
        count=1,
    )
    if count:
        sw_path.write_text(text)
PY

echo "Published $SRC -> $DEST"
echo "Icons: $ICON → favicon/PWA; $SPLASH → game.png splash"
echo "GitHub Pages: Settings → Pages → Deploy from a branch → main → /docs"
echo "Then commit and push docs/."

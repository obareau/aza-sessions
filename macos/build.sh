#!/usr/bin/env bash
# Construit « AZA Sessions.app » — universelle (Intel + Apple Silicon), macOS 12+.
#
# Sur un Mac, depuis la racine du dépôt :
#     macos/build.sh
#
# Prérequis :
#   - le Python de python.org (« macOS 64-bit universal2 installer ») : c'est lui
#     qui rend l'app universelle et compatible macOS 12. Celui de Homebrew ne
#     convient PAS (une seule architecture, et la version de macOS qui l'a compilé).
#   - les outils en ligne de commande Xcode (`xcode-select --install`) pour swiftc.
#
# Sortie : macos/dist/AZA Sessions.app, AZA-Sessions-<version>.dmg et .zip
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
BUILD="$HERE/build"
DIST="$HERE/dist"
APP="$DIST/AZA Sessions.app"
MIN_MACOS="12.0"
VERSION="$(sed -n 's/^VERSION *= *"\([^"]*\)".*/\1/p' "$ROOT/app.py")"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"

step() { printf '\n\033[1;38;5;208m▸ %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m✕ %s\033[0m\n' "$*" >&2; exit 1; }

[ -n "$VERSION" ] || fail "VERSION introuvable dans app.py"

# ── Python universel ─────────────────────────────────────────────────────────
PY="${PYTHON:-}"
if [ -z "$PY" ]; then
  for c in /Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12 \
           /Library/Frameworks/Python.framework/Versions/3.13/bin/python3.13; do
    [ -x "$c" ] && { PY="$c"; break; }
  done
fi
[ -n "$PY" ] || fail "Python de python.org introuvable — https://www.python.org/downloads/macos/"
PYEXE="$("$PY" -c 'import os, sys; print(os.path.realpath(sys.executable))')"
PYARCHS="$(lipo -archs "$PYEXE")"
[[ "$PYARCHS" == *x86_64* && "$PYARCHS" == *arm64* ]] \
  || fail "$PY n'est pas universel ($PYARCHS) — il faut l'installeur universal2 de python.org"
step "AZA Sessions $VERSION (build $BUILD_NUMBER) — Python $("$PY" -V 2>&1 | cut -d' ' -f2) [$PYARCHS]"

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD" "$DIST"

# ── Environnement ───────────────────────────────────────────────────────────
step "Environnement de build"
"$PY" -m venv "$BUILD/venv"
VPY="$BUILD/venv/bin/python"
"$VPY" -m pip install -q --upgrade pip
"$VPY" -m pip install -q -r "$HERE/requirements-app.txt"

# pip installe la roue de l'architecture qui tourne (arm64 OU x86_64) : on la
# remplace par la roue universelle, sans quoi PyInstaller refuse le build.
step "MarkupSafe universel"
MS="$("$VPY" -c 'import importlib.metadata as m; print(m.version("markupsafe"))')"
PYV="$("$VPY" -c 'import sys; print(f"{sys.version_info[0]}{sys.version_info[1]}")')"
# (MarkupSafe 3.0.3+ ne publie plus de roue universelle : le repli est alors normal.)
if "$VPY" -m pip download -q --no-deps --only-binary=:all: \
     --platform macosx_10_13_universal2 --platform macosx_10_9_universal2 \
     --platform macosx_11_0_universal2 --python-version "$PYV" \
     --implementation cp --abi "cp$PYV" -d "$BUILD/wheels" "markupsafe==$MS"; then
  "$VPY" -m pip install -q --force-reinstall --no-deps "$BUILD"/wheels/*.whl
else
  # Pas de roue universelle : MarkupSafe sait se passer de son accélérateur C.
  echo "  (pas de roue universelle — accélérateur C retiré)"
  find "$BUILD/venv" -path '*markupsafe/_speedups*.so' -delete
fi

step "Selftest depuis les sources"
"$VPY" "$HERE/server_main.py" --selftest

# ── Serveur Python ──────────────────────────────────────────────────────────
step "Serveur embarqué (PyInstaller, universal2)"
"$VPY" -m PyInstaller --noconfirm --clean --log-level WARN \
  --distpath "$BUILD/pyi-dist" --workpath "$BUILD/pyi-work" "$HERE/aza-server.spec"

# ── App Swift ───────────────────────────────────────────────────────────────
step "App (Swift — arm64 + x86_64, macOS $MIN_MACOS+)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
for arch in arm64 x86_64; do
  xcrun swiftc -O -swift-version 5 -parse-as-library -sdk "$SDK" -target "$arch-apple-macos$MIN_MACOS" \
    "$HERE"/AZASessions/*.swift -o "$BUILD/AZASessions-$arch"
done

# ── Assemblage ──────────────────────────────────────────────────────────────
step "Assemblage du bundle"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/AZA Sessions" \
  "$BUILD/AZASessions-arm64" "$BUILD/AZASessions-x86_64"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" \
  "$HERE/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" "$HERE/AppIcon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$HERE/AppIcon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

ditto "$BUILD/pyi-dist/aza-server" "$APP/Contents/Resources/aza-server"

# ── Signature & vérifications ───────────────────────────────────────────────
step "Signature ad hoc"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

step "Binaires : Intel + Apple Silicon, macOS $MIN_MACOS minimum"
"$VPY" "$HERE/scripts/verifier_binaires.py" "$APP" "$MIN_MACOS"

step "Selftest du binaire embarqué ($(uname -m))"
"$APP/Contents/Resources/aza-server/aza-server" --selftest

# ── Distribution ────────────────────────────────────────────────────────────
step "Image disque"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/AZA Sessions.app"
ln -s /Applications "$STAGE/Applications"
cp "$HERE/LISEZMOI.txt" "$STAGE/LISEZMOI.txt"
DMG="$DIST/AZA-Sessions-$VERSION.dmg"
for attempt in 1 2 3; do
  hdiutil create -quiet -volname "AZA Sessions $VERSION" -srcfolder "$STAGE" \
    -ov -format UDZO "$DMG" && break
  [ "$attempt" = 3 ] && fail "hdiutil a échoué trois fois"
  sleep 5
done
# Le .zip garde droits et liens (ditto) : c'est lui que la CI se repasse.
ditto -c -k --keepParent "$APP" "$DIST/AZA-Sessions-$VERSION.zip"

step "Prêt"
ls -lh "$DIST"

#!/bin/sh
# cargo-heal installer (binary-only distribution).
# Usage: curl -fsSL https://raw.githubusercontent.com/gist-rs/cargo-heal/main/install.sh | sh
set -eu

REPO="gist-rs/cargo-heal"
DEST="${CARGO_HEAL_INSTALL_DIR:-$HOME/.cargo/bin}"

need() { command -v "$1" >/dev/null 2>&1; }
need curl || { echo "error: curl is required" >&2; exit 1; }

OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS" in
    Darwin)
        case "$ARCH" in
            arm64) TARGET="aarch64-apple-darwin" ;;
            x86_64) TARGET="x86_64-apple-darwin" ;;
            *) echo "error: unsupported macOS arch: $ARCH" >&2; exit 1 ;;
        esac
        ;;
    Linux)
        case "$ARCH" in
            x86_64 | amd64) TARGET="x86_64-unknown-linux-musl" ;;
            aarch64 | arm64) TARGET="aarch64-unknown-linux-musl" ;;
            *) echo "error: unsupported Linux arch: $ARCH" >&2; exit 1 ;;
        esac
        ;;
    *)
        echo "error: unsupported OS: $OS (windows: use install.ps1)" >&2
        exit 1
        ;;
esac

# Latest release tag via the public API (public repo — no auth).
TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
[ -n "$TAG" ] || { echo "error: cannot resolve the latest release (none published yet?)" >&2; exit 1; }

BASE="https://github.com/$REPO/releases/download/$TAG"
ASSET="cargo-heal-$TAG-$TARGET.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "fetching $ASSET ..."
curl -fsSL -o "$TMP/$ASSET" "$BASE/$ASSET"
curl -fsSL -o "$TMP/SHA256SUMS" "$BASE/SHA256SUMS"

# Verify the archive hash against the release's SHA256SUMS.
want="$(awk -v f="$ASSET" '$2==f{print $1}' "$TMP/SHA256SUMS")"
[ -n "$want" ] || { echo "error: $ASSET not listed in SHA256SUMS" >&2; exit 1; }
if need sha256sum; then
    got="$(sha256sum "$TMP/$ASSET" | awk '{print $1}')"
elif need shasum; then
    got="$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')"
else
    echo "error: need sha256sum or shasum to verify the download" >&2
    exit 1
fi
[ "$got" = "$want" ] || { echo "error: checksum mismatch (want $want, got $got)" >&2; exit 1; }

mkdir -p "$DEST"
tar -xzf "$TMP/$ASSET" -C "$TMP"
mv "$TMP/cargo-heal" "$DEST/cargo-heal"
chmod +x "$DEST/cargo-heal"

echo "installed cargo-heal $TAG ($TARGET) -> $DEST/cargo-heal"
case ":$PATH:" in
    *":$DEST:"*) ;;
    *) echo "note: $DEST is not on your PATH - add it to use 'cargo heal'" ;;
esac

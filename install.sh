#!/usr/bin/env sh
set -eu

OWNER="kuopenx"
REPO="dart-vm"
LOCAL_BIN="$HOME/.local/bin"

case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux) OS="linux" ;;
  *) echo "Unsupported operating system: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

case "$OS/$ARCH" in
  darwin/amd64|darwin/arm64|linux/amd64) ;;
  *) echo "No released binary for $OS/$ARCH" >&2; exit 1 ;;
esac

ZIP_NAME="dart-vm-$OS-$ARCH.zip"
RELEASE_ROOT="https://github.com/$OWNER/$REPO/releases/latest/download"
TMP_DIR=$(mktemp -d)
INSTALL_TMP=""

cleanup() {
  rm -rf "$TMP_DIR"
  if [ -n "$INSTALL_TMP" ]; then
    rm -f "$INSTALL_TMP"
  fi
}
trap cleanup EXIT

echo "Downloading $ZIP_NAME..."
curl -fsSL -o "$TMP_DIR/$ZIP_NAME" "$RELEASE_ROOT/$ZIP_NAME"
curl -fsSL -o "$TMP_DIR/checksums.txt" "$RELEASE_ROOT/checksums.txt"

EXPECTED=$(awk -v name="$ZIP_NAME" '$2 == name { print $1; exit }' "$TMP_DIR/checksums.txt")
if [ -z "$EXPECTED" ]; then
  echo "No checksum found for $ZIP_NAME" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL=$(sha256sum "$TMP_DIR/$ZIP_NAME" | awk '{ print $1 }')
else
  ACTUAL=$(shasum -a 256 "$TMP_DIR/$ZIP_NAME" | awk '{ print $1 }')
fi

if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "Checksum mismatch: expected $EXPECTED, got $ACTUAL" >&2
  exit 1
fi

unzip -q "$TMP_DIR/$ZIP_NAME" -d "$TMP_DIR/extract"
mkdir -p "$LOCAL_BIN"
INSTALL_TMP="$LOCAL_BIN/.dart-vm.install.$$"
install -m 755 "$TMP_DIR/extract/dart-vm" "$INSTALL_TMP"
mv -f "$INSTALL_TMP" "$LOCAL_BIN/dart-vm"
INSTALL_TMP=""

echo "Installed dart-vm to $LOCAL_BIN/dart-vm"
case ":$PATH:" in
  *":$LOCAL_BIN:"*) ;;
  *)
    echo "Add this directory to PATH:" >&2
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
    ;;
esac

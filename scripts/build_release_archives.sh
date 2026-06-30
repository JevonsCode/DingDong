#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${DINGDONG_VERSION:-0.1.0}}"
BUILD_NUMBER="${DINGDONG_BUILD:-1}"
RELEASE_DIR="$ROOT_DIR/dist/release"

mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR"/DingDong-*.zip

for ARCH in arm64 x86_64; do
  if [[ "$ARCH" == "arm64" ]]; then
    LABEL="apple-silicon"
  else
    LABEL="intel"
  fi

  OUTPUT_APP="DingDong-$LABEL.app"
  DINGDONG_ARCH="$ARCH" \
    DINGDONG_VERSION="$VERSION" \
    DINGDONG_BUILD="$BUILD_NUMBER" \
    DINGDONG_OUTPUT_APP="$OUTPUT_APP" \
    "$ROOT_DIR/scripts/package_app.sh"

  ditto -c -k --sequesterRsrc --keepParent \
    "$ROOT_DIR/dist/$OUTPUT_APP" \
    "$RELEASE_DIR/DingDong-$VERSION-$LABEL.zip"
done

echo "$RELEASE_DIR"

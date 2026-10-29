#!/bin/bash
# Installe Godot (headless) dans les sessions cloud de Claude Code, pour lancer les tests.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.3-stable"
GODOT_DIR="$HOME/.local/share/godot-$GODOT_VERSION"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_SHA512="fd52bb4ba8acc30ca5accd1c566d470ad7282f891ccc0995dfafabcf92bcf76280ce182bf9d80ebd885f3ed2165d01e1fc3f2928436b15498dfbd98656c2a45a"

if [ ! -x "$GODOT_BIN" ]; then
  mkdir -p "$GODOT_DIR"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  echo "$GODOT_SHA512  $tmp/godot.zip" | sha512sum --check --status
  unzip -q -o "$tmp/godot.zip" -d "$GODOT_DIR"
  chmod +x "$GODOT_BIN"
  rm -rf "$tmp"
fi

mkdir -p "$HOME/.local/bin"
ln -sf "$GODOT_BIN" "$HOME/.local/bin/godot"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

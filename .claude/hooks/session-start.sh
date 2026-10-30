#!/bin/bash
# Installe Godot (headless) dans les sessions cloud de Claude Code, pour lancer les tests.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.6.1-stable"
GODOT_DIR="$HOME/.local/share/godot-$GODOT_VERSION"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_SHA512="a76fd0fe1d44a2dd6c065b6f7b434ad75f5593c07bda3d3017f8304f2d069acbcf0f39cb5d0976f0434b56e9ea852032ddbcbdb7e0ce1c75a47e1dacb6794bd7"

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

#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot/godot}"
if [[ ! -x "$godot_bin" ]]; then
  godot_bin="$(command -v godot || command -v godot4)"
fi
exec "$godot_bin" --path . "$@"

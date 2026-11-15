#!/usr/bin/env bash
# Capture the actual Godot window with a software OpenGL display.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p artifacts
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/purr-godot-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/purr-godot-config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/purr-godot-cache}"
godot_bin="${GODOT_BIN:-$PWD/.tools/godot/godot}"
"$godot_bin" --headless --path . --editor --import --quit
capture() {
  xvfb-run -a "$godot_bin" --path . --rendering-method gl_compatibility --audio-driver Dummy -- "$@" --screenshot
}
case "${1:-solo}" in
  solo) capture --showcase ;;
  versus)
    capture --versus-showcase
    capture --versus-lobby
    capture --versus-showcase --versus-pause
    ;;
  all)
    capture --showcase
    capture --title-showcase
    capture --versus-showcase
    capture --versus-lobby
    capture --versus-showcase --versus-pause
    ;;
  *) printf 'Usage: bash scripts/preview.sh [solo|versus|all]\n' >&2; exit 2 ;;
esac
printf 'Screenshots saved under artifacts/\n'

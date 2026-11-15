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
  yarn)
    capture --showcase
    capture --showcase --vertical-pair
    capture --versus-showcase
    ;;
  versus)
    capture --versus-showcase
    capture --versus-lobby
    capture --versus-showcase --versus-pause
    ;;
  outcomes)
    capture --won-showcase
    capture --lost-showcase
    capture --versus-showcase --versus-result
    ;;
  all)
    capture --showcase
    capture --showcase --vertical-pair
    capture --title-showcase
    capture --versus-showcase
    capture --versus-lobby
    capture --versus-showcase --versus-pause
    capture --won-showcase
    capture --lost-showcase
    capture --versus-showcase --versus-result
    ;;
  *) printf 'Usage: bash scripts/preview.sh [solo|versus|outcomes|yarn|all]\n' >&2; exit 2 ;;
esac
printf 'Screenshots saved under artifacts/\n'

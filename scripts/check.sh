#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
godot_bin="${GODOT_BIN:-$PWD/.tools/godot/godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/tmp/purr-godot-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/purr-godot-config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/purr-godot-cache}"
check_log="$(mktemp /tmp/purr-check.XXXXXX)"
trap 'rm -f "$check_log"' EXIT
run_godot() {
  "$godot_bin" "$@" > "$check_log" 2>&1 || { cat "$check_log"; return 1; }
  cat "$check_log"
  # Godot can exit 0 even when a script fails to load.
  if rg -q 'SCRIPT ERROR|Parse Error|Failed to load script' "$check_log"; then
    return 1
  fi
}
run_godot --headless --path . --editor --import --quit
for script in scripts/*.gd; do
  run_godot --headless --path . --script "$script" --check-only
done
run_godot --headless --path . --script tests/test_rules.gd
run_godot --headless --path . --script tests/test_versus.gd
run_godot --headless --path . --script tests/test_speed.gd
run_godot --headless --path . --script tests/test_ui.gd
run_godot --headless --path . --script tests/test_versus_ui.gd
run_godot --headless --path . --quit-after 10
python3 -m unittest discover -s tests -v

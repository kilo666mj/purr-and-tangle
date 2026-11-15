#!/usr/bin/env bash
# Run in a terminal with network access. Installs only inside this project.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p .tools/godot
curl --fail --location --retry 2 \
  'https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=linux.x86_64.zip&platform=linux.64' \
  --output .tools/godot/godot.zip
python3 - <<'PY'
from pathlib import Path
import zipfile
p = Path('.tools/godot')
name = 'Godot_v4.7.2-stable_linux.x86_64'
with zipfile.ZipFile(p / 'godot.zip') as archive:
    (p / 'godot').write_bytes(archive.read(name))
(p / 'godot').chmod(0o755)
(p / 'godot.zip').unlink()
PY
.tools/godot/godot --headless --version

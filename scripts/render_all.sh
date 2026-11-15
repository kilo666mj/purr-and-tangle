#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
export OCIO="$PWD/scripts/srgb.ocio"
mkdir -p artifacts assets/renders
# At most two Blender processes, two CPU threads each.
blender -b -noaudio -t 2 --python scripts/render_models.py -- cat_orange cat_blue cat_purple > artifacts/render-cats.log 2>&1 &
cats_pid=$!
blender -b -noaudio -t 2 --python scripts/render_models.py -- yarn_orange yarn_blue yarn_purple > artifacts/render-yarn.log 2>&1 &
yarn_pid=$!
result=0
wait "$cats_pid" || result=1
wait "$yarn_pid" || result=1
exit "$result"

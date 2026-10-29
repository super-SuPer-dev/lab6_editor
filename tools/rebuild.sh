#!/bin/bash
# Regenerate all scenes from tools/build.gd, then run the logic playtest.
# Usage (Git Bash): tools/rebuild.sh   (run from the project folder; set GODOT if needed)
GODOT=${GODOT:-/d/D_Godot/Engine/godot_console.exe}
HERE=$(cd "$(dirname "$0")/.." && pwd -W)
"$GODOT" --headless --path "$HERE" --script "$HERE/tools/build.gd" 2>&1 | grep -E 'saved|ERROR|SCRIPT'
"$GODOT" --headless --path "$HERE" --script "$HERE/tools/playtest.gd" 2>&1 | grep -E 'PASS|FAIL|RESULT'

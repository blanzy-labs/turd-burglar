#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr03_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R03 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 45 "$godot_bin" --headless --path "$repo_root" --script tests/tbr03_beetle_locomotion_acceptance.gd -- --level=restroom_003 >"$artifact_dir/tbr03-locomotion.log" 2>&1 || fail locomotion_model
for marker in TBR03_IDLE_STATE_OK TBR03_PHASE_ADVANCEMENT_OK TBR03_SIX_LEG_COVERAGE_OK TBR03_TRIPOD_OPPOSITION_OK TBR03_BODY_ANTENNA_MOTION_OK TBR03_IDLE_RETURN_OK TBR03_SPEED_SCALING_OK TBR03_GROUNDING_COLLISION_OK TBR03_BEETLE_LOCOMOTION_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr03-locomotion.log" || fail "marker_$marker"
done
printf 'Locomotion model .... PASS\n'

"$repo_root/tests/run_tbr02_acceptance.sh" "$artifact_dir/regression/tbr02" >"$artifact_dir/regression/tbr02.log" 2>&1 || fail tbr02_regression
grep -Fxq TBR02_ACCEPTANCE_OK "$artifact_dir/regression/tbr02.log" || fail tbr02_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS' 'TB-R01 regression ... PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr02.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-R01 regression ... PASS\nTB-R02 regression ... PASS\n'

timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr03_beetle_locomotion_acceptance.gd -- --level=restroom_003 --locomotion-pose=idle --screenshot-locomotion="$artifact_dir/idle-beetle.png" >"$artifact_dir/idle-beetle.log" 2>&1 || fail idle_screenshot
grep -Fxq "TBR03_IDLE_SCREENSHOT_OK=$artifact_dir/idle-beetle.png" "$artifact_dir/idle-beetle.log" || fail idle_screenshot_marker
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr03_beetle_locomotion_acceptance.gd -- --level=restroom_003 --locomotion-pose=moving --screenshot-locomotion="$artifact_dir/moving-beetle.png" >"$artifact_dir/moving-beetle.log" 2>&1 || fail moving_screenshot
grep -Fxq "TBR03_MOVING_SCREENSHOT_OK=$artifact_dir/moving-beetle.png" "$artifact_dir/moving-beetle.log" || fail moving_screenshot_marker
for image in idle-beetle.png moving-beetle.png; do
	file -b "$artifact_dir/$image" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$image"
done
idle_sha=$(sha256sum "$artifact_dir/idle-beetle.png" | cut -d' ' -f1)
moving_sha=$(sha256sum "$artifact_dir/moving-beetle.png" | cut -d' ' -f1)
[[ $idle_sha != "$moving_sha" ]] || fail locomotion_screenshots_identical
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr02/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr02/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
binary="$artifact_dir/build/turd-burglar.x86_64"
[[ -x $binary ]] || fail qa_binary_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail qa_binary_elf
for level_id in restroom_001 restroom_002 restroom_003; do
	timeout 30 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "exported_$level_id"
	grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_level_$level_id"
	grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_marker_$level_id"
done
printf 'Linux QA build ...... PASS\n'

total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --arg binary "$binary" --arg idle "$artifact_dir/idle-beetle.png" --arg moving "$artifact_dir/moving-beetle.png" --argjson total "$total_seconds" \
	'{slice:"TB-R03",status:$status,locomotion:{idle:"pass",phase_advancement:"pass",tripod_opposition:"pass",six_leg_coverage:"pass",speed_scaling:"pass",idle_return:"pass",body_antenna_motion:"pass",grounding:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbr01:"pass",tbr02:"pass"},godot_static:"pass",screenshots:{idle:$idle,moving:$moving},linux_binary:$binary,exported_runtime:"pass",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR03_ACCEPTANCE_OK\n'

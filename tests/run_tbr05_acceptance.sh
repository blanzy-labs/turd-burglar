#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr05_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R05 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 120 "$godot_bin" --headless --path "$repo_root" --script tests/tbr05_pickup_feedback_acceptance.gd >"$artifact_dir/tbr05-pickup-feedback.log" 2>&1 || fail pickup_feedback
for marker in TBR05_COLLECTION_ONCE_OK TBR05_TARGET_STATE_OK TBR05_EMPTY_TOILET_OK TBR05_NEAREST_PROMPT_OK TBR05_TBR06_IMMEDIATE_THRESHOLD_OK TBR05_HUD_FEEDBACK_OK TBR05_FINAL_EXIT_OK TBR05_RESTROOM_004_OK TBR05_PICKUP_FEEDBACK_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr05-pickup-feedback.log" || fail "marker_$marker"
done
printf 'Pickup feedback ...... PASS\n'

"$repo_root/tests/run_tbr06_acceptance.sh" "$artifact_dir/regression/tbr06" >"$artifact_dir/regression/tbr06.log" 2>&1 || fail tbr06_regression
grep -Fxq TBR06_ACCEPTANCE_OK "$artifact_dir/regression/tbr06.log" || fail tbr06_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS' 'TB-H01 stabilization  PASS' 'TB-R01 regression ... PASS' 'TB-R02 regression ... PASS' 'TB-R03 regression ... PASS' 'TB-R03A regression .. PASS' 'TB-R04 identity ..... PASS' 'TB-R04B regression .. PASS' 'TB-R04C regression .. PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr06.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-H01 stabilization  PASS\nTB-R01 regression ... PASS\nTB-R02 regression ... PASS\nTB-R03 regression ... PASS\nTB-R03A regression .. PASS\nTB-R04 identity ..... PASS\nTB-R04B regression .. PASS\nTB-R04C regression .. PASS\nTB-R06 regression ... PASS\n'

for state in normal-collectible targeted-collectible pickup-feedback hud-feedback final-exit door-threshold; do
	timeout 75 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr05_pickup_feedback_acceptance.gd -- --evidence="$state" --screenshot-feedback="$artifact_dir/$state.png" >"$artifact_dir/$state.log" 2>&1 || fail "screenshot_$state"
	marker=$(printf '%s' "$state" | tr '[:lower:]-' '[:upper:]_')
	grep -Fxq "TBR05_${marker}_SCREENSHOT_OK=$artifact_dir/$state.png" "$artifact_dir/$state.log" || fail "screenshot_marker_$state"
	file -b "$artifact_dir/$state.png" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$state"
done
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr06/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr06/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
binary="$artifact_dir/build/turd-burglar.x86_64"
[[ -x $binary ]] || fail qa_binary_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail qa_binary_elf
for level_id in restroom_001 restroom_002 restroom_003 restroom_004; do
	timeout 35 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "exported_$level_id"
	grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_level_$level_id"
	grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_marker_$level_id"
done
printf 'Linux QA build ...... PASS\n'

total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --arg binary "$binary" --arg normal "$artifact_dir/normal-collectible.png" --arg targeted "$artifact_dir/targeted-collectible.png" --arg pickup "$artifact_dir/pickup-feedback.png" --arg hud "$artifact_dir/hud-feedback.png" --arg final "$artifact_dir/final-exit.png" --arg door "$artifact_dir/door-threshold.png" --argjson total "$total_seconds" \
	'{slice:"TB-R05",status:$status,collection:{authoritative_immediate:"pass",signal_once:"pass",duplicate_rejected:"pass",empty_rejected:"pass"},feedback:{targeting:"pass",pickup_animation:"pass",plus_one:"pass",counter_punch:"pass",exit_unlock:"pass"},tbr06:{threshold:2,door_closed_at_one:"pass",door_opening_at_two:"pass",trigger_fire_count:1,door_open_count:1,animation_overlap:"pass",restroom_004:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbh01:"pass",tbr01:"pass",tbr02:"pass",tbr03:"pass",tbr03a:"pass",tbr04_identity:"pass",tbr04b:"pass",tbr04c:"pass",tbr06:"pass"},godot_static:"pass",screenshots:{normal:$normal,targeted:$targeted,pickup:$pickup,hud:$hud,final_exit:$final,door_threshold:$door},linux_binary:$binary,exported_runtime:"pass",human_qa:"pending",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR05_ACCEPTANCE_OK\n'

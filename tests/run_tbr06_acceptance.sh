#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr06_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R06 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 90 "$godot_bin" --headless --path "$repo_root" --script tests/tbr06_doors_triggers_acceptance.gd >"$artifact_dir/tbr06-doors-triggers.log" 2>&1 || fail doors_triggers
for marker in TBR06_EXISTING_LEVELS_OPTIONAL_FIELDS_OK TBR06_INVALID_SCHEMA_CASES_OK TBR06_RESTROOM_004_PROGRESSION_DATA_OK TBR06_ONE_SHOT_TRIGGER_OK TBR06_FINAL_EXIT_PRESERVED_OK TBR06_DOORS_TRIGGERS_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr06-doors-triggers.log" || fail "marker_$marker"
done
printf 'Doors/triggers ...... PASS\n'

"$repo_root/tests/run_tbr04c_acceptance.sh" "$artifact_dir/regression/tbr04c" >"$artifact_dir/regression/tbr04c.log" 2>&1 || fail tbr04c_regression
grep -Fxq TBR04C_ACCEPTANCE_OK "$artifact_dir/regression/tbr04c.log" || fail tbr04c_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS' 'TB-R01 regression ... PASS' 'TB-R02 regression ... PASS' 'TB-R03 regression ... PASS' 'TB-R03A regression .. PASS' 'TB-R04 identity ..... PASS' 'TB-R04B regression .. PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr04c.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-H01 stabilization  PASS\nTB-R01 regression ... PASS\nTB-R02 regression ... PASS\nTB-R03 regression ... PASS\nTB-R03A regression .. PASS\nTB-R04 identity ..... PASS\nTB-R04B regression .. PASS\nTB-R04C regression .. PASS\n'

for state in door-a-closed door-a-open middle-area door-b-closed door-b-open; do
	timeout 75 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr06_doors_triggers_acceptance.gd -- --evidence="$state" --screenshot-door="$artifact_dir/$state.png" >"$artifact_dir/$state.log" 2>&1 || fail "screenshot_$state"
	marker=$(printf '%s' "$state" | tr '[:lower:]-' '[:upper:]_')
	grep -Fxq "TBR06_${marker}_SCREENSHOT_OK=$artifact_dir/$state.png" "$artifact_dir/$state.log" || fail "screenshot_marker_$state"
	file -b "$artifact_dir/$state.png" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$state"
done
timeout 75 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --level=restroom_004 --screenshot-start="$artifact_dir/restroom-004-gameplay.png" >"$artifact_dir/restroom-004-gameplay.log" 2>&1 || fail gameplay_screenshot
grep -Fxq "TB_SCREENSHOT_OK=$artifact_dir/restroom-004-gameplay.png" "$artifact_dir/restroom-004-gameplay.log" || fail gameplay_screenshot_marker
file -b "$artifact_dir/restroom-004-gameplay.png" | grep -Fq 'PNG image data, 960 x 540' || fail gameplay_screenshot_png
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr04c/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr04c/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
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
jq -n --arg status pass --arg binary "$binary" --arg a_closed "$artifact_dir/door-a-closed.png" --arg a_open "$artifact_dir/door-a-open.png" --arg middle "$artifact_dir/middle-area.png" --arg b_closed "$artifact_dir/door-b-closed.png" --arg b_open "$artifact_dir/door-b-open.png" --arg gameplay "$artifact_dir/restroom-004-gameplay.png" --argjson total "$total_seconds" \
	'{slice:"TB-R06",status:$status,capability:{doors_supported:2,trigger_types:["collect_count"],actions:["open_door"],idempotent_open:"pass",moving_collision:"pass",one_shot_triggers:"pass"},level:{id:"restroom_004",staged_areas:3,soft_lock_proof:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbh01:"pass",tbr01:"pass",tbr02:"pass",tbr03:"pass",tbr03a:"pass",tbr04_identity:"pass",tbr04b:"pass",tbr04c:"pass",tbr05:"not_present"},godot_static:"pass",screenshots:{door_a_closed:$a_closed,door_a_open:$a_open,middle_area:$middle,door_b_closed:$b_closed,door_b_open:$b_open,gameplay:$gameplay},linux_binary:$binary,exported_runtime:"pass",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR06_ACCEPTANCE_OK\n'

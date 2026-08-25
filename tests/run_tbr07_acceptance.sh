#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr07_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R07 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 180 "$godot_bin" --headless --path "$repo_root" --script tests/tbr07_hazard_acceptance.gd >"$artifact_dir/tbr07-hazards.log" 2>&1 || fail hazard_acceptance
for marker in TBR07_EXISTING_LEVELS_OPTIONAL_HAZARDS_OK TBR07_INVALID_SCHEMA_CASES_OK TBR07_SAFE_RESET_LAYOUT_OK TBR07_RESTROOM_005_DATA_OK TBR07_RUNTIME_INSTANTIATION_OK TBR07_NON_PLAYER_IGNORED_OK TBR07_PLAYER_RESET_OK TBR07_PROGRESSION_PRESERVED_OK TBR07_REENTRY_OK TBR07_EXIT_PRESERVED_OK TBR07_HAZARD_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr07-hazards.log" || fail "marker_$marker"
done
printf 'Hazard acceptance ... PASS\n'

"$repo_root/tests/run_tbr05_acceptance.sh" "$artifact_dir/regression/tbr05" >"$artifact_dir/regression/tbr05.log" 2>&1 || fail tbr05_regression
grep -Fxq TBR05_ACCEPTANCE_OK "$artifact_dir/regression/tbr05.log" || fail tbr05_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS' 'TB-H01 stabilization  PASS' 'TB-R01 regression ... PASS' 'TB-R02 regression ... PASS' 'TB-R03 regression ... PASS' 'TB-R03A regression .. PASS' 'TB-R04 identity ..... PASS' 'TB-R04B regression .. PASS' 'TB-R04C regression .. PASS' 'TB-R06 regression ... PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr05.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-H01 stabilization  PASS\nTB-R01 regression ... PASS\nTB-R02 regression ... PASS\nTB-R03 regression ... PASS\nTB-R03A regression .. PASS\nTB-R04 identity ..... PASS\nTB-R04B regression .. PASS\nTB-R04C regression .. PASS\nTB-R05 regression ... PASS\nTB-R06 regression ... PASS\n'

for state in restroom-005 hazard-before-entry hazard-entry post-reset door-preserved exit-unlocked; do
	timeout 90 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr07_hazard_acceptance.gd -- --evidence="$state" --screenshot-hazard="$artifact_dir/$state.png" >"$artifact_dir/$state.log" 2>&1 || fail "screenshot_$state"
	marker=$(printf '%s' "$state" | tr '[:lower:]-' '[:upper:]_')
	grep -Fxq "TBR07_${marker}_SCREENSHOT_OK=$artifact_dir/$state.png" "$artifact_dir/$state.log" || fail "screenshot_marker_$state"
	file -b "$artifact_dir/$state.png" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$state"
done
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr05/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr05/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
binary="$artifact_dir/build/turd-burglar.x86_64"
[[ -x $binary ]] || fail qa_binary_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail qa_binary_elf
for level_id in restroom_001 restroom_002 restroom_003 restroom_004 restroom_005; do
	timeout 35 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "exported_$level_id"
	grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_level_$level_id"
	grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_marker_$level_id"
done
printf 'Linux QA build ...... PASS\n'

total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --arg binary "$binary" --arg gameplay "$artifact_dir/restroom-005.png" --arg before "$artifact_dir/hazard-before-entry.png" --arg entry "$artifact_dir/hazard-entry.png" --arg reset "$artifact_dir/post-reset.png" --arg door "$artifact_dir/door-preserved.png" --arg final "$artifact_dir/exit-unlocked.png" --argjson total "$total_seconds" \
	'{slice:"TB-R07",status:$status,capability:{hazard_types:["reset_zone"],data_driven:"pass",spatial_detection:"pass",one_activation_per_entry:"pass",reentry:"pass",non_player_ignored:"pass"},preservation:{objective:"pass",toilets:"pass",doors:"pass",triggers:"pass",exit:"pass",scene_reload:false},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbh01:"pass",tbr01:"pass",tbr02:"pass",tbr03:"pass",tbr03a:"pass",tbr04_identity:"pass",tbr04b:"pass",tbr04c:"pass",tbr05:"pass",tbr06:"pass"},godot_static:"pass",screenshots:{restroom_005:$gameplay,hazard_before_entry:$before,hazard_entry:$entry,post_reset:$reset,door_preserved:$door,exit_unlocked:$final},linux_binary:$binary,exported_runtime:"pass",levels:["restroom_001","restroom_002","restroom_003","restroom_004","restroom_005"],human_qa:"pending",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR07_ACCEPTANCE_OK\n'

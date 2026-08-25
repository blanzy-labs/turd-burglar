#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr08_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R08 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 240 "$godot_bin" --headless --path "$repo_root" --script tests/tbr08_special_turds_acceptance.gd >"$artifact_dir/tbr08-special-turds.log" 2>&1 || fail special_turds
for marker in TBR08_LEGACY_NORMAL_DEFAULT_OK TBR08_SCHEMA_CASES_OK TBR08_OPTIONAL_POWER_ROUTE_OK TBR08_RESTROOM_006_DATA_OK TBR08_VISUAL_IDENTITY_OK TBR08_OBJECTIVE_DOOR_ORDER_OK TBR08_DUPLICATE_PROTECTION_OK TBR08_TURBO_RUNTIME_OK TBR08_REFRESH_AND_COEXISTENCE_OK TBR08_EFFECT_EXPIRY_HUD_OK TBR08_GHOST_HAZARD_COMPOSITION_OK TBR08_TURBO_SURVIVES_RESET_OK TBR08_FINAL_EXIT_OK TBR08_SPECIAL_TURDS_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr08-special-turds.log" || fail "marker_$marker"
done
printf 'Special turds ....... PASS\n'

"$repo_root/tests/run_tbr07_acceptance.sh" "$artifact_dir/regression/tbr07" >"$artifact_dir/regression/tbr07.log" 2>&1 || fail tbr07_regression
grep -Fxq TBR07_ACCEPTANCE_OK "$artifact_dir/regression/tbr07.log" || fail tbr07_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS' 'TB-H01 stabilization  PASS' 'TB-R01 regression ... PASS' 'TB-R02 regression ... PASS' 'TB-R03 regression ... PASS' 'TB-R03A regression .. PASS' 'TB-R04 identity ..... PASS' 'TB-R04B regression .. PASS' 'TB-R04C regression .. PASS' 'TB-R05 regression ... PASS' 'TB-R06 regression ... PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr07.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-H01 stabilization  PASS\nTB-R01 regression ... PASS\nTB-R02 regression ... PASS\nTB-R03 regression ... PASS\nTB-R03A regression .. PASS\nTB-R04 identity ..... PASS\nTB-R04B regression .. PASS\nTB-R04C regression .. PASS\nTB-R05 regression ... PASS\nTB-R06 regression ... PASS\nTB-R07 regression ... PASS\n'

for state in normal-turd hot-shit ghost-turd turbo-hud ghost-hud both-effects ghost-hazard restroom-006 final-exit; do
	timeout 90 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr08_special_turds_acceptance.gd -- --evidence="$state" --screenshot-special="$artifact_dir/$state.png" >"$artifact_dir/$state.log" 2>&1 || fail "screenshot_$state"
	marker=$(printf '%s' "$state" | tr '[:lower:]-' '[:upper:]_')
	grep -Fxq "TBR08_${marker}_SCREENSHOT_OK=$artifact_dir/$state.png" "$artifact_dir/$state.log" || fail "screenshot_marker_$state"
	file -b "$artifact_dir/$state.png" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$state"
done
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr07/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr07/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
binary="$artifact_dir/build/turd-burglar.x86_64"
[[ -x $binary ]] || fail qa_binary_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail qa_binary_elf
for level_id in restroom_001 restroom_002 restroom_003 restroom_004 restroom_005 restroom_006; do
	timeout 35 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "exported_$level_id"
	grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_level_$level_id"
	grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_marker_$level_id"
done
printf 'Linux QA build ...... PASS\n'

total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --arg binary "$binary" --arg normal "$artifact_dir/normal-turd.png" --arg hot "$artifact_dir/hot-shit.png" --arg ghost "$artifact_dir/ghost-turd.png" --arg turbo_hud "$artifact_dir/turbo-hud.png" --arg ghost_hud "$artifact_dir/ghost-hud.png" --arg both "$artifact_dir/both-effects.png" --arg crossing "$artifact_dir/ghost-hazard.png" --arg gameplay "$artifact_dir/restroom-006.png" --arg final "$artifact_dir/final-exit.png" --argjson total "$total_seconds" \
	'{slice:"TB-R08",status:$status,capability:{turd_types:["normal","turbo","ghost"],timed_effects:["turbo","ghost"],refresh_without_stacking:"pass",independent_timers:"pass"},composition:{ghost_hazard_immunity:"pass",post_ghost_reset:"pass",turbo_survives_reset:"pass",door_objective_order:"pass",final_exit:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbh01:"pass",tbr01:"pass",tbr02:"pass",tbr03:"pass",tbr03a:"pass",tbr04_identity:"pass",tbr04b:"pass",tbr04c:"pass",tbr05:"pass",tbr06:"pass",tbr07:"pass"},godot_static:"pass",screenshots:{normal:$normal,hot_shit:$hot,ghost_turd:$ghost,turbo_hud:$turbo_hud,ghost_hud:$ghost_hud,both_effects:$both,ghost_hazard:$crossing,restroom_006:$gameplay,final_exit:$final},linux_binary:$binary,exported_runtime:"pass",levels:["restroom_001","restroom_002","restroom_003","restroom_004","restroom_005","restroom_006"],human_qa:"pending",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR08_ACCEPTANCE_OK\n'

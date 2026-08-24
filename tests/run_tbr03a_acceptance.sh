#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr03a_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R03A FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 45 "$godot_bin" --headless --path "$repo_root" --script tests/tbr03a_grounded_gait_acceptance.gd -- --level=restroom_003 >"$artifact_dir/tbr03a-grounded.log" 2>&1 || fail grounded_gait
for marker in TBR03A_SIX_ARTICULATED_LEGS_OK TBR03A_GROUNDING_TOLERANCE_OK TBR03A_UPPER_LOWER_ARTICULATION_OK TBR03A_SUPPORT_SWING_HEIGHT_OK TBR03A_TRIPOD_OPPOSITION_OK TBR03A_BODY_ARTICULATION_LIMITS_OK TBR03A_IDLE_RECOVERY_OK TBR03A_GROUNDED_GAIT_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr03a-grounded.log" || fail "marker_$marker"
done
printf 'Grounded gait ....... PASS\n'

"$repo_root/tests/run_tbr03_acceptance.sh" "$artifact_dir/regression/tbr03" >"$artifact_dir/regression/tbr03.log" 2>&1 || fail tbr03_regression
grep -Fxq TBR03_ACCEPTANCE_OK "$artifact_dir/regression/tbr03.log" || fail tbr03_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS' 'TB-R01 regression ... PASS' 'TB-R02 regression ... PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr03.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-R01 regression ... PASS\nTB-R02 regression ... PASS\nTB-R03 regression ... PASS\n'

timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr03a_grounded_gait_acceptance.gd -- --level=restroom_003 --grounded-pose=idle --screenshot-grounded="$artifact_dir/idle-grounding.png" >"$artifact_dir/idle-grounding.log" 2>&1 || fail idle_screenshot
grep -Fxq "TBR03A_IDLE_SCREENSHOT_OK=$artifact_dir/idle-grounding.png" "$artifact_dir/idle-grounding.log" || fail idle_screenshot_marker
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr03a_grounded_gait_acceptance.gd -- --level=restroom_003 --grounded-pose=moving --screenshot-grounded="$artifact_dir/moving-grounding.png" >"$artifact_dir/moving-grounding.log" 2>&1 || fail moving_screenshot
grep -Fxq "TBR03A_MOVING_SCREENSHOT_OK=$artifact_dir/moving-grounding.png" "$artifact_dir/moving-grounding.log" || fail moving_screenshot_marker
for image in idle-grounding.png moving-grounding.png; do
	file -b "$artifact_dir/$image" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$image"
done
idle_sha=$(sha256sum "$artifact_dir/idle-grounding.png" | cut -d' ' -f1)
moving_sha=$(sha256sum "$artifact_dir/moving-grounding.png" | cut -d' ' -f1)
[[ $idle_sha != "$moving_sha" ]] || fail grounding_screenshots_identical
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr03/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr03/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
binary="$artifact_dir/build/turd-burglar.x86_64"
[[ -x $binary ]] || fail qa_binary_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail qa_binary_elf
for level_id in restroom_001 restroom_002 restroom_003; do
	timeout 30 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "exported_$level_id"
	grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_level_$level_id"
	grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_marker_$level_id"
done
printf 'Linux QA build ...... PASS\n'

previous_foot=$(sed -n 's/^TBR03A_PRE_REFINEMENT_APPROX_FOOT_Y=//p' "$artifact_dir/tbr03a-grounded.log")
new_min=$(sed -n 's/^TBR03A_NEUTRAL_.*_FOOT_Y=//p' "$artifact_dir/tbr03a-grounded.log" | sort -n | head -1)
new_max=$(sed -n 's/^TBR03A_NEUTRAL_.*_FOOT_Y=//p' "$artifact_dir/tbr03a-grounded.log" | sort -n | tail -1)
total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --arg binary "$binary" --arg idle "$artifact_dir/idle-grounding.png" --arg moving "$artifact_dir/moving-grounding.png" --argjson previous "$previous_foot" --argjson new_min "$new_min" --argjson new_max "$new_max" --argjson total "$total_seconds" \
	'{slice:"TB-R03A",status:$status,grounding:{pre_refinement_approx_min_y:$previous,neutral_lower_leg_min_y:$new_min,neutral_lower_leg_max_y:$new_max},articulation:{six_upper_lower_legs:"pass",tripod_opposition:"pass",support_swing_height:"pass",body_limits:"pass",idle_recovery:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbr01:"pass",tbr02:"pass",tbr03:"pass"},godot_static:"pass",screenshots:{idle:$idle,moving:$moving},linux_binary:$binary,exported_runtime:"pass",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR03A_ACCEPTANCE_OK\n'

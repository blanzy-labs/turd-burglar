#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr04a_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R04A FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 45 "$godot_bin" --headless --path "$repo_root" --script tests/tbr04a_shell_stripe_refinement_acceptance.gd >"$artifact_dir/tbr04a-shell-band.log" 2>&1 || fail shell_band_refinement
for marker in TBR04A_CHARACTER_STRUCTURE_OK TBR04A_HORIZONTAL_BODY_BANDING_OK TBR04A_FRONT_SHELL_PLACEMENT_OK TBR04A_DARK_REAR_SEGMENT_OK TBR04A_IDENTITY_PRESERVED_OK TBR04A_SHELL_STRIPE_REFINEMENT_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr04a-shell-band.log" || fail "marker_$marker"
done
printf 'Shell-band geometry . PASS\n'

"$repo_root/tests/run_tbr04_acceptance.sh" "$artifact_dir/regression/tbr04" >"$artifact_dir/regression/tbr04.log" 2>&1 || fail tbr04_regression
grep -Fxq TBR04_ACCEPTANCE_OK "$artifact_dir/regression/tbr04.log" || fail tbr04_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS' 'TB-R01 regression ... PASS' 'TB-R02 regression ... PASS' 'TB-R03 regression ... PASS' 'TB-R03A regression .. PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr04.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-R01 regression ... PASS\nTB-R02 regression ... PASS\nTB-R03 regression ... PASS\nTB-R03A regression .. PASS\nTB-R04 regression ... PASS\n'

timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr04a_shell_stripe_refinement_acceptance.gd -- --screenshot-shell-band="$artifact_dir/shell-band-three-quarter.png" >"$artifact_dir/shell-band-three-quarter.log" 2>&1 || fail shell_band_screenshot
grep -Fxq "TBR04A_SHELL_BAND_SCREENSHOT_OK=$artifact_dir/shell-band-three-quarter.png" "$artifact_dir/shell-band-three-quarter.log" || fail shell_band_screenshot_marker
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --level=restroom_003 --screenshot-start="$artifact_dir/normal-gameplay.png" >"$artifact_dir/normal-gameplay.log" 2>&1 || fail normal_screenshot
grep -Fxq "TB_SCREENSHOT_OK=$artifact_dir/normal-gameplay.png" "$artifact_dir/normal-gameplay.log" || fail normal_screenshot_marker
for image in shell-band-three-quarter.png normal-gameplay.png; do
	file -b "$artifact_dir/$image" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$image"
done
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr04/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr04/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
binary="$artifact_dir/build/turd-burglar.x86_64"
[[ -x $binary ]] || fail qa_binary_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail qa_binary_elf
for level_id in restroom_001 restroom_002 restroom_003; do
	timeout 30 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "exported_$level_id"
	grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_level_$level_id"
	grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_marker_$level_id"
done
printf 'Linux QA build ...... PASS\n'

y_span=$(sed -n 's/^TBR04A_STRIPE_CENTER_Y_SPAN=//p' "$artifact_dir/tbr04a-shell-band.log")
z_span=$(sed -n 's/^TBR04A_STRIPE_CENTER_Z_SPAN=//p' "$artifact_dir/tbr04a-shell-band.log")
total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --arg binary "$binary" --arg side "$artifact_dir/shell-band-three-quarter.png" --arg normal "$artifact_dir/normal-gameplay.png" --argjson y_span "$y_span" --argjson z_span "$z_span" --argjson total "$total_seconds" \
	'{slice:"TB-R04A",status:$status,shell_band:{orientation:"front_to_rear",stripe_center_y_span:$y_span,stripe_center_z_span:$z_span,front_segment:"pass",dark_rear_abdomen:"pass"},character:{integrated_face:"pass",six_legs:"pass",two_antennae:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbr01:"pass",tbr02:"pass",tbr03:"pass",tbr03a:"pass",tbr04:"pass"},godot_static:"pass",screenshots:{side_three_quarter:$side,normal_gameplay:$normal},linux_binary:$binary,exported_runtime:"pass",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR04A_ACCEPTANCE_OK\n'

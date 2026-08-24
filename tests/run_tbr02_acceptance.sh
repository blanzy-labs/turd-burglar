#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr02_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R02 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/tbr02_player_identity_acceptance.gd >"$artifact_dir/tbr02-identity.log" 2>&1 || fail player_identity
for marker in TBR02_CORE_ANATOMY_OK TBR02_SIX_LEGS_OK TBR02_TWO_ANTENNAE_OK TBR02_FORWARD_AND_MASK_OK TBR02_LOW_POLY_SCALE_OK TBR02_COLLISION_CAMERA_OK TBR02_PLAYER_IDENTITY_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr02-identity.log" || fail "marker_$marker"
done
printf 'Player identity ..... PASS\n'

"$repo_root/tests/run_tbr01_acceptance.sh" "$artifact_dir/regression/tbr01" >"$artifact_dir/regression/tbr01.log" 2>&1 || fail tbr01_regression
grep -Fxq TBR01_ACCEPTANCE_OK "$artifact_dir/regression/tbr01.log" || fail tbr01_regression_marker
for marker in 'TB-001 regression ... PASS' 'TB-002 regression ... PASS' 'TB-003 regression ... PASS'; do
	grep -Fq "$marker" "$artifact_dir/regression/tbr01.log" || fail "regression_$marker"
done
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\nTB-R01 regression ... PASS\n'

timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --level=restroom_003 --screenshot-start="$artifact_dir/normal-gameplay.png" >"$artifact_dir/normal-gameplay.log" 2>&1 || fail normal_screenshot
grep -Fxq "TB_SCREENSHOT_OK=$artifact_dir/normal-gameplay.png" "$artifact_dir/normal-gameplay.log" || fail normal_screenshot_marker
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 --script tests/tbr02_player_identity_acceptance.gd -- --screenshot-character="$artifact_dir/character-close.png" >"$artifact_dir/character-close.log" 2>&1 || fail character_screenshot
grep -Fxq "TBR02_CHARACTER_SCREENSHOT_OK=$artifact_dir/character-close.png" "$artifact_dir/character-close.log" || fail character_screenshot_marker
for image in normal-gameplay.png character-close.png; do
	file -b "$artifact_dir/$image" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$image"
done
printf 'Rendered evidence ... PASS\n'

cp "$artifact_dir/regression/tbr01/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tbr01/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
binary="$artifact_dir/build/turd-burglar.x86_64"
[[ -x $binary ]] || fail qa_binary_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail qa_binary_elf
for level_id in restroom_001 restroom_002 restroom_003; do
	timeout 30 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "exported_$level_id"
	grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_level_$level_id"
	grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "exported_marker_$level_id"
done
printf 'Linux QA build ...... PASS\n'

visual_height=$(sed -n 's/^TBR02_VISUAL_HEIGHT=//p' "$artifact_dir/tbr02-identity.log")
total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --arg binary "$binary" --arg normal "$artifact_dir/normal-gameplay.png" --arg close "$artifact_dir/character-close.png" --argjson height "$visual_height" --argjson total "$total_seconds" \
	'{slice:"TB-R02",status:$status,character:{core_anatomy:"pass",legs:6,antennae:2,mask:"pass",forward_orientation:"pass",low_poly:"pass",visual_height:$height},controller:{tbr01:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass",tbr01:"pass"},godot_static:"pass",screenshots:{normal:$normal,character:$close},linux_binary:$binary,exported_runtime:"pass",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR02_ACCEPTANCE_OK\n'

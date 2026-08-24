#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tbr01_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-R01 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/tbr01_movement_acceptance.gd >"$artifact_dir/tbr01-movement.log" 2>&1 || fail movement_model
for marker in TBR01_CAMERA_FORWARD_OK TBR01_CAMERA_ROTATION_OK TBR01_STRAFE_FACING_OK TBR01_BACKPEDAL_FACING_OK TBR01_DIAGONAL_NORMALIZATION_OK TBR01_SMOOTH_FACING_OK TBR01_IDLE_CAMERA_FREEDOM_OK TBR01_CAMERA_PRESERVATION_OK TBR01_MOVEMENT_ACCEPTANCE_OK; do
	grep -Fxq "$marker" "$artifact_dir/tbr01-movement.log" || fail "marker_$marker"
done
printf 'Movement model ...... PASS\n'

"$repo_root/tests/run_tb003_acceptance.sh" "$artifact_dir/regression/tb003" >"$artifact_dir/regression/tb003.log" 2>&1 || fail tb003_regression
grep -Fxq TB003_ACCEPTANCE_OK "$artifact_dir/regression/tb003.log" || fail tb003_regression_marker
grep -Fq 'TB-001 regression ... PASS' "$artifact_dir/regression/tb003.log" || fail tb001_regression_marker
grep -Fq 'TB-002 regression ... PASS' "$artifact_dir/regression/tb003.log" || fail tb002_regression_marker
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\nTB-003 regression ... PASS\n'

cp "$artifact_dir/regression/tb003/build/turd-burglar.x86_64" "$artifact_dir/build/turd-burglar.x86_64" || fail qa_binary_copy
cp "$artifact_dir/regression/tb003/build/turd-burglar.pck" "$artifact_dir/build/turd-burglar.pck" || fail qa_pack_copy
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
jq -n --arg status pass --arg binary "$binary" --argjson total "$total_seconds" \
	'{slice:"TB-R01",status:$status,movement:{camera_forward:"pass",camera_rotation:"pass",strafe_facing:"pass",backpedal_facing:"pass",diagonal_normalization:"pass",smooth_rotation:"pass",idle_camera_freedom:"pass"},regression:{tb001:"pass",tb002:"pass",tb003:"pass"},godot_static:"pass",linux_binary:$binary,exported_runtime:"pass",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TBR01_ACCEPTANCE_OK\n'

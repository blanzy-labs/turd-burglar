#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tb003_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
mkdir -p "$artifact_dir/build" "$artifact_dir/regression"

fail() { printf 'TB-003 FAIL [%s]\n' "$1" >&2; exit 1; }
elapsed() { awk -v start="$1" -v end="$2" 'BEGIN {printf "%.3f",(end-start)/1000000000}'; }

timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-static.log" 2>&1 || fail godot_static
grep -Fxq TB001_STATIC_OK "$artifact_dir/godot-static.log" || fail tb001_static_marker
grep -Fxq TB002_STATIC_OK "$artifact_dir/godot-static.log" || fail tb002_static_marker
printf 'Godot static ........ PASS\n'

timeout 45 "$godot_bin" --headless --path "$repo_root" --script tests/tb003_level_acceptance.gd -- --level=restroom_003 >"$artifact_dir/tb003-level.log" 2>&1 || fail tb003_level
for marker in TB003_LEVEL_DATA_OK TB003_TEST_START_STATE_OK TB003_TEST_EMPTY_TOILETS_OK TB003_TEST_DUPLICATE_PROTECTION_OK TB003_EXIT_UNLOCKED TB003_HEIST_COMPLETE TB003_GAMEPLAY_ACCEPTANCE_OK; do
  grep -Fxq "$marker" "$artifact_dir/tb003-level.log" || fail "marker_$marker"
done
printf 'TB-003 gameplay ..... PASS\n'

timeout 30 "$godot_bin" --headless --path "$repo_root" -- --self-test --level=restroom_003 >"$artifact_dir/tb003-runtime.log" 2>&1 || fail tb003_runtime
for marker in TB_LEVEL_LOADED=restroom_003 TB_SELF_TEST_OK=restroom_003; do grep -Fxq "$marker" "$artifact_dir/tb003-runtime.log" || fail "runtime_$marker"; done
expected_toilets=$(sed -n 's/^TB003_TOILETS=//p' "$artifact_dir/tb003-level.log")
expected_collectibles=$(sed -n 's/^TB003_COLLECTIBLE_TURDS=//p' "$artifact_dir/tb003-level.log")
grep -Fxq "TB_TOILETS=$expected_toilets" "$artifact_dir/tb003-runtime.log" || fail runtime_toilet_count
grep -Fxq "TB_COLLECTIBLE_TURDS=$expected_collectibles" "$artifact_dir/tb003-runtime.log" || fail runtime_collectible_count
grep -Fxq "TB_REQUIRED_TURDS=$expected_collectibles" "$artifact_dir/tb003-runtime.log" || fail runtime_objective_count
printf 'Runtime markers ..... PASS\n'

"$repo_root/tests/run_tb001_acceptance.sh" "$artifact_dir/regression/tb001" >"$artifact_dir/regression/tb001.log" 2>&1 || fail tb001_regression
"$repo_root/tests/run_tb002_acceptance.sh" "$artifact_dir/regression/tb002" >"$artifact_dir/regression/tb002.log" 2>&1 || fail tb002_regression
grep -Fxq TB001_ACCEPTANCE_OK "$artifact_dir/regression/tb001.log" || fail tb001_regression_marker
grep -Fxq TB002_ACCEPTANCE_OK "$artifact_dir/regression/tb002.log" || fail tb002_regression_marker
printf 'TB-001 regression ... PASS\nTB-002 regression ... PASS\n'

timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --level=restroom_003 --screenshot-start="$artifact_dir/restroom-003-start.png" >"$artifact_dir/screenshot.log" 2>&1 || fail screenshot
grep -Fxq "TB_SCREENSHOT_OK=$artifact_dir/restroom-003-start.png" "$artifact_dir/screenshot.log" || fail screenshot_marker
file -b "$artifact_dir/restroom-003-start.png" | grep -Fq 'PNG image data, 960 x 540' || fail screenshot_png
printf 'Rendered screenshot . PASS\n'

binary="$artifact_dir/build/turd-burglar.x86_64"
timeout 120 "$godot_bin" --headless --path "$repo_root" --export-release 'Linux x86_64' "$binary" >"$artifact_dir/export.log" 2>&1 || fail linux_export
[[ -x $binary ]] || fail export_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail export_elf
[[ -f ${binary%.x86_64}.pck ]] || fail export_pck
timeout 30 "$binary" --headless -- --export-self-test --level=restroom_003 >"$artifact_dir/exported-runtime.log" 2>&1 || fail exported_runtime
for marker in TB_LEVEL_LOADED=restroom_003 TB_EXPORT_RUNTIME_OK=restroom_003; do grep -Fxq "$marker" "$artifact_dir/exported-runtime.log" || fail "exported_$marker"; done
printf 'Linux export/runtime  PASS\n'

total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n --arg status pass --argjson total "$total_seconds" --argjson toilets "$expected_toilets" --argjson collectibles "$expected_collectibles" \
  --arg screenshot "$artifact_dir/restroom-003-start.png" --arg binary "$binary" \
  '{slice:"TB-003",status:$status,level_id:"restroom_003",counts:{toilets:$toilets,collectibles:$collectibles},regression:{tb001:"pass",tb002:"pass"},godot_static:"pass",gameplay:"pass",screenshot:$screenshot,linux_binary:$binary,exported_runtime:"pass",total_seconds:$total}' >"$artifact_dir/result.json"
printf 'TB003_ACCEPTANCE_OK\n'

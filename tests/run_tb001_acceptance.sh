#!/usr/bin/env bash
set -u

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tb001_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)

mkdir -p "$artifact_dir/build"

elapsed() {
  awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", (end-start)/1000000000 }'
}

fail() {
  printf 'TB-001 FAIL [%s]\n' "$1" >&2
  exit 1
}

phase_start=$(date +%s%N)
timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-validation.log" 2>&1 || fail godot_static
grep -Fxq 'TB001_STATIC_OK' "$artifact_dir/godot-validation.log" || fail godot_static_marker
static_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Godot static .... PASS\n'

phase_start=$(date +%s%N)
timeout 30 "$godot_bin" --headless --path "$repo_root" -- --self-test >"$artifact_dir/godot-runtime.log" 2>&1 || fail godot_runtime
grep -Fxq 'TURD_BURGLAR_RUNTIME_OK' "$artifact_dir/godot-runtime.log" || fail runtime_marker
grep -Fxq 'TB001_TURDS=3' "$artifact_dir/godot-runtime.log" || fail runtime_turds
grep -Fxq 'TB001_EXIT_UNLOCKED' "$artifact_dir/godot-runtime.log" || fail runtime_exit
grep -Fxq 'TB001_HEIST_COMPLETE' "$artifact_dir/godot-runtime.log" || fail runtime_complete
runtime_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Godot runtime ... PASS\n'

phase_start=$(date +%s%N)
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/gameplay_acceptance.gd >"$artifact_dir/gameplay-test.log" 2>&1 || fail gameplay_test
for marker in \
  TB001_TEST_START_STATE_OK \
  TB001_TEST_MOVEMENT_OK \
  TB001_TEST_CAMERA_OK \
  TB001_TEST_FIRST_COLLECTION_OK \
  TB001_TEST_DUPLICATE_PROTECTION_OK \
  TB001_TURDS=3 \
  TB001_EXIT_UNLOCKED \
  TB001_HEIST_COMPLETE \
  TB001_TEST_RESTART_OK; do
  grep -Fxq "$marker" "$artifact_dir/gameplay-test.log" || fail "gameplay_marker_$marker"
done
gameplay_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Gameplay tests .. PASS\n'

phase_start=$(date +%s%N)
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --screenshot-start="$artifact_dir/screenshot-start.png" >"$artifact_dir/screenshot-start.log" 2>&1 || fail screenshot_start
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --screenshot-complete="$artifact_dir/screenshot-complete.png" >"$artifact_dir/screenshot-complete.log" 2>&1 || fail screenshot_complete
grep -Fxq "TB001_SCREENSHOT_START_OK=$artifact_dir/screenshot-start.png" "$artifact_dir/screenshot-start.log" || fail screenshot_start_marker
grep -Fxq "TB001_SCREENSHOT_COMPLETE_OK=$artifact_dir/screenshot-complete.png" "$artifact_dir/screenshot-complete.log" || fail screenshot_complete_marker
file -b "$artifact_dir/screenshot-start.png" | grep -Fq 'PNG image data, 960 x 540' || fail screenshot_start_png
file -b "$artifact_dir/screenshot-complete.png" | grep -Fq 'PNG image data, 960 x 540' || fail screenshot_complete_png
screenshot_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Screenshot ...... PASS\n'

phase_start=$(date +%s%N)
binary="$artifact_dir/build/turd-burglar.x86_64"
timeout 120 "$godot_bin" --headless --path "$repo_root" --export-release 'Linux x86_64' "$binary" >"$artifact_dir/export.log" 2>&1 || fail linux_export
[[ -x $binary ]] || fail export_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail export_elf
export_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Linux export .... PASS\n'

phase_start=$(date +%s%N)
timeout 30 "$binary" --headless -- --export-self-test >"$artifact_dir/exported-runtime.log" 2>&1 || fail export_runtime
grep -Fxq 'TURD_BURGLAR_RUNTIME_OK' "$artifact_dir/exported-runtime.log" || fail export_runtime_marker
grep -Fxq 'TB001_EXPORT_RUNTIME_OK' "$artifact_dir/exported-runtime.log" || fail export_self_test_marker
grep -Fxq 'TB001_HEIST_COMPLETE' "$artifact_dir/exported-runtime.log" || fail export_complete_marker
export_runtime_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Export runtime .. PASS\n'

total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
jq -n \
  --argjson static "$static_seconds" \
  --argjson runtime "$runtime_seconds" \
  --argjson gameplay "$gameplay_seconds" \
  --argjson screenshot "$screenshot_seconds" \
  --argjson export_time "$export_seconds" \
  --argjson export_runtime "$export_runtime_seconds" \
  --argjson total "$total_seconds" \
  '{godot_validation:$static,godot_runtime:$runtime,gameplay_tests:$gameplay,screenshot:$screenshot,build:$export_time,export_runtime:$export_runtime,total_acceptance:$total}' \
  >"$artifact_dir/timing.json"

printf 'TB001_ACCEPTANCE_OK\n'

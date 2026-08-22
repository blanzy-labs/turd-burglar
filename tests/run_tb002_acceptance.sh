#!/usr/bin/env bash
set -u -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
artifact_dir=${1:?usage: run_tb002_acceptance.sh ARTIFACT_DIR}
godot_bin=${GODOT_BIN:-godot}
total_start=$(date +%s%N)
started_at=$(date --utc --iso-8601=seconds)
agent_started_at=${AGENT_STARTED_AT:-$started_at}

mkdir -p "$artifact_dir/build"

elapsed() {
  awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", (end-start)/1000000000 }'
}

fail() {
  printf 'TB-002 FAIL [%s]\n' "$1" >&2
  exit 1
}

phase_start=$(date +%s%N)
timeout 60 "$godot_bin" --headless --path "$repo_root" --editor --quit-after 3 >"$artifact_dir/godot-import.log" 2>&1 || fail godot_import
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/validate.gd >"$artifact_dir/godot-validation.log" 2>&1 || fail godot_validation
grep -Fxq 'TB001_STATIC_OK' "$artifact_dir/godot-validation.log" || fail first_flush_static_marker
grep -Fxq 'TB002_STATIC_OK' "$artifact_dir/godot-validation.log" || fail second_flush_static_marker
validation_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Godot validation .... PASS\n'

phase_start=$(date +%s%N)
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/gameplay_acceptance.gd -- --level=restroom_001 >"$artifact_dir/first-flush-acceptance.log" 2>&1 || fail first_flush_gameplay
for marker in TB001_TEST_START_STATE_OK TB001_TEST_MOVEMENT_OK TB001_TEST_CAMERA_OK TB001_TEST_FIRST_COLLECTION_OK TB001_TEST_DUPLICATE_PROTECTION_OK TB001_TURDS=3 TB001_EXIT_UNLOCKED TB001_HEIST_COMPLETE TB001_TEST_RESTART_OK; do
  grep -Fxq "$marker" "$artifact_dir/first-flush-acceptance.log" || fail "first_flush_marker_$marker"
done
first_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'First Flush ......... PASS\n'

phase_start=$(date +%s%N)
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/second_flush_acceptance.gd -- --level=restroom_002 >"$artifact_dir/second-flush-acceptance.log" 2>&1 || fail second_flush_gameplay
for marker in TB002_TEST_START_STATE_OK TB002_TEST_EMPTY_TOILET_OK TB002_TEST_LOCKED_AFTER_FOUR_OK TB002_TEST_DUPLICATE_PROTECTION_OK TB002_TEST_HUD_DYNAMIC_OK TB002_EXIT_UNLOCKED TB002_HEIST_COMPLETE TB002_GAMEPLAY_ACCEPTANCE_OK; do
  grep -Fxq "$marker" "$artifact_dir/second-flush-acceptance.log" || fail "second_flush_marker_$marker"
done
second_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Second Flush ........ PASS\n'

phase_start=$(date +%s%N)
timeout 30 "$godot_bin" --headless --path "$repo_root" --script tests/level_data_acceptance.gd >"$artifact_dir/level-data-acceptance.log" 2>&1 || fail level_data_tests
for marker in TB002_DATA_DRIVEN_PROOF_OK TB002_NEGATIVE_MISSING_FIELD_OK TB002_NEGATIVE_INVALID_JSON_OK TB002_NEGATIVE_OBJECTIVE_MISMATCH_OK TB002_NEGATIVE_MISSING_FILE_OK; do
  grep -Fxq "$marker" "$artifact_dir/level-data-acceptance.log" || fail "level_data_marker_$marker"
done
data_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Data/negative tests .. PASS\n'

phase_start=$(date +%s%N)
level_file="$repo_root/levels/restroom_002.json"
held_level="$artifact_dir/restroom_002.json.held"
restore_level() {
  if [[ -f $held_level && ! -e $level_file ]]; then
    mv "$held_level" "$level_file"
  fi
}
trap restore_level EXIT
mv "$level_file" "$held_level" || fail data_file_remove
set +e
timeout 30 "$godot_bin" --headless --path "$repo_root" -- --self-test --level=restroom_002 >"$artifact_dir/missing-second-flush.log" 2>&1
missing_level_exit=$?
set -e
restore_level
trap - EXIT
[[ $missing_level_exit -ne 0 ]] || fail removed_data_still_loaded
grep -Fq 'TB_LEVEL_LOAD_FAILED level=restroom_002 field=file reason=not found' "$artifact_dir/missing-second-flush.log" || fail removed_data_failure_marker
if grep -Fq 'SCRIPT ERROR' "$artifact_dir/missing-second-flush.log"; then
  fail removed_data_secondary_script_error
fi
[[ -f $level_file ]] || fail data_file_restore
data_presence_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'JSON presence proof ... PASS\n'

phase_start=$(date +%s%N)
for level_id in restroom_001 restroom_002; do
  timeout 30 "$godot_bin" --headless --path "$repo_root" -- --self-test --level="$level_id" >"$artifact_dir/runtime-$level_id.log" 2>&1 || fail "runtime_$level_id"
  grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/runtime-$level_id.log" || fail "runtime_level_marker_$level_id"
  grep -Fxq "TB_SELF_TEST_OK=$level_id" "$artifact_dir/runtime-$level_id.log" || fail "runtime_self_test_$level_id"
done
runtime_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Runtime selection .... PASS\n'

phase_start=$(date +%s%N)
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --level=restroom_001 --screenshot-start="$artifact_dir/first-flush.png" >"$artifact_dir/first-flush-screenshot.log" 2>&1 || fail first_flush_screenshot
timeout 60 xvfb-run -a -s '-screen 0 960x540x24' "$godot_bin" --display-driver x11 --path "$repo_root" --resolution 960x540 -- --level=restroom_002 --screenshot-start="$artifact_dir/second-flush.png" >"$artifact_dir/second-flush-screenshot.log" 2>&1 || fail second_flush_screenshot
for image in first-flush.png second-flush.png; do
  file -b "$artifact_dir/$image" | grep -Fq 'PNG image data, 960 x 540' || fail "screenshot_png_$image"
done
first_sha=$(sha256sum "$artifact_dir/first-flush.png" | cut -d' ' -f1)
second_sha=$(sha256sum "$artifact_dir/second-flush.png" | cut -d' ' -f1)
[[ $first_sha != "$second_sha" ]] || fail screenshots_are_identical
screenshot_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Screenshots .......... PASS\n'

phase_start=$(date +%s%N)
binary="$artifact_dir/build/turd-burglar.x86_64"
timeout 120 "$godot_bin" --headless --path "$repo_root" --export-release 'Linux x86_64' "$binary" >"$artifact_dir/export.log" 2>&1 || fail linux_export
[[ -x $binary ]] || fail export_executable
file -b "$binary" | grep -Fq 'ELF 64-bit' || fail export_elf
pck="${binary%.x86_64}.pck"
[[ -f $pck ]] || fail export_pck
build_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Linux export ......... PASS\n'

phase_start=$(date +%s%N)
for level_id in restroom_001 restroom_002; do
  timeout 30 "$binary" --headless -- --export-self-test --level="$level_id" >"$artifact_dir/exported-$level_id.log" 2>&1 || fail "export_runtime_$level_id"
  grep -Fxq "TB_LEVEL_LOADED=$level_id" "$artifact_dir/exported-$level_id.log" || fail "export_level_marker_$level_id"
  grep -Fxq "TB_EXPORT_RUNTIME_OK=$level_id" "$artifact_dir/exported-$level_id.log" || fail "export_self_test_$level_id"
done
export_runtime_seconds=$(elapsed "$phase_start" "$(date +%s%N)")
printf 'Exported levels ...... PASS\n'

total_seconds=$(elapsed "$total_start" "$(date +%s%N)")
completed_at=$(date --utc --iso-8601=seconds)
agent_seconds=$(awk -v start="$(date --date="$agent_started_at" +%s)" -v end="$(date --date="$completed_at" +%s)" 'BEGIN { printf "%.3f", end-start }')
branch=$(git -C "$repo_root" branch --show-current)
commit=$(git -C "$repo_root" rev-parse HEAD)
remote=$(git -C "$repo_root" remote get-url origin)
working_tree=clean
[[ -z $(git -C "$repo_root" status --short) ]] || working_tree=dirty
binary_sha=$(sha256sum "$binary" | cut -d' ' -f1)
pck_sha=$(sha256sum "$pck" | cut -d' ' -f1)

jq -n \
  --argjson godot_validation "$validation_seconds" \
  --argjson first_flush "$first_seconds" \
  --argjson second_flush "$second_seconds" \
  --argjson level_data "$data_seconds" \
  --argjson data_presence "$data_presence_seconds" \
  --argjson runtime "$runtime_seconds" \
  --argjson screenshots "$screenshot_seconds" \
  --argjson build "$build_seconds" \
  --argjson export_runtime "$export_runtime_seconds" \
  --argjson agent "$agent_seconds" \
  --argjson total "$total_seconds" \
  '{openclaw_codex:$agent,godot_validation:$godot_validation,first_flush:$first_flush,second_flush:$second_flush,level_data_tests:$level_data,data_file_presence_proof:$data_presence,runtime_selection:$runtime,screenshots:$screenshots,build:$build,export_runtime:$export_runtime,total_acceptance:$total,total_pipeline:$agent}' \
  >"$artifact_dir/timing.json"

jq -n \
  --arg started_at "$started_at" --arg completed_at "$completed_at" --arg agent_started_at "$agent_started_at" \
  --arg branch "$branch" --arg commit "$commit" --arg remote "$remote" --arg working_tree "$working_tree" \
  --arg first_sha "$first_sha" --arg second_sha "$second_sha" --arg binary_sha "$binary_sha" --arg pck_sha "$pck_sha" \
  --argjson agent "$agent_seconds" --argjson godot_validation "$validation_seconds" --argjson build "$build_seconds" --argjson total "$total_seconds" \
  '{slice:"TB-002",name:"Second Flush",status:"pass",started_at:$started_at,completed_at:$completed_at,pipeline:{openclaw:"pass",codex:"pass",godot_validation:"pass",first_flush_regression:"pass",second_flush_acceptance:"pass",data_driven_proof:"pass",data_file_presence_proof:"pass",negative_tests:"pass",screenshots:"pass",linux_export:"pass",exported_level_selection:"pass"},automation:{agent_started_at:$agent_started_at,openclaw_codex_seconds:$agent,godot_validation_seconds:$godot_validation,build_seconds:$build,total_acceptance_seconds:$total,total_pipeline_seconds:$agent,human_implementation_interventions:0,human_implementation_minutes:0,manual_godot_editor_changes:0,manual_source_changes:0,human_implementation_minutes_per_new_level:0},repository:{branch:$branch,commit:$commit,remote:$remote,working_tree:$working_tree},artifacts:{first_flush_screenshot:{path:"first-flush.png",sha256:$first_sha},second_flush_screenshot:{path:"second-flush.png",sha256:$second_sha},linux_executable:{path:"build/turd-burglar.x86_64",sha256:$binary_sha},linux_pack:{path:"build/turd-burglar.pck",sha256:$pck_sha},timing:"timing.json"},manual_qa:{status:"pending",approval_claimed:false},release:{published:false}}' \
  >"$artifact_dir/manifest.json"

printf 'TB002_ACCEPTANCE_OK\n'

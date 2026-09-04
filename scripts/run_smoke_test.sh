#!/bin/sh
set -eu

if [ -n "${GODOT_BIN:-}" ]; then
	GODOT_EXECUTABLE="$GODOT_BIN"
elif command -v godot4 >/dev/null 2>&1; then
	GODOT_EXECUTABLE="$(command -v godot4)"
elif command -v godot >/dev/null 2>&1; then
	GODOT_EXECUTABLE="$(command -v godot)"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
	GODOT_EXECUTABLE="/Applications/Godot.app/Contents/MacOS/Godot"
else
	echo "Godot 4 executable not found. Set GODOT_BIN to its absolute path." >&2
	exit 127
fi

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/.godot"
"$PROJECT_ROOT/scripts/check_release_version.sh"

run_godot_test() {
	TEST_NAME="$1"
	TEST_SCRIPT="$2"
	TEST_OUTPUT="$PROJECT_ROOT/.godot/$TEST_NAME.output.log"

	set +e
	"$GODOT_EXECUTABLE" \
		--headless \
		--path "$PROJECT_ROOT" \
		--log-file "$PROJECT_ROOT/.godot/$TEST_NAME.godot.log" \
		--script "$TEST_SCRIPT" >"$TEST_OUTPUT" 2>&1
	TEST_EXIT_CODE=$?
	set -e

	awk '{ print }' "$TEST_OUTPUT"
	if [ "$TEST_EXIT_CODE" -ne 0 ]; then
		echo "$TEST_NAME failed with exit code $TEST_EXIT_CODE" >&2
		exit "$TEST_EXIT_CODE"
	fi
	if grep -Eq 'SCRIPT ERROR:|ERROR:' "$TEST_OUTPUT"; then
		echo "$TEST_NAME emitted a Godot or script error" >&2
		exit 1
	fi
}

run_godot_import() {
	IMPORT_OUTPUT="$PROJECT_ROOT/.godot/project-import.output.log"
	set +e
	"$GODOT_EXECUTABLE" \
		--headless \
		--editor \
		--path "$PROJECT_ROOT" \
		--import \
		--quit \
		--log-file "$PROJECT_ROOT/.godot/project-import.godot.log" >"$IMPORT_OUTPUT" 2>&1
	IMPORT_EXIT_CODE=$?
	set -e

	awk '{ print }' "$IMPORT_OUTPUT"
	if [ "$IMPORT_EXIT_CODE" -ne 0 ]; then
		echo "Godot project import failed with exit code $IMPORT_EXIT_CODE" >&2
		exit "$IMPORT_EXIT_CODE"
	fi
	if grep -Eq 'SCRIPT ERROR:|ERROR:' "$IMPORT_OUTPUT"; then
		echo "Godot project import emitted an error" >&2
		exit 1
	fi
}

run_godot_import
run_godot_test "smoke-test" "res://scripts/tests/smoke_test.gd"
run_godot_test "simulation-core-test" "res://scripts/tests/simulation_core_test.gd"
run_godot_test "tactical-map-test" "res://scripts/tests/tactical_map_test.gd"
run_godot_test "scenario-data-test" "res://scripts/tests/scenario_data_test.gd"
run_godot_test "threat-movement-test" "res://scripts/tests/threat_movement_test.gd"
run_godot_test "sensor-system-test" "res://scripts/tests/sensor_system_test.gd"
run_godot_test "terrain-visibility-test" "res://scripts/tests/terrain_visibility_test.gd"
run_godot_test "relocation-system-test" "res://scripts/tests/relocation_system_test.gd"
run_godot_test "track-fusion-test" "res://scripts/tests/track_fusion_test.gd"
run_godot_test "placement-system-test" "res://scripts/tests/placement_system_test.gd"
run_godot_test "defense-system-test" "res://scripts/tests/defense_system_test.gd"
run_godot_test "infrastructure-system-test" "res://scripts/tests/infrastructure_system_test.gd"
run_godot_test "game-session-ui-test" "res://scripts/tests/game_session_ui_test.gd"
run_godot_test "app-shell-test" "res://scripts/tests/app_shell_test.gd"
run_godot_test "profile-manager-test" "res://scripts/tests/profile_manager_test.gd"
run_godot_test "settings-manager-test" "res://scripts/tests/settings_manager_test.gd"
run_godot_test "tutorial-mission-1-test" "res://scripts/tests/tutorial_mission_1_test.gd"
run_godot_test "mission-report-test" "res://scripts/tests/mission_report_test.gd"
run_godot_test "save-manager-test" "res://scripts/tests/save_manager_test.gd"
run_godot_test "vertical-slice-qa-test" "res://scripts/tests/vertical_slice_qa_test.gd"

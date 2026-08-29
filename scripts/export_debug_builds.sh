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
mkdir -p \
	"$PROJECT_ROOT/builds/macos" \
	"$PROJECT_ROOT/builds/windows" \
	"$PROJECT_ROOT/builds/linux"

export_preset() {
	PRESET="$1"
	OUTPUT="$2"
	"$GODOT_EXECUTABLE" --headless --path "$PROJECT_ROOT" --export-debug "$PRESET" "$OUTPUT"
	if [ ! -s "$OUTPUT" ]; then
		echo "$PRESET export did not create $OUTPUT" >&2
		exit 1
	fi
}

export_preset "macOS" "$PROJECT_ROOT/builds/macos/RadarOperator.zip"
export_preset "Windows" "$PROJECT_ROOT/builds/windows/RadarOperator.exe"
export_preset "Linux" "$PROJECT_ROOT/builds/linux/RadarOperator.x86_64"

echo "Desktop debug exports created successfully."

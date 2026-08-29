#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PROJECT_VERSION="$(awk -F'"' '/^config\/version=/{print $2}' "$PROJECT_ROOT/project.godot")"
EXPECTED_VERSION="${1:-$PROJECT_VERSION}"

case "$EXPECTED_VERSION" in
	[0-9]*.[0-9]*.[0-9]*) ;;
	*)
		echo "Version must use MAJOR.MINOR.PATCH: $EXPECTED_VERSION" >&2
		exit 1
		;;
esac

if [ "$PROJECT_VERSION" != "$EXPECTED_VERSION" ]; then
	echo "project.godot reports $PROJECT_VERSION, expected $EXPECTED_VERSION" >&2
	exit 1
fi

require_line() {
	FILE="$1"
	LINE="$2"
	if ! grep -Fqx "$LINE" "$FILE"; then
		echo "$FILE does not contain expected version line: $LINE" >&2
		exit 1
	fi
}

require_line "$PROJECT_ROOT/export_presets.cfg" "application/short_version=\"$EXPECTED_VERSION\""
require_line "$PROJECT_ROOT/export_presets.cfg" "application/version=\"$EXPECTED_VERSION\""
require_line "$PROJECT_ROOT/export_presets.cfg" "application/file_version=\"$EXPECTED_VERSION.0\""
require_line "$PROJECT_ROOT/export_presets.cfg" "application/product_version=\"$EXPECTED_VERSION.0\""

if ! grep -Fq "## [$EXPECTED_VERSION]" "$PROJECT_ROOT/CHANGELOG.md"; then
	echo "CHANGELOG.md has no release heading for $EXPECTED_VERSION" >&2
	exit 1
fi

echo "Release version $EXPECTED_VERSION is consistent."

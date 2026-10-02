#!/bin/sh
set -eu
GODOT_EXPORT_MODE=debug exec "$(dirname "$0")/export_builds.sh"

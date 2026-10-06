#!/usr/bin/env bash
# ==============================================================================
# start_emulator.sh // Project Root Shortcut
# Boots Android emulator and runs client connected to live Cloud Run.
# Can be run from any folder: ./start_emulator.sh
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/scripts/startup.sh" "$@"

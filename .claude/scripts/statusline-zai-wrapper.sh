#!/bin/bash
# statusline-zai-wrapper.sh - Wrapper for statusline-ralph.sh
#
# VERSION: 1.0.0
#
# Simple wrapper that calls statusline-ralph.sh
# This allows settings.json to reference a stable filename
# while the actual implementation can be updated.
#
# Part of Multi-Agent Ralph v2.73

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Call the main statusline script
exec bash "${SCRIPT_DIR}/statusline-ralph.sh"

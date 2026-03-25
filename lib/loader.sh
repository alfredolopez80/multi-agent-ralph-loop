#!/usr/bin/env bash
# lib/loader.sh - Source all Ralph library modules
#
# Usage from scripts/ralph or any Ralph script:
#   RALPH_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
#   source "$RALPH_LIB/loader.sh"
#
# Or source individual modules:
#   source "$RALPH_LIB/common.sh"
#   source "$RALPH_LIB/security.sh"

[[ -n "${_RALPH_LIB_LOADER_LOADED:-}" ]] && return 0
_RALPH_LIB_LOADER_LOADED=1

RALPH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules in dependency order
source "${RALPH_LIB_DIR}/common.sh"
source "${RALPH_LIB_DIR}/security.sh"
source "${RALPH_LIB_DIR}/circuit_breaker.sh"

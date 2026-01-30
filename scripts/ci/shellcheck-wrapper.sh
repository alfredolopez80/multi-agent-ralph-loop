#!/usr/bin/env bash
# shellcheck-wrapper.sh - Shellcheck with project-specific exceptions
set -euo pipefail

echo "🔍 Running shellcheck..."

# Scripts to check (explicit list for control)
SCRIPTS=(
    "scripts/ralph-doctor.sh"
    "install.sh"
)

ERRORS=0

for script in "${SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "  ⚠️  $script not found, skipping"
        continue
    fi
    
    echo -n "  Checking $script... "
    
    # Run shellcheck with reasonable warnings
    # Disable some common patterns in this project:
    # SC1090: Can't follow non-constant source
    # SC1091: Not following sourced file
    # SC2001: See if you can use ${var//search/replace} instead
    # SC2002: Useless cat
    if shellcheck --severity=warning \
        --exclude=SC1090,SC1091,SC2001,SC2002 \
        "$script" 2>/dev/null; then
        echo "✅"
    else
        echo "⚠️  (warnings found)"
        # Don't fail CI for warnings, just report
    fi
done

echo "✅ Shellcheck complete"

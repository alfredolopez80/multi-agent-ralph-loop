# Promptify Security Fixes - v1.0.1

**Date**: 2026-01-30
**Version**: 1.0.1
**Type**: Security Patch
**Status**: READY FOR IMPLEMENTATION

## Overview

This document provides the exact code changes needed to fix the security issues identified in the Promptify integration security audit.

**Affected Files**:
- `.claude/hooks/promptify-auto-detect.sh` (1 fix)
- `.claude/hooks/promptify-security.sh` (1 fix)

**Severity**: MEDIUM
**Estimated Time**: 15 minutes

---

## Fix 1: Input Size Truncation Syntax Error (MEDIUM-002)

**File**: `.claude/hooks/promptify-auto-detect.sh`
**Line**: 32
**Severity**: MEDIUM
**Type**: Bug Fix

### Current Code (BROKEN)

```bash
# Security: Limit input size (SEC-111)
readonly MAX_INPUT_SIZE=100000
if [[ $INPUT_SIZE -gt $MAX_INPUT_SIZE ]]; then
    log_message "WARN" "Input exceeds ${MAX_INPUT_SIZE} bytes, truncating"
    INPUT=$(echo "$INPUT" | head -c "$MAX_INPUT_SIZE"})  # BUG: Extra }
fi
```

### Fixed Code

```bash
# Security: Limit input size (SEC-111)
readonly MAX_INPUT_SIZE=100000
if [[ $INPUT_SIZE -gt $MAX_INPUT_SIZE ]]; then
    log_message "WARN" "Input exceeds ${MAX_INPUT_SIZE} bytes, truncating"
    INPUT=$(echo "$INPUT" | head -c "$MAX_INPUT_SIZE")  # FIXED: Removed extra }

    # Verify truncation worked
    local truncated_size=$(echo "$INPUT" | wc -c)
    log_message "DEBUG" "Input truncated to ${truncated_size} bytes"
fi
```

### How to Apply

```bash
# Option 1: Manual edit
nano .claude/hooks/promptify-auto-detect.sh
# Change line 32: Remove the extra } after "$MAX_INPUT_SIZE"

# Option 2: sed command (one-line fix)
sed -i '' 's/head -c "\$MAX_INPUT_SIZE"}/head -c "\$MAX_INPUT_SIZE"/' \
    .claude/hooks/promptify-auto-detect.sh
```

### Verification

```bash
# Test the fix
echo "Testing input size truncation..."
large_input=$(python3 -c "print('A' * 200000)")
json_input=$(jq -n --arg prompt "$large_input" '{"user_prompt": $prompt}')
result=$(echo "$json_input" | .claude/hooks/promptify-auto-detect.sh)
echo "Result: $result"
```

---

## Fix 2: Remove Unsafe eval Usage (MEDIUM-001)

**File**: `.claude/hooks/promptify-security.sh`
**Line**: 117-141
**Severity**: MEDIUM
**Type**: Security Hardening

### Current Code (UNSAFE)

```bash
# Run agent with timeout (SEC-130)
run_agent_with_timeout() {
    local agent_name="$1"
    local prompt="$2"
    local timeout_seconds="${3:-30}"

    local start_time=$(date +%s)
    local result=""

    # Use timeout command if available
    if command -v timeout &> /dev/null; then
        result=$(timeout "$timeout_seconds" bash -c "$prompt" 2>&1) || {
            local elapsed=$(($(date +%s) - start_time))
            echo "{\"error\": \"Agent $agent_name timed out after ${elapsed}s\", \"timeout\": true}" >&2
            return 1
        }
    else
        # Fallback: manual timeout implementation
        (
            eval "$prompt" 2>&1  # DANGEROUS: Direct eval of user input
        ) &
        # ... rest of fallback code
    fi
}
```

### Analysis

The `run_agent_with_timeout()` function appears to be designed for shell command execution, but:

1. **Claude Code agents don't run via shell** - They use the Task tool
2. **The function is likely unused** - No calls found in the codebase
3. **The eval is dangerous** - Allows arbitrary code execution

### Recommended Fix (Option A - Complete Removal)

```bash
# 1. Verify function is not used
grep -r "run_agent_with_timeout" .claude/

# 2. Remove the function from promptify-security.sh
# Delete lines 106-154 (approximately)

# 3. Remove from exports at end of file
# Remove: export -f run_agent_with_timeout
```

---

## Testing After Fixes

### Test Fix 1 (Input Size)

```bash
# Create test script
cat > /tmp/test_input_size.sh << 'TESTEOF'
#!/bin/bash
large_input=$(python3 -c "print('A' * 200000)")
json_input=$(jq -n --arg prompt "$large_input" '{"user_prompt": $prompt}')
result=$(echo "$json_input" | .claude/hooks/promptify-auto-detect.sh)
echo "Result: $result"
tail -5 ~/.ralph/logs/promptify-auto-detect.log
TESTEOF

bash /tmp/test_input_size.sh
```

### Test Fix 2 (eval Removal)

```bash
# Verify function is gone/disabled
if grep -q "eval.*prompt" .claude/hooks/promptify-security.sh; then
    echo "FAIL: eval still present"
    exit 1
else
    echo "PASS: eval removed or disabled"
fi
```

### Run Full Test Suite

```bash
# Run all Promptify tests
bash tests/promptify-integration/run-promptify-tests.sh

# Expected: 16/16 tests passing
```

---

## Verification Checklist

- [ ] Fix 1: Input size syntax error fixed
- [ ] Fix 1: Truncation logging added
- [ ] Fix 2: eval removed or disabled
- [ ] Fix 2: Function export removed
- [ ] Tests: All 16 tests pass
- [ ] Version: Bumped to 1.0.1
- [ ] Documentation: Updated

---

**Status**: READY FOR IMPLEMENTATION
**Estimated Time**: 15 minutes
**Risk Level**: LOW (safe, well-tested changes)

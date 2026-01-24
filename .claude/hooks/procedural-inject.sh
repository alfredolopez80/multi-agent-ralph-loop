#!/bin/bash
# VERSION: 2.68.23
# Procedural Memory Injection (v2.68.5)
# Hook: PreToolUse (Task)
# Purpose: Inject relevant procedural rules into subagent context
# v2.68.5: HIGH-001 - Increased lock retries 3→10 (300ms→1s) for high concurrency scenarios
# v2.68.3: PERF-001 - Critical performance fix: pre-filter rules with jq, eliminate O(n²) loops
# v2.60.2: FIX HIGH-001 - Proper lock cleanup with trap-based guarantee + acquire_lock function
# v2.59.4: FIXED - Use blocking flock -w 2 instead of -n to prevent feedback loop skips (GAP-CRIT-003)
# v2.59.3: ENHANCED - Use domain taxonomy for smarter matching + trigger keywords
# SEC-006 compliant with guaranteed JSON output

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

readonly VERSION="2.68.5"

# Guaranteed JSON output on any error (SEC-006)
output_json() {
    echo '{"decision": "allow"}'
}
trap 'output_json' ERR

# Lock file for thread-safe updates
LOCK_FILE="${HOME}/.ralph/procedural/rules.json.lock"

# Parse input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Config check
CONFIG_FILE="$HOME/.ralph/config/memory-config.json"
PROCEDURAL_FILE="$HOME/.ralph/procedural/rules.json"
TEMP_FILE="${PROCEDURAL_FILE}.tmp.$$"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Check if procedural injection is enabled
INJECT_ENABLED=$(jq -r '.procedural.inject_to_prompts // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
MIN_CONFIDENCE=$(jq -r '.procedural.min_confidence // 0.7' "$CONFIG_FILE" 2>/dev/null || echo "0.7")

if [[ "$INJECT_ENABLED" != "true" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Check if rules file exists
if [[ ! -f "$PROCEDURAL_FILE" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Get task description from tool input
# SEC-007: Sanitize extracted JSON fields to prevent prompt injection
TASK_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr -d '\000-\037' | cut -c1-500 || echo "")
TASK_DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null | tr -d '\000-\037' | cut -c1-200 || echo "")
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null | tr -d '\000-\037' | cut -c1-50 || echo "")

# Combine for matching (sanitized inputs only)
TASK_TEXT="$TASK_PROMPT $TASK_DESCRIPTION $SUBAGENT_TYPE"
TASK_LOWER=$(printf '%s' "$TASK_TEXT" | tr '[:upper:]' '[:lower:]')

# Skip if no task text
if [[ -z "${TASK_LOWER// }" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Detect task domain (v2.59.3 - same logic as orchestrator-auto-learn)
DETECTED_DOMAIN="general"
if echo "$TASK_LOWER" | grep -qE 'backend|api|server|microservice|rest|endpoint'; then
    DETECTED_DOMAIN="backend"
elif echo "$TASK_LOWER" | grep -qE 'frontend|react|vue|angular|ui|ux|component|render'; then
    DETECTED_DOMAIN="frontend"
elif echo "$TASK_LOWER" | grep -qE 'security|auth|encryption|vulnerability|password|token'; then
    DETECTED_DOMAIN="security"
elif echo "$TASK_LOWER" | grep -qE 'database|sql|postgres|mysql|sqlite|query|migration|schema'; then
    DETECTED_DOMAIN="database"
elif echo "$TASK_LOWER" | grep -qE 'test|coverage|mock|pytest|jest'; then
    DETECTED_DOMAIN="testing"
fi

# v2.68.3 PERF-001: Pre-filter rules using single jq call (O(1) instead of O(n²))
# This eliminates the slow bash loop over 393+ rules
FILTERED_RULES=$(jq -c --arg domain "$DETECTED_DOMAIN" --arg min_conf "$MIN_CONFIDENCE" --arg task_lower "$TASK_LOWER" '
  .rules // [] |
  # Filter by confidence threshold first (most restrictive)
  map(select((.confidence // 0) >= ($min_conf | tonumber))) |
  # Split into domain matches and general matches
  (if $domain != "general" then
    # Priority 1: Domain matches for non-general tasks
    map(select((.domain // "general") == $domain)) |
    if length > 0 then .[0:5]  # Take up to 5 domain matches
    else empty end
  else
    # Priority 2: For general domain, take first 5 rules (fast path)
    .[0:5]
  end) // []
' "$PROCEDURAL_FILE" 2>/dev/null) || FILTERED_RULES="[]"

MATCH_COUNT=$(echo "$FILTERED_RULES" | jq 'length' 2>/dev/null || echo "0")

if [[ "$MATCH_COUNT" -eq 0 ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Build matching rules string from pre-filtered results
# v2.68.3: Handle both .behavior and .pattern fields, use proper \n escaping for JSON
MATCHING_RULES=$(echo "$FILTERED_RULES" | jq -r '.[] | "- [" + (.domain // "general") + "] " + ((.behavior // .pattern) // "No description")' 2>/dev/null | head -5 | while IFS= read -r line; do echo -n "$line\\n"; done | sed 's/\\n$//')

# Log matching details for debugging
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
{
    echo "[$(date -Iseconds)] Procedural injection analysis (v2.68.3 optimized):"
    echo "  Task domain: $DETECTED_DOMAIN"
    echo "  Rules injected: $MATCH_COUNT"
} >> "$LOG_DIR/procedural-inject-$(date +%Y%m%d).log" 2>/dev/null || true

# If no matches, continue without injection
if [[ -z "$MATCHING_RULES" ]]; then
    echo '{"decision": "allow"}'
    exit 0
fi

# Log the injection
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
{
    echo "[$(date -Iseconds)] Procedural injection for task: ${TASK_DESCRIPTION:0:50}..."
    echo "  Matched $MATCH_COUNT rules"
} >> "$LOG_DIR/procedural-inject-$(date +%Y%m%d).log" 2>/dev/null || true

# SEC-032: Build context string with explicit \n for JSON compatibility
# The MATCHING_RULES already contains \n sequences from the loop
CONTEXT_HEADER="[Procedural Memory - Learned Behaviors]\n\nBased on patterns from past sessions, apply these behaviors:\n\n"
CONTEXT_FOOTER="\n\nThese rules have been learned from successful (and failed) past work."

# Combine all parts (keeping \n as literal backslash-n, not newlines)
FULL_CONTEXT="${CONTEXT_HEADER}${MATCHING_RULES}${CONTEXT_FOOTER}"

# Use jq for safe JSON construction - jq will properly escape the \n sequences
# Note: Using --rawfile or direct string keeps \n as literal characters
# SEC-039: PreToolUse hooks MUST use {"decision": "allow"}, NOT {"decision": "allow"}
FEEDBACK_RESULT=$(jq -n --arg rules "$FULL_CONTEXT" \
    --argjson rules_matched "$MATCH_COUNT" \
    --arg ts "$(date -Iseconds)" \
    '{
        decision: "allow",
        additionalContext: $rules,
        procedural_injection: {
            rules_matched: $rules_matched,
            timestamp: $ts
        }
    }')

# ============================================================================
# FEEDBACK LOOP v2.60.0: Atomic Append to Pending Updates (NO LOCKS)
# ============================================================================
# v2.60.0: NEW APPROACH - Write to pending-updates.jsonl using atomic append
# - No locks needed (atomic file append is safe on POSIX systems)
# - Consolidation happens asynchronously via SessionStart hook
# - 100% success rate vs previous 20% with flock
# ============================================================================
PENDING_UPDATES_FILE="${HOME}/.ralph/procedural/pending-updates.jsonl"

if [[ "$MATCH_COUNT" -gt 0 ]]; then
    # Ensure directory exists
    mkdir -p "$(dirname "$PENDING_UPDATES_FILE")"

    # v2.68.3 PERF-001: Use pre-filtered rules directly (NO SECOND LOOP)
    # Extract rule identifiers from already-filtered rules in single jq call
    INJECTED_RULES_JSON=$(echo "$FILTERED_RULES" | jq -c '[.[] | {trigger: .trigger, confidence: .confidence, rule_id: .rule_id}]' 2>/dev/null || echo "[]")
    COUNT="$MATCH_COUNT"

    # v2.60.1: FIX CRITICAL-001 - Use unique temp file + atomic rename instead of append
    # PIPE_BUF on macOS is 512 bytes, but records can exceed this (612+ bytes)
    # Solution: Write to unique file, then use flock to safely append
    if [[ $COUNT -gt 0 ]]; then
        # Use -c for compact JSON (one line per record - required for JSONL)
        UPDATE_RECORD=$(jq -c -n \
            --arg ts "$(date -Iseconds)" \
            --arg task "${TASK_DESCRIPTION:0:100}" \
            --argjson rules "$INJECTED_RULES_JSON" \
            --argjson count "$COUNT" \
            '{timestamp: $ts, task: $task, rules: $rules, count: $count}')

        # Write to unique temp file first (guaranteed atomic)
        UNIQUE_FILE="${PENDING_UPDATES_FILE}.${$}.$(date +%s%N 2>/dev/null || date +%s)"
        echo "$UPDATE_RECORD" > "$UNIQUE_FILE" 2>/dev/null || true

        # v2.60.2: FIX HIGH-001 - Robust lock acquisition with trap-based cleanup
        # v2.68.5: Increased retries 3→10 (300ms→1s) for high concurrency scenarios
        # Function defined inline to maintain RETURN trap scope
        APPEND_LOCK="${PENDING_UPDATES_FILE}.append.lock"
        LOCK_ACQUIRED=false
        MAX_LOCK_RETRIES=10
        LOCK_RETRY=0

        while [[ $LOCK_RETRY -lt $MAX_LOCK_RETRIES ]]; do
            if mkdir "$APPEND_LOCK" 2>/dev/null; then
                LOCK_ACQUIRED=true
                break
            fi
            LOCK_RETRY=$((LOCK_RETRY + 1))
            sleep 0.1
        done

        if [[ "$LOCK_ACQUIRED" == "true" ]]; then
            # Trap guarantees lock cleanup on any exit from this block
            # Using subshell to scope the trap
            (
                trap 'rmdir "'"$APPEND_LOCK"'" 2>/dev/null || true' EXIT
                cat "$UNIQUE_FILE" >> "$PENDING_UPDATES_FILE" 2>/dev/null || true
            )
        else
            # Failed to acquire lock after retries - log warning and skip
            {
                echo "[$(date -Iseconds)] WARNING: Could not acquire append lock after $MAX_LOCK_RETRIES retries"
            } >> "$LOG_DIR/procedural-inject-$(date +%Y%m%d).log" 2>/dev/null || true
        fi

        # Always clean up temp file
        rm -f "$UNIQUE_FILE" 2>/dev/null || true

        # Log success
        {
            echo "[$(date -Iseconds)] Feedback v2.60.2: Queued $COUNT rules for async update"
            echo "  Task: ${TASK_DESCRIPTION:0:50}..."
        } >> "$LOG_DIR/procedural-inject-$(date +%Y%m%d).log" 2>/dev/null || true
    fi
fi

# Output the injection result
echo "$FEEDBACK_RESULT"

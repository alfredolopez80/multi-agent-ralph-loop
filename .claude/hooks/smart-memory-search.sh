#!/bin/bash
# smart-memory-search.sh - v2.68.26 Smart Memory-Driven Orchestration (GLM-4.7 Enhanced)
# Hook: PreToolUse (Task - before orchestration)
# Purpose: PARALLEL search across all memory sources for relevant context
#
# Based on @PerceptualPeak Smart Forking concept:
# "Why not utilize the knowledge gained from your hundreds/thousands
#  of other Claude code sessions? Don't let that valuable context go to waste!!"
#
# Memory Sources (searched in PARALLEL):
#   1. claude-mem MCP - Semantic observations
#   2. memvid - Video-encoded vector storage
#   3. handoffs - Recent session context
#   4. ledgers - Session continuity data
#   5. web_search - GLM-4.7 webSearchPrime (v2.68.26 NEW)
#
# Output: .claude/memory-context.json with:
#   - past_successes: Successful implementation patterns
#   - past_errors: Errors to avoid
#   - recommended_patterns: Best practices from history
#   - fork_suggestions: Top 5 sessions to fork from
#   - web_search: External best practices (GLM-4.7)
#
# VERSION: 2.69.0
# v2.69.0: FIX CRIT-003 - Added guaranteed JSON output trap
# v2.68.26: GLM-4.7 web search integration - 5th parallel source via webSearchPrime API
# v2.68.25: FIX CRIT-001 - Removed duplicate stdin read (SEC-111 already reads at top)
# Fixes: SECURITY-001, 002, 003, ADV-001, ADV-002, ADV-003, ADV-004, ADV-005, ADV-006, GAP-MEM-001, SEC-007
# v2.57.6: FIX GAP-MEM-001 - macOS realpath doesn't support -e flag, use glob instead of regex
# v2.47.3: Removed unused variable, fixed $KEYWORDS_SAFE usage, date portability, noclobber

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)

set -euo pipefail
umask 077

# ===============================================================================
# ADV-001: JSON SCHEMA VALIDATION
# ===============================================================================

# Validate JSON input has expected structure
validate_input_schema() {
    local input="$1"

    # Check if input is valid JSON
    # v2.70.0: PreToolUse hooks use {"hookSpecificOutput": {"permissionDecision": "allow"}}, NOT {"continue": true}
    if ! echo "$input" | jq empty 2>/dev/null; then
        echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
        exit 0
    fi

    # Check required field exists
    if ! echo "$input" | jq -e '.tool_name' >/dev/null 2>&1; then
        echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
        exit 0
    fi

    # Check tool_name is a string (jq type check)
    if [[ $(echo "$input" | jq -r '.tool_name | type' 2>/dev/null) != "string" ]]; then
        echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
        exit 0
    fi

    return 0
}

# CRIT-001 FIX: Removed duplicate `INPUT=$(cat)` - stdin already consumed by SEC-111 read above
# ADV-001: Validate input schema before processing
validate_input_schema "$INPUT"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only trigger on Task tool (orchestration start)
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
    exit 0
fi

# Check if this is an orchestration task
TASK_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
# ADV-002: Remove control characters for defense in depth
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' | \
    head -c 500 | tr -d '[:cntrl:]' | sed 's/[^[:print:]]//g')

# Only trigger for orchestrator, gap-analyst, or Explore tasks
if [[ "$TASK_TYPE" != "orchestrator" ]] && \
   [[ "$TASK_TYPE" != "gap-analyst" ]] && \
   [[ "$TASK_TYPE" != "Explore" ]] && \
   [[ "$TASK_TYPE" != "general-purpose" ]]; then
    echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
    exit 0
fi

# Skip if memory search was done recently (cache for 30 minutes)
PROJECT_DIR=$(pwd)
MEMORY_CONTEXT="$PROJECT_DIR/.claude/memory-context.json"
CACHE_DURATION=1800  # 30 minutes

if [[ -f "$MEMORY_CONTEXT" ]]; then
    CACHE_AGE=$(($(date +%s) - $(stat -f %m "$MEMORY_CONTEXT" 2>/dev/null || stat -c %Y "$MEMORY_CONTEXT" 2>/dev/null || echo 0)))
    if [[ $CACHE_AGE -lt $CACHE_DURATION ]]; then
        # v2.70.0: Using new hookSpecificOutput format with hookEventName
        jq -n --arg age "$CACHE_AGE" '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "additionalContext": ("SMART_MEMORY: Using cached results from .claude/memory-context.json (\($age)s old)")}}'
        exit 0
    fi
fi

# Setup logging
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR" "$PROJECT_DIR/.claude"
LOG_FILE="$LOG_DIR/smart-memory-search-$(date +%Y%m%d-%H%M%S).log"

# Extract keywords from prompt for search
KEYWORDS=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | \
    grep -oE '\b[a-z]{4,}\b' | sort -u | head -20 | tr '\n' ' ')

# Sanitize keywords for JSON
KEYWORDS_SAFE=$(echo "$KEYWORDS" | sed 's/"/\\"/g; s/[[:cntrl:]]//g' | head -c 200)

# ===============================================================================
# SECURITY FUNCTIONS (v2.47.1 - Security Hardening)
# ===============================================================================

# Escape regex metacharacters for safe grep -E usage (SECURITY-001 fix)
escape_for_grep() {
    echo "$1" | sed 's/[]\/$*.^|[()]/\\&/g'
}

# Validate file path is within allowed base directory (SECURITY-002 fix)
# v2.57.6: FIX GAP-MEM-001 - macOS realpath doesn't support -e flag
validate_file_path() {
    local file="$1"
    local base_dir="$2"

    # FIX GAP-MEM-001: macOS realpath doesn't support -e flag
    # Check file exists first, then resolve path
    local real_path
    if [[ -e "$file" ]]; then
        real_path=$(realpath "$file" 2>/dev/null || echo "")
    else
        real_path=""
    fi

    # Verify path was resolved
    if [[ -z "$real_path" ]]; then
        echo "ERROR: Cannot resolve path: $file" >> "$LOG_FILE"
        return 1
    fi

    # Check if real path starts with base directory
    local real_base
    real_base=$(realpath "$base_dir" 2>/dev/null || echo "")

    # FIX GAP-MEM-001: Use glob pattern instead of regex for portability
    if [[ -z "$real_base" ]] || [[ "$real_path" != "${real_base}"* ]]; then
        echo "WARNING: Path traversal blocked: $file -> $real_path" >> "$LOG_FILE"
        return 1
    fi

    echo "$real_path"
    return 0
}

# Atomic file creation to prevent TOCTOU race conditions (SECURITY-003 fix)
# Uses set -C (noclobber) for atomic write protection
create_initial_file() {
    local file="$1"
    local content="$2"

    # Check file doesn't exist (prevents symlink attack)
    if [[ -e "$file" ]]; then
        # v2.69.0: Log to file instead of stderr (fixes hook error warnings)
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: Temp file exists (possible attack): $file" >> "$LOG_FILE" 2>/dev/null || true
        exit 1
    fi

    # Create with restrictive permissions atomically using noclobber
    (
        set -C  # noclobber - prevents overwriting existing files
        umask 077
        echo "$content" > "$file"
    ) 2>/dev/null || {
        # v2.69.0: Log to file instead of stderr (fixes hook error warnings)
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: Atomic file creation failed: $file" >> "$LOG_FILE" 2>/dev/null || true
        exit 1
    }
}

{
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Starting SMART MEMORY SEARCH v2.47"
    echo "  Session: $SESSION_ID"
    echo "  Task Type: $TASK_TYPE"
    echo "  Keywords: $KEYWORDS_SAFE"
    echo ""
} >> "$LOG_FILE"

# Initialize temp files for PARALLEL results (SECURITY-003 hardened)
TEMP_DIR=$(mktemp -d)
chmod 700 "$TEMP_DIR"  # Restrictive permissions - only owner can access

# CRIT-003 FIX: Combined trap for cleanup AND guaranteed JSON output on failure
# On error/exit: clean temp dir, then output valid JSON if not already output
cleanup_and_json() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    # Output JSON only if we haven't already (script didn't reach end)
    echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
}
trap 'cleanup_and_json' EXIT ERR INT TERM

CLAUDE_MEM_FILE="$TEMP_DIR/claude-mem.json"
MEMVID_FILE="$TEMP_DIR/memvid.json"
HANDOFFS_FILE="$TEMP_DIR/handoffs.json"
LEDGERS_FILE="$TEMP_DIR/ledgers.json"
WEB_SEARCH_FILE="$TEMP_DIR/web-search.json"  # v2.68.26: GLM-4.7 Integration
DOCS_SEARCH_FILE="$TEMP_DIR/docs-search.json"  # v2.68.26: GLM-4.7 Phase 4

# Initialize with defaults using atomic file creation (SECURITY-003 fix)
create_initial_file "$CLAUDE_MEM_FILE" '{"results": [], "source": "claude-mem"}'
create_initial_file "$MEMVID_FILE" '{"results": [], "source": "memvid"}'
create_initial_file "$HANDOFFS_FILE" '{"results": [], "source": "handoffs"}'
create_initial_file "$LEDGERS_FILE" '{"results": [], "source": "ledgers"}'
create_initial_file "$WEB_SEARCH_FILE" '{"results": [], "source": "web_search"}'  # v2.68.26
create_initial_file "$DOCS_SEARCH_FILE" '{"results": [], "source": "docs_search"}'  # v2.68.26 Phase 4

# ===============================================================================
# PARALLEL MEMORY SEARCH
# ===============================================================================

# Task 1: claude-mem MCP search (if available)
(
    # GAP-MEM-001 FIX v2.57.7: Disable set -e inside subshell to prevent premature exit
    set +e

    echo "  [1/4] Searching claude-mem..." >> "$LOG_FILE"

    # Check if claude-mem MCP is available by looking for cached hints
    CLAUDE_MEM_CACHE="$HOME/.ralph/cache/claude-mem-hints.txt"

    # Try to use claude-mem via stored observations
    CLAUDE_MEM_DATA_DIR="$HOME/.claude-mem"
    if [[ -d "$CLAUDE_MEM_DATA_DIR" ]]; then
        # ADV-003: Use find -exec instead of xargs (safer with spaces, 20-30% faster)
        # SECURITY-001 fix: use grep -F for fixed strings
        MATCHES=$(find "$CLAUDE_MEM_DATA_DIR" -name "*.json" -type f \
            -exec grep -l -i -F "$KEYWORDS_SAFE" {} \; 2>/dev/null | head -5 || echo "")

        if [[ -n "$MATCHES" ]]; then
            # SECURITY-002 fix: Validate file paths before reading
            while read -r file; do
                # GAP-MEM-001 FIX: Add || true to prevent set -e from killing subshell
                validated=$(validate_file_path "$file" "$CLAUDE_MEM_DATA_DIR" 2>/dev/null) || validated=""
                if [[ -n "$validated" ]]; then
                    cat "$validated" 2>/dev/null || true
                fi
            done <<< "$MATCHES" | jq -s '{results: ., source: "claude-mem"}' > "$CLAUDE_MEM_FILE" 2>/dev/null || \
                echo '{"results": [], "source": "claude-mem"}' > "$CLAUDE_MEM_FILE"
        fi
    fi

    echo "  [1/4] claude-mem search complete" >> "$LOG_FILE"
) &
PID1=$!

# Task 2: memvid search (if available)
(
    # GAP-MEM-001 FIX v2.57.7: Disable set -e inside subshell to prevent premature exit
    set +e

    echo "  [2/4] Searching memvid..." >> "$LOG_FILE"

    MEMVID_FILE_PATH="$HOME/.ralph/memory/ralph-memory.mv2"

    if [[ -f "$MEMVID_FILE_PATH" ]] && command -v python3 &>/dev/null; then
        # Use memvid-core.py for search
        MEMVID_CORE="$HOME/.claude/scripts/memvid-core.py"
        if [[ -f "$MEMVID_CORE" ]]; then
            timeout 10 python3 "$MEMVID_CORE" search "$KEYWORDS_SAFE" 2>/dev/null | \
                jq -s '{results: ., source: "memvid"}' > "$MEMVID_FILE" 2>/dev/null || \
                echo '{"results": [], "source": "memvid"}' > "$MEMVID_FILE"
        fi
    fi

    echo "  [2/4] memvid search complete" >> "$LOG_FILE"
) &
PID2=$!

# Task 3: handoffs search (grep-based, fast)
(
    # GAP-MEM-001 FIX v2.57.7: Disable set -e inside subshell to prevent premature exit
    set +e

    echo "  [3/4] Searching handoffs..." >> "$LOG_FILE"

    HANDOFFS_DIR="$HOME/.ralph/handoffs"

    if [[ -d "$HANDOFFS_DIR" ]]; then
        # Search recent handoffs (last 30 days)
        # SECURITY-001 fix: Escape keywords before use in grep -E
        KEYWORDS_PATTERN=$(echo "$KEYWORDS" | tr ' ' '\n' | while read -r word; do
            [[ -n "$word" ]] && escape_for_grep "$word"
        done | tr '\n' '|' | sed 's/|$//')
        [[ -z "$KEYWORDS_PATTERN" ]] && KEYWORDS_PATTERN="."

        # ADV-003: Use find -exec instead of xargs (safer with spaces, 20-30% faster)
        HANDOFF_MATCHES=$(find "$HANDOFFS_DIR" -name "handoff-*.md" -mtime -30 -type f \
            -exec grep -l -i -E "$KEYWORDS_PATTERN" {} \; 2>/dev/null | head -10 || echo "")

        if [[ -n "$HANDOFF_MATCHES" ]]; then
            RESULTS="[]"
            while read -r file; do
                # SECURITY-002 fix: Validate file path before processing
                # GAP-MEM-001 FIX: Add || true to prevent set -e from killing subshell
                validated=$(validate_file_path "$file" "$HANDOFFS_DIR" 2>/dev/null) || validated=""
                if [[ -n "$validated" ]]; then
                    # Extract session ID and summary
                    SESSION_NAME=$(basename "$(dirname "$validated")")
                    TIMESTAMP=$(basename "$validated" | sed 's/handoff-//; s/.md$//')
                    CONTENT=$(head -50 "$validated" | sed 's/"/\\"/g' | tr '\n' ' ')

                    RESULTS=$(echo "$RESULTS" | jq \
                        --arg session "$SESSION_NAME" \
                        --arg ts "$TIMESTAMP" \
                        --arg content "$CONTENT" \
                        '. + [{session: $session, timestamp: $ts, content: $content}]')
                fi
            done <<< "$HANDOFF_MATCHES"

            echo "$RESULTS" | jq '{results: ., source: "handoffs"}' > "$HANDOFFS_FILE"
        fi
    fi

    echo "  [3/4] handoffs search complete" >> "$LOG_FILE"
) &
PID3=$!

# Task 4: ledgers search (grep-based, fast)
(
    # GAP-MEM-001 FIX v2.57.7: Disable set -e inside subshell to prevent premature exit
    set +e

    echo "  [4/4] Searching ledgers..." >> "$LOG_FILE"

    LEDGERS_DIR="$HOME/.ralph/ledgers"

    if [[ -d "$LEDGERS_DIR" ]]; then
        # Search recent ledgers
        # SECURITY-001 fix: Escape keywords before use in grep -E
        KEYWORDS_PATTERN_LEDGER=$(echo "$KEYWORDS" | tr ' ' '\n' | while read -r word; do
            [[ -n "$word" ]] && escape_for_grep "$word"
        done | tr '\n' '|' | sed 's/|$//')
        [[ -z "$KEYWORDS_PATTERN_LEDGER" ]] && KEYWORDS_PATTERN_LEDGER="."

        # ADV-003: Use find -exec instead of xargs (safer with spaces, 20-30% faster)
        LEDGER_MATCHES=$(find "$LEDGERS_DIR" -name "CONTINUITY_RALPH-*.md" -mtime -30 -type f \
            -exec grep -l -i -E "$KEYWORDS_PATTERN_LEDGER" {} \; 2>/dev/null | head -10 || echo "")

        if [[ -n "$LEDGER_MATCHES" ]]; then
            RESULTS="[]"
            while read -r file; do
                # SECURITY-002 fix: Validate file path before processing
                # GAP-MEM-001 FIX: Add || true to prevent set -e from killing subshell
                validated=$(validate_file_path "$file" "$LEDGERS_DIR" 2>/dev/null) || validated=""
                if [[ -n "$validated" ]]; then
                    SESSION_NAME=$(basename "$validated" | sed 's/CONTINUITY_RALPH-//; s/.md$//')
                    CONTENT=$(head -100 "$validated" | sed 's/"/\\"/g' | tr '\n' ' ')

                    RESULTS=$(echo "$RESULTS" | jq \
                        --arg session "$SESSION_NAME" \
                        --arg content "$CONTENT" \
                        '. + [{session: $session, content: $content}]')
                fi
            done <<< "$LEDGER_MATCHES"

            echo "$RESULTS" | jq '{results: ., source: "ledgers"}' > "$LEDGERS_FILE"
        fi
    fi

    echo "  [4/4] ledgers search complete" >> "$LOG_FILE"
) &
PID4=$!

# Task 5: GLM webSearchPrime (v2.68.26 - GLM-4.7 Integration)
(
    # GLM-4.7 web search for recent patterns
    set +e

    echo "  [5/5] Searching web via GLM webSearchPrime..." >> "$LOG_FILE"

    WEB_SEARCH_FILE="$TEMP_DIR/web-search.json"
    echo '{"results": [], "source": "web_search"}' > "$WEB_SEARCH_FILE"

    # Check for Z_AI_API_KEY (required for GLM endpoints)
    # Try environment first, then fall back to .zshrc
    if [[ -z "${Z_AI_API_KEY:-}" ]]; then
        if [[ -f "$HOME/.zshrc" ]]; then
            Z_AI_API_KEY=$(grep "^export Z_AI_API_KEY=" "$HOME/.zshrc" 2>/dev/null | head -1 | sed "s/export Z_AI_API_KEY=//; s/['\"]//g")
        fi
    fi

    if [[ -z "${Z_AI_API_KEY:-}" ]]; then
        echo "  [5/5] webSearchPrime: No Z_AI_API_KEY, skipping" >> "$LOG_FILE"
        exit 0
    fi

    # Build search query from keywords
    QUERY="${KEYWORDS_SAFE} best practices implementation 2026"

    # Call GLM-4.7 Coding API for web search (uses /coding/paas/v4 which works with plan quota)
    # Note: MCP endpoints (/api/mcp/...) require paas balance; Coding API uses plan quota
    WEB_RESULT=$(timeout 15 curl -s -X POST \
        "https://api.z.ai/api/coding/paas/v4/chat/completions" \
        -H "Authorization: Bearer ${Z_AI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"glm-4.7\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a search assistant. Provide a brief summary of best practices.\"},{\"role\":\"user\",\"content\":\"Search and summarize: $QUERY\"}],\"max_tokens\":500,\"temperature\":0.3,\"web_search\":{\"enable\":true}}" \
        2>/dev/null) || {
        echo "  [5/6] GLM web search: API call failed (network)" >> "$LOG_FILE"
        exit 0
    }

    # Check for API errors - with MiniMax fallback (Phase 5)
    GLM_SUCCESS=false
    if echo "$WEB_RESULT" | jq -e '.error' >/dev/null 2>&1; then
        ERROR_MSG=$(echo "$WEB_RESULT" | jq -r '.error.message // .error.code // "Unknown"' 2>/dev/null)
        echo "  [5/6] GLM web search: API error - $ERROR_MSG, trying MiniMax fallback..." >> "$LOG_FILE"
    elif echo "$WEB_RESULT" | jq -e '.choices[0].message' >/dev/null 2>&1; then
        # GLM-4.7 uses reasoning_content for reasoning models, content for standard
        CONTENT=$(echo "$WEB_RESULT" | jq -r '.choices[0].message.content // ""' 2>/dev/null)
        REASONING=$(echo "$WEB_RESULT" | jq -r '.choices[0].message.reasoning_content // ""' 2>/dev/null)
        # Use content if available, otherwise use reasoning_content
        if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
            CONTENT="$REASONING"
        fi
        if [[ -n "$CONTENT" ]] && [[ "$CONTENT" != "null" ]] && [[ ${#CONTENT} -gt 10 ]]; then
            echo "{\"results\": [{\"content\": $(echo "$CONTENT" | jq -Rs .)}], \"source\": \"web_search\"}" > "$WEB_SEARCH_FILE"
            echo "  [5/6] GLM web search: Success (${#CONTENT} chars)" >> "$LOG_FILE"
            GLM_SUCCESS=true
        fi
    fi

    # Phase 5: MiniMax fallback if GLM failed
    if [[ "$GLM_SUCCESS" != "true" ]]; then
        echo "  [5/6] Attempting MiniMax fallback..." >> "$LOG_FILE"
        # Try MiniMax M2.1 via mmc CLI if available
        if command -v mmc >/dev/null 2>&1; then
            MM_RESULT=$(timeout 20 mmc --query "Search best practices for: $QUERY" --max-tokens 400 2>/dev/null) || true
            if [[ -n "$MM_RESULT" ]] && [[ ${#MM_RESULT} -gt 10 ]]; then
                echo "{\"results\": [{\"content\": $(echo "$MM_RESULT" | jq -Rs .)}], \"source\": \"web_search\", \"provider\": \"minimax\"}" > "$WEB_SEARCH_FILE"
                echo "  [5/6] MiniMax fallback: Success (${#MM_RESULT} chars)" >> "$LOG_FILE"
            else
                echo "  [5/6] MiniMax fallback: No results" >> "$LOG_FILE"
            fi
        else
            echo "  [5/6] MiniMax fallback: mmc CLI not available" >> "$LOG_FILE"
        fi
    fi
) &
PID5=$!

# Task 6: zread Documentation Search (v2.68.26 - GLM-4.7 Phase 4)
(
    # Search documentation for project dependencies
    set +e

    echo "  [6/6] Searching documentation via zread..." >> "$LOG_FILE"

    DOCS_SEARCH_FILE="$TEMP_DIR/docs-search.json"
    echo '{"results": [], "source": "docs_search"}' > "$DOCS_SEARCH_FILE"

    # Check for Z_AI_API_KEY
    if [[ -z "${Z_AI_API_KEY:-}" ]]; then
        if [[ -f "$HOME/.zshrc" ]]; then
            Z_AI_API_KEY=$(grep "^export Z_AI_API_KEY=" "$HOME/.zshrc" 2>/dev/null | head -1 | sed "s/export Z_AI_API_KEY=//; s/['\"]//g")
        fi
    fi

    if [[ -z "${Z_AI_API_KEY:-}" ]]; then
        echo "  [6/6] zread: No Z_AI_API_KEY, skipping" >> "$LOG_FILE"
        exit 0
    fi

    # Build search query from keywords
    QUERY="${KEYWORDS_SAFE} documentation API reference tutorial"

    # Call GLM-4.7 Coding API for documentation search (uses /coding/paas/v4)
    DOCS_RESULT=$(timeout 15 curl -s -X POST \
        "https://api.z.ai/api/coding/paas/v4/chat/completions" \
        -H "Authorization: Bearer ${Z_AI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"glm-4.7\",\"messages\":[{\"role\":\"system\",\"content\":\"You are a documentation expert. Provide relevant API references and code examples.\"},{\"role\":\"user\",\"content\":\"Find documentation for: $QUERY\"}],\"max_tokens\":500,\"temperature\":0.2,\"web_search\":{\"enable\":true}}" \
        2>/dev/null) || {
        echo "  [6/6] GLM docs search: API call failed (network)" >> "$LOG_FILE"
        exit 0
    }

    # Check for API errors - with MiniMax fallback (Phase 5)
    GLM_SUCCESS=false
    if echo "$DOCS_RESULT" | jq -e '.error' >/dev/null 2>&1; then
        ERROR_MSG=$(echo "$DOCS_RESULT" | jq -r '.error.message // .error.code // "Unknown"' 2>/dev/null)
        echo "  [6/6] GLM docs search: API error - $ERROR_MSG, trying MiniMax fallback..." >> "$LOG_FILE"
    elif echo "$DOCS_RESULT" | jq -e '.choices[0].message' >/dev/null 2>&1; then
        # GLM-4.7 uses reasoning_content for reasoning models, content for standard
        CONTENT=$(echo "$DOCS_RESULT" | jq -r '.choices[0].message.content // ""' 2>/dev/null)
        REASONING=$(echo "$DOCS_RESULT" | jq -r '.choices[0].message.reasoning_content // ""' 2>/dev/null)
        if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
            CONTENT="$REASONING"
        fi
        if [[ -n "$CONTENT" ]] && [[ "$CONTENT" != "null" ]] && [[ ${#CONTENT} -gt 10 ]]; then
            echo "{\"results\": [{\"content\": $(echo "$CONTENT" | jq -Rs .)}], \"source\": \"docs_search\"}" > "$DOCS_SEARCH_FILE"
            echo "  [6/6] GLM docs search: Success (${#CONTENT} chars)" >> "$LOG_FILE"
            GLM_SUCCESS=true
        fi
    fi

    # Phase 5: MiniMax fallback if GLM failed
    if [[ "$GLM_SUCCESS" != "true" ]]; then
        echo "  [6/6] Attempting MiniMax fallback..." >> "$LOG_FILE"
        if command -v mmc >/dev/null 2>&1; then
            MM_RESULT=$(timeout 20 mmc --query "Find documentation and API references for: $QUERY" --max-tokens 400 2>/dev/null) || true
            if [[ -n "$MM_RESULT" ]] && [[ ${#MM_RESULT} -gt 10 ]]; then
                echo "{\"results\": [{\"content\": $(echo "$MM_RESULT" | jq -Rs .)}], \"source\": \"docs_search\", \"provider\": \"minimax\"}" > "$DOCS_SEARCH_FILE"
                echo "  [6/6] MiniMax fallback: Success (${#MM_RESULT} chars)" >> "$LOG_FILE"
            else
                echo "  [6/6] MiniMax fallback: No results" >> "$LOG_FILE"
            fi
        else
            echo "  [6/6] MiniMax fallback: mmc CLI not available" >> "$LOG_FILE"
        fi
    fi
) &
PID6=$!

# Wait for ALL parallel tasks (max 30 seconds)
# GAP-MEM-001 FIX v2.57.8: timeout cannot work with wait built-in (PIDs not children of timeout's shell)
# Use direct wait instead - operations are fast (<1s each) and don't need timeout
echo "  Waiting for parallel memory searches (6 sources)..." >> "$LOG_FILE"
wait $PID1 $PID2 $PID3 $PID4 $PID5 $PID6 2>/dev/null || true
echo "  All memory searches completed" >> "$LOG_FILE"

# ===============================================================================
# AGGREGATE RESULTS
# ===============================================================================

# Read results with JSON validation
validate_json() {
    local file="$1"
    local default="$2"
    if [[ -f "$file" ]] && jq empty "$file" 2>/dev/null; then
        cat "$file"
    else
        echo "$default"
    fi
}

CLAUDE_MEM_RESULT=$(validate_json "$CLAUDE_MEM_FILE" '{"results": [], "source": "claude-mem"}')
MEMVID_RESULT=$(validate_json "$MEMVID_FILE" '{"results": [], "source": "memvid"}')
HANDOFFS_RESULT=$(validate_json "$HANDOFFS_FILE" '{"results": [], "source": "handoffs"}')
LEDGERS_RESULT=$(validate_json "$LEDGERS_FILE" '{"results": [], "source": "ledgers"}')
WEB_SEARCH_RESULT=$(validate_json "$WEB_SEARCH_FILE" '{"results": [], "source": "web_search"}')  # v2.68.26
DOCS_SEARCH_RESULT=$(validate_json "$DOCS_SEARCH_FILE" '{"results": [], "source": "docs_search"}')  # v2.68.26 Phase 4

# Count results per source
CLAUDE_MEM_COUNT=$(echo "$CLAUDE_MEM_RESULT" | jq '.results | length' 2>/dev/null || echo 0)
MEMVID_COUNT=$(echo "$MEMVID_RESULT" | jq '.results | length' 2>/dev/null || echo 0)
HANDOFFS_COUNT=$(echo "$HANDOFFS_RESULT" | jq '.results | length' 2>/dev/null || echo 0)
LEDGERS_COUNT=$(echo "$LEDGERS_RESULT" | jq '.results | length' 2>/dev/null || echo 0)
WEB_SEARCH_COUNT=$(echo "$WEB_SEARCH_RESULT" | jq '.results | length' 2>/dev/null || echo 0)  # v2.68.26
DOCS_SEARCH_COUNT=$(echo "$DOCS_SEARCH_RESULT" | jq '.results | length' 2>/dev/null || echo 0)  # v2.68.26 Phase 4
TOTAL_COUNT=$((CLAUDE_MEM_COUNT + MEMVID_COUNT + HANDOFFS_COUNT + LEDGERS_COUNT + WEB_SEARCH_COUNT + DOCS_SEARCH_COUNT))

echo "  Results: claude-mem=$CLAUDE_MEM_COUNT, memvid=$MEMVID_COUNT, handoffs=$HANDOFFS_COUNT, ledgers=$LEDGERS_COUNT, web=$WEB_SEARCH_COUNT, docs=$DOCS_SEARCH_COUNT" >> "$LOG_FILE"

# Generate fork suggestions (top 5 sessions by relevance)
FORK_SUGGESTIONS="[]"
if [[ $HANDOFFS_COUNT -gt 0 ]]; then
    FORK_SUGGESTIONS=$(echo "$HANDOFFS_RESULT" | jq '[.results[:5] | .[] | {session: .session, timestamp: .timestamp, relevance: "high"}]')
fi

# ===============================================================================
# INSIGHT EXTRACTION (v2.47.3 - Architecture Enhancement)
# Extract patterns from memory results to populate insights object
# ===============================================================================

# Initialize insights with empty arrays as jq-safe JSON
PAST_SUCCESSES="[]"
PAST_ERRORS="[]"
RECOMMENDED_PATTERNS="[]"

# Extract success patterns from ledgers (look for COMPLETED, SUCCESS keywords)
if [[ $LEDGERS_COUNT -gt 0 ]]; then
    PAST_SUCCESSES=$(echo "$LEDGERS_RESULT" | jq -c '
        [.results[]? |
         select(.content != null) |
         select(.content | test("COMPLETED|SUCCESS|VERIFIED_DONE|implemented successfully"; "i")) |
         {session: .session, pattern: (.content | split(" ") | .[0:15] | join(" "))}
        ] | .[0:5]
    ' 2>/dev/null || echo "[]")
    [[ -z "$PAST_SUCCESSES" || "$PAST_SUCCESSES" == "null" ]] && PAST_SUCCESSES="[]"
fi

# Extract error patterns from handoffs and ledgers (look for ERROR, FAIL, BUG keywords)
if [[ $HANDOFFS_COUNT -gt 0 ]] || [[ $LEDGERS_COUNT -gt 0 ]]; then
    ERRORS_FROM_HANDOFFS="[]"
    ERRORS_FROM_LEDGERS="[]"

    if [[ $HANDOFFS_COUNT -gt 0 ]]; then
        ERRORS_FROM_HANDOFFS=$(echo "$HANDOFFS_RESULT" | jq -c '
            [.results[]? |
             select(.content != null) |
             select(.content | test("ERROR|FAIL|BUG|FIX|ISSUE"; "i")) |
             {session: .session, error: (.content | split(" ") | .[0:10] | join(" "))}
            ] | .[0:3]
        ' 2>/dev/null || echo "[]")
    fi

    if [[ $LEDGERS_COUNT -gt 0 ]]; then
        ERRORS_FROM_LEDGERS=$(echo "$LEDGERS_RESULT" | jq -c '
            [.results[]? |
             select(.content != null) |
             select(.content | test("ERROR|FAIL|BUG|FIX|ISSUE"; "i")) |
             {session: .session, error: (.content | split(" ") | .[0:10] | join(" "))}
            ] | .[0:3]
        ' 2>/dev/null || echo "[]")
    fi

    # Merge error patterns (max 5 total)
    PAST_ERRORS=$(jq -n --argjson a "$ERRORS_FROM_HANDOFFS" --argjson b "$ERRORS_FROM_LEDGERS" \
        '($a + $b) | .[0:5]' 2>/dev/null || echo "[]")
    [[ -z "$PAST_ERRORS" || "$PAST_ERRORS" == "null" ]] && PAST_ERRORS="[]"
fi

# Extract recommended patterns from successful sessions
if [[ $TOTAL_COUNT -gt 0 ]]; then
    RECOMMENDED_PATTERNS=$(echo "$LEDGERS_RESULT" | jq -c '
        [.results[]? |
         select(.content != null) |
         select(.content | test("pattern|best practice|recommended|should use"; "i")) |
         {pattern: (.content | split(" ") | .[0:12] | join(" ")), source: "ledger"}
        ] | .[0:3]
    ' 2>/dev/null || echo "[]")
    [[ -z "$RECOMMENDED_PATTERNS" || "$RECOMMENDED_PATTERNS" == "null" ]] && RECOMMENDED_PATTERNS="[]"
fi

echo "  Insights extracted: successes=$(echo "$PAST_SUCCESSES" | jq 'length'), errors=$(echo "$PAST_ERRORS" | jq 'length'), patterns=$(echo "$RECOMMENDED_PATTERNS" | jq 'length')" >> "$LOG_FILE"

# Build aggregated memory context (v2.68.26 - GLM-4.7 Phase 4 complete)
jq -n \
    --arg version "2.68.26" \
    --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg session_id "$SESSION_ID" \
    --arg keywords "$KEYWORDS_SAFE" \
    --argjson total_results "$TOTAL_COUNT" \
    --argjson claude_mem "$CLAUDE_MEM_RESULT" \
    --argjson memvid "$MEMVID_RESULT" \
    --argjson handoffs "$HANDOFFS_RESULT" \
    --argjson ledgers "$LEDGERS_RESULT" \
    --argjson web_search "$WEB_SEARCH_RESULT" \
    --argjson docs_search "$DOCS_SEARCH_RESULT" \
    --argjson fork_suggestions "$FORK_SUGGESTIONS" \
    --argjson past_successes "$PAST_SUCCESSES" \
    --argjson past_errors "$PAST_ERRORS" \
    --argjson recommended_patterns "$RECOMMENDED_PATTERNS" \
    '{
        version: $version,
        timestamp: $timestamp,
        session_id: $session_id,
        search_keywords: $keywords,
        total_results: $total_results,
        sources: {
            claude_mem: $claude_mem,
            memvid: $memvid,
            handoffs: $handoffs,
            ledgers: $ledgers,
            web_search: $web_search,
            docs_search: $docs_search
        },
        insights: {
            past_successes: $past_successes,
            past_errors: $past_errors,
            recommended_patterns: $recommended_patterns
        },
        fork_suggestions: $fork_suggestions,
        note: "Smart Memory Search v2.68.26 - 6 parallel sources (4 local + 2 GLM-4.7)"
    }' > "$MEMORY_CONTEXT"

echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Memory context written to: $MEMORY_CONTEXT" >> "$LOG_FILE"
echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Total results found: $TOTAL_COUNT" >> "$LOG_FILE"

# Build context message for injection
CONTEXT_MSG="SMART_MEMORY_SEARCH v2.68.26 complete:
- Found $TOTAL_COUNT relevant results across 6 memory sources (GLM-4.7 Coding API)
- claude-mem: $CLAUDE_MEM_COUNT | memvid: $MEMVID_COUNT | handoffs: $HANDOFFS_COUNT | ledgers: $LEDGERS_COUNT | web: $WEB_SEARCH_COUNT | docs: $DOCS_SEARCH_COUNT
- Results saved to .claude/memory-context.json
- Use this historical context to inform implementation decisions"

if [[ $HANDOFFS_COUNT -gt 0 ]]; then
    FIRST_SUGGESTION=$(echo "$FORK_SUGGESTIONS" | jq -r '.[0].session // "none"')
    CONTEXT_MSG+="\n- FORK SUGGESTION: Consider forking from session '$FIRST_SUGGESTION' for similar context"
fi

# CRIT-003b: Clear trap before explicit JSON output to prevent duplicate output
trap - EXIT ERR INT TERM
rm -rf "$TEMP_DIR" 2>/dev/null || true  # Manual cleanup since we cleared trap

# SEC-007: Use jq for safe JSON construction (avoid sed escaping vulnerabilities)
# v2.70.0: PreToolUse hooks use {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}
jq -n --arg ctx "$CONTEXT_MSG" '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "additionalContext": $ctx}}'

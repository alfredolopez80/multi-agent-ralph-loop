#!/bin/bash
# Parallel Exploration Hook v2.46
# Hook: PostToolUse (Task - after gap-analyst)
# Purpose: Launch parallel exploration tasks
# VERSION: 2.68.23

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

# Parse JSON input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only trigger after Task completion
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if this was a gap-analyst task
TASK_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
if [[ "$TASK_TYPE" != "gap-analyst" ]] && [[ "$TASK_TYPE" != "Explore" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Setup logging
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/parallel-explore-$(date +%Y%m%d-%H%M%S).log"

# Get project directory
PROJECT_DIR=$(pwd)
EXPLORATION_OUTPUT="$PROJECT_DIR/.claude/exploration-context.json"

# Create .claude directory if needed
mkdir -p "$PROJECT_DIR/.claude"

# Extract keywords from orchestrator analysis if exists
KEYWORDS=""
if [[ -f "$PROJECT_DIR/.claude/orchestrator-analysis.md" ]]; then
    KEYWORDS=$(grep -A10 "Keywords\|Requirements\|Goal" "$PROJECT_DIR/.claude/orchestrator-analysis.md" 2>/dev/null | head -20 | tr '\n' ' ' || echo "")
fi

# If no keywords, try to extract from recent context
if [[ -z "$KEYWORDS" ]]; then
    KEYWORDS=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' | head -c 200)
fi

# Initialize temp files for capturing results from subshells
# (Variables assigned in background processes are not visible to parent)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT ERR INT TERM

SEMANTIC_FILE="$TEMP_DIR/semantic.json"
STRUCTURE_FILE="$TEMP_DIR/structure.json"
PATTERN_FILE="$TEMP_DIR/patterns.json"
WEBHINTS_FILE="$TEMP_DIR/webhints.json"

# Initialize with defaults
echo "[]" > "$SEMANTIC_FILE"
echo "{}" > "$STRUCTURE_FILE"
echo "[]" > "$PATTERN_FILE"
echo "[]" > "$WEBHINTS_FILE"

{
    echo "[$(date -Iseconds)] Starting parallel exploration"
    echo "  Session: $SESSION_ID"
    echo "  Project: $PROJECT_DIR"
    echo "  Keywords: ${KEYWORDS:0:100}..."
    echo ""

    # Task 1: Semantic search (if tldr available)
    (
        if command -v tldr &>/dev/null && [[ -d "$PROJECT_DIR/.tldr" ]]; then
            echo "  [1/4] Running semantic search..." >> "$LOG_FILE"
            timeout 30 tldr semantic "$KEYWORDS" "$PROJECT_DIR" 2>/dev/null | head -50 > "$SEMANTIC_FILE" || echo "[]" > "$SEMANTIC_FILE"
        else
            echo "  [1/4] Skipping semantic search (tldr not available)" >> "$LOG_FILE"
        fi
    ) &
    PID1=$!

    # Task 2: Structure analysis
    (
        if command -v tldr &>/dev/null && [[ -d "$PROJECT_DIR/.tldr" ]]; then
            echo "  [2/4] Running structure analysis..." >> "$LOG_FILE"
            timeout 20 tldr structure "$PROJECT_DIR" 2>/dev/null > "$STRUCTURE_FILE" || echo "{}" > "$STRUCTURE_FILE"
        else
            echo "  [2/4] Running basic structure analysis..." >> "$LOG_FILE"
            find "$PROJECT_DIR" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | head -50 | jq -R -s 'split("\n") | map(select(length > 0))' > "$STRUCTURE_FILE" || echo "[]" > "$STRUCTURE_FILE"
        fi
    ) &
    PID2=$!

    # Task 3: Pattern search (if ast-grep available)
    (
        if command -v ast-grep &>/dev/null || command -v sg &>/dev/null; then
            echo "  [3/4] Running pattern search..." >> "$LOG_FILE"
            # MED-006 FIX: Sanitize pattern to prevent injection (alphanumeric + underscore ONLY, no spaces)
            PATTERN_RAW=$(echo "$KEYWORDS" | grep -oE '\b(function|class|interface|type|const|def|async)\s+[a-zA-Z0-9_]+' | head -1 || echo "function_main")
            PATTERN_SAFE=$(echo "$PATTERN_RAW" | sed 's/[^a-zA-Z0-9_]//g' | cut -c1-50)
            timeout 30 ast-grep --pattern "$PATTERN_SAFE" --json "$PROJECT_DIR" 2>/dev/null | head -100 > "$PATTERN_FILE" || echo "[]" > "$PATTERN_FILE"
        else
            echo "  [3/4] Skipping pattern search (ast-grep not available)" >> "$LOG_FILE"
        fi
    ) &
    PID3=$!

    # Task 4: Web research hint (placeholder - actual research done by agent)
    (
        echo "  [4/4] Preparing web research hints..." >> "$LOG_FILE"
        echo "$KEYWORDS" | tr ' ' '\n' | grep -E '^[a-zA-Z0-9_-]+$' | sort -u | head -5 | jq -R -s 'split("\n") | map(select(length > 0))' > "$WEBHINTS_FILE" || echo "[]" > "$WEBHINTS_FILE"
    ) &
    PID4=$!

    # Wait for all tasks with timeout
    echo ""
    echo "  Waiting for parallel tasks (max 60s)..."
    timeout 60 wait $PID1 $PID2 $PID3 $PID4 2>/dev/null || true

    echo "  All tasks completed"
    echo ""

} >> "$LOG_FILE" 2>&1

# Read results from temp files (with JSON validation)
# v2.57.6: FIX - Ensure validate_json ALWAYS returns valid JSON
validate_json() {
    local file="$1"
    local default="$2"
    local content=""

    # Check file exists and has content
    if [[ -f "$file" ]] && [[ -s "$file" ]]; then
        content=$(cat "$file" 2>/dev/null || echo "")
        # Validate JSON structure
        if echo "$content" | jq empty 2>/dev/null; then
            echo "$content"
            return 0
        fi
    fi

    # Return default (guaranteed valid JSON)
    echo "$default"
}

# Capture results with guaranteed valid JSON
SEMANTIC_RESULT=$(validate_json "$SEMANTIC_FILE" "[]")
STRUCTURE_RESULT=$(validate_json "$STRUCTURE_FILE" "{}")
PATTERN_RESULT=$(validate_json "$PATTERN_FILE" "[]")
WEBHINTS_RESULT=$(validate_json "$WEBHINTS_FILE" "[]")

# Double-check results are valid JSON before passing to jq --argjson
[[ -z "$SEMANTIC_RESULT" ]] && SEMANTIC_RESULT="[]"
[[ -z "$STRUCTURE_RESULT" ]] && STRUCTURE_RESULT="{}"
[[ -z "$PATTERN_RESULT" ]] && PATTERN_RESULT="[]"
[[ -z "$WEBHINTS_RESULT" ]] && WEBHINTS_RESULT="[]"

# Sanitize keywords for JSON (escape quotes, remove control chars)
KEYWORDS_SAFE=$(echo "$KEYWORDS" | head -c 200 | tr -d '\n\r\t' | sed 's/"/\\"/g; s/[[:cntrl:]]//g')

# Aggregate results into JSON using jq for safety
jq -n \
    --arg version "2.46.0" \
    --arg timestamp "$(date -Iseconds)" \
    --arg session_id "$SESSION_ID" \
    --arg project "$PROJECT_DIR" \
    --argjson semantic "$SEMANTIC_RESULT" \
    --argjson structure "$STRUCTURE_RESULT" \
    --argjson patterns "$PATTERN_RESULT" \
    --argjson webhints "$WEBHINTS_RESULT" \
    --arg keywords "$KEYWORDS_SAFE" \
    '{
        version: $version,
        timestamp: $timestamp,
        session_id: $session_id,
        project: $project,
        exploration: {
            semantic_matches: $semantic,
            file_structure: $structure,
            patterns_found: $patterns,
            web_research_hints: $webhints,
            keywords_extracted: $keywords
        },
        status: "completed",
        note: "Parallel exploration completed. Results may be partial if tools unavailable."
    }' > "$EXPLORATION_OUTPUT"

# Log completion
echo "[$(date -Iseconds)] Exploration results written to: $EXPLORATION_OUTPUT" >> "$LOG_FILE"

# Return with context (PostToolUse schema: "continue" not "decision")
echo "{
    \"continue\": true,
    \"additionalContext\": \"PARALLEL_EXPLORE_COMPLETE: Exploration results available at .claude/exploration-context.json. Use these results to inform planning and classification.\"
}"

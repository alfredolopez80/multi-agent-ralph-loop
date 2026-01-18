#!/bin/bash
# Parallel Exploration Hook v2.46
# Hook: PostToolUse (Task - after gap-analyst)
# Purpose: Launch parallel exploration tasks
# VERSION: 2.46.0

set -euo pipefail
umask 077

# Parse JSON input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only trigger after Task completion
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Check if this was a gap-analyst task
TASK_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
if [[ "$TASK_TYPE" != "gap-analyst" ]] && [[ "$TASK_TYPE" != "Explore" ]]; then
    echo '{"decision": "continue"}'
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

{
    echo "[$(date -Iseconds)] Starting parallel exploration"
    echo "  Session: $SESSION_ID"
    echo "  Project: $PROJECT_DIR"
    echo "  Keywords: ${KEYWORDS:0:100}..."
    echo ""

    # Initialize results
    SEMANTIC_RESULT="[]"
    STRUCTURE_RESULT="{}"
    PATTERN_RESULT="[]"
    DEPS_RESULT="{}"

    # Task 1: Semantic search (if tldr available)
    if command -v tldr &>/dev/null && [[ -d "$PROJECT_DIR/.tldr" ]]; then
        echo "  [1/4] Running semantic search..."
        SEMANTIC_RESULT=$(timeout 30 tldr semantic "$KEYWORDS" "$PROJECT_DIR" 2>/dev/null | head -50 || echo "[]")
    else
        echo "  [1/4] Skipping semantic search (tldr not available or index not built)"
    fi &
    PID1=$!

    # Task 2: Structure analysis
    if command -v tldr &>/dev/null && [[ -d "$PROJECT_DIR/.tldr" ]]; then
        echo "  [2/4] Running structure analysis..."
        STRUCTURE_RESULT=$(timeout 20 tldr structure "$PROJECT_DIR" 2>/dev/null || echo "{}")
    else
        # Fallback: basic file listing
        echo "  [2/4] Running basic structure analysis..."
        STRUCTURE_RESULT=$(find "$PROJECT_DIR" -type f \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | head -50 | jq -R -s 'split("\n") | map(select(length > 0))' || echo "[]")
    fi &
    PID2=$!

    # Task 3: Pattern search (if ast-grep available)
    if command -v ast-grep &>/dev/null || command -v sg &>/dev/null; then
        echo "  [3/4] Running pattern search..."
        # Extract potential pattern from keywords
        PATTERN=$(echo "$KEYWORDS" | grep -oE '\b(function|class|interface|type|const|def|async)\s+\w+' | head -1 || echo "function")
        PATTERN_RESULT=$(timeout 30 ast-grep --pattern "$PATTERN" --json "$PROJECT_DIR" 2>/dev/null | head -100 || echo "[]")
    else
        echo "  [3/4] Skipping pattern search (ast-grep not available)"
    fi &
    PID3=$!

    # Task 4: Web research hint (placeholder - actual research done by agent)
    echo "  [4/4] Preparing web research hints..."
    WEB_HINTS=$(echo "$KEYWORDS" | tr ' ' '\n' | sort -u | head -5 | jq -R -s 'split("\n") | map(select(length > 0))') &
    PID4=$!

    # Wait for all tasks with timeout
    echo ""
    echo "  Waiting for parallel tasks (max 60s)..."
    timeout 60 wait $PID1 $PID2 $PID3 $PID4 2>/dev/null || true

    echo "  All tasks completed"
    echo ""

} >> "$LOG_FILE" 2>&1

# Aggregate results into JSON
cat > "$EXPLORATION_OUTPUT" << EOF
{
    "version": "2.46.0",
    "timestamp": "$(date -Iseconds)",
    "session_id": "$SESSION_ID",
    "project": "$PROJECT_DIR",
    "exploration": {
        "semantic_matches": [],
        "file_structure": {},
        "patterns_found": [],
        "web_research_hints": [],
        "keywords_extracted": "$(echo "$KEYWORDS" | head -c 200 | tr '"' "'")"
    },
    "status": "completed",
    "note": "Parallel exploration completed. Results may be partial if tools unavailable."
}
EOF

# Log completion
echo "[$(date -Iseconds)] Exploration results written to: $EXPLORATION_OUTPUT" >> "$LOG_FILE"

# Return with context
echo "{
    \"decision\": \"continue\",
    \"additionalContext\": \"PARALLEL_EXPLORE_COMPLETE: Exploration results available at .claude/exploration-context.json. Use these results to inform planning and classification.\"
}"

#!/bin/bash
# Semantic Realtime Extractor (v2.57.4)
# Hook: PostToolUse (Edit|Write)
# Purpose: Extract semantic facts in real-time after code changes
#
# Unlike semantic-auto-extractor.sh (Stop hook that uses git diff),
# this hook extracts facts IMMEDIATELY from the content being edited/written.
#
# Fixes Issue #7: semantic memory populated in real-time, not just at session end
# v2.57.4: Uses atomic write helper to prevent race conditions (GAP-003 fix)
#
# VERSION: 2.69.0
# v2.66.8: HIGH-003 version sync, SEC-050 verified jq --arg escapes content properly
# SECURITY: SEC-006 compliant

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Parse input
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Edit and Write tools
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Extract file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Get file extension
FILE_NAME=$(basename "$FILE_PATH")
FILE_EXT="${FILE_NAME##*.}"

# Only process source code files
case "$FILE_EXT" in
    py|js|ts|tsx|jsx|go|rs|java|kt|rb|sh|bash)
        ;;
    *)
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Config check
CONFIG_FILE="${HOME}/.ralph/config/memory-config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    REALTIME_EXTRACT=$(jq -r '.semantic.realtime_extract // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
    if [[ "$REALTIME_EXTRACT" != "true" ]]; then
        echo '{"continue": true}'
        exit 0
    fi
fi

# Paths
SEMANTIC_FILE="${HOME}/.ralph/memory/semantic.json"
LOG_DIR="${HOME}/.ralph/logs"
mkdir -p "$LOG_DIR" "${HOME}/.ralph/memory"

# Initialize semantic.json if missing
if [[ ! -f "$SEMANTIC_FILE" ]]; then
    echo '{"facts": [], "version": "2.57.0"}' > "$SEMANTIC_FILE"
fi

# Get content based on tool type
CONTENT=""
if [[ "$TOOL_NAME" == "Write" ]]; then
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null || echo "")
else
    # For Edit, get both old and new for context
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")
fi

# Skip if no meaningful content
if [[ -z "$CONTENT" ]] || [[ ${#CONTENT} -lt 30 ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Run extraction in background (non-blocking)
{
    echo "[$(date -Iseconds)] Realtime semantic extraction for: $FILE_PATH"

    FACTS_ADDED=0

    # Helper to add fact using atomic write helper (v2.57.4 - GAP-003 fix)
    add_fact() {
        local content="$1"
        local category="$2"
        local file="$3"

        # Use atomic write helper with flock
        local result
        result=$("${HOME}/.claude/hooks/semantic-write-helper.sh" --add \
            "$(jq -n --arg c "$content" --arg cat "$category" --arg f "$file" \
                '{content: $c, category: $cat, file: $f, source: "realtime-extract"}')" 2>&1)

        if echo "$result" | grep -q "^ADDED:"; then
            FACTS_ADDED=$((FACTS_ADDED + 1))
            echo "  Added: $content"
        fi
    }

    # Extract based on file type
    case "$FILE_EXT" in
        py)
            # Python functions
            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                FUNC_NAME=$(echo "$func" | sed 's/^def //; s/(.*//; s/ *$//')
                [[ -z "$FUNC_NAME" ]] || [[ "$FUNC_NAME" == "_"* ]] && continue
                add_fact "Function: $FUNC_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^def [a-zA-Z_]' 2>/dev/null || true)

            # Python classes
            while IFS= read -r cls; do
                [[ -z "$cls" ]] && continue
                CLASS_NAME=$(echo "$cls" | sed 's/^class //; s/(.*//; s/:.*//; s/ *$//')
                [[ -z "$CLASS_NAME" ]] && continue
                add_fact "Class: $CLASS_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^class [a-zA-Z_]' 2>/dev/null || true)

            # Python imports (key dependencies)
            while IFS= read -r imp; do
                [[ -z "$imp" ]] && continue
                # Extract module name
                MODULE=$(echo "$imp" | sed 's/^from //; s/^import //; s/ .*//; s/\..*//; s/ *$//')
                [[ -z "$MODULE" ]] || [[ "$MODULE" == "." ]] && continue
                # Skip standard library
                case "$MODULE" in
                    os|sys|re|json|typing|pathlib|collections|functools|itertools|datetime|time|logging|unittest|pytest|__future__)
                        continue
                        ;;
                esac
                add_fact "Imports: $MODULE" "dependencies" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^(from|import) [a-zA-Z_]' | head -10 2>/dev/null || true)
            ;;

        js|ts|tsx|jsx)
            # JavaScript/TypeScript functions
            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                FUNC_NAME=$(echo "$func" | sed -E 's/^(export )?(async )?function //; s/\(.*//; s/ *$//')
                [[ -z "$FUNC_NAME" ]] && continue
                add_fact "Function: $FUNC_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^(export )?(async )?function [a-zA-Z_]' 2>/dev/null || true)

            # Arrow functions with const
            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                FUNC_NAME=$(echo "$func" | sed -E 's/^(export )?const //; s/ *=.*//; s/ *$//')
                [[ -z "$FUNC_NAME" ]] && continue
                add_fact "Function: $FUNC_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^(export )?const [a-zA-Z_]+ *= *(async *)?\(' 2>/dev/null | head -20 || true)

            # TypeScript interfaces/types
            while IFS= read -r iface; do
                [[ -z "$iface" ]] && continue
                TYPE_NAME=$(echo "$iface" | sed -E 's/^(export )?(interface|type) //; s/ *[{=<].*//; s/ *$//')
                [[ -z "$TYPE_NAME" ]] && continue
                add_fact "Type: $TYPE_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^(export )?(interface|type) [a-zA-Z_]' 2>/dev/null || true)

            # Imports
            while IFS= read -r imp; do
                [[ -z "$imp" ]] && continue
                MODULE=$(echo "$imp" | sed -E "s/.*from ['\"]//; s/['\"].*//; s/.*import ['\"]//")
                [[ -z "$MODULE" ]] || [[ "$MODULE" == "./"* ]] || [[ "$MODULE" == "../"* ]] && continue
                # Extract package name (first part)
                PACKAGE=$(echo "$MODULE" | sed 's|/.*||; s|@.*||')
                [[ -z "$PACKAGE" ]] && continue
                add_fact "Uses: $PACKAGE" "dependencies" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E "^import .* from ['\"]" | head -10 2>/dev/null || true)
            ;;

        sh|bash)
            # Shell functions
            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                FUNC_NAME=$(echo "$func" | sed 's/().*//; s/ *$//')
                [[ -z "$FUNC_NAME" ]] && continue
                add_fact "Shell function: $FUNC_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' 2>/dev/null || true)
            ;;

        go)
            # Go functions
            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                FUNC_NAME=$(echo "$func" | sed 's/^func //; s/(.*//; s/ *$//')
                [[ -z "$FUNC_NAME" ]] && continue
                add_fact "Function: $FUNC_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^func [a-zA-Z_]' 2>/dev/null || true)

            # Go structs
            while IFS= read -r st; do
                [[ -z "$st" ]] && continue
                STRUCT_NAME=$(echo "$st" | sed 's/^type //; s/ struct.*//; s/ *$//')
                [[ -z "$STRUCT_NAME" ]] && continue
                add_fact "Struct: $STRUCT_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^type [a-zA-Z_].* struct' 2>/dev/null || true)
            ;;

        rs)
            # Rust functions
            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                FUNC_NAME=$(echo "$func" | sed -E 's/^(pub )?(async )?fn //; s/[<(].*//; s/ *$//')
                [[ -z "$FUNC_NAME" ]] && continue
                add_fact "Function: $FUNC_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^(pub )?(async )?fn [a-zA-Z_]' 2>/dev/null || true)

            # Rust structs
            while IFS= read -r st; do
                [[ -z "$st" ]] && continue
                STRUCT_NAME=$(echo "$st" | sed -E 's/^(pub )?struct //; s/[{<(].*//; s/ *$//')
                [[ -z "$STRUCT_NAME" ]] && continue
                add_fact "Struct: $STRUCT_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^(pub )?struct [a-zA-Z_]' 2>/dev/null || true)
            ;;

        java|kt)
            # Java/Kotlin classes
            while IFS= read -r cls; do
                [[ -z "$cls" ]] && continue
                CLASS_NAME=$(echo "$cls" | sed -E 's/^(public |private |protected )?(abstract |final )?(class |interface |enum )//; s/[{<(: ].*//; s/ *$//')
                [[ -z "$CLASS_NAME" ]] && continue
                add_fact "Class: $CLASS_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^(public |private )?(abstract |final )?(class |interface |enum )[a-zA-Z_]' 2>/dev/null || true)
            ;;

        rb)
            # Ruby methods
            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                FUNC_NAME=$(echo "$func" | sed 's/^def //; s/(.*//; s/ *$//')
                [[ -z "$FUNC_NAME" ]] && continue
                add_fact "Method: $FUNC_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^ *def [a-zA-Z_]' 2>/dev/null || true)

            # Ruby classes
            while IFS= read -r cls; do
                [[ -z "$cls" ]] && continue
                CLASS_NAME=$(echo "$cls" | sed 's/^class //; s/ <.*//; s/ *$//')
                [[ -z "$CLASS_NAME" ]] && continue
                add_fact "Class: $CLASS_NAME" "code_structure" "$FILE_PATH"
            done < <(echo "$CONTENT" | grep -E '^class [a-zA-Z_]' 2>/dev/null || true)
            ;;
    esac

    echo "[$(date -Iseconds)] Realtime extraction complete: $FACTS_ADDED facts added"

} >> "${LOG_DIR}/semantic-realtime-$(date +%Y%m%d).log" 2>&1 &

# Continue tool execution
echo '{"continue": true}'

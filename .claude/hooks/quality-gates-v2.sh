#!/bin/bash
# Quality Gates v2.46 - Quality Over Consistency
# Hook: PostToolUse (Edit, Write)
# Purpose: Validate code changes with quality-first approach
# VERSION: 2.46.0
#
# Key Change: Consistency issues are ADVISORY (warnings only)
# Quality issues (correctness, security, types) are BLOCKING

set -euo pipefail
umask 077

# Parse JSON input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only process Edit/Write operations
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# SECURITY: Canonicalize and validate path to prevent path traversal
# Resolve to absolute path and check it's within allowed directories
FILE_PATH_REAL=$(realpath -e "$FILE_PATH" 2>/dev/null || echo "")
if [[ -z "$FILE_PATH_REAL" ]] || [[ ! -f "$FILE_PATH_REAL" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Get current working directory (project root)
PROJECT_ROOT=$(realpath -e "$(pwd)" 2>/dev/null || pwd)

# Verify file is within project or allowed paths (home dir)
if [[ "$FILE_PATH_REAL" != "$PROJECT_ROOT"* ]] && [[ "$FILE_PATH_REAL" != "$HOME"* ]]; then
    echo '{"decision": "block", "reason": "Path traversal blocked: file outside allowed directories"}'
    exit 0
fi

# Use the validated path going forward
FILE_PATH="$FILE_PATH_REAL"

# Setup logging
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/quality-gates-$(date +%Y%m%d).log"

# Get file extension
EXT="${FILE_PATH##*.}"

# Initialize result tracking
BLOCKING_ERRORS=""
ADVISORY_WARNINGS=""
CHECKS_RUN=0
CHECKS_PASSED=0

log_check() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    echo "  [$status] $check_name: $message" >> "$LOG_FILE"
}

{
    echo ""
    echo "[$(date -Iseconds)] Quality Gates v2.46 - $FILE_PATH"
    echo "  Session: $SESSION_ID"
    echo "  Extension: $EXT"
    echo ""
    echo "  === STAGE 1: CORRECTNESS (blocking) ==="

    # Stage 1: CORRECTNESS - Syntax/Parse errors (BLOCKING)
    case "$EXT" in
        py)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            if python3 -m py_compile "$FILE_PATH" 2>&1; then
                log_check "Python syntax" "PASS" "Valid syntax"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_check "Python syntax" "FAIL" "Syntax error"
                BLOCKING_ERRORS+="Python syntax error in $FILE_PATH\n"
            fi
            ;;

        ts|tsx)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            if command -v npx &>/dev/null; then
                if npx tsc --noEmit --skipLibCheck "$FILE_PATH" 2>&1 | head -5; then
                    log_check "TypeScript" "PASS" "No type errors"
                    CHECKS_PASSED=$((CHECKS_PASSED + 1))
                else
                    # Check if it's a real error or just warnings
                    TS_OUTPUT=$(npx tsc --noEmit --skipLibCheck "$FILE_PATH" 2>&1 || true)
                    if echo "$TS_OUTPUT" | grep -q "error TS"; then
                        log_check "TypeScript" "FAIL" "Type errors found"
                        BLOCKING_ERRORS+="TypeScript errors in $FILE_PATH\n"
                    else
                        log_check "TypeScript" "PASS" "Compiled with warnings"
                        CHECKS_PASSED=$((CHECKS_PASSED + 1))
                    fi
                fi
            fi
            ;;

        js|jsx)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            if node --check "$FILE_PATH" 2>&1; then
                log_check "JavaScript syntax" "PASS" "Valid syntax"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_check "JavaScript syntax" "FAIL" "Syntax error"
                BLOCKING_ERRORS+="JavaScript syntax error in $FILE_PATH\n"
            fi
            ;;

        go)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            if command -v gofmt &>/dev/null; then
                if gofmt -e "$FILE_PATH" >/dev/null 2>&1; then
                    log_check "Go syntax" "PASS" "Valid syntax"
                    CHECKS_PASSED=$((CHECKS_PASSED + 1))
                else
                    log_check "Go syntax" "FAIL" "Syntax error"
                    BLOCKING_ERRORS+="Go syntax error in $FILE_PATH\n"
                fi
            fi
            ;;

        rs)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            # Rust syntax check via rustfmt
            if command -v rustfmt &>/dev/null; then
                if rustfmt --check "$FILE_PATH" 2>&1; then
                    log_check "Rust syntax" "PASS" "Valid syntax"
                    CHECKS_PASSED=$((CHECKS_PASSED + 1))
                else
                    log_check "Rust syntax" "WARN" "Format issues"
                    ADVISORY_WARNINGS+="Rust formatting issues in $FILE_PATH\n"
                    CHECKS_PASSED=$((CHECKS_PASSED + 1))  # Not blocking
                fi
            fi
            ;;

        json)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            if python3 -c "import json; json.load(open('$FILE_PATH'))" 2>&1; then
                log_check "JSON syntax" "PASS" "Valid JSON"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_check "JSON syntax" "FAIL" "Invalid JSON"
                BLOCKING_ERRORS+="Invalid JSON in $FILE_PATH\n"
            fi
            ;;

        yaml|yml)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            if python3 -c "import yaml; yaml.safe_load(open('$FILE_PATH'))" 2>&1; then
                log_check "YAML syntax" "PASS" "Valid YAML"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_check "YAML syntax" "FAIL" "Invalid YAML"
                BLOCKING_ERRORS+="Invalid YAML in $FILE_PATH\n"
            fi
            ;;

        sh|bash)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            if bash -n "$FILE_PATH" 2>&1; then
                log_check "Bash syntax" "PASS" "Valid syntax"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_check "Bash syntax" "FAIL" "Syntax error"
                BLOCKING_ERRORS+="Bash syntax error in $FILE_PATH\n"
            fi
            ;;
    esac

    echo ""
    echo "  === STAGE 2: QUALITY (blocking) ==="

    # Stage 2: QUALITY - Type checking for typed languages (BLOCKING)
    case "$EXT" in
        py)
            if command -v mypy &>/dev/null; then
                CHECKS_RUN=$((CHECKS_RUN + 1))
                MYPY_OUTPUT=$(mypy "$FILE_PATH" --ignore-missing-imports 2>&1 || true)
                if echo "$MYPY_OUTPUT" | grep -q "error:"; then
                    ERROR_COUNT=$(echo "$MYPY_OUTPUT" | grep -c "error:" || echo "0")
                    log_check "Python types" "FAIL" "$ERROR_COUNT type errors"
                    BLOCKING_ERRORS+="Type errors in $FILE_PATH ($ERROR_COUNT errors)\n"
                else
                    log_check "Python types" "PASS" "No type errors"
                    CHECKS_PASSED=$((CHECKS_PASSED + 1))
                fi
            fi
            ;;
    esac

    echo ""
    echo "  === STAGE 3: CONSISTENCY (advisory - NOT blocking) ==="

    # Stage 3: CONSISTENCY - Linting (ADVISORY - warnings only)
    case "$EXT" in
        py)
            if command -v ruff &>/dev/null; then
                CHECKS_RUN=$((CHECKS_RUN + 1))
                RUFF_OUTPUT=$(ruff check "$FILE_PATH" 2>&1 || true)
                if [[ -n "$RUFF_OUTPUT" ]] && echo "$RUFF_OUTPUT" | grep -qE "^$FILE_PATH"; then
                    LINT_COUNT=$(echo "$RUFF_OUTPUT" | grep -c "^$FILE_PATH" || echo "0")
                    log_check "Python lint (ruff)" "WARN" "$LINT_COUNT style issues (advisory)"
                    ADVISORY_WARNINGS+="Style issues in $FILE_PATH ($LINT_COUNT warnings) - not blocking per quality-over-consistency policy\n"
                else
                    log_check "Python lint (ruff)" "PASS" "No lint issues"
                fi
                CHECKS_PASSED=$((CHECKS_PASSED + 1))  # Always passes (advisory)
            fi
            ;;

        ts|tsx|js|jsx)
            if command -v npx &>/dev/null && [[ -f "$(dirname "$FILE_PATH")/.eslintrc.js" ]] || [[ -f "$(dirname "$FILE_PATH")/.eslintrc.json" ]] || [[ -f "$(dirname "$FILE_PATH")/eslint.config.js" ]]; then
                CHECKS_RUN=$((CHECKS_RUN + 1))
                ESLINT_OUTPUT=$(npx eslint "$FILE_PATH" 2>&1 || true)
                if echo "$ESLINT_OUTPUT" | grep -qE "error|warning"; then
                    LINT_COUNT=$(echo "$ESLINT_OUTPUT" | grep -cE "error|warning" || echo "0")
                    log_check "ESLint" "WARN" "$LINT_COUNT issues (advisory)"
                    ADVISORY_WARNINGS+="ESLint issues in $FILE_PATH ($LINT_COUNT warnings) - not blocking per quality-over-consistency policy\n"
                else
                    log_check "ESLint" "PASS" "No lint issues"
                fi
                CHECKS_PASSED=$((CHECKS_PASSED + 1))  # Always passes (advisory)
            fi
            ;;

        go)
            if command -v golint &>/dev/null; then
                CHECKS_RUN=$((CHECKS_RUN + 1))
                GOLINT_OUTPUT=$(golint "$FILE_PATH" 2>&1 || true)
                if [[ -n "$GOLINT_OUTPUT" ]]; then
                    log_check "Go lint" "WARN" "Style issues (advisory)"
                    ADVISORY_WARNINGS+="Go lint issues in $FILE_PATH - not blocking per quality-over-consistency policy\n"
                else
                    log_check "Go lint" "PASS" "No lint issues"
                fi
                CHECKS_PASSED=$((CHECKS_PASSED + 1))  # Always passes (advisory)
            fi
            ;;
    esac

    echo ""
    echo "  Summary: $CHECKS_PASSED/$CHECKS_RUN checks passed"
    if [[ -n "$BLOCKING_ERRORS" ]]; then
        echo "  BLOCKING ERRORS:"
        echo -e "    $BLOCKING_ERRORS"
    fi
    if [[ -n "$ADVISORY_WARNINGS" ]]; then
        echo "  ADVISORY WARNINGS (not blocking):"
        echo -e "    $ADVISORY_WARNINGS"
    fi
    echo ""

} >> "$LOG_FILE" 2>&1

# Prepare response
if [[ -n "$BLOCKING_ERRORS" ]]; then
    # Quality issues - BLOCK
    ERRORS_JSON=$(echo -e "$BLOCKING_ERRORS" | jq -R -s '.')
    WARNINGS_JSON=$(echo -e "$ADVISORY_WARNINGS" | jq -R -s '.')
    echo "{
        \"decision\": \"block\",
        \"reason\": \"Quality gate failed: blocking errors found\",
        \"blocking_errors\": $ERRORS_JSON,
        \"advisory_warnings\": $WARNINGS_JSON,
        \"checks\": {\"passed\": $CHECKS_PASSED, \"total\": $CHECKS_RUN}
    }"
else
    # No blocking errors - CONTINUE (with warnings if any)
    if [[ -n "$ADVISORY_WARNINGS" ]]; then
        WARNINGS_JSON=$(echo -e "$ADVISORY_WARNINGS" | jq -R -s '.')
        echo "{
            \"decision\": \"continue\",
            \"advisory_warnings\": $WARNINGS_JSON,
            \"note\": \"Quality over consistency: style issues noted but not blocking\",
            \"checks\": {\"passed\": $CHECKS_PASSED, \"total\": $CHECKS_RUN}
        }"
    else
        echo "{
            \"decision\": \"continue\",
            \"checks\": {\"passed\": $CHECKS_PASSED, \"total\": $CHECKS_RUN}
        }"
    fi
fi

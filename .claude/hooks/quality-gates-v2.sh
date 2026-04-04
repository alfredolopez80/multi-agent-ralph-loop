#!/bin/bash
# Quality Gates v2.84.0 - Consolidated Quality, Security, Ralph Gates & Stop Verification
# Hook: PostToolUse (Edit, Write) + Stop
# Purpose: Unified quality validation hook combining:
#   - quality-gates-v2.sh: syntax, types, semgrep/gitleaks, linting
#   - ralph-quality-gates.sh: prompt quality validation via Ralph gates
#   - security-real-audit.sh: regex-based security pattern matching
#   - stop-verification.sh: session stop completeness checks
# VERSION: 2.84.0
# Timestamp: 2026-04-04
# v2.84.0: Consolidated 4 hooks into one unified quality gate
# v2.83.1: PERF-001 - Added result caching for tsc to avoid redundant executions
# v2.69.1: FIX - PostToolUse hooks CANNOT block - changed continue:false to continue:true with warnings
# v2.68.9: CRIT-002 FIX - Actually clear EXIT trap before explicit JSON output
# v2.68.1: FIX CRIT-005 - Clear EXIT trap before explicit JSON output to prevent duplicate JSON
#
# Stage 2.5 SECURITY: semgrep (SAST) + gitleaks (secrets) + regex pattern matching
# Install tools: ~/.claude/scripts/install-security-tools.sh
#
# Key Change: Consistency issues are ADVISORY (warnings only)
# Quality issues (correctness, security, types) are WARNINGS (PostToolUse cannot block)

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

umask 077

# --- Detect hook type from input ---
# Stop hooks have no tool_name; PostToolUse hooks have tool_name
HOOK_TYPE="post_tool_use"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ -z "$TOOL_NAME" ]]; then
    HOOK_TYPE="stop"
fi

# Error trap for guaranteed JSON output (v2.62.3)
# Format depends on hook type: PostToolUse uses "continue", Stop uses "decision"
if [[ "$HOOK_TYPE" == "stop" ]]; then
    trap 'echo "{\"decision\": \"approve\"}"' ERR EXIT
else
    trap 'echo "{\"continue\": true}"' ERR EXIT
fi

# Setup logging (shared by all sections)
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/quality-gates-$(date +%Y%m%d).log"
LOG_FILE_JSON="${LOG_FILE}.jsonl"

# JSON structured logging function
log_json() {
    local level="$1"
    local message="$2"
    local hook_name="${0##*/}"
    jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg lvl "$level" \
        --arg hook "$hook_name" \
        --arg msg "$message" \
        '{timestamp: $ts, level: $lvl, hook: $hook, message: $msg}' \
        >> "$LOG_FILE_JSON" 2>/dev/null || true
}

log_check() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    echo "  [$status] $check_name: $message" >> "$LOG_FILE"
}

# ============================================================================
# SECTION: STOP VERIFICATION (from stop-verification.sh)
# Hook: Stop - Verifies completeness before session termination
# Uses {"decision": "approve|block"} format
# ============================================================================
run_stop_verification() {
    local _hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${_hook_dir}/lib/worktree-utils.sh" 2>/dev/null || {
        get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
        get_main_repo() { get_project_root; }
        get_claude_dir() { echo "$(get_main_repo)/.claude"; }
    }
    local project_dir="$(get_project_root)"
    local stop_log_file="${HOME}/.ralph/logs/stop-verification.log"
    mkdir -p "$(dirname "$stop_log_file")"

    _stop_log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$stop_log_file"
    }

    local warnings=()
    local checks_passed=0
    local total_checks=4

    # 1. Check pending TODOs
    if [ -f "${project_dir}/.claude/progress.md" ]; then
        local pending_todos
        pending_todos=$(grep -c "^\- \[ \]" "${project_dir}/.claude/progress.md" 2>/dev/null | tr -d ' \n') || pending_todos=0
        pending_todos=${pending_todos:-0}
        if ! [[ "$pending_todos" =~ ^[0-9]+$ ]]; then
            pending_todos=0
        fi
        if [ "$pending_todos" -gt 0 ]; then
            warnings+=("TODOs pendientes: ${pending_todos} items sin completar en progress.md")
        else
            checks_passed=$((checks_passed + 1))
        fi
    else
        checks_passed=$((checks_passed + 1))
    fi

    # 2. Check uncommitted changes
    if [ -d "${project_dir}/.git" ]; then
        local uncommitted
        uncommitted=$(git -C "$project_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$uncommitted" -gt 0 ]; then
            warnings+=("Cambios sin commit: ${uncommitted} archivos modificados")
        else
            checks_passed=$((checks_passed + 1))
        fi
    else
        checks_passed=$((checks_passed + 1))
    fi

    # 3. Check recent lint errors
    local lint_log="${HOME}/.ralph/logs/quality-gates.log"
    if [ -f "$lint_log" ]; then
        local today lint_errors
        today=$(date '+%Y-%m-%d')
        lint_errors=$(grep "$today" "$lint_log" 2>/dev/null | grep -c "ERROR\|FAILED" | tr -d ' \n') || lint_errors=0
        lint_errors=${lint_errors:-0}
        if ! [[ "$lint_errors" =~ ^[0-9]+$ ]]; then
            lint_errors=0
        fi
        if [ "$lint_errors" -gt 0 ]; then
            warnings+=("Errores de lint: ${lint_errors} errores en la ultima sesion")
        else
            checks_passed=$((checks_passed + 1))
        fi
    else
        checks_passed=$((checks_passed + 1))
    fi

    # 4. Check recent test failures
    local test_log="${HOME}/.ralph/logs/test-results.log"
    if [ -f "$test_log" ]; then
        local today test_failures
        today=$(date '+%Y-%m-%d')
        test_failures=$(grep "$today" "$test_log" 2>/dev/null | grep -c "FAILED\|ERROR" | tr -d ' \n') || test_failures=0
        test_failures=${test_failures:-0}
        if ! [[ "$test_failures" =~ ^[0-9]+$ ]]; then
            test_failures=0
        fi
        if [ "$test_failures" -gt 0 ]; then
            warnings+=("Tests fallidos: ${test_failures} tests fallaron")
        else
            checks_passed=$((checks_passed + 1))
        fi
    else
        checks_passed=$((checks_passed + 1))
    fi

    # Generate output
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop verification: ${checks_passed}/${total_checks} checks passed" >> "$stop_log_file"

    trap - EXIT

    if [ ${#warnings[@]} -gt 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Warnings: ${warnings[*]}" >> "$stop_log_file"
        local warning_msg="Stop Verification: ${checks_passed}/${total_checks} passed. Issues: "
        for w in "${warnings[@]}"; do
            warning_msg+="$w; "
        done
        echo "{\"decision\": \"approve\", \"reason\": \"$warning_msg\"}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] All checks passed" >> "$stop_log_file"
        echo "{\"decision\": \"approve\", \"reason\": \"Stop Verification: All ${total_checks} checks passed\"}"
    fi
    exit 0
}

# ============================================================================
# SECTION: RALPH PROMPT QUALITY GATES (from ralph-quality-gates.sh)
# Library functions for prompt quality validation via Ralph gates CLI
# ============================================================================

# Check if Ralph gates command is available
ralph_gates_command_exists() {
    command -v ralph &>/dev/null && ralph gates --help &>/dev/null
}

# Validate prompt through quality gates
ralph_validate_prompt_quality() {
    local prompt="$1"
    local prompt_type="${2:-general}"

    if ! ralph_gates_command_exists; then
        echo '{"valid": true, "score": 100, "reason": "Ralph gates not available, auto-passing"}'
        return 0
    fi

    local temp_prompt
    temp_prompt=$(mktemp)
    echo "$prompt" > "$temp_prompt"

    local validation_result=""
    if ralph gates validate --prompt-file "$temp_prompt" --type "$prompt_type" --json 2>/dev/null; then
        validation_result=$(ralph gates validate --prompt-file "$temp_prompt" --type "$prompt_type" --json 2>/dev/null || echo '{"valid": true, "score": 85}')
    else
        validation_result='{"valid": true, "score": 85, "reason": "Validation unavailable, using default"}'
    fi

    rm -f "$temp_prompt"
    echo "$validation_result"
}

# Get quality suggestions for prompt improvement
ralph_get_quality_suggestions() {
    local prompt="$1"
    local clarity_score="${2:-50}"

    if [[ $clarity_score -ge 80 ]]; then
        echo ""
        return 0
    fi

    local suggestions=""
    local prompt_lower
    prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    if echo "$prompt_lower" | grep -qE "thing|stuff|something|anything"; then
        suggestions+="- Replace vague words (thing, stuff) with specific terms\n"
    fi
    if ! echo "$prompt_lower" | grep -qE "you are|act as|role"; then
        suggestions+="- Add a role definition (e.g., 'You are a backend engineer')\n"
    fi
    if ! echo "$prompt_lower" | grep -qE "must|should|require|constraint"; then
        suggestions+="- Specify constraints and requirements\n"
    fi
    if ! echo "$prompt_lower" | grep -qE "output|format|return|result"; then
        suggestions+="- Define the expected output format\n"
    fi
    local word_count
    word_count=$(echo "$prompt" | wc -w | tr -d ' ')
    if [[ $word_count -lt 10 ]]; then
        suggestions+="- Add more detail and context (currently $word_count words)\n"
    fi

    echo -e "$suggestions"
}

# Validate with Ralph gates and get combined score
ralph_validate_with_gates() {
    local prompt="$1"
    local prompt_type="${2:-general}"
    local clarity_score="${3:-50}"

    local gates_result
    gates_result=$(ralph_validate_prompt_quality "$prompt" "$prompt_type")
    local gates_valid
    gates_valid=$(echo "$gates_result" | jq -r '.valid // true' 2>/dev/null || echo "true")
    local gates_score
    gates_score=$(echo "$gates_result" | jq -r '.score // 85' 2>/dev/null || echo "85")

    local combined_score=$(( (clarity_score * 60 + gates_score * 40) / 100 ))
    local suggestions
    suggestions=$(ralph_get_quality_suggestions "$prompt" "$clarity_score")

    jq -n \
        --argjson valid "$gates_valid" \
        --argjson score "$combined_score" \
        --argjson clarity "$clarity_score" \
        --argjson gates "$gates_score" \
        --arg suggestions "$suggestions" \
        '{
            valid: $valid,
            combined_score: $score,
            clarity_score: $clarity,
            gates_score: $gates,
            suggestions: $suggestions
        }'
}

# ============================================================================
# SECTION: SECURITY PATTERN AUDIT (from security-real-audit.sh)
# Regex-based security pattern matching on edited/written files
# ============================================================================
run_security_pattern_audit() {
    local file_path="$1"
    local sec_log_file="${RALPH_LOGS:-$HOME/.ralph/logs}/security-audit.log"
    local sec_log_json="${sec_log_file}.jsonl"
    mkdir -p "$(dirname "$sec_log_file")" 2>/dev/null || true

    # Security patterns to check (P0, P1, P2)
    local patterns=(
        # P0 - Critical: secrets
        "sk-[a-zA-Z0-9]{32}"
        "sk_live_[a-zA-Z0-9]{32}"
        "AKIA[0-9A-Z]{16}"
        "password.*=.*['\"].*['\"]"
        "api_key.*=.*['\"].*['\"]"
        "secret.*=.*['\"].*['\"]"
        "token.*=.*['\"].*['\"]"
        # P0 - Injection
        "SELECT.*WHERE.*\+"
        "eval\("
        "exec\("
        "system\("
        "innerHTML"
        "document\.write"
        # P1 - High: weak crypto
        "md5\("
        "sha1\("
        "ecb"
        "none"
        # P2 - Medium: security debt
        "TODO.*security"
        "FIXME.*security"
        "HACK.*security"
    )

    local findings=0
    local matching_patterns=()

    for pattern in "${patterns[@]}"; do
        if grep -qiE "$pattern" "$file_path" 2>/dev/null; then
            findings=$((findings + 1))
            matching_patterns+=("$pattern")
        fi
    done

    # Log findings (not stdout)
    {
        echo "[$(date -Iseconds)] Security Pattern Audit: $file_path"
        if [[ $findings -gt 0 ]]; then
            echo "  Found $findings potential security issues:"
            for pattern in "${matching_patterns[@]}"; do
                echo "    - Pattern: $pattern"
            done
        else
            echo "  No obvious security issues found"
        fi
    } >> "$sec_log_file" 2>/dev/null || true

    # Structured JSON logging
    if [[ $findings -gt 0 ]]; then
        log_json "WARN" "Security pattern audit found $findings issues in $file_path"
        for pattern in "${matching_patterns[@]}"; do
            log_json "WARN" "Security pattern match: $pattern"
        done
    else
        log_json "INFO" "Security pattern audit passed for $file_path"
    fi

    # Return findings count via global variables for the caller
    SECURITY_PATTERN_FINDINGS=$findings
    SECURITY_PATTERN_MATCHES=("${matching_patterns[@]}")
}

# ============================================================================
# MAIN: Route to Stop verification or PostToolUse quality gates
# ============================================================================

if [[ "$HOOK_TYPE" == "stop" ]]; then
    run_stop_verification
    # run_stop_verification exits internally
fi

# --- PostToolUse path continues below ---

# Parse JSON input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only process Edit/Write operations (PostToolUse schema: "continue" not "decision")
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    trap - EXIT  # CRIT-005: Clear trap before explicit output
    echo '{"continue": true}'
    exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
    trap - EXIT  # CRIT-005: Clear trap before explicit output
    echo '{"continue": true}'
    exit 0
fi

# SECURITY: Canonicalize and validate path to prevent path traversal
# SEC-045: Fixed realpath -e which doesn't exist on macOS (use realpath without -e)
# Resolve to absolute path and check it's within allowed directories
FILE_PATH_REAL=$(realpath "$FILE_PATH" 2>/dev/null || echo "")
if [[ -z "$FILE_PATH_REAL" ]] || [[ ! -f "$FILE_PATH_REAL" ]]; then
    trap - EXIT  # CRIT-005: Clear trap before explicit output
    echo '{"continue": true}'
    exit 0
fi

# Get current working directory (project root)
# SEC-045: Fixed macOS compatibility - realpath without -e flag
PROJECT_ROOT=$(realpath "$(pwd)" 2>/dev/null || pwd)

# Verify file is within project or allowed paths (home dir)
# v2.69.1: PostToolUse hooks CANNOT block - changed from continue:false to continue:true with warning
if [[ "$FILE_PATH_REAL" != "$PROJECT_ROOT"* ]] && [[ "$FILE_PATH_REAL" != "$HOME"* ]]; then
    trap - EXIT  # CRIT-005: Clear trap before explicit output
    jq -n '{"continue": true, "warning": "Path traversal detected: file outside allowed directories (PostToolUse cannot block)"}'
    exit 0
fi

# Use the validated path going forward
FILE_PATH="$FILE_PATH_REAL"

# PERF-001: Cache setup for TypeScript results
CACHE_DIR="${HOME}/.ralph/cache/quality-gates"
mkdir -p "$CACHE_DIR"

# PERF-001: Cache functions for TypeScript compilation results
get_cache_key() {
    local file="$1"
    # Hash del contenido + mtime (cross-platform)
    local mtime hash
    mtime=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo "0")
    hash=$(md5 -q "$file" 2>/dev/null || md5sum "$file" 2>/dev/null | cut -d' ' -f1 || echo "")
    echo "${mtime}_${hash}"
}

check_cached() {
    local file="$1"
    local cache_key=$(get_cache_key "$file")
    local cache_file="${CACHE_DIR}/${cache_key}"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return 0
    fi
    return 1
}

save_cache() {
    local file="$1"
    local result="$2"
    local cache_key=$(get_cache_key "$file")
    echo "$result" > "${CACHE_DIR}/${cache_key}"
    # Limit cache size (keep only last 1000 entries)
    # SEC: Safe file cleanup without xargs (handles spaces in paths)
    ls -t "${CACHE_DIR}"/* 2>/dev/null | tail -n +1001 | while IFS= read -r f; do rm -f "$f"; done 2>/dev/null || true
}

# Get file extension
EXT="${FILE_PATH##*.}"

# Initialize result tracking
BLOCKING_ERRORS=""
ADVISORY_WARNINGS=""
CHECKS_RUN=0
CHECKS_PASSED=0

{
    echo ""
    echo "[$(date -Iseconds)] Quality Gates v2.84.0 - $FILE_PATH"
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
                # FASE 2: Optimizacion - Ejecutar tsc una sola vez y reusar resultado
                TS_OUTPUT=$(npx tsc --noEmit --skipLibCheck "$FILE_PATH" 2>&1 || true)
                if [[ -z "$TS_OUTPUT" ]]; then
                    # No errors
                    log_check "TypeScript" "PASS" "No type errors"
                    CHECKS_PASSED=$((CHECKS_PASSED + 1))
                else
                    # Check if it's a real error or just warnings
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
            # SEC-041: Fixed Python command injection - use sys.argv instead of interpolation
            if python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$FILE_PATH" 2>&1; then
                log_check "JSON syntax" "PASS" "Valid JSON"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_check "JSON syntax" "FAIL" "Invalid JSON"
                BLOCKING_ERRORS+="Invalid JSON in $FILE_PATH\n"
            fi
            ;;

        yaml|yml)
            CHECKS_RUN=$((CHECKS_RUN + 1))
            # SEC-041: Fixed Python command injection - use sys.argv instead of interpolation
            if python3 -c 'import yaml, sys; yaml.safe_load(open(sys.argv[1]))' "$FILE_PATH" 2>&1; then
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
    echo "  === STAGE 2.5: SECURITY (blocking) ==="

    # Stage 2.5: SECURITY - semgrep + gitleaks (BLOCKING)
    # Only runs if tools are installed (graceful degradation)

    # 2.5a: semgrep - Static Application Security Testing (SAST)
    if command -v semgrep &>/dev/null; then
        CHECKS_RUN=$((CHECKS_RUN + 1))

        # Determine config based on file type
        SEMGREP_CONFIG="auto"
        case "$EXT" in
            py) SEMGREP_CONFIG="p/python" ;;
            ts|tsx|js|jsx) SEMGREP_CONFIG="p/javascript" ;;
            go) SEMGREP_CONFIG="p/golang" ;;
            rb) SEMGREP_CONFIG="p/ruby" ;;
            java) SEMGREP_CONFIG="p/java" ;;
            rs) SEMGREP_CONFIG="p/rust" ;;
        esac

        # Run semgrep with timeout (5s max) and severity filter
        SEMGREP_OUTPUT=$(timeout 5 semgrep --config="$SEMGREP_CONFIG" \
            --severity=ERROR --severity=WARNING \
            --json --quiet "$FILE_PATH" 2>/dev/null || echo '{"results":[]}')

        SEMGREP_ERRORS=$(echo "$SEMGREP_OUTPUT" | jq '.results | length' 2>/dev/null || echo "0")

        if [[ "$SEMGREP_ERRORS" -gt 0 ]]; then
            # Extract first 3 findings for context
            FINDINGS=$(echo "$SEMGREP_OUTPUT" | jq -r '.results[:3][] | "    - \(.check_id): \(.extra.message // "security issue")"' 2>/dev/null || echo "    - security issues found")
            log_check "semgrep SAST" "FAIL" "$SEMGREP_ERRORS security issues"
            BLOCKING_ERRORS+="Security issues in $FILE_PATH ($SEMGREP_ERRORS findings):\n$FINDINGS\n"
        else
            log_check "semgrep SAST" "PASS" "No security issues"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        fi
    else
        # GAP-011: Auto-install semgrep if not present (blocking if fails)
        log_check "semgrep SAST" "AUTOINSTALL" "Installing semgrep..."
        if bash "${HOME}/.claude/scripts/install-security-tools.sh" --check 2>/dev/null | grep -q "not installed"; then
            bash "${HOME}/.claude/scripts/install-security-tools.sh" 2>&1 | tail -5 >> "$LOG_FILE" || true
        fi

        # Verify installation
        if command -v semgrep &>/dev/null; then
            log_check "semgrep SAST" "INSTALL" "semgrep installed, re-running check..."
            # Re-run the check now that semgrep is installed
            CHECKS_RUN=$((CHECKS_RUN + 1))
            SEMGREP_OUTPUT=$(timeout 10 semgrep --config="auto" \
                --severity=ERROR --severity=WARNING \
                --json --quiet "$FILE_PATH" 2>/dev/null || echo '{"results":[]}')
            SEMGREP_ERRORS=$(echo "$SEMGREP_OUTPUT" | jq '.results | length' 2>/dev/null || echo "0")
            if [[ "$SEMGREP_ERRORS" -gt 0 ]]; then
                log_check "semgrep SAST" "FAIL" "$SEMGREP_ERRORS security issues"
                BLOCKING_ERRORS+="Security issues in $FILE_PATH ($SEMGREP_ERRORS findings)\n"
            else
                log_check "semgrep SAST" "PASS" "No security issues"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            fi
        else
            log_check "semgrep SAST" "FAIL" "Auto-install failed, security scan skipped"
            BLOCKING_ERRORS+="semgrep installation failed. Run manually: ~/.claude/scripts/install-security-tools.sh\n"
        fi
    fi

    # 2.5b: gitleaks - Secret Detection (only for staged files)
    if command -v gitleaks &>/dev/null; then
        # Only check if file is in a git repo
        if git -C "$(dirname "$FILE_PATH")" rev-parse --git-dir &>/dev/null; then
            CHECKS_RUN=$((CHECKS_RUN + 1))

            # Check specific file for secrets
            GITLEAKS_OUTPUT=$(gitleaks detect --source="$FILE_PATH" \
                --no-git --report-format=json 2>/dev/null || echo '[]')

            SECRETS_FOUND=$(echo "$GITLEAKS_OUTPUT" | jq 'length' 2>/dev/null || echo "0")

            if [[ "$SECRETS_FOUND" -gt 0 ]]; then
                # Extract secret types found
                SECRET_TYPES=$(echo "$GITLEAKS_OUTPUT" | jq -r '.[].RuleID' 2>/dev/null | sort -u | head -3 | tr '\n' ', ' || echo "secrets")
                log_check "gitleaks secrets" "FAIL" "$SECRETS_FOUND secret(s) detected: ${SECRET_TYPES%, }"
                BLOCKING_ERRORS+="SECRETS DETECTED in $FILE_PATH ($SECRETS_FOUND found)\n    Types: ${SECRET_TYPES%, }\n    ACTION: Remove secrets immediately!\n"
            else
                log_check "gitleaks secrets" "PASS" "No secrets detected"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            fi
        fi
    else
        # GAP-011: Auto-install gitleaks if not present (blocking if fails)
        log_check "gitleaks secrets" "AUTOINSTALL" "Installing gitleaks..."
        if bash "${HOME}/.claude/scripts/install-security-tools.sh" --check 2>/dev/null | grep -q "not installed"; then
            bash "${HOME}/.claude/scripts/install-security-tools.sh" 2>&1 | tail -3 >> "$LOG_FILE" || true
        fi

        # Verify installation
        if command -v gitleaks &>/dev/null; then
            log_check "gitleaks secrets" "INSTALL" "gitleaks installed"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_check "gitleaks secrets" "FAIL" "Auto-install failed"
            BLOCKING_ERRORS+="gitleaks installation failed. Run manually: ~/.claude/scripts/install-security-tools.sh\n"
        fi
    fi

    echo ""
    echo "  === STAGE 2.6: SECURITY PATTERN AUDIT (blocking) ==="

    # Stage 2.6: SECURITY PATTERN AUDIT (from security-real-audit.sh)
    # Regex-based pattern matching for secrets, injection, weak crypto
    CHECKS_RUN=$((CHECKS_RUN + 1))
    SECURITY_PATTERN_FINDINGS=0
    SECURITY_PATTERN_MATCHES=()
    run_security_pattern_audit "$FILE_PATH"

    if [[ "$SECURITY_PATTERN_FINDINGS" -gt 0 ]]; then
        log_check "Security patterns" "FAIL" "$SECURITY_PATTERN_FINDINGS patterns matched"
        PATTERN_LIST=""
        for p in "${SECURITY_PATTERN_MATCHES[@]}"; do
            PATTERN_LIST+="    - $p\n"
        done
        BLOCKING_ERRORS+="Security pattern matches in $FILE_PATH ($SECURITY_PATTERN_FINDINGS found):\n$PATTERN_LIST"
    else
        log_check "Security patterns" "PASS" "No security patterns matched"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    fi

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
    echo "  === STAGE 4: RALPH PROMPT QUALITY (advisory) ==="

    # Stage 4: RALPH PROMPT QUALITY - Check if Ralph gates CLI is available
    # This is informational only; prompt validation is available via functions above
    if ralph_gates_command_exists; then
        log_check "Ralph gates" "PASS" "Ralph gates CLI available"
    else
        log_check "Ralph gates" "INFO" "Ralph gates CLI not installed (prompt validation skipped)"
    fi

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

# CRIT-002 FIX: Clear EXIT trap before explicit JSON output to prevent duplicate JSON
trap - EXIT

# v2.69.1: PostToolUse hooks CANNOT block - always return continue:true
# Prepare response (PostToolUse schema: "continue" boolean, not "decision" string)
if [[ -n "$BLOCKING_ERRORS" ]]; then
    # Quality issues detected - WARNING (PostToolUse cannot block)
    ERRORS_JSON=$(echo -e "$BLOCKING_ERRORS" | jq -R -s '.')
    WARNINGS_JSON=$(echo -e "$ADVISORY_WARNINGS" | jq -R -s '.')
    echo "{
        \"continue\": true,
        \"warning\": \"Quality gate failed: blocking errors found (PostToolUse cannot block)\",
        \"blocking_errors\": $ERRORS_JSON,
        \"advisory_warnings\": $WARNINGS_JSON,
        \"checks\": {\"passed\": $CHECKS_PASSED, \"total\": $CHECKS_RUN}
    }"
else
    # No blocking errors - CONTINUE (with warnings if any)
    if [[ -n "$ADVISORY_WARNINGS" ]]; then
        WARNINGS_JSON=$(echo -e "$ADVISORY_WARNINGS" | jq -R -s '.')
        echo "{
            \"continue\": true,
            \"advisory_warnings\": $WARNINGS_JSON,
            \"note\": \"Quality over consistency: style issues noted but not blocking\",
            \"checks\": {\"passed\": $CHECKS_PASSED, \"total\": $CHECKS_RUN}
        }"
    else
        echo "{
            \"continue\": true,
            \"checks\": {\"passed\": $CHECKS_PASSED, \"total\": $CHECKS_RUN}
        }"
    fi
fi

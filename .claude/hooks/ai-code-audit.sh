#!/usr/bin/env bash
#===============================================================================
# AI Code Audit Hook v2.68.0
# PostToolUse hook - AUTO-INVOKE comprehensive AI code quality checks
#===============================================================================
#
# VERSION: 2.68.23
# TRIGGER: PostToolUse (Edit|Write) - After significant code changes
# PURPOSE: Detect and flag AI-generated code anti-patterns:
#   - Dead code and unused imports
#   - Over-engineering / premature abstraction
#   - Fallback/placeholder patterns that pass tests but fail in production
#   - Mock behavior testing (tests that test mocks, not real behavior)
#   - Hardcoded data in tests
#   - YAGNI violations
#
# SKILLS INVOKED: /deslop, /code-reviewer, testing-anti-patterns, kaizen

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

readonly VERSION="2.68.0"
readonly HOOK_NAME="ai-code-audit"

# Configuration
readonly MARKERS_DIR="${HOME}/.ralph/markers"
readonly LOG_FILE="${HOME}/.ralph/logs/ai-code-audit.log"
readonly THRESHOLD_FILES=3  # Trigger after 3+ files changed
readonly COOLDOWN_MINUTES=20

# Ensure directories exist
mkdir -p "$MARKERS_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Logging
log() {
    echo "[$(date -Iseconds)] [$HOOK_NAME] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get session ID
get_session_id() {
    echo "${CLAUDE_SESSION_ID:-$$}"
}

# Check cooldown
is_within_cooldown() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/ai-audit-cooldown-${session_id}"
    
    if [[ -f "$marker" ]]; then
        local marker_age marker_time
        # MED-008 FIX: Portable stat for macOS and Linux
        if [[ "$OSTYPE" == "darwin"* ]]; then
            marker_time=$(stat -f %m "$marker" 2>/dev/null || echo 0)
        else
            marker_time=$(stat -c %Y "$marker" 2>/dev/null || echo 0)
        fi
        marker_age=$(( $(date +%s) - marker_time ))
        (( marker_age < COOLDOWN_MINUTES * 60 ))
    else
        return 1
    fi
}

# Update cooldown
update_cooldown() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/ai-audit-cooldown-${session_id}"
    touch "$marker" 2>/dev/null || true
}

# Get changed files count in this session
get_changed_files_count() {
    git diff --name-only HEAD~1 2>/dev/null | wc -l | tr -d ' ' || echo "0"
}

# Check if file is test file
is_test_file() {
    local file_path="$1"
    local filename
    filename=$(basename "$file_path" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    
    # SC2221/SC2222 FIX: *test* already covers *.test.*, *spec* covers *.spec.*
    case "$filename" in
        *test*|*spec*)
            return 0
            ;;
    esac
    
    case "$file_path" in
        */__tests__/*|*/tests/*|*/test/*|*/spec/*)
            return 0
            ;;
    esac
    
    return 1
}

# Detect AI code anti-patterns in content
detect_ai_antipatterns() {
    local file_path="$1"
    local patterns_found=()
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    local content
    content=$(cat "$file_path" 2>/dev/null || echo "")
    
    # 1. DEAD CODE PATTERNS
    # Commented out code blocks
    if echo "$content" | grep -qE '^\s*//\s*(const|let|var|function|class|import|export)' 2>/dev/null; then
        patterns_found+=("DEAD_CODE:commented_code")
    fi
    
    # Unused TODO/FIXME that AI adds defensively
    if echo "$content" | grep -qiE 'TODO.*implement|FIXME.*later|TODO.*add' 2>/dev/null; then
        patterns_found+=("DEAD_CODE:placeholder_todo")
    fi
    
    # 2. OVER-ENGINEERING PATTERNS
    # Premature abstraction (interface/abstract for single use)
    if echo "$content" | grep -qE 'abstract class \w+Base|interface I\w+Service' 2>/dev/null; then
        patterns_found+=("OVERKILL:premature_abstraction")
    fi
    
    # Factory pattern for simple instantiation
    if echo "$content" | grep -qE 'Factory\s*{|createInstance|getInstance' 2>/dev/null; then
        patterns_found+=("OVERKILL:unnecessary_factory")
    fi
    
    # 3. FALLBACK/PLACEHOLDER PATTERNS (dangerous - pass tests, fail prod)
    # Default return values that hide failures
    local fallback_pattern='return\s*(\[\]|\{\}|null|undefined|""|0|false)\s*;?\s*//.*fallback'
    if echo "$content" | grep -qiE "$fallback_pattern" 2>/dev/null; then
        patterns_found+=("FALLBACK:silent_default")
    fi
    
    # Catch-all that swallows errors
    if echo "$content" | grep -qE 'catch\s*\([^)]*\)\s*\{[^}]*\}' 2>/dev/null; then
        # Check if catch block is empty or just logs
        if echo "$content" | grep -qE 'catch\s*\([^)]*\)\s*\{\s*(//|console\.log|return|}\s*$)' 2>/dev/null; then
            patterns_found+=("FALLBACK:swallowed_error")
        fi
    fi
    
    # Hardcoded fallback values
    if echo "$content" | grep -qiE '\?\?\s*["\x27].*default.*["\x27]|\?\?\s*\[\]|\|\|\s*\[\]' 2>/dev/null; then
        patterns_found+=("FALLBACK:hardcoded_default")
    fi
    
    # 4. TEST ANTI-PATTERNS (if test file)
    if is_test_file "$file_path"; then
        # Testing mock existence instead of behavior
        if echo "$content" | grep -qE 'expect.*mock.*toBeInTheDocument|expect.*Mock.*toBe' 2>/dev/null; then
            patterns_found+=("TEST:testing_mock_behavior")
        fi
        
        # Hardcoded test data that matches implementation
        if echo "$content" | grep -qE 'expect\(.*\)\.toBe\(["\x27][A-Z_]+["\x27]\)' 2>/dev/null; then
            patterns_found+=("TEST:hardcoded_expected_value")
        fi
        
        # Mock everything pattern
        local mock_count
        mock_count=$(echo "$content" | grep -c 'jest\.mock\|vi\.mock\|mock(' 2>/dev/null || echo "0")
        if [[ "$mock_count" -gt 5 ]]; then
            patterns_found+=("TEST:over_mocking")
        fi
    fi
    
    # 5. AI SLOP PATTERNS
    # Excessive defensive checks
    if echo "$content" | grep -qE 'if\s*\(\s*!\s*\w+\s*\)\s*return|if\s*\(\s*\w+\s*===?\s*(null|undefined)\s*\)' 2>/dev/null; then
        local guard_count
        guard_count=$(echo "$content" | grep -cE 'if\s*\(\s*!\s*\w+\s*\)\s*return' 2>/dev/null || echo "0")
        if [[ "$guard_count" -gt 3 ]]; then
            patterns_found+=("SLOP:excessive_guards")
        fi
    fi
    
    # Type cast to any
    if echo "$content" | grep -qE 'as\s+any|\(\s*\w+\s*as\s+any\s*\)' 2>/dev/null; then
        patterns_found+=("SLOP:any_cast")
    fi
    
    # Return patterns found
    if [[ ${#patterns_found[@]} -gt 0 ]]; then
        printf '%s\n' "${patterns_found[@]}"
        return 0
    fi
    
    return 1
}

# Main logic
main() {
    # Read input from stdin
    local input
    input=$(cat 2>/dev/null || echo '{}')
    
    # Extract tool name and file path
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
    local file_path
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    
    # Only process Edit/Write
    if [[ "$tool_name" != "Edit" ]] && [[ "$tool_name" != "Write" ]]; then
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi
    
    # Skip if within cooldown
    if is_within_cooldown; then
        log "Within cooldown, skipping"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi
    
    # Check changed files count
    local changed_count
    changed_count=$(get_changed_files_count)
    
    if [[ "$changed_count" -lt "$THRESHOLD_FILES" ]]; then
        log "Changed files ($changed_count) < threshold ($THRESHOLD_FILES)"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi
    
    # Detect patterns in current file
    local patterns
    patterns=$(detect_ai_antipatterns "$file_path" 2>/dev/null || echo "")
    
    if [[ -z "$patterns" ]]; then
        log "No AI anti-patterns detected in $file_path"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi
    
    # Update cooldown
    update_cooldown
    
    log "AI ANTI-PATTERNS DETECTED: $patterns"
    
    # Build pattern list for message
    local pattern_list
    pattern_list=$(echo "$patterns" | tr '\n' ', ' | sed 's/,$//')
    
    # Build IMPERATIVE instruction
    local instruction
    instruction=$(cat << EOF
**AUTO-INVOKE REQUIRED: AI Code Quality Audit**

AI-generated code anti-patterns detected in recent changes:
\`$pattern_list\`

**Changed files:** $changed_count files modified

**YOU MUST NOW EXECUTE ONE OF:**

**Option 1 - Full AI Slop Cleanup (RECOMMENDED):**
\`\`\`
/deslop
\`\`\`
Removes: Extra comments, defensive checks, \`any\` casts, inline imports

**Option 2 - Code Review with Factorization:**
\`\`\`yaml
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  prompt: |
    Review recent changes for AI code anti-patterns:
    - Dead code and unused imports
    - Over-engineering / premature abstraction
    - Fallback patterns that hide failures
    - Tests that test mock behavior instead of real behavior
    - YAGNI violations
    
    Suggest factorization and simplification.
\`\`\`

**Option 3 - Kaizen Review (Simplification Focus):**
Apply kaizen principles to simplify over-engineered code.
Check: YAGNI, premature abstraction, unnecessary patterns.

**Detected Pattern Types:**
| Pattern | Issue |
|---------|-------|
| DEAD_CODE | Commented code, placeholder TODOs |
| OVERKILL | Premature abstraction, unnecessary factories |
| FALLBACK | Silent defaults, swallowed errors |
| TEST | Testing mocks, over-mocking, hardcoded values |
| SLOP | Excessive guards, \`any\` casts |

After cleanup, continue with normal flow.
EOF
)
    
    # Output with system message (imperative instruction)
    local escaped_instruction
    escaped_instruction=$(echo "$instruction" | jq -Rs '.')
    
    trap - ERR EXIT
    echo "{\"continue\": true, \"systemMessage\": $escaped_instruction}"
}

main "$@"

#!/bin/bash
# ralph-subagent-start.sh - Initialize subagents with Ralph context, memory, and integration
# VERSION: 2.95.0
# REPO: multi-agent-ralph-loop
#
# Triggered by: SubagentStart hook event (matcher: ralph-*)
# Purpose: Load Ralph context into new subagents, inject active context,
#          coordinate integration setup, and apply procedural memory patterns.
#
# v2.95.0 Changes:
#   - Merged ralph-context-injector.sh (context injection)
#   - Merged ralph-integration.sh (prompt enhancement + quality gate coordination)
#   - Merged ralph-memory-integration.sh (procedural memory patterns)
#
# v2.88.0 Changes:
#   - Register subagent state on start (Finding #4)
#   - Track parent-child relationships
#   - Enable lifecycle tracking for Stop hook
#
# Input (stdin JSON):
#   {
#     "subagentId": "subagent-xxx",
#     "subagentType": "ralph-coder|ralph-reviewer|ralph-tester|ralph-researcher",
#     "parentId": "parent-xxx",
#     "sessionId": "session-xxx",
#     "taskId": "task-xxx"
#   }
#
# Output (stdout JSON):
#   {"continue": true, "hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": "..."}}

set -euo pipefail

# Configuration
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  get_main_repo() { get_project_root; }
  get_claude_dir() { echo "$(get_main_repo)/.claude"; }
}
REPO_ROOT="$(get_project_root)"
STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"
MEMORY_DIR="$HOME/.ralph/memory"
PROCEDURAL_MEMORY="$HOME/.ralph/procedural/rules.json"
PROMPTIFY_CONFIG="$HOME/.ralph/config/promptify.json"
mkdir -p "$LOG_DIR" "$STATE_DIR"

# ============================================
# Section: Context Injection (from ralph-context-injector.sh v1.0.0)
# ============================================

# Check if we're in a Ralph project
is_ralph_project() {
    if [[ -f ".claude/plan-state.json" ]]; then
        return 0
    fi
    if command -v ralph &>/dev/null; then
        if ralph status --compact &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Get Ralph active context
get_ralph_context() {
    local context=""
    if ! command -v ralph &>/dev/null; then
        echo ""
        return 0
    fi
    if ralph context show &>/dev/null; then
        context=$(ralph context show 2>/dev/null || echo "")
    fi
    echo "$context"
}

# Get Ralph memory entries by query
get_ralph_memory() {
    local query="${1:-recent patterns}"
    local memory=""
    if ! command -v ralph &>/dev/null; then
        echo ""
        return 0
    fi
    if ralph memory-search "$query" --limit 5 2>/dev/null; then
        memory=$(ralph memory-search "$query" --limit 5 --format json 2>/dev/null || echo "{}")
    fi
    echo "$memory"
}

# Build context block for prompt enhancement
build_context_block() {
    local include_ralph_context="${1:-true}"
    local include_ralph_memory="${2:-true}"
    local context_block=""

    if [[ "$include_ralph_context" == "true" ]] && is_ralph_project; then
        local ralph_context
        ralph_context=$(get_ralph_context)
        if [[ -n "$ralph_context" ]]; then
            context_block+="<ralph_context>
$ralph_context
</ralph_context>

"
        fi
    fi

    if [[ "$include_ralph_memory" == "true" ]] && is_ralph_project; then
        local ralph_memory
        ralph_memory=$(get_ralph_memory "prompt patterns")
        if [[ -n "$ralph_memory" ]] && [[ "$ralph_memory" != "{}" ]]; then
            local patterns
            patterns=$(echo "$ralph_memory" | jq -r '.[] | .pattern' 2>/dev/null || echo "")
            if [[ -n "$patterns" ]]; then
                context_block+="<ralph_memory_patterns>
$patterns
</ralph_memory_patterns>

"
            fi
        fi
    fi

    echo "$context_block"
}

# ============================================
# Section: Procedural Memory (from ralph-memory-integration.sh v1.0.0)
# ============================================

# Check if procedural memory exists
procedural_memory_exists() {
    [[ -f "$PROCEDURAL_MEMORY" ]]
}

# Get relevant patterns for a prompt type
get_patterns_for_prompt_type() {
    local prompt="$1"
    local prompt_type="${2:-general}"
    local limit="${3:-5}"

    if ! procedural_memory_exists; then
        echo ""
        return 0
    fi

    local patterns
    patterns=$(jq -r --arg type "$prompt_type" --argjson limit "$limit" '
        map(select(.category == $type or .category == "general"))
        | sort_by(.confidence // 0) | reverse
        | .[0:.limit]
        | .pattern
        | join("\n")
    ' "$PROCEDURAL_MEMORY" 2>/dev/null || echo "")

    echo "$patterns"
}

# Detect prompt type from text
detect_prompt_type() {
    local prompt_lower
    prompt_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    if echo "$prompt_lower" | grep -qE "(implement|create|build|add|write)"; then
        echo "implementation"
    elif echo "$prompt_lower" | grep -qE "(fix|debug|error|issue|fail)"; then
        echo "debugging"
    elif echo "$prompt_lower" | grep -qE "(test|spec|validate|check)"; then
        echo "testing"
    elif echo "$prompt_lower" | grep -qE "(refactor|improve|optimize|clean)"; then
        echo "refactoring"
    else
        echo "general"
    fi
}

# Apply procedural patterns to a prompt
apply_procedural_patterns() {
    local original_prompt="$1"
    local prompt_type="${2:-}"

    if [[ -z "$prompt_type" ]]; then
        prompt_type=$(detect_prompt_type "$original_prompt")
    fi

    local patterns
    patterns=$(get_patterns_for_prompt_type "$original_prompt" "$prompt_type" 5)

    if [[ -n "$patterns" ]]; then
        echo "$original_prompt"$'\n\n<procedural_patterns_from_ralph>\n'"$patterns"$'\n</procedural_patterns_from_ralph>'
    else
        echo "$original_prompt"
    fi
}

# Learn pattern from successful prompt
learn_pattern() {
    local pattern="$1"
    local category="${2:-general}"
    local confidence="${3:-80}"

    if ! procedural_memory_exists; then
        mkdir -p "$(dirname "$PROCEDURAL_MEMORY")"
        echo "[]" > "$PROCEDURAL_MEMORY"
    fi

    local new_pattern
    new_pattern=$(jq -n \
        --arg pattern "$pattern" \
        --arg category "$category" \
        --argjson confidence "$confidence" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          pattern: $pattern,
          category: $category,
          confidence: $confidence,
          timestamp: $timestamp,
          source: "promptify-integration"
        }')

    local updated_memory
    updated_memory=$(jq ". += [$new_pattern]" "$PROCEDURAL_MEMORY")
    echo "$updated_memory" > "$PROCEDURAL_MEMORY"
}

# Auto-learn from successful executions
auto_learn_from_success() {
    local optimized_prompt="$1"
    local execution_result="${2:-success}"

    if [[ "$execution_result" != "success" ]]; then
        return 0
    fi

    learn_pattern "$optimized_prompt" "general" 70
}

# Get memory statistics
get_memory_stats() {
    if ! procedural_memory_exists; then
        echo '{"total_patterns": 0, "categories": {}}'
        return 0
    fi

    jq '{
        total_patterns: length,
        categories: map(group_by(.category) | {category: .[0].category, count: length})
    }' "$PROCEDURAL_MEMORY"
}

# ============================================
# Section: Integration Coordinator (from ralph-integration.sh v1.0.0)
# ============================================

# Get configuration value from promptify config
get_integration_config() {
    local key="$1"
    local default="${2:-true}"

    if [[ -f "$PROMPTIFY_CONFIG" ]]; then
        jq -r "${key} // \"${default}\"" "$PROMPTIFY_CONFIG" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Enhance prompt with Ralph context and memory
enhance_prompt_with_ralph() {
    local original_prompt="$1"
    local enhanced_prompt="$original_prompt"

    local inject_context
    inject_context=$(get_integration_config '.integration.inject_ralph_context' 'true')
    local use_memory
    use_memory=$(get_integration_config '.integration.use_ralph_memory' 'true')

    if [[ "$inject_context" == "true" ]]; then
        local ralph_context
        ralph_context=$(get_ralph_context)
        if [[ -n "$ralph_context" ]]; then
            enhanced_prompt="$original_prompt"$'\n\n<ralph_active_context>\n'"$ralph_context"$'\n</ralph_active_context>'
        fi
    fi

    if [[ "$use_memory" == "true" ]]; then
        local prompt_type
        prompt_type=$(detect_prompt_type "$original_prompt")
        local enhanced_with_memory
        enhanced_with_memory=$(apply_procedural_patterns "$enhanced_prompt" "$prompt_type")
        if [[ "$enhanced_with_memory" != "$enhanced_prompt" ]]; then
            enhanced_prompt="$enhanced_with_memory"
        fi
    fi

    echo "$enhanced_prompt"
}

# Validate enhanced prompt through quality gates
validate_enhanced_prompt() {
    local prompt="$1"
    local clarity_score="${2:-50}"
    local use_gates
    use_gates=$(get_integration_config '.integration.validate_with_quality_gates' 'true')

    if [[ "$use_gates" != "true" ]]; then
        jq -n '{valid: true, score: '"$clarity_score"', reason: "Quality gates disabled"}'
        return 0
    fi

    local prompt_type
    prompt_type=$(detect_prompt_type "$prompt")

    # Source quality gates if available; otherwise report skipped
    if type validate_with_gates &>/dev/null; then
        validate_with_gates "$prompt" "$prompt_type" "$clarity_score"
    else
        jq -n '{valid: true, score: '"$clarity_score"', reason: "Quality gates not loaded"}'
    fi
}

# Full enhancement + validation pipeline
enhance_and_validate() {
    local original_prompt="$1"
    local clarity_score="${2:-50}"

    local enhanced_prompt
    enhanced_prompt=$(enhance_prompt_with_ralph "$original_prompt")

    local validation_result
    validation_result=$(validate_enhanced_prompt "$enhanced_prompt" "$clarity_score")

    jq -n \
        --arg original "$original_prompt" \
        --arg enhanced "$enhanced_prompt" \
        --argjson validation "$validation_result" \
        '{
            original_prompt: $original,
            enhanced_prompt: $enhanced,
            validation: $validation
        }'
}

# ============================================
# Section: Subagent Initialization (original v2.88.0 logic)
# ============================================

# Read stdin for subagent info
# SEC-111: Limit stdin to 100KB to prevent memory exhaustion
stdin_data=$(head -c 100000)

# Extract info
# v2.89.2: Official field names first (agent_id, agent_type), then fallbacks
subagent_id=$(echo "$stdin_data" | jq -r '.agent_id // .subagentId // .subagent_id // "unknown"')
subagent_type=$(echo "$stdin_data" | jq -r '.agent_type // .subagentType // .subagent_type // "unknown"')
parent_id=$(echo "$stdin_data" | jq -r '.parent_id // .parentId // "unknown"')
session_id=$(echo "$stdin_data" | jq -r '.sessionId // .session_id // "default"')
task_id=$(echo "$stdin_data" | jq -r '.taskId // .task_id // ""')

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SubagentStart: ${subagent_id} (${subagent_type}) parent=${parent_id} session=${session_id}" >> "$LOG_DIR/agent-teams.log"

# ============================================
# v2.88.0: Register subagent state (Finding #4)
# ============================================
SUBAGENT_STATE="$STATE_DIR/${session_id}/subagents/${subagent_id}.json"
mkdir -p "$(dirname "$SUBAGENT_STATE")"

jq -n \
    --arg id "$subagent_id" \
    --arg type "$subagent_type" \
    --arg parent "$parent_id" \
    --arg session "$session_id" \
    --arg task "$task_id" \
    --arg time "$(date -Iseconds)" \
    '{
        id: $id,
        type: $type,
        parent: $parent,
        session: $session,
        task: $task,
        status: "active",
        started_at: $time,
        last_heartbeat: $time
    }' > "$SUBAGENT_STATE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Subagent state registered: $SUBAGENT_STATE" >> "$LOG_DIR/agent-teams.log"

# ============================================
# Build context based on subagent type
# ============================================
CONTEXT=""

# Common Ralph context for all subagents
CONTEXT+="# Ralph Context for ${subagent_type}\n\n"

# Add project context if available
if [[ -f "$REPO_ROOT/CLAUDE.md" ]]; then
    # Extract key sections (first 50 lines for context)
    CONTEXT+="## Project Guidelines\n"
    CONTEXT+="$(head -50 "$REPO_ROOT/CLAUDE.md" | grep -v "^#" | grep -v "^$" | head -20)\n\n"
fi

# Add quality standards
CONTEXT+="## Quality Standards\n"
CONTEXT+="- CORRECTNESS: Syntax valid, logic sound\n"
CONTEXT+="- QUALITY: No console.log, proper types\n"
CONTEXT+="- SECURITY: No hardcoded secrets, input validation\n"
CONTEXT+="- CONSISTENCY: Follow project style\n\n"

# Add type-specific context
case "$subagent_type" in
    ralph-coder)
        CONTEXT+="## Coder Guidelines\n"
        CONTEXT+="- Run quality gates before marking work complete\n"
        CONTEXT+="- Use /gates command to verify\n"
        CONTEXT+="- Follow YAGNI principles\n\n"
        ;;
    ralph-reviewer)
        CONTEXT+="## Reviewer Guidelines\n"
        CONTEXT+="- Check for OWASP Top 10 vulnerabilities\n"
        CONTEXT+="- Verify proper error handling\n"
        CONTEXT+="- Ensure code follows project patterns\n\n"
        ;;
    ralph-tester)
        CONTEXT+="## Tester Guidelines\n"
        CONTEXT+="- Target 80% coverage for new code\n"
        CONTEXT+="- Use Arrange-Act-Assert pattern\n"
        CONTEXT+="- Name tests: test_<feature>_<scenario>_<expected>\n\n"
        ;;
    ralph-researcher)
        CONTEXT+="## Researcher Guidelines\n"
        CONTEXT+="- Find existing patterns to reuse\n"
        CONTEXT+="- Identify required dependencies\n"
        CONTEXT+="- Document findings clearly\n\n"
        ;;
esac

# Add recent memory context if available (semantic memory)
if [[ -f "$MEMORY_DIR/semantic.json" ]]; then
    recent_entries=$(jq -r '.observations[:3][] | "- " + .title' "$MEMORY_DIR/semantic.json" 2>/dev/null || echo "")
    if [[ -n "$recent_entries" ]]; then
        CONTEXT+="## Recent Learnings\n"
        CONTEXT+="$recent_entries\n\n"
    fi
fi

# ============================================
# v2.95.0: Inject active Ralph context
# ============================================
if is_ralph_project 2>/dev/null; then
    ralph_active_ctx=$(get_ralph_context 2>/dev/null || echo "")
    if [[ -n "$ralph_active_ctx" ]]; then
        CONTEXT+="## Active Ralph Context\n"
        CONTEXT+="$ralph_active_ctx\n\n"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Context injection: Ralph project detected for ${subagent_id}" >> "$LOG_DIR/agent-teams.log"
fi

# ============================================
# v2.95.0: Apply procedural memory patterns
# ============================================
if procedural_memory_exists; then
    # Map subagent type to a prompt-type category for pattern lookup
    case "$subagent_type" in
        ralph-coder)      _mem_type="implementation" ;;
        ralph-reviewer)   _mem_type="refactoring" ;;
        ralph-tester)     _mem_type="testing" ;;
        ralph-researcher) _mem_type="general" ;;
        *)                _mem_type="general" ;;
    esac

    proc_patterns=$(get_patterns_for_prompt_type "" "$_mem_type" 3 2>/dev/null || echo "")
    if [[ -n "$proc_patterns" ]]; then
        CONTEXT+="## Procedural Patterns (${_mem_type})\n"
        CONTEXT+="$proc_patterns\n\n"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Memory integration: ${_mem_type} patterns loaded for ${subagent_id}" >> "$LOG_DIR/agent-teams.log"
fi

# ============================================
# v2.95.0: Integration config-driven context block
# ============================================
inject_cfg=$(get_integration_config '.integration.inject_ralph_context' 'true' 2>/dev/null || echo "true")
memory_cfg=$(get_integration_config '.integration.use_ralph_memory' 'true' 2>/dev/null || echo "true")

if [[ "$inject_cfg" == "true" ]] || [[ "$memory_cfg" == "true" ]]; then
    extra_block=$(build_context_block "$inject_cfg" "$memory_cfg" 2>/dev/null || echo "")
    if [[ -n "$extra_block" ]]; then
        CONTEXT+="## Integration Context Block\n"
        CONTEXT+="$extra_block\n"
    fi
fi

# Output context
# v2.87.0 FIX: SubagentStart uses {"continue": true} format
# Context is passed via hookSpecificOutput.additionalContext
CONTEXT_ESCAPED=$(echo -e "$CONTEXT" | jq -Rs '.')
cat <<EOF
{"continue": true, "hookSpecificOutput": {"hookEventName": "SubagentStart", "additionalContext": $CONTEXT_ESCAPED}}
EOF

exit 0

#!/usr/bin/env bash
# context-windows.sh — Model-aware context window configuration (v3.1.0)
#
# Maps model names to their actual context windows for accurate compaction.
# Used by context-warning.sh and other hooks that need context awareness.
#
# GLM-5.1: 256K official, 220K usable (system prompt + overhead + response buffer)
# Claude Opus: 1M official, ~950K usable
# Claude Sonnet/Haiku: 200K official, ~180K usable

# Model → usable context window (tokens)
# GLM-5.1: 256K usable oficialmente. Safety margin via thresholds, no reducción artificial.
declare -A MODEL_CONTEXT_WINDOWS=(
    ["glm-5.2"]=200000
    ["glm-5.1"]=256000
    ["glm-5-turbo"]=128000
    ["glm-5"]=128000
    ["glm-4.7"]=128000
    ["glm-4.5-air"]=64000
    ["glm-4"]=128000
    ["minimax-m2.7"]=200000
    ["claude-opus-5"]=950000
    ["claude-fable-5"]=950000
    ["claude-opus-4-8"]=950000
    ["claude-opus-4-7"]=950000
    ["claude-opus-4-6"]=950000
    ["claude-sonnet-5"]=180000
    ["claude-sonnet-4-6"]=180000
    ["claude-haiku-4-5"]=180000
    # Native Claude Code session whose model id was not exposed. 200K is the
    # smallest window any current Claude model has, so it never over-promises.
    ["claude-unknown"]=180000
)

# Normalize a raw model id into a table key.
# Strips vendor suffixes in brackets (e.g. "claude-opus-5[1m]" -> "claude-opus-5"),
# which otherwise break associative-array subscripts, and lowercases the result.
normalize_model_id() {
    printf '%s' "$1" | sed -E 's/\[[^]]*\]//g; s/[[:space:]]+//g' | tr '[:upper:]' '[:lower:]'
}

# Detect the model actually serving THIS session.
#
# v3.2.0 — Z_AI_MODEL_DEEP / MINIMAX_MODEL_* are static provider configuration
# exported by the user's shell profile. They are always set, in every session,
# and say nothing about which model is answering. Reading them as a bare
# fallback made every native Claude session report itself as GLM. An alternative
# provider is only believed when ANTHROPIC_BASE_URL proves the session routes there.
get_detected_model() {
    local raw=""

    # 1. Hook stdin JSON — authoritative when Claude Code provides it
    if [[ -n "${INPUT:-}" ]] && command -v jq >/dev/null 2>&1; then
        raw=$(printf '%s' "$INPUT" | jq -r '.model.id // empty' 2>/dev/null)
    fi

    # 1b. Transcript — UserPromptSubmit's stdin carries transcript_path but no
    # model field (verified against Claude Code 2.1.241), and every assistant
    # entry records the model that produced it. Last one wins.
    if [[ -z "$raw" ]] && [[ -n "${INPUT:-}" ]] && command -v jq >/dev/null 2>&1; then
        local tpath
        tpath=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
        if [[ -n "$tpath" && -r "$tpath" ]]; then
            raw=$(tail -n 40 "$tpath" 2>/dev/null \
                | jq -rs 'map(.message.model // empty) | map(select(. != "")) | last // empty' 2>/dev/null)
        fi
    fi

    # 2. Explicit per-session override (set by Zai/MiniMax wrappers)
    [[ -z "$raw" ]] && raw="${ANTHROPIC_MODEL:-}"

    # 3. Alternative providers — ONLY with routing evidence, never from bare config
    if [[ -z "$raw" ]]; then
        case "${ANTHROPIC_BASE_URL:-}" in
            *z.ai*)     raw="${Z_AI_MODEL_DEEP:-}" ;;
            *minimax*)  raw="${MINIMAX_MODEL_STANDARD:-}" ;;
        esac
    fi

    # 4. Native Claude Code with no model in stdin: identify the family, not a guess
    if [[ -z "$raw" ]] && [[ "${AI_AGENT:-}" == claude-code* ]]; then
        raw="claude-unknown"
    fi

    [[ -z "$raw" ]] && { echo "unknown"; return; }
    normalize_model_id "$raw"
}

# Get usable context window for current model (tokens)
get_context_window() {
    local model
    model=$(get_detected_model)

    # Exact match
    if [[ -n "${MODEL_CONTEXT_WINDOWS[$model]:-}" ]]; then
        echo "${MODEL_CONTEXT_WINDOWS[$model]}"
        return
    fi

    # Prefix match (e.g., glm-5.1-0123), longest key first so the most specific
    # entry wins. Bash iterates associative keys in unspecified order, so an
    # unsorted loop could match "glm-5" before "glm-5.2" and pick the wrong window.
    local known
    while IFS= read -r known; do
        if [[ "$model" == "${known}"* ]]; then
            echo "${MODEL_CONTEXT_WINDOWS[$known]}"
            return
        fi
    done < <(printf '%s\n' "${!MODEL_CONTEXT_WINDOWS[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

    # Unknown model — conservative default (128K)
    echo "128000"
}

# Get compaction thresholds as percentage of usable context
# Returns space-separated: INFO_PCT WARNING_PCT CRITICAL_PCT
#
# These are applied against whatever base Claude Code reports.
# For GLM models with broken stdin JSON, the transcript-based
# estimator converts to absolute tokens first.
get_compaction_thresholds() {
    local window
    window=$(get_context_window)

    if [[ "$window" -le 64000 ]]; then
        echo "35 50 60"        # Very small models
    elif [[ "$window" -le 128000 ]]; then
        echo "45 60 70"        # 128K models
    elif [[ "$window" -le 256000 ]]; then
        echo "60 75 85"        # 256K models (GLM-5.1)
    elif [[ "$window" -le 500000 ]]; then
        echo "65 78 85"        # Large models
    else
        echo "75 85 90"        # 1M+ models (Opus)
    fi
}

# Estimate tokens from a file path (rough BPE: bytes / 4)
estimate_tokens_from_file() {
    local filepath="$1"
    if [[ -f "$filepath" && -r "$filepath" ]]; then
        local bytes
        bytes=$(wc -c < "$filepath" 2>/dev/null || echo "0")
        echo $((bytes / 4))
    else
        echo "0"
    fi
}

# Calculate context usage percentage from estimated tokens
# Args: estimated_tokens
# Returns: percentage (0-100)
calculate_usage_pct() {
    local tokens="$1"
    local window
    window=$(get_context_window)
    if [[ "$window" -eq 0 ]]; then
        echo "50"
        return
    fi
    local pct=$((tokens * 100 / window))
    # Clamp to 0-100
    [[ $pct -gt 100 ]] && pct=100
    [[ $pct -lt 0 ]] && pct=0
    echo "$pct"
}

# Check if current model is a GLM variant (needs transcript-based estimation)
is_glm_model() {
    local model
    model=$(get_detected_model)
    [[ "$model" == glm-* ]]
}

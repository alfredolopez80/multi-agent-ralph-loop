#!/bin/bash
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
    ["glm-5.1"]=256000
    ["glm-5"]=128000
    ["glm-4.7"]=128000
    ["glm-4.5-air"]=64000
    ["glm-4"]=128000
    ["claude-opus-4-8"]=950000
    ["claude-opus-4-7"]=950000
    ["claude-opus-4-6"]=950000
    ["claude-sonnet-4-6"]=180000
    ["claude-haiku-4-5"]=180000
)

# Detect current model from environment
get_detected_model() {
    echo "${ANTHROPIC_MODEL:-${Z_AI_MODEL_DEEP:-unknown}}"
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

    # Prefix match (e.g., glm-5.1-0123)
    for known in "${!MODEL_CONTEXT_WINDOWS[@]}"; do
        if [[ "$model" == "${known}"* ]]; then
            echo "${MODEL_CONTEXT_WINDOWS[$known]}"
            return
        fi
    done

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

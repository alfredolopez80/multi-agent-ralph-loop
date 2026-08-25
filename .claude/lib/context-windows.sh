#!/usr/bin/env bash
# context-windows.sh — Model-aware context window configuration (v3.3.0)
#
# Maps model names to their actual context windows for accurate compaction.
# Used by context-warning.sh and other hooks that need context awareness.
#
# v3.3.0 (T7, issue #53 follow-up):
#   - "[1m]" is parsed EXPLICITLY: any model carrying it resolves to a 1M window,
#     independent of the table (normalize_model_id used to strip it silently).
#   - glm-5.3 (1M native, docs.z.ai) and minimax-m3 (512K guaranteed floor,
#     1M via [1m], minimax.io) added to the table; old entries kept.
#   - get_context_window accepts an optional raw model id (unit-testable; the
#     no-arg detection path is unchanged for existing callers).
#   - estimate_tokens_from_file / calculate_usage_pct removed together with
#     context-warning.sh "Method 1.5" (transcript-size estimation retired).
#
# GLM-5.1: 256K official, 220K usable (system prompt + overhead + response buffer)
# Claude Opus: 1M official, ~950K usable
# Claude Sonnet/Haiku: 200K official, ~180K usable

# Model → usable context window (tokens)
# GLM-5.1: 256K usable officially. Safety margin via thresholds, no artificial reduction.
#
# A plain "key value" table, NOT `declare -A` (#42/#44). This file is sourced by
# context-warning.sh, which runs on UserPromptSubmit — every message. Associative
# arrays are bash 4, macOS ships bash 3.2, and there `declare -A` does not abort: it
# warns to stderr and then collapses every key onto index 0, because an unset name in
# an array subscript evaluates arithmetically to 0. Every lookup would return whichever
# entry landed last, so a Claude session could be told it had a 64K window and get
# compaction warnings at entirely the wrong point — silently, on every prompt.
#
# This is #43's defect, which was treated then by changing the shebang from
# `#!/bin/bash` to `#!/usr/bin/env bash`. That only helps when PATH already has a
# bash 4; on stock macOS it resolves straight back to 3.2. A lookup table does not
# need associative arrays, so the requirement is removed rather than guarded.
#
# Window sources (checked 2026-08-25):
#   glm-5.3    — 1M-token context window natively (docs.z.ai/guides/llm/glm-5.3).
#                The "[1m]" marker is consistent with, not additional to, this.
#   minimax-m3 — up to 1M with a GUARANTEED minimum of 512K
#                (minimax.io/models/text/m3). The base entry is the guaranteed
#                floor; "[1m]" selects the full 1M configuration.
_model_context_table() {
    cat <<'TABLE'
glm-5.3 1000000
glm-5.2 200000
glm-5.1 256000
glm-5-turbo 128000
glm-5 128000
glm-4.7 128000
glm-4.5-air 64000
glm-4 128000
minimax-m3 512000
minimax-m2.7 200000
claude-opus-5 950000
claude-fable-5 950000
claude-opus-4-8 950000
claude-opus-4-7 950000
claude-opus-4-6 950000
claude-sonnet-5 180000
claude-sonnet-4-6 180000
claude-haiku-4-5 180000
claude-unknown 180000
TABLE
}

# Normalize a raw model id into a table key.
# Strips vendor suffixes in brackets (e.g. "claude-opus-5[1m]" -> "claude-opus-5"),
# which otherwise break associative-array subscripts, and lowercases the result.
normalize_model_id() {
    printf '%s' "$1" | sed -E 's/\[[^]]*\]//g; s/[[:space:]]+//g' | tr '[:upper:]' '[:lower:]'
}

# True when the RAW model id carries the "[1m]" 1M-context marker.
# normalize_model_id strips bracket suffixes for table lookup, so the marker
# must be read on the raw id BEFORE that strip — it changes the window outright
# rather than selecting a table row (T7: glm-5.3[1m] used to normalize down to
# a bare id and could never reach 1M through the table alone).
has_1m_context() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | grep -q '\[1m\]'
}

# Detect the model actually serving THIS session — RAW id, un-normalized, so
# callers can still see markers like "[1m]".
#
# v3.2.0 — Z_AI_MODEL_DEEP / MINIMAX_MODEL_* are static provider configuration
# exported by the user's shell profile. They are always set, in every session,
# and say nothing about which model is answering. Reading them as a bare
# fallback made every native Claude session report itself as GLM. An alternative
# provider is only believed when ANTHROPIC_BASE_URL proves the session routes there.
get_raw_model() {
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

    echo "${raw:-unknown}"
}

# Table key for the detected model (lowercased, bracket suffixes stripped).
# Behavior is identical to the pre-v3.3.0 single function.
get_detected_model() {
    normalize_model_id "$(get_raw_model)"
}

# Get usable context window (tokens).
# Optional arg: a RAW model id (e.g. "glm-5.3[1m]") so tests can exercise the
# mapping directly. Without an arg, the current session's model is detected —
# the production path, unchanged for existing callers.
get_context_window() {
    local raw
    if [[ -n "${1:-}" ]]; then
        raw="$1"
    else
        raw=$(get_raw_model)
        [[ -z "$raw" ]] && raw="unknown"
    fi

    # "[1m]" marker: 1M window for ANY model carrying it — an explicit rule,
    # deliberately NOT a table row (an unknown model with [1m] must still
    # resolve to 1M; the table alone can never guarantee that).
    if has_1m_context "$raw"; then
        echo "1000000"
        return
    fi

    local model
    model=$(normalize_model_id "$raw")

    # Exact match
    local val
    val=$(_model_context_table | awk -v m="$model" '$1 == m { print $2; exit }')
    if [[ -n "$val" ]]; then
        echo "$val"
        return
    fi

    # Prefix match (e.g., glm-5.1-0123), longest key first so the most specific entry
    # wins — an unsorted pass could match "glm-5" before "glm-5.2" and pick the wrong
    # window. The table's own order is not relied upon.
    local known
    while read -r known val; do
        [[ -n "$known" ]] || continue
        if [[ "$model" == "${known}"* ]]; then
            echo "$val"
            return
        fi
    done < <(_model_context_table | awk 'NF { print length($1), $0 }' | sort -rn | cut -d' ' -f2-)

    # Unknown model — conservative default (128K)
    echo "128000"
}

# Get compaction thresholds as percentage of usable context
# Returns space-separated: INFO_PCT WARNING_PCT CRITICAL_PCT
#
# These are applied against whatever base Claude Code reports in the hook's
# stdin JSON (context-warning.sh Method 1). The transcript-size estimator that
# used to convert them to absolute tokens was retired in v3.3.0 — see
# context-warning.sh "Method 1.5".
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

# Check if current model is a GLM variant
is_glm_model() {
    local model
    model=$(get_detected_model)
    [[ "$model" == glm-* ]]
}

#!/usr/bin/env bash
# ctx-query.sh — index-once-query-many for ~/.ralph/procedural/rules.json
# ==============================================================================
# Purpose (A2, hooks-memory-optimization plan 2026-06-17):
#   rules.json is 1.09MB / 2028 rules. Hooks that need top-N rules used to
#   re-parse the whole JSON with N sequential jq calls on every invocation.
#   This library builds a queryable INDEX of rules.json ONCE (invalidated only
#   when rules.json mtime/size changes) and answers repeated queries from the
#   index — never re-parsing the full JSON per query.
#
# NOTE: ctx-mode MCP is NOT invocable from bash. This ports the PRINCIPLE
#       (index-once, query-many), not the MCP tool.
#
# Backend selection:
#   1. sqlite3 present  -> SQLite index at ~/.ralph/cache/rules-index.db
#   2. sqlite3 absent   -> TSV index at  ~/.ralph/cache/rules-index.tsv
#                          (built ONCE with a single jq -r; queried with awk/sort)
#
# Scoring (matches .claude/lib/layers.py Layer1):
#   score = confidence * usage_count
#   (applied_count is absent from the current schema; usage_count is the
#    effective usage signal. layers.py uses max(usage_count, applied_count).)
#
# Public functions (source this file, then call):
#   ctx_query_top_rules <n>            -> top N rules by score (all domains)
#   ctx_query_by_domain <domain> <n>   -> top N rules within <domain>
#   ctx_query_rule <rule_id>           -> single rule by id
#
# Output format (TSV, one rule per line; downstream code parses with cut/IFS):
#   rule_id<TAB>domain<TAB>confidence<TAB>usage_count<TAB>score<TAB>behavior<TAB>trigger<TAB>tags
#
# This file is SOURCEABLE and idempotent. It defines functions only; it runs
# nothing at source time except guard-variable setup.
# ==============================================================================

# Guard: allow multiple sources without redefining.
if [[ -n "${_CTX_QUERY_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || true
fi
_CTX_QUERY_SH_LOADED=1

umask 077

# ---------------------------------------------------------------------------
# Configuration (overridable via env for testing)
# ---------------------------------------------------------------------------
: "${CTX_RULES_JSON:=${HOME}/.ralph/procedural/rules.json}"
: "${CTX_CACHE_DIR:=${HOME}/.ralph/cache}"
: "${CTX_DB_PATH:=${CTX_CACHE_DIR}/rules-index.db}"
: "${CTX_TSV_PATH:=${CTX_CACHE_DIR}/rules-index.tsv}"
: "${CTX_STAMP_PATH:=${CTX_CACHE_DIR}/rules-index.stamp}"
: "${CTX_QUERY_LOG:=${HOME}/.ralph/logs/ctx-query.log}"

_ctx_log() {
    mkdir -p "$(dirname "$CTX_QUERY_LOG")" 2>/dev/null || true
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ctx-query: $*" >> "$CTX_QUERY_LOG" 2>/dev/null || true
}

# Cross-platform mtime+size signature of rules.json (used for invalidation).
_ctx_source_signature() {
    local f="$CTX_RULES_JSON"
    [[ -f "$f" ]] || { echo "missing"; return 0; }
    # macOS: stat -f '%m %z'; Linux: stat -c '%Y %s'
    stat -f '%m %z' "$f" 2>/dev/null || stat -c '%Y %s' "$f" 2>/dev/null || echo "nostat"
}

# Detect backend: "sqlite" if sqlite3 present, else "tsv".
_ctx_backend() {
    if command -v sqlite3 >/dev/null 2>&1; then
        echo "sqlite"
    else
        echo "tsv"
    fi
}

# ---------------------------------------------------------------------------
# Index build (idempotent — rebuilds only if rules.json signature changed)
# ---------------------------------------------------------------------------
# Emits the canonical TSV stream from rules.json with a SINGLE jq pass.
# Columns: rule_id, domain, confidence, usage_count, score, behavior, trigger, tags
# Tabs/newlines inside fields are stripped so each rule is exactly one line.
_ctx_emit_tsv() {
    jq -r '
        .rules[]
        | select(.rule_id != null and (.rule_id | length) > 0)
        | [
            (.rule_id // ""),
            (.domain // "null"),
            ((.confidence // 0) | tostring),
            ((.usage_count // 0) | tostring),
            (((.confidence // 0) * (.usage_count // 0)) | tostring),
            ((.behavior // "")  | gsub("[\t\n\r]"; " ")),
            ((.trigger  // "")  | gsub("[\t\n\r]"; " ")),
            ((.tags // []) | join(","))
          ]
        | @tsv
    ' "$CTX_RULES_JSON" 2>/dev/null
}

_ctx_build_index() {
    local backend sig current_sig
    backend="$(_ctx_backend)"
    mkdir -p "$CTX_CACHE_DIR" 2>/dev/null || true

    if [[ ! -f "$CTX_RULES_JSON" ]]; then
        _ctx_log "WARN rules.json not found at $CTX_RULES_JSON"
        return 1
    fi

    current_sig="$(_ctx_source_signature)"

    # Idempotence: skip rebuild if stamp matches current signature AND the
    # index artifact for the active backend exists.
    if [[ -f "$CTX_STAMP_PATH" ]]; then
        sig="$(cat "$CTX_STAMP_PATH" 2>/dev/null || echo "")"
        if [[ "$sig" == "${backend}:${current_sig}" ]]; then
            if [[ "$backend" == "sqlite" && -f "$CTX_DB_PATH" ]]; then
                return 0
            elif [[ "$backend" == "tsv" && -f "$CTX_TSV_PATH" ]]; then
                return 0
            fi
        fi
    fi

    _ctx_log "INFO building index backend=$backend sig=$current_sig"

    if [[ "$backend" == "sqlite" ]]; then
        _ctx_build_sqlite || return 1
    else
        _ctx_build_tsv || return 1
    fi

    # Stamp last (commit point) so a partial build is not considered valid.
    printf '%s' "${backend}:${current_sig}" > "$CTX_STAMP_PATH" 2>/dev/null || true
    _ctx_log "INFO index built backend=$backend"
    return 0
}

_ctx_build_tsv() {
    local tmp
    tmp="$(mktemp "${CTX_CACHE_DIR}/.rules-index.tsv.XXXXXX")" || return 1
    if ! _ctx_emit_tsv > "$tmp"; then
        rm -f "$tmp" 2>/dev/null || true
        return 1
    fi
    # Atomic publish.
    mv -f "$tmp" "$CTX_TSV_PATH" 2>/dev/null || { rm -f "$tmp"; return 1; }
    chmod 600 "$CTX_TSV_PATH" 2>/dev/null || true
    return 0
}

_ctx_build_sqlite() {
    local tmpdb tmptsv
    tmptsv="$(mktemp "${CTX_CACHE_DIR}/.rules-index.tsv.XXXXXX")" || return 1
    if ! _ctx_emit_tsv > "$tmptsv"; then
        rm -f "$tmptsv" 2>/dev/null || true
        return 1
    fi

    tmpdb="$(mktemp "${CTX_CACHE_DIR}/.rules-index.db.XXXXXX")" || { rm -f "$tmptsv"; return 1; }
    rm -f "$tmpdb"  # sqlite3 will create it fresh

    # Build the DB from the TSV. .import handles tabs natively.
    # stdout is redirected to the log too — PRAGMA journal_mode echoes "off".
    if ! sqlite3 "$tmpdb" >>"$CTX_QUERY_LOG" 2>&1 <<SQL
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
CREATE TABLE rules (
    rule_id     TEXT,
    domain      TEXT,
    confidence  REAL,
    usage_count INTEGER,
    score       REAL,
    behavior    TEXT,
    trigger_txt TEXT,
    tags        TEXT
);
.mode tabs
.import '${tmptsv}' rules
CREATE INDEX idx_score  ON rules(score DESC);
CREATE INDEX idx_domain ON rules(domain, score DESC);
CREATE INDEX idx_ruleid ON rules(rule_id);
SQL
    then
        rm -f "$tmptsv" "$tmpdb" 2>/dev/null || true
        return 1
    fi

    rm -f "$tmptsv" 2>/dev/null || true
    mv -f "$tmpdb" "$CTX_DB_PATH" 2>/dev/null || { rm -f "$tmpdb"; return 1; }
    chmod 600 "$CTX_DB_PATH" 2>/dev/null || true
    return 0
}

# ---------------------------------------------------------------------------
# Query helpers (TSV output on stdout). Each ensures the index is current.
# ---------------------------------------------------------------------------

# SQLite emits one row per line, tab-separated, in our canonical column order.
_ctx_sqlite_select() {
    sqlite3 -separator $'\t' "$CTX_DB_PATH" "$1" 2>/dev/null
}

# TSV query: stable sort by score descending using awk+sort, no JSON re-parse.
# Args: <filter_awk_expr> <limit>
_ctx_tsv_select() {
    local filter="$1" limit="$2"
    # Columns in TSV: 1=rule_id 2=domain 3=confidence 4=usage 5=score 6=behavior 7=trigger 8=tags
    awk -F'\t' "$filter" "$CTX_TSV_PATH" \
        | sort -t$'\t' -k5,5 -g -r \
        | head -n "$limit"
}

ctx_query_top_rules() {
    local n="${1:-9}"
    [[ "$n" =~ ^[0-9]+$ ]] || n=9
    _ctx_build_index || return 1
    if [[ "$(_ctx_backend)" == "sqlite" && -f "$CTX_DB_PATH" ]]; then
        _ctx_sqlite_select \
            "SELECT rule_id, domain, confidence, usage_count, score, behavior, trigger_txt, tags \
             FROM rules ORDER BY score DESC, rule_id ASC LIMIT ${n};"
    else
        _ctx_tsv_select '{print}' "$n"
    fi
}

ctx_query_by_domain() {
    local domain="${1:?domain required}" n="${2:-9}"
    [[ "$n" =~ ^[0-9]+$ ]] || n=9
    _ctx_build_index || return 1
    if [[ "$(_ctx_backend)" == "sqlite" && -f "$CTX_DB_PATH" ]]; then
        # Parameterized via printf-quoted literal (domain comes from internal
        # data/keywords, not raw user JSON; still single-quote-escaped).
        local esc="${domain//\'/\'\'}"
        _ctx_sqlite_select \
            "SELECT rule_id, domain, confidence, usage_count, score, behavior, trigger_txt, tags \
             FROM rules WHERE domain = '${esc}' ORDER BY score DESC, rule_id ASC LIMIT ${n};"
    else
        # awk filter on column 2 (domain), exact match.
        _ctx_tsv_select "\$2 == \"${domain}\" {print}" "$n"
    fi
}

ctx_query_rule() {
    local rid="${1:?rule_id required}"
    _ctx_build_index || return 1
    if [[ "$(_ctx_backend)" == "sqlite" && -f "$CTX_DB_PATH" ]]; then
        local esc="${rid//\'/\'\'}"
        _ctx_sqlite_select \
            "SELECT rule_id, domain, confidence, usage_count, score, behavior, trigger_txt, tags \
             FROM rules WHERE rule_id = '${esc}' LIMIT 1;"
    else
        awk -F'\t' -v rid="$rid" '$1 == rid {print; exit}' "$CTX_TSV_PATH" 2>/dev/null
    fi
}

#!/usr/bin/env bash
# vault-fact-extractor.sh — Unified vault fact extraction (v3.0)
# Hook: PostToolUse (Edit|Write|Bash)
# VERSION: 3.0.0
#
# Consolidates: decision-extractor.sh + semantic-realtime-extractor.sh
# Strategy: Thin wrapper that feeds the same stdin input to both original
# extractors. Original extraction logic is 100% preserved — no code was
# merged, modified, or rewritten. Both extractors remain as internal modules.
#
# decision-extractor.sh extracts:
#   - Design patterns (Singleton, Factory, Observer, Strategy, etc.)
#   - Architectural decisions (async/await, caching, rate limiting, etc.)
#   - Configuration changes (package.json, Dockerfile, etc.)
#   - Global decisions for infrastructure files with CRITICAL/MUST/NEVER
#
# semantic-realtime-extractor.sh extracts:
#   - Code structure: functions, classes, imports, types, structs
#   - Supports: Python, JS/TS, Shell, Go, Rust, Java/Kotlin, Ruby
#
# Both write to: ~/Documents/Obsidian/MiVault/projects/{project}/facts/
#
# SECURITY: SEC-111 (stdin length limit), SEC-006 (error trap)

set -euo pipefail
umask 077

# Guaranteed JSON output on any error
trap 'echo "{\"continue\": true}"' ERR EXIT

# SEC-111: Read input once from stdin (100KB max)
INPUT=$(head -c 100000)

# Extractor scripts (remain in hooks/ as internal modules, no longer directly wired)
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
DECISION_EXTRACTOR="$HOOKS_DIR/decision-extractor.sh"
SEMANTIC_EXTRACTOR="$HOOKS_DIR/semantic-realtime-extractor.sh"

# Run both extractors in parallel, piping the same input to each.
# Each extractor handles its own background execution and logging internally
# (their extraction blocks use { ... } >> logfile &).
# Their JSON protocol output is suppressed — this wrapper handles it.
if [[ -x "$DECISION_EXTRACTOR" ]]; then
    echo "$INPUT" | "$DECISION_EXTRACTOR" >/dev/null 2>&1 &
fi

if [[ -x "$SEMANTIC_EXTRACTOR" ]]; then
    echo "$INPUT" | "$SEMANTIC_EXTRACTOR" >/dev/null 2>&1 &
fi

# No wait needed — both extractors already run their logic in background blocks.
# The child processes will continue independently after this wrapper exits.

trap - ERR EXIT
echo '{"continue": true}'

#!/usr/bin/env bash
umask 077
INPUT=$(head -c 100000)

TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p ~/.claude/state
echo "{\"tool\": \"$TOOL\", \"ts\": \"$TIMESTAMP\"}" >> ~/.claude/state/step-log-$(date +%Y%m%d).jsonl

echo '{"continue": true}'

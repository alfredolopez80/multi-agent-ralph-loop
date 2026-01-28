#!/bin/bash
# force-statusline-refresh.sh - Force statusline cache refresh
#
# This script updates the context cache and triggers a statusline refresh
# by touching the statusline script file (modifies timestamp).
#
# Part of Multi-Agent Ralph v2.77.2

CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/context-usage.json"
STATUSLINE_SCRIPT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/scripts/statusline-ralph.sh"

echo "=== Forzar Actualización del Statusline ==="
echo ""

# Show current cache
if [[ -f "$CACHE_FILE" ]]; then
    echo "Caché actual:"
    jq '.' "$CACHE_FILE"
    echo ""
else
    echo "✗ No hay caché"
    echo ""
fi

# Update cache with provided values or use current values
if [[ -n "$1" ]] && [[ -n "$2" ]]; then
    # Manual update: ./force-statusline-refresh.sh <USED_PCT> <FREE_TOKENS>
    used_pct=$1
    free_tokens=$2
    context_size=200000
    used_tokens=$((context_size - free_tokens))
    remaining_pct=$((100 - used_pct))

    cache_json=$(jq -n \
        --argjson timestamp "$(date +%s)" \
        --argjson context_size "$context_size" \
        --argjson used_tokens "$used_tokens" \
        --argjson free_tokens "$free_tokens" \
        --argjson used_percentage "$used_pct" \
        --argjson remaining_percentage "$remaining_pct" \
        '{
            timestamp: $timestamp,
            context_size: $context_size,
            used_tokens: $used_tokens,
            free_tokens: $free_tokens,
            used_percentage: $used_percentage,
            remaining_percentage: $remaining_percentage
        }')

    mkdir -p "$CACHE_DIR"
    echo "$cache_json" > "$CACHE_FILE"
    echo "✓ Caché actualizado manualmente: ${used_pct}% usado"
    echo ""
fi

# Touch the statusline script to trigger a reload
touch "$STATUSLINE_SCRIPT"
echo "✓ Statusline script actualizado (touch)"
echo ""

# Show expected display
if [[ -f "$CACHE_FILE" ]]; then
    used_pct=$(jq -r '.used_percentage' "$CACHE_FILE")
    remaining_pct=$(jq -r '.remaining_percentage' "$CACHE_FILE")
    free_tokens=$(jq -r '.free_tokens' "$CACHE_FILE")
    used_tokens=$(jq -r '.used_tokens' "$CACHE_FILE")

    echo "Display esperado en el statusline:"
    echo "  CtxUse: ${used_tokens}k/200k tokens (${used_pct}%)"
    echo "  Free: ${free_tokens}k (${remaining_pct}%)"
    echo "  Buff: 45.0k tokens (22.5%)"
    echo ""
fi

echo "=== Instrucciones ==="
echo ""
echo "El statusline debería actualizarse automáticamente."
echo "Si no se actualiza inmediatamente:"
echo "  1. Ejecuta cualquier comando (git status, ls, etc.)"
echo "  2. O pulsa Enter en una línea vacía"
echo "  3. El statusline se recargará con los nuevos valores"
echo ""
echo "Para verificar manualmente:"
echo "  cat ~/.ralph/cache/context-usage.json | jq '.'"

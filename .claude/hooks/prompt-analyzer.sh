#!/bin/bash
# prompt-analyzer.sh - Analiza y clasifica prompts del usuario
# Parte del sistema de orquestación multi-agente con Codex-First
# VERSION: 2.57.3
# v2.57.3: Fixed newline escaping in JSON messages (SEC-031 continued)

set -uo pipefail

# SEC-031: Guaranteed JSON output on any exit
output_json() {
    jq -n '{action: "execute_direct", model: "sonnet", context: "fallback"}'
}
trap 'output_json' EXIT

# 1. Leer prompt del usuario via stdin
PROMPT=$(cat)

# 2. Convertir a minúsculas para comparación case-insensitive
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# 3. Clasificar por keywords y complejidad

# MUY SIMPLE - Ejecutar directamente con Haiku 4.5 (ultra rápido y económico)
if echo "$PROMPT_LOWER" | grep -qE '(^fix typo|^read |^search |^ls |^cat |^show |^what is|^find file|^grep |^view |^display |^list )'; then
    trap - EXIT
    jq -n '{action: "execute_direct", model: "haiku", context: "Tarea muy simple - Haiku 4.5"}'
    exit 0
fi

# SIMPLE - Ejecutar directamente con Sonnet 4.5
if echo "$PROMPT_LOWER" | grep -qE '(refactor small|simple test|update comment|rename |format code|move file|minor change|update function)'; then
    trap - EXIT
    jq -n '{action: "execute_direct", model: "sonnet", context: "Tarea simple - Sonnet 4.5"}'
    exit 0
fi

# MEDIA - Ejecutar directamente con Sonnet 4.5
if echo "$PROMPT_LOWER" | grep -qE '(minor docs|small feature|basic implementation|medium refactor|update module)'; then
    trap - EXIT
    jq -n '{action: "execute_direct", model: "sonnet", context: "Tarea media - Sonnet 4.5"}'
    exit 0
fi

# COMPLEJA TÉCNICA - Preguntar al usuario
if echo "$PROMPT_LOWER" | grep -qE '(architecture|review|code review|security|vulnerabilities|unit test|coverage|bugs|codebase|analyze code|refactor|optimize|performance|implement|feature|api|integration)'; then
    trap - EXIT
    jq -n --arg msg "🔧 Tarea COMPLEJA TÉCNICA detectada. ¿Activar modo plan con orquestación de agentes? Agentes sugeridos: Codex (technical) + Opus (coordinator)" \
        '{action: "ask_user", type: "technical_complex", message: $msg, suggested_agents: ["codex", "opus", "sonnet"]}'
    exit 0
fi

# COMPLEJA ESTRATÉGICA - Preguntar al usuario
if echo "$PROMPT_LOWER" | grep -qE '(compare|decide|strategy|evaluate|pros cons|trade-offs|plan|roadmap|design|architect|choose)'; then
    trap - EXIT
    jq -n --arg msg "🎯 Tarea COMPLEJA ESTRATÉGICA detectada. ¿Activar modo plan con orquestación? Agentes sugeridos: Opus (coordinator) + Codex (analysis)" \
        '{action: "ask_user", type: "strategic_complex", message: $msg, suggested_agents: ["opus", "codex"]}'
    exit 0
fi

# ULTRA-COMPLEJA - Preguntar con advertencia de costo
if echo "$PROMPT_LOWER" | grep -qE '(security audit|comprehensive|full analysis|deep dive|critical review|complete overhaul|system-wide)'; then
    trap - EXIT
    jq -n --arg msg "⚠️ TAREA ULTRA-COMPLEJA detectada. ¿Activar modo plan con Opus + UltraThink? ADVERTENCIA: Alto costo (15-20x vs Sonnet). Agentes sugeridos: Codex (audit) + Gemini (context) + Opus+UltraThink (synthesis)" \
        '{action: "ask_user", type: "ultra_complex", message: $msg, suggested_agents: ["opus+ultrathink", "codex", "gemini"]}'
    exit 0
fi

# DEFAULT - Si hay duda, preguntar al usuario
trap - EXIT
jq -n --arg msg "❓ No pude clasificar esta tarea automáticamente. ¿Requiere modo plan/orquestación o ejecución directa?" \
    '{action: "ask_user", type: "unknown", message: $msg, options: ["plan", "direct"]}'

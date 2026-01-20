#!/bin/bash
# prompt-analyzer.sh - Analiza y clasifica prompts del usuario
# Parte del sistema de orquestación multi-agente con Codex-First

# 1. Leer prompt del usuario via stdin
# VERSION: 2.57.0
PROMPT=$(cat)

# 2. Convertir a minúsculas para comparación case-insensitive
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# 3. Clasificar por keywords y complejidad

# MUY SIMPLE - Ejecutar directamente con Haiku 4.5 (ultra rápido y económico)
if echo "$PROMPT_LOWER" | grep -qE '(^fix typo|^read |^search |^ls |^cat |^show |^what is|^find file|^grep |^view |^display |^list )'; then
  cat <<EOF
{
  "action": "execute_direct",
  "model": "haiku",
  "context": "Tarea muy simple - Haiku 4.5"
}
EOF
  exit 0
fi

# SIMPLE - Ejecutar directamente con Sonnet 4.5
if echo "$PROMPT_LOWER" | grep -qE '(refactor small|simple test|update comment|rename |format code|move file|minor change|update function)'; then
  cat <<EOF
{
  "action": "execute_direct",
  "model": "sonnet",
  "context": "Tarea simple - Sonnet 4.5"
}
EOF
  exit 0
fi

# MEDIA - Ejecutar directamente con Sonnet 4.5
if echo "$PROMPT_LOWER" | grep -qE '(minor docs|small feature|basic implementation|medium refactor|update module)'; then
  cat <<EOF
{
  "action": "execute_direct",
  "model": "sonnet",
  "context": "Tarea media - Sonnet 4.5"
}
EOF
  exit 0
fi

# COMPLEJA TÉCNICA - Preguntar al usuario
if echo "$PROMPT_LOWER" | grep -qE '(architecture|review|code review|security|vulnerabilities|unit test|coverage|bugs|codebase|analyze code|refactor|optimize|performance|implement|feature|api|integration)'; then
  cat <<EOF
{
  "action": "ask_user",
  "type": "technical_complex",
  "message": "🔧 Tarea COMPLEJA TÉCNICA detectada\\n\\n¿Activar modo plan con orquestación de agentes?\\n\\nAgentes sugeridos: Codex (technical) + Opus (coordinator)",
  "suggested_agents": ["codex", "opus", "sonnet"]
}
EOF
  exit 0
fi

# COMPLEJA ESTRATÉGICA - Preguntar al usuario
if echo "$PROMPT_LOWER" | grep -qE '(compare|decide|strategy|evaluate|pros cons|trade-offs|plan|roadmap|design|architect|choose)'; then
  cat <<EOF
{
  "action": "ask_user",
  "type": "strategic_complex",
  "message": "🎯 Tarea COMPLEJA ESTRATÉGICA detectada\\n\\n¿Activar modo plan con orquestación?\\n\\nAgentes sugeridos: Opus (coordinator) + Codex (analysis)",
  "suggested_agents": ["opus", "codex"]
}
EOF
  exit 0
fi

# ULTRA-COMPLEJA - Preguntar con advertencia de costo
if echo "$PROMPT_LOWER" | grep -qE '(security audit|comprehensive|full analysis|deep dive|critical review|complete overhaul|system-wide)'; then
  cat <<EOF
{
  "action": "ask_user",
  "type": "ultra_complex",
  "message": "⚠️  TAREA ULTRA-COMPLEJA detectada\\n\\n¿Activar modo plan con Opus + UltraThink?\\n\\n⚠️ ADVERTENCIA: Alto costo (15-20x vs Sonnet)\\n\\nAgentes sugeridos: Codex (audit) + Gemini (context) + Opus+UltraThink (synthesis)",
  "suggested_agents": ["opus+ultrathink", "codex", "gemini"]
}
EOF
  exit 0
fi

# DEFAULT - Si hay duda, preguntar al usuario
cat <<EOF
{
  "action": "ask_user",
  "type": "unknown",
  "message": "❓ No pude clasificar esta tarea automáticamente\\n\\n¿Requiere modo plan/orquestación o ejecución directa?",
  "options": ["plan", "direct"]
}
EOF

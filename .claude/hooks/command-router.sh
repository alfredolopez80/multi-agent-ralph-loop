#!/bin/bash
# command-router.sh - Intelligent Command Router
# VERSION: 1.0.0
# Hook: UserPromptSubmit
# Purpose: Analyze prompt and suggest optimal command
#
# Supported Commands:
#   /bug         - Systematic debugging
#   /edd         - Feature definition with eval specs
#   /orchestrator - Complex task orchestration
#   /loop        - Iterative execution with validation
#   /adversarial - Specification refinement
#   /gates       - Quality gates validation
#   /security    - Security vulnerability audit
#   /parallel    - Comprehensive parallel review
#   /audit       - Quality audit and health check

set -euo pipefail

# Security: Limit input size (SEC-111)
readonly MAX_INPUT_SIZE=100000
readonly CONFIG_FILE="$HOME/.ralph/config/command-router.json"
readonly LOG_DIR="$HOME/.ralph/logs"
readonly LOG_FILE="$LOG_DIR/command-router.log"

# Create directories if needed
mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$CONFIG_FILE")"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Trap for guaranteed JSON output
trap '{ echo "{\"continue\": true}"; exit 0; }' ERR INT TERM

# Read and validate input
INPUT=$(cat)
INPUT_SIZE=$(echo "$INPUT" | wc -c)

if [[ $INPUT_SIZE -gt $MAX_INPUT_SIZE ]]; then
    log_message "WARN" "Input exceeds ${MAX_INPUT_SIZE} bytes, truncating"
    INPUT=$(echo "$INPUT" | head -c "$MAX_INPUT_SIZE")
fi

# Parse user prompt
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null || echo "")

if [[ -z "$USER_PROMPT" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Security: Redact sensitive information (SEC-110)
REDACTED_PROMPT=$(echo "$USER_PROMPT" | sed -E 's/(password|secret|token|api_key|credential)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi')

log_message "INFO" "Processing prompt: ${REDACTED_PROMPT:0:100}..."

# Convert to lowercase for pattern matching
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')
WORD_COUNT=$(echo "$USER_PROMPT" | wc -w | tr -d ' ')

# Intent classification function
classify_intent() {
    local intent="unclear"
    local confidence=0

    # BUG detection - highest priority (English + Spanish)
    if echo "$PROMPT_LOWER" | grep -qE 'bug|error|issue|fail|crash|broken|doesn.t work|exception|stack trace|fix bug|reproduce|fallo|error|excepción|no funciona|rompió|falló'; then
        intent="bug"
        confidence=90

    # SPEC REFINEMENT detection (adversarial) (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'spec|specification|PRD|refine.*requirement|edge cases|gaps|challenge.*spec|validate.*spec|especificación|refinar|validar.*espec|casos.*borde|huecos|desafío.*espec'; then
        if [[ $WORD_COUNT -gt 15 ]]; then
            intent="adversarial"
            confidence=85
        fi

    # SECURITY AUDIT detection (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'security|audit.*vulnerability|CWE|OWASP|auth.*oriz|injection|XSS|SQL.*injection|security.*review|seguridad|auditoría|vulnerabilidad|inyección|revisión.*seguridad'; then
        intent="security"
        confidence=88

    # QUALITY GATES detection (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'quality gates|lint|format|type check|validation|pre-commit|CI/CD|check quality|quality.*gate|calidad|formato|validación|verificar.*calidad'; then
        intent="gates"
        confidence=85

    # COMPREHENSIVE REVIEW detection (parallel) (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'comprehensive.*review|multiple.*aspect|6-aspect|parallel.*review|full.*review|revisión.*completa|revisión.*múltiples.*aspectos|revisión.*paralela'; then
        intent="parallel"
        confidence=85

    # AUDIT detection (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'audit.*quality|quality.*audit|health check|comprehensive.*audit|auditoría.*calidad|revisión.*salud|auditoría.*completa'; then
        intent="audit"
        confidence=82

    # SMALL FEATURE detection (edd) (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'define|specification|capability|requirement|small feature|add feature|new feature|definir|especificación|capacidad|requisito|feature.*pequeña|agregar.*feature|nueva.*feature|nueva.*funcionalidad'; then
        if [[ $WORD_COUNT -lt 30 ]]; then
            intent="edd"
            confidence=85
        fi

    # COMPLEX TASK detection (orchestrator) (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'implement|create|build|migrate|refactor|architecture|design|integration|system|module|component|service|api|implementar|crear|construir|migrar|refactorizar|arquitectura|diseño|integración|sistema|módulo|componente|servicio'; then
        if echo "$PROMPT_LOWER" | grep -qE '\band\b|\bthen\b|\bafter\b|y.*luego|después|entonces'; then
            intent="orchestrator"
            confidence=85
        elif [[ $WORD_COUNT -ge 8 ]]; then
            intent="orchestrator"
            confidence=80
        fi

    # ITERATIVE TASK detection (loop) (English + Spanish)
    elif echo "$PROMPT_LOWER" | grep -qE 'iterate|refine|loop|until|retry|quality gates|validation|test until|keep trying|iterative|iterar|refinar|hasta|hasta.*que|reintentar|iterativo'; then
        intent="loop"
        confidence=85
    fi

    echo "$intent|$confidence"
}

# Generate suggestion message
generate_suggestion() {
    local intent="$1"
    local suggestion=""

    case "$intent" in
        bug)
            suggestion="💡 **Sugerencia**: Detecté una tarea de debugging. Considera usar \`/bug\` para debugging sistemático: analizar → reproducir → localizar → corregir → validar."
            ;;
        edd)
            suggestion="💡 **Sugerencia**: Detecté una tarea de definición de feature. Considera usar \`/edd\` para crear especificaciones estructuradas con eval antes de la implementación."
            ;;
        orchestrator)
            suggestion="💡 **Sugerencia**: Detecté una tarea compleja. Considera usar \`/orchestrator\` para workflow completo: evaluar → clarificar → clasificar → planear → ejecutar → validar."
            ;;
        loop)
            suggestion="💡 **Sugerencia**: Detecté una tarea iterativa. Considera usar \`/loop\` para ejecución repetida hasta que pasen los quality gates."
            ;;
        adversarial)
            suggestion="💡 **Sugerencia**: Detecté una tarea de refinamiento de especificación. Considera usar \`/adversarial\` para desafiar suposiciones, identificar gaps y validar requisitos."
            ;;
        gates)
            suggestion="💡 **Sugerencia**: Detecté una tarea de validación de calidad. Considera usar \`/gates\` para quality gates automatizados: linting, formateo, type checking y tests."
            ;;
        security)
            suggestion="💡 **Sugerencia**: Detecté una tarea de auditoría de seguridad. Considera usar \`/security\` para análisis comprehensivo de vulnerabilidades con validación dual."
            ;;
        parallel)
            suggestion="💡 **Sugerencia**: Detecté una tarea de revisión comprehensiva. Considera usar \`/parallel\` para revisión paralela de 6 aspectos con agentes especializados múltiples."
            ;;
        audit)
            suggestion="💡 **Sugerencia**: Detecté una tarea de auditoría de calidad. Considera usar \`/audit\` para auditoría de calidad y health check comprehensivo."
            ;;
        *)
            return 0
            ;;
    esac

    echo "$suggestion"
}

# Main execution
RESULT=$(classify_intent)
INTENT=$(echo "$RESULT" | cut -d'|' -f1)
CONFIDENCE=$(echo "$RESULT" | cut -d'|' -f2)

log_message "DEBUG" "Intent: $INTENT, Confidence: $CONFIDENCE%"

# Check if router is enabled
ROUTER_ENABLED=$(jq -r '.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
CONFIDENCE_THRESHOLD=$(jq -r '.confidence_threshold // 80' "$CONFIG_FILE" 2>/dev/null || echo "80")

# Only suggest if confidence >= threshold
if [[ $CONFIDENCE -ge $CONFIDENCE_THRESHOLD ]] && [[ "$ROUTER_ENABLED" == "true" ]]; then
    SUGGESTION=$(generate_suggestion "$INTENT")

    if [[ -n "$SUGGESTION" ]]; then
        log_message "INFO" "Suggesting /$INTENT (confidence: ${CONFIDENCE}%)"

        # Output suggestion via additionalContext (non-intrusive)
        # Escape for JSON (SEC-002)
        SUGGESTION_ESCAPED=$(echo "$SUGGESTION" | jq -Rs .)

        # Output combined JSON with both additionalContext and continue
        cat <<EOF
{
    "additionalContext": $SUGGESTION_ESCAPED,
    "continue": true
}
EOF
        exit 0
    fi
fi

# Always continue (no suggestion)
echo '{"continue": true}'

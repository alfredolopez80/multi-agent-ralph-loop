#!/bin/bash
# command-router.sh - Unified Prompt Analysis Hook
# VERSION: 2.0.0
# Hook: UserPromptSubmit
# Purpose: Consolidated hook that handles:
#   1. Command routing - Suggest optimal /command for the task
#   2. Curator suggestion - Suggest /curator when procedural memory is empty
#   3. Prompt analysis - Classify prompt complexity and suggest model routing
#   4. Promptify auto-detect - Detect vague prompts and suggest /promptify
#
# Merges former standalone hooks:
#   - command-router.sh (v1.0.0)
#   - curator-suggestion.sh (v2.69.0)
#   - prompt-analyzer.sh (v2.69.0)
#   - promptify-auto-detect.sh (v1.0.0)
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
#   /curator     - Learn from high-quality repos
#   /promptify   - Optimize vague prompts

set -euo pipefail

# =============================================================================
# SHARED SETUP
# =============================================================================

# Security: Limit input size (SEC-111)
readonly MAX_INPUT_SIZE=100000
readonly CONFIG_FILE="$HOME/.ralph/config/command-router.json"
readonly PROMPTIFY_CONFIG_FILE="$HOME/.ralph/config/promptify.json"
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

# SEC-111: Read input with size limit to prevent memory exhaustion
INPUT=$(head -c "$MAX_INPUT_SIZE")

# Parse user prompt
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null || echo "")

if [[ -z "$USER_PROMPT" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# SEC-111: Input length validation to prevent DoS from large prompts
if [[ ${#USER_PROMPT} -gt $MAX_INPUT_SIZE ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Security: Redact sensitive information (SEC-110)
REDACTED_PROMPT=$(echo "$USER_PROMPT" | sed -E 's/(password|secret|token|api_key|credential)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi')

log_message "INFO" "Processing prompt: ${REDACTED_PROMPT:0:100}..."

# Convert to lowercase for pattern matching (shared across all analyzers)
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')
WORD_COUNT=$(echo "$USER_PROMPT" | wc -w | tr -d ' ')

# Collector for all suggestions from each analyzer
ALL_SUGGESTIONS=()

# =============================================================================
# SECTION 1: COMMAND ROUTING
# Detect task intent and suggest the optimal /command
# =============================================================================

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

generate_command_suggestion() {
    local intent="$1"
    local suggestion=""

    case "$intent" in
        bug)
            suggestion="[Command Router] Detecte una tarea de debugging. Considera usar \`/bug\` para debugging sistematico: analizar -> reproducir -> localizar -> corregir -> validar."
            ;;
        edd)
            suggestion="[Command Router] Detecte una tarea de definicion de feature. Considera usar \`/edd\` para crear especificaciones estructuradas con eval antes de la implementacion."
            ;;
        orchestrator)
            suggestion="[Command Router] Detecte una tarea compleja. Considera usar \`/orchestrator\` para workflow completo: evaluar -> clarificar -> clasificar -> planear -> ejecutar -> validar."
            ;;
        loop)
            suggestion="[Command Router] Detecte una tarea iterativa. Considera usar \`/loop\` para ejecucion repetida hasta que pasen los quality gates."
            ;;
        adversarial)
            suggestion="[Command Router] Detecte una tarea de refinamiento de especificacion. Considera usar \`/adversarial\` para desafiar suposiciones, identificar gaps y validar requisitos."
            ;;
        gates)
            suggestion="[Command Router] Detecte una tarea de validacion de calidad. Considera usar \`/gates\` para quality gates automatizados: linting, formateo, type checking y tests."
            ;;
        security)
            suggestion="[Command Router] Detecte una tarea de auditoria de seguridad. Considera usar \`/security\` para analisis comprehensivo de vulnerabilidades con validacion dual."
            ;;
        parallel)
            suggestion="[Command Router] Detecte una tarea de revision comprehensiva. Considera usar \`/parallel\` para revision paralela de 6 aspectos con agentes especializados multiples."
            ;;
        audit)
            suggestion="[Command Router] Detecte una tarea de auditoria de calidad. Considera usar \`/audit\` para auditoria de calidad y health check comprehensivo."
            ;;
        *)
            return 0
            ;;
    esac

    echo "$suggestion"
}

run_command_router() {
    local result
    result=$(classify_intent)
    local intent
    intent=$(echo "$result" | cut -d'|' -f1)
    local confidence
    confidence=$(echo "$result" | cut -d'|' -f2)

    log_message "DEBUG" "Command Router - Intent: $intent, Confidence: $confidence%"

    # Check if router is enabled
    local router_enabled
    router_enabled=$(jq -r '.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
    local confidence_threshold
    confidence_threshold=$(jq -r '.confidence_threshold // 80' "$CONFIG_FILE" 2>/dev/null || echo "80")

    # Only suggest if confidence >= threshold
    if [[ $confidence -ge $confidence_threshold ]] && [[ "$router_enabled" == "true" ]]; then
        local suggestion
        suggestion=$(generate_command_suggestion "$intent")

        if [[ -n "$suggestion" ]]; then
            log_message "INFO" "Command Router: Suggesting /$intent (confidence: ${confidence}%)"
            ALL_SUGGESTIONS+=("$suggestion")
        fi
    fi
}

# =============================================================================
# SECTION 2: CURATOR SUGGESTION
# Suggest /curator when procedural memory is empty and user mentions learning
# =============================================================================

run_curator_suggestion() {
    # Keywords that suggest the user wants to learn from best practices
    local keywords="best practice|pattern|learn from|reference|example repo|quality code|clean code|architecture pattern|design pattern"

    # Check if prompt contains relevant keywords
    if ! echo "$PROMPT_LOWER" | grep -qE "$keywords"; then
        return 0
    fi

    # Check curator corpus status
    local corpus_dir="${HOME}/.ralph/curator/corpus/approved"
    local corpus_count=0
    if [[ -d "$corpus_dir" ]]; then
        corpus_count=$(find "$corpus_dir" -type f -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    fi

    # Check procedural rules
    local rules_file="${HOME}/.ralph/procedural/rules.json"
    local rules_count=0
    local learned_count=0
    if [[ -f "$rules_file" ]]; then
        rules_count=$(jq -r '.rules | length // 0' "$rules_file" 2>/dev/null || echo "0")
        learned_count=$(jq -r '[.rules[] | select(.source_repo != null)] | length // 0' "$rules_file" 2>/dev/null || echo "0")
    fi

    # If corpus is empty and few learned rules, suggest curator
    if [[ "$corpus_count" -eq 0 ]] && [[ "$learned_count" -lt 3 ]]; then
        ALL_SUGGESTIONS+=("[Curator] Your procedural memory is nearly empty ($rules_count rules, $learned_count learned from repos). Consider running \`/curator full --type backend --lang typescript\` to discover, score, and learn from high-quality repositories.")
        log_message "INFO" "Curator: Suggested /curator full (corpus: $corpus_count, learned: $learned_count)"
        return 0
    fi

    # If corpus exists but few learned rules, suggest learning
    if [[ "$corpus_count" -gt 0 ]] && [[ "$learned_count" -lt 3 ]]; then
        ALL_SUGGESTIONS+=("[Curator] You have $corpus_count approved repos but only $learned_count learned rules. Run \`/curator learn --type backend --lang typescript\` to extract patterns from your approved repositories.")
        log_message "INFO" "Curator: Suggested /curator learn (corpus: $corpus_count, learned: $learned_count)"
        return 0
    fi
}

# =============================================================================
# SECTION 3: PROMPT ANALYSIS
# Classify prompt complexity and suggest model routing
# =============================================================================

run_prompt_analyzer() {
    local classification=""

    # MUY SIMPLE - Haiku 4.5
    if echo "$PROMPT_LOWER" | grep -qE '(^fix typo|^read |^search |^ls |^cat |^show |^what is|^find file|^grep |^view |^display |^list )'; then
        classification="[Prompt Analysis] Tarea muy simple detectada. Modelo sugerido: Haiku 4.5 (ultra rapido y economico)."
    # SIMPLE - Sonnet 4.5
    elif echo "$PROMPT_LOWER" | grep -qE '(refactor small|simple test|update comment|rename |format code|move file|minor change|update function)'; then
        classification="[Prompt Analysis] Tarea simple detectada. Modelo sugerido: Sonnet 4.5."
    # MEDIA - Sonnet 4.5
    elif echo "$PROMPT_LOWER" | grep -qE '(minor docs|small feature|basic implementation|medium refactor|update module)'; then
        classification="[Prompt Analysis] Tarea media detectada. Modelo sugerido: Sonnet 4.5."
    # COMPLEJA TECNICA
    elif echo "$PROMPT_LOWER" | grep -qE '(architecture|review|code review|security|vulnerabilities|unit test|coverage|bugs|codebase|analyze code|refactor|optimize|performance|implement|feature|api|integration)'; then
        classification="[Prompt Analysis] Tarea COMPLEJA TECNICA detectada. Considerar modo plan con orquestacion de agentes. Agentes sugeridos: Codex (technical) + Opus (coordinator)."
    # COMPLEJA ESTRATEGICA
    elif echo "$PROMPT_LOWER" | grep -qE '(compare|decide|strategy|evaluate|pros cons|trade-offs|plan|roadmap|design|architect|choose)'; then
        classification="[Prompt Analysis] Tarea COMPLEJA ESTRATEGICA detectada. Considerar modo plan con orquestacion. Agentes sugeridos: Opus (coordinator) + Codex (analysis)."
    # ULTRA-COMPLEJA
    elif echo "$PROMPT_LOWER" | grep -qE '(security audit|comprehensive|full analysis|deep dive|critical review|complete overhaul|system-wide)'; then
        classification="[Prompt Analysis] TAREA ULTRA-COMPLEJA detectada. Considerar modo plan con Opus + UltraThink. ADVERTENCIA: Alto costo (15-20x vs Sonnet). Agentes sugeridos: Codex (audit) + Gemini (context) + Opus+UltraThink (synthesis)."
    fi

    if [[ -n "$classification" ]]; then
        ALL_SUGGESTIONS+=("$classification")
        log_message "INFO" "Prompt Analyzer: $classification"
    fi
}

# =============================================================================
# SECTION 4: PROMPTIFY AUTO-DETECT
# Detect vague prompts and suggest /promptify optimization
# =============================================================================

calculate_clarity_score() {
    local prompt="$1"
    local score=100
    local prompt_lower
    prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    # Load promptify config
    local promptify_log_level="INFO"
    if [[ -f "$PROMPTIFY_CONFIG_FILE" ]]; then
        promptify_log_level=$(jq -r '.log_level // "INFO"' "$PROMPTIFY_CONFIG_FILE" 2>/dev/null || echo "INFO")
    fi

    # 1. Word count penalty (too short = vague)
    local word_count
    word_count=$(echo "$prompt" | wc -w | tr -d ' ')
    if [[ $word_count -lt 5 ]]; then
        score=$((score - 40))
        [[ "$promptify_log_level" == "DEBUG" ]] && log_message "DEBUG" "Promptify: Word count penalty: -40% (count: $word_count)"
    elif [[ $word_count -lt 10 ]]; then
        score=$((score - 20))
        [[ "$promptify_log_level" == "DEBUG" ]] && log_message "DEBUG" "Promptify: Word count penalty: -20% (count: $word_count)"
    fi

    # 2. Vague word penalty
    local vague_words=("thing" "stuff" "something" "anything" "nothing" "fix it" "make it better" "help me" "whatsit" "thingy" "whatever")
    for word in "${vague_words[@]}"; do
        if echo "$prompt_lower" | grep -qE "$word"; then
            score=$((score - 15))
            [[ "$promptify_log_level" == "DEBUG" ]] && log_message "DEBUG" "Promptify: Vague word penalty: -15% (word: $word)"
        fi
    done

    # 3. Pronoun penalty (ambiguous references)
    if echo "$prompt_lower" | grep -qE "\b(this|that|it|they|them)\s+\b"; then
        score=$((score - 10))
        [[ "$promptify_log_level" == "DEBUG" ]] && log_message "DEBUG" "Promptify: Pronoun penalty: -10% (ambiguous reference)"
    fi

    # 4. Missing structure penalty
    local has_role=false
    local has_task=false
    local has_constraints=false

    if echo "$prompt_lower" | grep -qE "(you are|act as|role|persona|you.re a|you are an?)"; then
        has_role=true
    fi

    if echo "$prompt_lower" | grep -qE "(implement|create|build|write|analyze|design|fix|add|make|develop|code)"; then
        has_task=true
    fi

    if echo "$prompt_lower" | grep -qE "(must|should|constraint|requirement|limit|except|but|however)"; then
        has_constraints=true
    fi

    if [[ "$has_role" == false ]]; then
        score=$((score - 15))
    fi
    if [[ "$has_task" == false ]]; then
        score=$((score - 20))
    fi
    if [[ "$has_constraints" == false ]]; then
        score=$((score - 10))
    fi

    # Ensure score is within 0-100 range
    if [[ $score -lt 0 ]]; then
        score=0
    elif [[ $score -gt 100 ]]; then
        score=100
    fi

    echo "$score"
}

run_promptify_auto_detect() {
    # Load config with defaults
    local enabled=true
    local threshold=50
    if [[ -f "$PROMPTIFY_CONFIG_FILE" ]]; then
        enabled=$(jq -r '.enabled // true' "$PROMPTIFY_CONFIG_FILE" 2>/dev/null || echo "true")
        threshold=$(jq -r '.vagueness_threshold // 50' "$PROMPTIFY_CONFIG_FILE" 2>/dev/null || echo "50")
    fi

    # Exit if disabled
    if [[ "$enabled" != "true" ]]; then
        log_message "DEBUG" "Promptify: Disabled in config"
        return 0
    fi

    # Calculate clarity score
    local clarity_score
    clarity_score=$(calculate_clarity_score "$USER_PROMPT")

    log_message "INFO" "Promptify: Clarity score: $clarity_score% (threshold: ${threshold}%)"

    # If clarity score is below threshold, suggest /promptify
    if [[ $clarity_score -lt $threshold ]]; then
        local prompt_lower
        prompt_lower=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')
        local missing_parts=()

        if ! echo "$prompt_lower" | grep -qE "(you are|act as|role|persona)"; then
            missing_parts+=("Role definition")
        fi
        if ! echo "$prompt_lower" | grep -qE "(implement|create|build|write|analyze|design|fix)"; then
            missing_parts+=("Task specification")
        fi
        if ! echo "$prompt_lower" | grep -qE "(must|should|constraint|requirement|limit)"; then
            missing_parts+=("Constraints")
        fi

        local missing_text=""
        if [[ ${#missing_parts[@]} -gt 0 ]]; then
            missing_text=" Missing: $(IFS=', '; echo "${missing_parts[*]}")."
        fi

        ALL_SUGGESTIONS+=("[Promptify] Prompt clarity score is ${clarity_score}% (below ${threshold}% threshold).${missing_text} Consider using \`/promptify\` to optimize your prompt with role definition, task specification, constraints, and output format. Usage: \`/promptify <your prompt>\` or with modifiers: \`/promptify +ask\`, \`/promptify +deep\`, \`/promptify +web\`.")
        log_message "INFO" "Promptify: Suggested /promptify (clarity: $clarity_score%, missing: ${#missing_parts[@]} elements)"
    else
        log_message "DEBUG" "Promptify: No suggestion needed (clarity: $clarity_score% >= threshold: ${threshold}%)"
    fi
}

# =============================================================================
# MAIN EXECUTION
# Run all analyzers and emit combined suggestions
# =============================================================================

run_command_router
run_curator_suggestion
run_prompt_analyzer
run_promptify_auto_detect

# Emit output
if [[ ${#ALL_SUGGESTIONS[@]} -gt 0 ]]; then
    # Combine all suggestions with separator
    COMBINED=""
    for i in "${!ALL_SUGGESTIONS[@]}"; do
        if [[ $i -gt 0 ]]; then
            COMBINED="${COMBINED}\n---\n"
        fi
        COMBINED="${COMBINED}${ALL_SUGGESTIONS[$i]}"
    done

    # Escape for JSON (SEC-002)
    COMBINED_ESCAPED=$(printf '%s' "$COMBINED" | jq -Rs .)

    cat <<EOF
{
    "additionalContext": $COMBINED_ESCAPED,
    "continue": true
}
EOF
    exit 0
fi

# Always continue (no suggestion)
echo '{"continue": true}'

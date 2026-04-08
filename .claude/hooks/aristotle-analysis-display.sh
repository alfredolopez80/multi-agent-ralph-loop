#!/usr/bin/env bash
umask 077

# Read stdin (limit to prevent abuse)
INPUT=$(head -c 100000)

# Extract prompt from JSON
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

# Default: continue without message
OUTPUT='{"continue": true}'

# Skip if empty prompt
if [[ -z "$PROMPT" ]]; then
    echo "$OUTPUT"
    exit 0
fi

# Complexity estimation function
estimate_complexity() {
    local prompt="$1"
    local complexity=1
    local lower_prompt

    # Convert to lowercase (Bash 4+ native, no subprocess)
    lower_prompt="${prompt,,}"

    # High complexity indicators (4+)
    if [[ "$lower_prompt" =~ refactor ]]; then ((complexity+=4)); fi
    if [[ "$lower_prompt" =~ architecture|architectural ]]; then ((complexity+=3)); fi
    if [[ "$lower_prompt" =~ redesign ]]; then ((complexity+=3)); fi
    if [[ "$lower_prompt" =~ migrate|migration ]]; then ((complexity+=3)); fi
    if [[ "$lower_prompt" =~ implement.*system|create.*system|build.*system ]]; then ((complexity+=3)); fi
    if [[ "$lower_prompt" =~ create.*agent|build.*agent|multi.*agent ]]; then ((complexity+=3)); fi
    if [[ "$lower_prompt" =~ team|parallel|parallelism ]]; then ((complexity+=2)); fi
    if [[ "$lower_prompt" =~ orchestration|orchestrator ]]; then ((complexity+=2)); fi
    if [[ "$lower_prompt" =~ design.*pattern|design.*system ]]; then ((complexity+=2)); fi
    if [[ "$lower_prompt" =~ comprehensive|complete.*solution ]]; then ((complexity+=2)); fi
    if [[ "$lower_prompt" =~ analyze.*and.*implement|investigate.*and.*fix ]]; then ((complexity+=2)); fi

    # Moderate complexity indicators (3) — avoid overlap with high-level patterns above
    if [[ "$lower_prompt" =~ implement ]] && [[ ! "$lower_prompt" =~ implement.*system ]]; then ((complexity+=2)); fi
    if [[ "$lower_prompt" =~ add.*feature|create.*function ]]; then ((complexity+=2)); fi
    if [[ "$lower_prompt" =~ modify.*file|update.*code|change.*function ]]; then ((complexity+=1)); fi
    if [[ "$lower_prompt" =~ fix.*bug|debug|troubleshoot ]]; then ((complexity+=1)); fi
    if [[ "$lower_prompt" =~ test.*coverage|write.*test|create.*test ]]; then ((complexity+=1)); fi

    # Low complexity indicators (reduce)
    if [[ "$lower_prompt" =~ ^(what\ is|show\ me|list\ |read\ |explain\ |describe\ ) ]]; then ((complexity-=1)); fi
    if [[ "$lower_prompt" =~ fix.*typo|small.*change|minor.*edit ]]; then ((complexity-=1)); fi
    if [[ "$lower_prompt" =~ quick|simple|just ]]; then ((complexity-=1)); fi

    # Ensure minimum complexity of 1
    if [[ $complexity -lt 1 ]]; then
        complexity=1
    fi

    # Cap at 10
    if [[ $complexity -gt 10 ]]; then
        complexity=10
    fi

    echo "$complexity"
}

COMPLEXITY=$(estimate_complexity "$PROMPT")

# Generate output based on complexity
if [[ $COMPLEXITY -ge 4 ]]; then
    # Full 5-phase Aristotle reminder
    SYSTEM_MESSAGE="🏛️ Aristotle First Principles (Complejidad: $COMPLEXITY)
Fase 1: Autopsia de Suposiciones — identificar suposiciones heredadas
Fase 2: Verdades Irreductibles — qué survives cuando se remueven suposiciones
Fase 3: Reconstrucción desde Cero — 3 enfoques usando solo verdades
Fase 4: Mapa Suposición vs Verdad — comparar convencional vs primeros principios
Fase 5: El Movimiento Aristotélico — la acción de mayor impacto único
→ Se recomienda EnterPlanMode para este nivel de complejidad"

    # Use jq for safe JSON encoding (handles quotes, newlines, special chars)
    OUTPUT=$(jq -n --arg msg "$SYSTEM_MESSAGE" '{continue: true, systemMessage: $msg}')

elif [[ $COMPLEXITY -eq 3 ]]; then
    # Quick Aristotle reminder
    SYSTEM_MESSAGE="Quick Aristotle Check: Fase 1 (Autopsia de Suposiciones) + Fase 5 (Movimiento Aristotélico)"
    OUTPUT=$(jq -n --arg msg "$SYSTEM_MESSAGE" '{continue: true, systemMessage: $msg}')
fi

# Output JSON (silent for complexity 1-2)
echo "$OUTPUT"

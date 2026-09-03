# Anchored Summary Design - v2.47

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

## Concepto

El **Anchored Summary** es un resumen estructurado que "ancla" información crítica para que persista a través de compactaciones de contexto. A diferencia de un resumen genérico, está diseñado específicamente para:

1. **Preservar decisiones arquitectónicas** - No re-debatir lo ya decidido
2. **Mantener estado de tareas** - Continuidad sin pérdida de progreso
3. **Retener contexto semántico** - Referencias a claude-mem IDs relevantes
4. **Optimizar recuperación** - Estructura que facilita búsqueda selectiva

## Secciones Disponibles

El usuario puede elegir qué secciones incluir según el tipo de trabajo:

### Secciones Core (Siempre Incluidas)

| Sección | Propósito | Tokens Est. |
|---------|-----------|-------------|
| `GOAL` | Objetivo actual de la sesión | ~50 |
| `DECISIONS` | Decisiones tomadas (no re-debatir) | ~100-200 |
| `PROGRESS` | Estado de completitud de tareas | ~100-150 |

### Secciones Opcionales

| Sección | Propósito | Cuándo Incluir | Tokens Est. |
|---------|-----------|----------------|-------------|
| `ARCHITECTURE` | Decisiones de diseño de sistema | Proyectos nuevos, refactors | ~200-400 |
| `ERRORS_FIXED` | Errores resueltos (no repetir) | Debugging sessions | ~100-200 |
| `API_CONTRACTS` | Interfaces definidas | Backend/API work | ~150-300 |
| `TEST_COVERAGE` | Estado de tests y gaps | TDD sessions | ~100-200 |
| `DEPENDENCIES` | Libs/versiones críticas | Dependency updates | ~50-100 |
| `SECURITY` | Decisiones de seguridad | Security audits | ~150-250 |
| `PERFORMANCE` | Optimizaciones aplicadas | Performance work | ~100-200 |
| `CLAUDE_MEM_REFS` | IDs de observaciones relevantes | Sessions largas | ~50-100 |

## Perfiles Predefinidos

### Perfil: `development` (Default)
```yaml
sections:
  - GOAL
  - DECISIONS
  - PROGRESS
  - ARCHITECTURE
  - ERRORS_FIXED
estimated_tokens: ~600-1000
```

### Perfil: `debugging`
```yaml
sections:
  - GOAL
  - DECISIONS
  - PROGRESS
  - ERRORS_FIXED
  - TEST_COVERAGE
  - CLAUDE_MEM_REFS
estimated_tokens: ~500-800
```

### Perfil: `security-audit`
```yaml
sections:
  - GOAL
  - DECISIONS
  - PROGRESS
  - SECURITY
  - DEPENDENCIES
  - API_CONTRACTS
estimated_tokens: ~700-1200
```

### Perfil: `minimal`
```yaml
sections:
  - GOAL
  - DECISIONS
  - PROGRESS
estimated_tokens: ~250-400
```

### Perfil: `comprehensive`
```yaml
sections: ALL
estimated_tokens: ~1500-2500
```

## Formato del Anchored Summary

```markdown
# 🔖 ANCHORED SUMMARY
Session: {session_id}
Profile: {profile_name}
Generated: {timestamp}
Context at generation: {percentage}%

## 🎯 GOAL
{current_objective}

## ⚖️ DECISIONS (DO NOT RE-DEBATE)
1. {decision_1} - Rationale: {why}
2. {decision_2} - Rationale: {why}
...

## ✅ PROGRESS
| Task | Status | Notes |
|------|--------|-------|
| {task} | {done/pending/blocked} | {notes} |

## 🏗️ ARCHITECTURE (if included)
- Pattern: {pattern_used}
- Key files: {file_list}
- Constraints: {constraints}

## 🐛 ERRORS_FIXED (if included)
| Error | Root Cause | Fix Applied |
|-------|------------|-------------|
| {error} | {cause} | {fix} |

## 🔗 CLAUDE_MEM_REFS (if included)
Relevant observations for deep context:
- #{id1}: {title} (~{tokens}t)
- #{id2}: {title} (~{tokens}t)

---
💡 Use `mcp__plugin_claude-mem_mcp-search__get_observations` with IDs above for full details.
```

## Integración con Hooks

### PreCompact Hook Enhancement

```bash
# En pre-compact-handoff.sh
generate_anchored_summary() {
    local profile="${1:-development}"
    local output_file="$2"

    # Leer perfil de configuración
    local config_file="${HOME}/.ralph/config/anchored-profiles.json"
    local sections=$(jq -r ".${profile}.sections[]" "$config_file" 2>/dev/null)

    # Generar cada sección según perfil
    for section in $sections; do
        generate_section "$section" >> "$output_file"
    done
}
```

### SessionStart Hook Enhancement

```bash
# En session-start-ledger.sh
inject_anchored_summary() {
    local summary_file="${HOME}/.ralph/state/anchored-summary.md"

    if [[ -f "$summary_file" ]]; then
        # Verificar que no sea muy antiguo (< 24h)
        local age=$(($(date +%s) - $(stat -f %m "$summary_file")))
        if [[ $age -lt 86400 ]]; then
            cat "$summary_file"
        fi
    fi
}
```

## CLI Commands

```bash
# Generar Anchored Summary con perfil
ralph anchor [profile]           # development (default)
ralph anchor debugging           # debugging profile
ralph anchor security-audit      # security profile
ralph anchor --custom GOAL,PROGRESS,SECURITY  # custom sections

# Listar perfiles disponibles
ralph anchor --list-profiles

# Ver summary actual
ralph anchor --show

# Limpiar summary
ralph anchor --clear
```

## Validación con MiniMax M2.1

El Anchored Summary puede validarse con un modelo económico antes de persistirse:

```bash
# Validación automática (8% costo vs Opus)
ralph anchor --validate

# Flujo de validación:
# 1. Generar summary draft
# 2. Enviar a MiniMax M2.1 con prompt:
#    "Valida que este resumen capture toda la información crítica
#     sin redundancia. Sugiere mejoras si faltan decisiones importantes
#     o hay información innecesaria."
# 3. Aplicar sugerencias automáticamente
# 4. Persistir versión final
```

## Configuración

Archivo: `~/.ralph/config/anchored-profiles.json`

```json
{
  "development": {
    "sections": ["GOAL", "DECISIONS", "PROGRESS", "ARCHITECTURE", "ERRORS_FIXED"],
    "max_tokens": 1000,
    "validate": true
  },
  "debugging": {
    "sections": ["GOAL", "DECISIONS", "PROGRESS", "ERRORS_FIXED", "TEST_COVERAGE", "CLAUDE_MEM_REFS"],
    "max_tokens": 800,
    "validate": true
  },
  "security-audit": {
    "sections": ["GOAL", "DECISIONS", "PROGRESS", "SECURITY", "DEPENDENCIES", "API_CONTRACTS"],
    "max_tokens": 1200,
    "validate": true
  },
  "minimal": {
    "sections": ["GOAL", "DECISIONS", "PROGRESS"],
    "max_tokens": 400,
    "validate": false
  },
  "comprehensive": {
    "sections": "ALL",
    "max_tokens": 2500,
    "validate": true
  }
}
```

## Flujo Completo de Context Management v2.47

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SESSION START                                     │
├─────────────────────────────────────────────────────────────────────┤
│  1. SessionStart hook fires                                          │
│  2. Reset counters (operation-counter, message_count) ← v2.47 fix   │
│  3. Load Anchored Summary if exists                                  │
│  4. Load ledger + handoff                                            │
│  5. Inject claude-mem hints                                          │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    DURING SESSION                                    │
├─────────────────────────────────────────────────────────────────────┤
│  • context-warning.sh monitors usage (75% warning, 85% critical)    │
│  • operation-counter increments on tool calls                        │
│  • message_count increments on prompts                               │
│  • auto-save-context.sh saves every 5 operations                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    PRE-COMPACTION (75%+ triggered)                   │
├─────────────────────────────────────────────────────────────────────┤
│  1. PreCompact hook fires                                            │
│  2. Generate Anchored Summary with selected profile                  │
│  3. Validate with MiniMax M2.1 (optional)                            │
│  4. Save ledger + handoff                                            │
│  5. Context extractor captures rich state                            │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    POST-COMPACTION                                   │
├─────────────────────────────────────────────────────────────────────┤
│  1. SessionStart:compact triggers                                    │
│  2. Counters reset to 0                                              │
│  3. Anchored Summary injected (decisions preserved)                  │
│  4. claude-mem refs available for deep context                       │
│  5. Session continues with minimal context loss                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Métricas de Éxito

| Métrica | v2.46 | v2.47 Target |
|---------|-------|--------------|
| Context accuracy | False 100% | Real % from counters |
| Decision preservation | ~60% | **95%+** |
| Compaction data loss | ~40% | **<10%** |
| Session continuity | Manual | **Automatic** |
| Validation cost | N/A | **8% (MiniMax)** |

## Próximos Pasos

1. ✅ Diseño del Anchored Summary
2. ☐ Implementar generador de secciones
3. ☐ Crear perfiles JSON
4. ☐ Integrar validación MiniMax
5. ☐ Actualizar hooks PreCompact/SessionStart
6. ☐ Documentar CLI commands

---

*Documento generado como parte de v2.47 Context Management Enhancement*

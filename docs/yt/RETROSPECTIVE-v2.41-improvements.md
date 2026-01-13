# 📊 Retrospective: Mejoras Prioritarias para Ralph v2.41

> **Análisis cruzado de 4 videos** sobre Ralph Loop y Claude Code
> **Fecha**: 2026-01-13
> **Objetivo**: Identificar las 5 mejoras más impactantes basadas en patrones comunes

---

## Summary

| Métrica | Valor |
|---------|-------|
| Videos analizados | 4 |
| Duración total | ~70 minutos |
| Ideas identificadas | 28 |
| Patrones comunes | 6 |
| Mejoras prioritarias | 5 |

### Fuentes Analizadas

| Video | Autor | Insight Principal |
|-------|-------|-------------------|
| Claude Cowork | World of AI | Tareas async, "delega y vete" |
| Stop Using Ralph Plugin | Chase AI | Nueva sesión por tarea es CRÍTICO |
| Ralph from 1st Principles | **Creador Original** | Malloc determinístico del context window |
| Claude Code 2.1 Update | World of AI | context: fork, hooks en frontmatter |

---

## Patrones Comunes Identificados

### Patrón 1: Gestión Determinística del Context Window

**Consenso de 3/4 videos**:

```
┌─────────────────────────────────────────────────────────────┐
│   EL PROBLEMA FUNDAMENTAL: CONTEXT ROT                      │
│                                                             │
│   0K ────────── 100K ────────── 150K ────────── 200K       │
│   [====SMART====][===DEGRADANDO===][====DUMB====]          │
│                                                             │
│   SOLUCIÓN: Nueva sesión por tarea                         │
│   Cada iteración empieza en 0K tokens                      │
└─────────────────────────────────────────────────────────────┘
```

**Citas clave**:
- Creador: *"Context windows are arrays. The less you use, the better outcomes you get."*
- Chase AI: *"El plugin NO inicia nuevas sesiones - perdiendo el beneficio principal."*

### Patrón 2: Estado Persistente Entre Iteraciones

**Consenso de 3/4 videos**:

| Archivo | Propósito | Estado en Ralph v2.40 |
|---------|-----------|----------------------|
| `progress.md` | Documenta intentos/errores | ❌ No existe |
| `implementation_plan.md` | Tracking con checkboxes | 🔶 Parcial (ledger) |
| Lookup tables (PIN) | Keywords para search tool | ❌ No existe |

### Patrón 3: Aislamiento de Contexto

**De Claude Code 2.1**:

```yaml
context: fork  # Sub-agentes no contaminan contexto principal
```

**Aplicación**: Skills como `/gates`, `/adversarial`, `/parallel` deberían usar fork.

### Patrón 4: Tareas Asíncronas de Larga Duración

**De Cowork + Claude Code 2.1**:

- "Delega y vete" - iniciar tarea y alejarse
- Sub-agentes async que continúan independientemente
- Notificaciones cuando completa o requiere input

### Patrón 5: Low Control, High Oversight

**Del creador**:
- No micro-gestionar cada paso
- Un objetivo por loop = menos context window
- LLM decide prioridades

---

## Las 5 Mejoras Prioritarias para v2.41

### 🥇 Mejora #1: Session Refresh por Tarea (CRÍTICA)

**Impacto**: 🔴 ALTO | **Riesgo**: 🟡 MEDIO | **Esfuerzo**: 🟡 MEDIO

**Problema actual**:
Ralph v2.40 usa `run_in_background` pero NO fuerza nueva sesión. El contexto se acumula hasta auto-compact (~150K tokens), operando en la "dumb zone" la mayor parte del tiempo.

**Propuesta**:

```bash
# scripts/ralph - Añadir función session_refresh_loop
session_refresh_loop() {
    local MAX_ITERATIONS=${1:-25}
    local PROMPT_FILE=${2:-"prompt.md"}

    for i in $(seq 1 $MAX_ITERATIONS); do
        echo "=== Iteración $i de $MAX_ITERATIONS ==="

        # NUEVA SESIÓN por iteración
        claude --new-session \
            --prompt "$(cat $PROMPT_FILE)" \
            --dangerously-skip-permissions

        # Verificar completion
        if task_completed; then
            echo "✅ Tarea completada en iteración $i"
            break
        fi
    done
}
```

**Archivos a modificar**:
- `scripts/ralph` - Añadir `session_refresh_loop()`
- `.claude/skills/loop/SKILL.md` - Usar session refresh
- `.claude/agents/orchestrator.md` - Opción `per_task_session: true`

**Justificación**:
> "El poder no es que se repita 10 veces. El poder es que se repite con el CONTEXTO de iteraciones anteriores y con una NUEVA SESIÓN." - Chase AI

---

### 🥈 Mejora #2: progress.md Automático

**Impacto**: 🔴 ALTO | **Riesgo**: 🟢 BAJO | **Esfuerzo**: 🟢 BAJO

**Problema actual**:
No hay memoria persistente de intentos fallidos entre sesiones. Cada iteración puede repetir los mismos errores.

**Propuesta**:

```markdown
# ~/.ralph/progress.md (auto-generado)

## Sesión: 313fbc97-c238-462a-9f46-42732d854d75
### Iteración 1 - 2026-01-13 10:30
- **Tarea**: Implementar autenticación JWT
- **Intentos**: Usar jsonwebtoken library
- **Resultado**: ❌ Falló - conflicto con versión de Node
- **Errores**: `TypeError: jwt.sign is not a function`
- **Próximo intento**: Usar jose library en su lugar

### Iteración 2 - 2026-01-13 10:35
- **Tarea**: Implementar autenticación JWT
- **Intentos**: Usar jose library (basado en iteración anterior)
- **Resultado**: ✅ Completado
```

**Implementación**:

```bash
# Añadir a hooks/post-tool-use.sh
append_progress() {
    local RESULT=$1
    local ATTEMPTS=$2

    cat >> ~/.ralph/progress.md << EOF

### Iteración $(date +%s) - $(date +"%Y-%m-%d %H:%M")
- **Tarea**: $CURRENT_TASK
- **Intentos**: $ATTEMPTS
- **Resultado**: $RESULT
EOF
}
```

**Archivos a crear/modificar**:
- `~/.ralph/progress.md` - Nuevo archivo
- `hooks/session-start-ledger.sh` - Cargar progress.md
- `hooks/pre-compact-handoff.sh` - Guardar a progress.md

---

### 🥉 Mejora #3: Sistema de PIN/Lookup Tables

**Impacto**: 🟡 MEDIO-ALTO | **Riesgo**: 🟢 BAJO | **Esfuerzo**: 🟡 MEDIO

**Problema actual**:
CLAUDE.md es el único "PIN" (frame of reference). No hay lookup tables optimizadas para el search tool.

**Propuesta del creador**:

```markdown
# ~/.ralph/pins/readme.md (Lookup Table Principal)

| Especificación | Keywords | Archivos |
|----------------|----------|----------|
| Autenticación | login, auth, JWT, OAuth, session, token | src/auth/*, specs/auth.md |
| Base de datos | DB, SQL, query, migration, schema | src/db/*, specs/database.md |
| API endpoints | REST, route, handler, middleware | src/api/*, specs/api.md |
| Testing | test, spec, mock, fixture, jest, pytest | tests/*, specs/testing.md |
```

**Por qué funciona**:
- Más keywords = más hits del search tool
- Menos "invención" por parte del LLM
- Frame de referencia estable que NO se pierde con compaction

**Implementación**:

```bash
# Nuevo comando: ralph pin
cmd_pin() {
    case "$1" in
        init)
            mkdir -p ~/.ralph/pins
            create_default_pins
            ;;
        add)
            add_pin "$2" "$3" "$4"  # nombre, keywords, archivos
            ;;
        search)
            grep -i "$2" ~/.ralph/pins/readme.md
            ;;
    esac
}
```

---

### 🏅 Mejora #4: context: fork en Skills Críticos

**Impacto**: 🟡 MEDIO | **Riesgo**: 🟢 BAJO | **Esfuerzo**: 🟢 BAJO

**Problema actual**:
Skills como `/gates`, `/adversarial`, `/parallel` ejecutan en el mismo contexto, potencialmente contaminando el estado principal.

**Propuesta (Claude Code 2.1)**:

```yaml
# ~/.claude/skills/gates/SKILL.md
---
name: gates
description: Quality validation (format, lint, tests)
context: fork  # ← AÑADIR ESTO
allowed-tools: Bash,Read,Grep
---
```

**Skills a modificar**:

| Skill | Razón para fork |
|-------|-----------------|
| `/gates` | Validación no debe contaminar contexto de desarrollo |
| `/adversarial` | Múltiples agentes revisores independientes |
| `/parallel` | Por definición, tareas paralelas deben estar aisladas |
| `/security` | Auditoría debe ser contexto limpio |

**Implementación**:
Añadir `context: fork` al frontmatter de cada skill listado.

---

### 🎖️ Mejora #5: Modo "Delega y Vete" (Background Tasks)

**Impacto**: 🟡 MEDIO | **Riesgo**: 🟡 MEDIO | **Esfuerzo**: 🟡 MEDIO

**Problema actual**:
`run_in_background` existe pero no tiene:
- Notificaciones al completar
- Estado persistente si se cierra terminal
- Fácil recuperación de resultados

**Propuesta (inspirada en Cowork)**:

```bash
# ralph background <task>
ralph background "Revisa seguridad de todos los módulos"

# Output:
# ✅ Tarea iniciada en background
# 📁 Log: ~/.ralph/background/task-abc123.log
# 🔔 Notificación cuando complete
#
# Para ver estado: ralph background status abc123
# Para cancelar: ralph background cancel abc123
```

**Implementación**:

```bash
cmd_background() {
    local TASK="$1"
    local TASK_ID=$(uuidgen | cut -d'-' -f1)
    local LOG_FILE="$HOME/.ralph/background/task-${TASK_ID}.log"

    mkdir -p ~/.ralph/background

    # Ejecutar en background con nohup
    nohup claude --prompt "$TASK" > "$LOG_FILE" 2>&1 &

    # Guardar PID para tracking
    echo $! > ~/.ralph/background/${TASK_ID}.pid

    # Configurar notificación
    setup_completion_notification "$TASK_ID" "$LOG_FILE"

    echo "✅ Tarea $TASK_ID iniciada"
    echo "📁 Log: $LOG_FILE"
}
```

---

## Matriz de Priorización

| # | Mejora | Impacto | Riesgo | Esfuerzo | Score |
|---|--------|---------|--------|----------|-------|
| 1 | Session refresh por tarea | 🔴 10 | 🟡 5 | 🟡 5 | **25** |
| 2 | progress.md automático | 🔴 9 | 🟢 2 | 🟢 3 | **23** |
| 3 | PIN/Lookup tables | 🟡 7 | 🟢 2 | 🟡 5 | **19** |
| 4 | context: fork en skills | 🟡 6 | 🟢 2 | 🟢 2 | **18** |
| 5 | Modo background | 🟡 6 | 🟡 4 | 🟡 5 | **15** |

**Fórmula**: Score = Impacto × 2 + (10 - Riesgo) + (10 - Esfuerzo) / 2

---

## Plan de Implementación Sugerido

### Semana 1: Fundamentos (Mejoras 1-2)
```
Día 1-2: Implementar session_refresh_loop() en scripts/ralph
Día 3-4: Crear sistema de progress.md con hooks
Día 5: Testing y documentación
```

### Semana 2: Optimización (Mejoras 3-4)
```
Día 1-2: Crear sistema de PIN/Lookup tables
Día 3: Añadir context: fork a skills críticos
Día 4-5: Testing integrado y ajustes
```

### Semana 3: UX (Mejora 5)
```
Día 1-3: Implementar modo background con notificaciones
Día 4-5: Documentación y release v2.41
```

---

## Proposed Changes (JSON)

```json
[
  {
    "type": "agent_behavior",
    "file": "scripts/ralph",
    "change": "Añadir session_refresh_loop() para nueva sesión por iteración",
    "justification": "Core del Ralph Loop según creador - evita context rot"
  },
  {
    "type": "new_command",
    "file": "~/.ralph/progress.md",
    "change": "Crear sistema de progress.md con hooks automáticos",
    "justification": "Memoria persistente entre iteraciones evita repetir errores"
  },
  {
    "type": "new_command",
    "file": "scripts/ralph + ~/.ralph/pins/",
    "change": "Implementar comando 'ralph pin' con lookup tables",
    "justification": "Mejora hit rate del search tool, reduce invención del LLM"
  },
  {
    "type": "quality_gate",
    "file": "~/.claude/skills/gates/SKILL.md",
    "change": "Añadir 'context: fork' al frontmatter",
    "justification": "Aislamiento de contexto según best practices Claude Code 2.1"
  },
  {
    "type": "new_command",
    "file": "scripts/ralph",
    "change": "Implementar 'ralph background' con notificaciones",
    "justification": "Patrón 'delega y vete' de Cowork para tareas largas"
  }
]
```

---

## What Went Well (en los videos analizados)

1. ✅ **Documentación clara del problema**: Los 4 videos explican con diagramas por qué el context rot es crítico
2. ✅ **Soluciones concretas**: El creador proporciona código real, no solo teoría
3. ✅ **Consenso entre fuentes**: 3 de 4 videos coinciden en los principios fundamentales
4. ✅ **Claude Code 2.1 ya tiene features útiles**: `context: fork` y async agents están disponibles

## Improvement Opportunities

1. **Gap principal**: Ralph v2.40 NO implementa session refresh por tarea - esto es crítico
2. **Falta progress.md**: Sin memoria de errores, cada iteración puede repetir los mismos problemas
3. **PINs no optimizados**: CLAUDE.md es demasiado genérico para ser un buen lookup table
4. **Skills sin aislamiento**: `context: fork` no se usa, contaminando contexto

---

## Conclusión

Los 4 videos analizados revelan un patrón claro: **Ralph Loop es fundamentalmente sobre malloc determinístico del context window**. El plugin oficial de Anthropic NO implementa esto correctamente porque no inicia nuevas sesiones.

Las 5 mejoras propuestas para v2.41 abordan directamente estos gaps:

1. **Session refresh** → Evita context rot (el problema principal)
2. **progress.md** → Memoria entre iteraciones
3. **PIN/Lookup tables** → Mejor hit rate del search
4. **context: fork** → Aislamiento de sub-agentes
5. **Background mode** → UX de "delega y vete"

**Recomendación**: Implementar mejoras 1-2 primero (semana 1) ya que tienen el mayor impacto con riesgo moderado.

---

## Siguiente Paso

```bash
# Comenzar implementación de Mejora #1
ralph worktree "feat/v2.41-session-refresh"
```

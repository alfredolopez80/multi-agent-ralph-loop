# Plan de Integración Completa de Swarm Mode v2.81.1

**Date**: 2026-01-30
**Version**: v2.81.1
**Status**: PLAN COMPLETO
**Author**: Claude Code + User Collaboration

## Objetivo

Integrar **swarm mode de forma completa y permanente** en todo Multi-Agent Ralph Loop, asegurando que:
- Todos los comandos (/orchestrator, /loop, /edd, /bug, etc.) usen spawn mode
- Todas las tareas se ejecuten en background con teammates
- El sistema use spawn mode por defecto para cualquier actividad

## Estado Actual Confirmado

✅ **Swarm mode está completamente configurado**:
- `permissions.defaultMode = "delegate"` ✓
- Variables de entorno se establecen dinámicamente ✓
- 37 agentes disponibles ✓
- Documentación completa ✓

## Arquitectura Objetivo

```
Usuario ingresa tarea
       ↓
   [Comando/Skill]
       ↓
┌──────────────────────────────────────┐
│  1. Crear Team (spawnTeam)             │
│  2. Spawnear N Teammates (Task)         │
│  3. Crear Tasks (TaskCreate)           │
│  4. Asignar Tasks (TaskUpdate)          │
│  5. Coordinar vía TeammateTool         │
└──────────────────────────────────────┘
       ↓
   Ejecución Paralela (background)
       ↓
  Resultados consolidados
```

## Comandos a Actualizar

### 1. /orchestrator (YA CONFIGURADO)

**Estado**: ✅ Completo
**Archivo**: `.claude/commands/orchestrator.md`

Ya tiene parámetros de swarm:
```yaml
Task:
  team_name: "orchestration-team"
  mode: "delegate"

ExitPlanMode:
  launchSwarm: true
  teammateCount: 3
```

### 2. /loop (REQUIERE ACTUALIZACIÓN)

**Estado**: ⚠️ Parcialmente configurado
**Archivo**: `.claude/commands/loop.md`

**Cambios requeridos**:
```yaml
# Agregar al final del archivo
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  team_name: "loop-execution-team"    # ← AGREGAR
  name: "loop-lead"                   # ← AGREGAR
  mode: "delegate"                    # ← AGREGAR
  run_in_background: true            # ← AGREGAR
  prompt: "$ARGUMENTS"
```

### 3. /edd (REQUIERE INTEGRACIÓN)

**Estado**: ❌ Sin swarm mode
**Archivo**: `.claude/skills/edd/skill.md`

**Cambios requeridos**:
```yaml
# Agregar sección de swarm mode
## Swarm Mode Integration (v2.81.1)

EDD framework now supports swarm mode for parallel evaluation:

### Spawn Evaluation Team
```bash
/edd "Define feature X" --swarm
```

This spawns:
- 1 Team Leader (evaluation coordinator)
- 3 Teammates (parallel evaluators)

### Team Composition
- **Leader**: EDD coordinator
- **Teammate 1**: Capability checks specialist
- **Teammate 2**: Behavior checks specialist
- **Teammate 3**: Non-functional checks specialist
```

### 4. /bug (REQUIERE CREACIÓN)

**Estado**: ❌ No existe
**Acción**: Crear comando `/bug` con swarm mode

```bash
# Crear .claude/commands/bug.md
---
name: bug
prefix: "@bug"
category: debugging
color: red
description: "Debugging with swarm mode: analyze → reproduce → fix → validate"
argument-hint: "<bug description>"
---

# /bug - Swarm Mode Debugging

Spawns debugging team for systematic bug analysis:

## Team Composition
- **Leader**: Debug coordinator
- **Teammate 1**: Error analysis specialist
- **Teammate 2**: Code archaeologist (finds root cause)
- **Teammate 3**: Fix validator

## Usage
/bug "Authentication fails after 30 minutes"
```

### 5. Otros Comandos a Actualizar

| Comando | Estado Requerido | teammateCount | team_name |
|---------|----------------|---------------|-----------|
| `/adversarial` | ⚠️ Parcial | 3 | adversarial-council |
| `/parallel` | ⚠️ Parcial | 6 | parallel-execution |
| `/gates` | ❌ Sin swarm | 3 | quality-gates-team |
| `/clarify` | ❌ Sin swarm | 2 | clarification-team |

## Patrón de Implementación

### Template para Comandos con Swarm Mode

```markdown
---
name: command-name
prefix: "@cmd"
category: category
description: "Description with swarm mode"
argument-hint: "<task>"
---

# /command-name

## Swarm Mode Integration (v2.81.1)

This command uses swarm mode by default:

### Auto-Spawn Configuration
```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  team_name: "command-team"           # Unique team name
  name: "command-lead"                # Lead agent name
  mode: "delegate"                     # Enable delegation
  run_in_background: true            # Background execution
  prompt: "$ARGUMENTS"
```

### Manual Override
To disable swarm mode:
```bash
/command-name "task" --no-swarm
```

## Team Composition
- **Leader**: [Purpose]
- **Teammate 1**: [Specialization]
- **Teammate 2**: [Specialization]
- **Teammate 3**: [Specialization]
```

## Script de Actualización Automática

Crear `.claude/scripts/add-swarm-to-command.sh`:

```bash
#!/bin/bash
# add-swarm-to-command.sh
# Agrega parámetros de swarm mode a un comando existente

COMMAND_FILE="$1"
TEAM_NAME="$2"
LEAD_NAME="$3"
TEAMMATE_COUNT="${4:-3}"

if [[ ! -f "$COMMAND_FILE" ]]; then
  echo "Error: Command file not found: $COMMAND_FILE"
  exit 1
fi

# Buscar sección Task o crear si no existe
if ! grep -q "^Task:" "$COMMAND_FILE"; then
  echo "Error: Command file doesn't have Task section"
  exit 1
fi

# Agregar parámetros de swarm
TEMP_FILE=$(mktemp)
cp "$COMMAND_FILE" "$TEMP_FILE"

cat >> "$TEMP_FILE" << 'EOF

## Swarm Mode (v2.81.1)
Auto-spawns team for parallel execution:

EOF

cat >> "$TEMP_FILE" << EOF
\`\`\`yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  team_name: "$TEAM_NAME"
  name: "$LEAD_NAME"
  mode: "delegate"
  run_in_background: true
  prompt: "\$ARGUMENTS"
\`\`\`
EOF

mv "$TEMP_FILE" "$COMMAND_FILE"
echo "✓ Swarm mode added to $COMMAND_FILE"
echo "  Team: $TEAM_NAME"
echo "  Lead: $LEAD_NAME"
echo "  Teammates: $TEAMMATE_COUNT"
```

## Hook para Auto-Background

Crear `.claude/hooks/auto-background-swarm.sh`:

```bash
#!/bin/bash
# auto-background-swarm.sh
# PostToolUse hook - Automatically sends tasks to background with swarm

# Detectar si es comando que soporta swarm
SUPPORTED_COMMANDS=("orchestrator" "loop" "edd" "bug" "adversarial" "parallel")
COMMAND_TYPE="$1"

if [[ " ${SUPPORTED_COMMANDS[@]} " =~ " ${COMMAND_TYPE} " ]]; then
  # Verificar si tiene run_in_background
  if ! grep -q "run_in_background: true" ".claude/commands/${COMMAND_TYPE}.md"; then
    echo "⚠️  WARNING: $COMMAND_TYPE doesn't have run_in_background"
    echo "   Consider adding: run_in_background: true"
  fi
fi
echo '{"continue": true}'
```

## Validación

### Test de Integración

```bash
# Verificar que todos los comandos tengan swarm mode
for cmd in orchestrator loop edd adversarial parallel gates; do
  if grep -q "team_name.*${cmd}" ".claude/commands/${cmd}.md"; then
    echo "✓ $cmd has swarm mode"
  else
    echo "❌ $cmd missing swarm mode"
  fi
done
```

### Test de Ejecución Real

```bash
# Probar swarm mode con tarea simple
/orchestrator "create hello world function"

# Verificar que se creó team
ls -la ~/.claude/teams/

# Verificar que se crearon tareas
ls -la ~/.claude/tasks/
```

## Plan de Implementación

### Fase 1: Core Commands (PRIORIDAD ALTA)
- [ ] Actualizar `/loop` con swarm mode completo
- [ ] Integrar `/edd` con swarm mode
- [ ] Crear `/bug` con swarm mode
- [ ] Validar integración

### Fase 2: Secondary Commands (PRIORIDAD MEDIA)
- [ ] Actualizar `/adversarial` con swarm mode
- [ ] Actualizar `/parallel` con swarm mode
- [ ] Actualizar `/gates` con swarm mode

### Fase 3: Global Hooks (PRIORIDAD MEDIA)
- [ ] Crear hook `auto-background-swarm.sh`
- [ ] Integrar en PostToolUse
- [ ] Validar que no rompe comandos existentes

### Fase 4: Documentation (PRIORIDAD BAJA)
- [ ] Actualizar CLAUDE.md con swarm mode
- [ ] Crear guía de uso de swarm mode
- [ ] Documentar patrones de comunicación inter-agent

### Fase 5: Testing (PRIORIDAD ALTA)
- [ ] Test de integración de cada comando
- [ ] Test de comunicación inter-agent
- [ ] Test de cleanup de teams
- [ ] Test de背景 execution

## Cronograma Estimado

| Fase | Tiempo Estimado | Complejidad |
|------|----------------|-------------|
| Fase 1 | 2 horas | Media |
| Fase 2 | 1 hora | Baja |
| Fase 3 | 2 horas | Media |
| Fase 4 | 1 hora | Baja |
| Fase 5 | 3 horas | Alta |
| **Total** | **9 horas** | - |

## Métricas de Éxito

1. ✅ Todos los comandos principales tienen `team_name`
2. ✅ Todos los comandos principales tienen `mode: delegate`
3. ✅ Todos los comandos principales tienen `run_in_background: true`
4. ✅ Tests de integración pasan
5. ✅ Ejecución real de prueba funciona

## Próximos Pasos

1. **Revisar plan** con usuario
2. **Aprobar implementación**
3. **Ejecutar Fase 1** (core commands)
4. **Validar resultados**
5. **Continuar con fases restantes**

---

**Plan Creado**: 2026-01-30 1:20 PM GMT+1
**Próxima Revisión**: Después de aprobación del usuario

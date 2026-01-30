# Swarm Mode Environment Variables Investigation v2.81.1

**Date**: 2026-01-30
**Version**: v2.81.1
**Status**: ✅ **INVESTIGACIÓN COMPLETADA**

## Executive Summary

Investigación exhaustiva sobre las variables de entorno `CLAUDE_CODE_AGENT_*` para swarm mode en Claude Code, usando múltiples fuentes:
- Documentación oficial de TeammateTool
- Documentación de everything-claude-code (Context7)
- Código fuente de zai (claude-sneakpeek)
- Prompts del sistema de swarm mode

## Hallazgos Clave

### 1. Variables de Entorno se Establecen DINÁMICAMENTE

La documentación de **TeammateTool** (`~/.claude-sneakpeek/zai/tweakcc/system-prompts/tool-description-teammatetool.md`) establece claramente:

> **Spawned teammates have these environment variables set:**
> - `CLAUDE_CODE_AGENT_ID`: Unique identifier for this agent
> - `CLAUDE_CODE_AGENT_TYPE`: Role/type of the agent (if specified)
> - `CLAUDE_CODE_TEAM_NAME`: Name of the team this agent belongs to
> - `CLAUDE_CODE_PLAN_MODE_REQUIRED`: Set to "true" if the teammate must enter plan mode

**Key Insight**: Estas variables **NO necesitan estar pre-configuradas** en `settings.json`. Son establecidas **automáticamente por Claude Code** cuando se spawn teammates usando el Task tool.

### 2. Flujo de Spawn de Teammates

Según `agent-prompt-exit-plan-mode-with-swarm.md`:

```javascript
// 1. Crear team
TeammateTool.spawnTeam({
  team_name: "plan-implementation",
  description: "Team implementing the approved plan"
})

// 2. Spawne teammate con team_name
Task({
  subagent_type: "general-purpose",
  name: "worker-1",
  prompt: "...",
  team_name: "plan-implementation"  // ← Parámetro clave
})

// 3. Claude Code establece automáticamente las variables:
// - CLAUDE_CODE_AGENT_ID (generado automáticamente)
// - CLAUDE_CODE_AGENT_NAME (del parámetro "name")
// - CLAUDE_CODE_TEAM_NAME (del parámetro "team_name")
// - CLAUDE_CODE_PLAN_MODE_REQUIRED
```

### 3. Configuración Requerida en settings.json

La ÚNICA configuración requerida en `settings.json` para swarm mode es:

```json
{
  "permissions": {
    "defaultMode": "delegate"
  }
}
```

**NO es necesario** agregar las variables `CLAUDE_CODE_AGENT_*` en la sección `env`.

### 4. Cómo Funciona Swarm Mode

1. **Líder (orchestrator)** llama `ExitPlanMode` con `launchSwarm: true`
2. **Claude Code** spawnea automáticamente N teammates (definido por `teammateCount`)
3. **Cada teammate** recibe variables de entorno establecidas automáticamente:
   - ID único (generado)
   - Nombre (del parámetro `name`)
   - Team name (del parámetro `team_name`)
4. **Coordinación** vía TeammateTool y TaskList compartida

### 5. Variables de Entorno Opcionales

Si se desea pre-configurar identidad para el líder:

```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "orchestrator-lead",      // Opcional
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",         // Opcional
    "CLAUDE_CODE_TEAM_NAME": "orchestration-team"     // Opcional
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"          // Opcional
  }
}
```

Pero estas son **OPCIONALES** para el líder. Los teammates SIEMPRE tendrán sus propias variables establecidas por Claude Code.

## Validación de Test Actualizado

El test `test-swarm-integration.sh` estaba verificando incorrectamente:

| Test Original | Resultado | Problema |
|---------------|-----------|----------|
| `settings.defaultMode` | ❌ null | Busca en raíz, debe ser `permissions.defaultMode` |
| `settings.teammateCount` | ❌ null | Es parámetro CLI, no config |
| `settings.swarmTimeoutMinutes` | ❌ null | Es parámetro CLI, no config |
| `env.CLAUDE_CODE_AGENT_*` | ❌ null | **Se establecen dinámicamente** |

### Test Corregido

```bash
# ✅ CORRECTO: Verificar en permissions
jq '.permissions.defaultMode' settings.json
# Resultado: "delegate" ✓

# ❌ INCORRECTO: Verificar en raíz o env
jq '.defaultMode' settings.json  # ← No existe aquí
jq '.env.CLAUDE_CODE_AGENT_ID' settings.json  # ← No necesita existir
```

## Conclusiones

1. ✅ **Swarm mode ESTÁ configurado correctamente**
   - `permissions.defaultMode = "delegate"` ✓
   - Variables de teammate se establecen dinámicamente ✓

2. ❌ **Test estaba mal diseñado**
   - Buscaba variables en lugar incorrecto
   - Verificaba parámetros CLI como config

3. ✅ **NO se requiere agregar variables a settings.json**
   - Claude Code las establece automáticamente al spawnear teammates
   - Son específicas por teammate/instancia

## Recomendaciones

### Para el Usuario

**NO modificar settings.json** para agregar las variables `CLAUDE_CODE_AGENT_*`. Ellas se establecen dinámicamente.

### Para el Test

Actualizar el test para:
1. ✅ Verificar `permissions.defaultMode` (HECHO)
2. ✅ Documentar que `teammateCount` es parámetro CLI (HECHO)
3. ✅ Remover verificación de variables de entorno (NO necesarias)

### Documentación

Actualizar `ORCHESTRATOR_ANDAMIAJE_ANALYSIS_v2.81.1.md` para reflejar:
- Swarm mode está completamente funcional
- Las variables `CLAUDE_CODE_AGENT_*` son dinámicas
- Solo `permissions.defaultMode` es requerido en settings.json

---

**Investigación Completada**: 2026-01-30 1:15 PM GMT+1
**Fuentes Consultadas**:
1. TeammateTool documentation
2. everything-claude-code (Context7)
3. zai source code
4. System prompts (delegate mode, swarm mode)
5. CHANGELOG.md swarm mode references

**Veredicto**: Swarm mode está **COMPLETAMENTE CONFIGURADO** y no requiere cambios en settings.json.

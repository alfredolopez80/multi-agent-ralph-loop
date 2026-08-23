# Cómo Usar Swarm Mode en Claude/Zai

**Versión**: 2.81.0
**Fecha**: 2026-01-29
**Estado**: ✅ VERIFICADO Y FUNCIONAL

---

## ✅ Verificación Completada

Tu instalación de claude/zai está **perfectamente configurada** para Swarm Mode:

| Componente | Estado | Detalles |
|------------|--------|----------|
| **Claude Code** | ✅ Listo | Versión 2.1.22 |
| **Swarm Gate** | ✅ Parcheado | 0 ocurrencias de `tengu_brass_pebble` |
| **TeammateTool** | ✅ Disponible | 6 referencias encontradas |
| **Model** | ✅ Configurado | GLM-4.7 como PRIMARY |
| **defaultMode** | ✅ Configurado | "delegate" para swarm |
| **Agent ID** | ✅ Configurado | "claude-orchestrator" |
| **Agent Name** | ✅ Configurado | "Orchestrator" |
| **Team Name** | ✅ Configurado | "multi-agent-ralph-loop" |

---

## 🚀 Cómo Usar Swarm Mode

### Método 1: Usando /orchestrator (Recomendado)

Simplemente ejecuta el comando `/orchestrator` con cualquier tarea:

```bash
/orchestrator "crear una función de hello world en TypeScript"
```

**Qué sucederá automáticamente**:
1. El orchestrator creará el equipo "multi-agent-ralph-loop"
2. Escribirá un plan en `.claude/orchestrator-analysis.md`
3. Llamará a `ExitPlanMode` con `launchSwarm: true`
4. **Spawneará 3 teammates automáticamente**:
   - `code-reviewer` - Revisará tu código
   - `test-architect` - Creará tests
   - `security-auditor` - Auditará seguridad
5. Los teammates coordinarán mediante la lista de tareas compartida
6. Todos trabajarán en paralelo

### Método 2: Usando /loop

```bash
/loop "implementar autenticación con JWT"
```

**Qué sucederá**:
1. Loop creará el equipo "loop-execution-team"
2. Podrá delegar tareas a teammates si es necesario
3. Ejecutará iterativamente hasta VERIFIED_DONE
4. Validará calidad en cada iteración

### Método 3: Usando Task Tool Directamente

Si quieres más control manual, puedes usar el Task tool directamente:

```yaml
Task:
  subagent_type: "orchestrator"
  model: "sonnet"                      # GLM-4.7 es PRIMARY
  team_name: "orchestration-team"      # Crea el equipo
  name: "orchestrator-lead"            # Nombre del agente
  mode: "delegate"                     # Permite delegar a teammates
  prompt: "Implementar feature X"

ExitPlanMode:
  launchSwarm: true                    # Spawnea teammates
  teammateCount: 3                     # Cantidad de teammates
```

---

## 🎯 Ejemplo Práctico

Vamos a probar con un ejemplo simple:

```bash
/orchestrator "crear una función que sume dos números en TypeScript"
```

**Flujo esperado**:

1. **Fase de Clarificación** (si es necesario)
   - El orchestrator te preguntará detalles
   - Responde las preguntas

2. **Fase de Planificación**
   - Creará un plan detallado
   - Lo guardará en `.claude/orchestrator-analysis.md`

3. **Fase de Swarm (¡Aquí empieza la magia!)**
   - Llamará a `ExitPlanMode` con `launchSwarm: true`
   - **Spawneará 3 teammates automáticamente**
   - Verás algo como:
     ```
     Spawning teammate 1/3: code-reviewer
     Spawning teammate 2/3: test-architect
     Spawning teammate 3/3: security-auditor
     ```

4. **Fase de Ejecución**
   - Los teammates trabajarán en paralelo
   - Coordinarán mediante la lista de tareas compartida
   - Se enviarán mensajes entre agentes

5. **Fase de Validación**
   - Quality gates se ejecutarán automáticamente
   - Cada teammate validará su parte

6. **Fase de Retrospectiva**
   - Análisis de mejoras
   - Aprendizaje automático

---

## 📊 Cómo Verificar que Swarm Funciona

### Verificación 1: Ver los Agents Spawneados

Después de ejecutar `/orchestrator`, deberías ver:

```
✓ Spawning teammates for orchestration-team
  - code-reviewer (ID: xxx)
  - test-architect (ID: xxx)
  - security-auditor (ID: xxx)
```

### Verificación 2: Ver la Lista de Tareas Compartida

Los teammates pueden ver las tareas de otros:

```bash
# Los teammates pueden ver tareas compartidas
# (Esto es automático, no necesitas ejecutar nada)
```

### Verificación 3: Ver Mensajes entre Agents

Los agentes se envían mensajes automáticamente:

```
[orchestrator-lead → code-reviewer]: "Por favor revisa este código"
[code-reviewer → orchestrator-lead]: "Revisión completa, 2 issues encontrados"
```

---

## 🔧 Configuración Actual

Tu configuración en `~/.claude-sneakpeek/zai/config/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"
  },
  "permissions": {
    "defaultMode": "delegate"
  },
  "model": "glm-4.7"
}
```

**Explicación**:
- `CLAUDE_CODE_AGENT_ID`: Identificador único de tu agente
- `CLAUDE_CODE_AGENT_NAME`: Nombre legible ("Orchestrator")
- `CLAUDE_CODE_TEAM_NAME`: Nombre del equipo (para coordinación)
- `CLAUDE_CODE_PLAN_MODE_REQUIRED`: `"false"` = Auto-aprobar planes
- `defaultMode`: `"delegate"` = Permite delegar a teammates
- `model`: `"glm-4.7"` = Modelo PRIMARY para todo

---

## 🎬 Ejemplo Completo

Pongamos que quieres crear un API REST:

```bash
/orchestrator "crear un API REST con endpoints para usuarios y productos"
```

**Lo que sucederá**:

1. **Clarificación**
   - ¿Qué framework? (Express, Fastify, etc.)
   - ¿Qué base de datos? (PostgreSQL, MongoDB, etc.)
   - ¿Autenticación? (JWT, OAuth, etc.)

2. **Planificación**
   - Plan detallado en `.claude/orchestrator-analysis.md`

3. **Swarm** (¡3 teammates spawnearán!)
   - **Teammate 1 (code-reviewer)**: Revisará cada endpoint
   - **Teammate 2 (test-architect)**: Creará tests para cada endpoint
   - **Teammate 3 (security-auditor)**: Auditará seguridad de cada endpoint

4. **Ejecución Paralela**
   - Mientras tú implementas los endpoints
   - El code-reviewer los revisa en tiempo real
   - El test-architect crea tests simultáneamente
   - El security-auditor valida seguridad

5. **Validación**
   - Quality gates automáticos
   - TypeScript compile check
   - ESLint check
   - Tests execution

6. **Resultado Final**
   - API REST completo
   - Código revisado
   - Tests creados
   - Seguridad validada
   - Documentación generada

---

## 📋 Comandos Disponibles

### Comandos de Swarm

| Comando | Descripción | Uso |
|---------|-------------|-----|
| `/orchestrator` | Orquestación completa con swarm | Tareas complejas |
| `/loop` | Ejecución iterativa con team | Refinamiento iterativo |

### Task Tool Parameters

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `team_name` | "orchestration-team" | Nombre del equipo |
| `name` | "orchestrator-lead" | Tu nombre en el equipo |
| `mode` | "delegate" | Permite delegar |
| `launchSwarm` | `true` | Spawnea teammates |
| `teammateCount` | `1-5` | Cantidad de teammates |

---

## 🐛 Solución de Problemas

### Problema: Los teammates no spawnean

**Síntoma**: Ejecutas `/orchestrator` pero no ves teammates

**Solución**:
```bash
# Verifica que la configuración está correcta
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '{
  agent_id: .env.CLAUDE_CODE_AGENT_ID,
  agent_name: .env.CLAUDE_CODE_AGENT_NAME,
  team_name: .env.CLAUDE_CODE_TEAM_NAME
}'

# Si falta algo, ejecuta el script de configuración
bash tests/swarm-mode/configure-swarm-mode.sh
```

### Problema: Error de permisos

**Síntoma**: "Permission denied" o "Cannot delegate"

**Solución**:
```bash
# Verifica defaultMode
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.permissions.defaultMode'
# Debe ser: "delegate"

# Si no es "delegate", cámbialo
jq '.permissions.defaultMode = "delegate"' \
  ~/.claude-sneakpeek/zai/config/settings.json \
  > /tmp/settings.json.tmp && \
  mv /tmp/settings.json.tmp ~/.claude-sneakpeek/zai/config/settings.json
```

### Problema: Teams no se coordinan

**Síntoma**: Los agents no se ven entre sí

**Solución**:
```bash
# Verifica que todos tengan el mismo TEAM_NAME
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.env.CLAUDE_CODE_TEAM_NAME'
# Debe ser: "multi-agent-ralph-loop"
```

---

## 📚 Documentación Adicional

### Guías Detalladas

- **[SETTINGS_CONFIGURATION_GUIDE.md](SETTINGS_CONFIGURATION_GUIDE.md)** - Explicación detallada de cada configuración
- **[REPRODUCTION_GUIDE.md](REPRODUCTION_GUIDE.md)** - Cómo reproducir en cualquier máquina
- **[README.md](README.md)** - Resumen del suite de tests

### Documentación Técnica

- **[SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md](../../docs/architecture/SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md)** - Análisis técnico completo
- **[SWARM_MODE_VALIDATION_v2.81.0.md](../../docs/architecture/SWARM_MODE_VALIDATION_v2.81.0.md)** - Reporte de validación

### Scripts de Ayuda

```bash
# Validar configuración
bash tests/swarm-mode/test-swarm-mode-config.sh

# Reconfigurar si es necesario
bash tests/swarm-mode/configure-swarm-mode.sh
```

---

## ✅ Respuesta Directa a Tu Pregunta

**¿Puedes correr el sistema de swarm en claude/zai?**

**¡SÍ!** Tu instalación está perfectamente configurada:

✅ Claude Code 2.1.22 instalado
✅ Swarm mode habilitado (gate parcheado)
✅ TeammateTool disponible
✅ Variables de agente configuradas
✅ Permisos correctos (delegate mode)
✅ GLM-4.7 como modelo PRIMARY

**Solo necesitas ejecutar**:
```bash
/orchestrator "tu tarea aquí"
```

Y el sistema spawneará automáticamente 3 teammates que trabajarán en paralelo contigo.

---

## 🎉 ¡Pruebalo Ahora!

```bash
# Prueba simple
/orchestrator "crear una función que sume dos números"

# Prueba más compleja
/loop "implementar un sistema de autenticación con JWT"

# O simplemente pregunta
/orchestrator "ayúdame a entender cómo funciona swarm mode"
```

**¡Swarm mode está listo para usar en claude/zai!** 🚀

---

**Estado**: ✅ VERIFICADO Y FUNCIONAL
**Fecha**: 2026-01-29
**Versión**: 2.81.0

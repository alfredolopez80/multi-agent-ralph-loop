# GLM-5 Agent Teams - Guía de Pruebas

## Pruebas Rápidas

### 1. Ejecutar Test Suite Completo

```bash
# Ejecutar todos los tests (20 tests)
./tests/agent-teams/test-glm5-teammates.sh
```

### 2. Probar GLM-5 API Manualmente

```bash
# Test básico de conectividad
curl -X POST "https://api.z.ai/api/coding/paas/v4/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $Z_AI_API_KEY" \
  --data-raw '{"model":"glm-5","messages":[{"role":"user","content":"Say hello"}],"max_tokens":50}'
```

### 3. Probar Teammate Script

```bash
# Spawn un teammate GLM-5
.claude/scripts/glm5-teammate.sh coder "Escribe una función hello world en Python" "test-001"

# Verificar que creó los archivos
ls -la .ralph/teammates/test-001/
ls -la .ralph/reasoning/test-001.txt
```

### 4. Probar Team Coordinator

```bash
# Inicializar un equipo
.claude/scripts/glm5-init-team.sh "test-team"

# Ver status
.claude/scripts/glm5-team-coordinator.sh "" "" status

# Ver archivo de status
cat .ralph/team-status.json
```

### 5. Probar Memory System

```bash
# Inicializar memoria para un agente
.claude/scripts/glm5-agent-memory.sh glm5-coder project init

# Escribir a memoria
.claude/scripts/glm5-agent-memory.sh glm5-coder project write semantic "This is a test fact"

# Leer memoria
.claude/scripts/glm5-agent-memory.sh glm5-coder project read semantic
```

### 6. Verificar Hooks Registrados

```bash
# Ver qué hooks están configurados
jq '.hooks | keys' ~/.claude-sneakpeek/zai/config/settings.json

# Ver TeammateIdle hook
jq '.hooks.TeammateIdle' ~/.claude-sneakpeek/zai/config/settings.json

# Ver TaskCompleted hook
jq '.hooks.TaskCompleted' ~/.claude-sneakpeek/zai/config/settings.json
```

### 7. Ver Logs

```bash
# Ver logs de teammates
cat .ralph/logs/teammates.log

# Ver logs de tareas
cat .ralph/logs/tasks.log

# Ver logs de memoria
cat .ralph/logs/memory.log
```

## Validación Completa

```bash
# 1. Todos los tests deben pasar
./tests/agent-teams/test-glm5-teammates.sh
# Esperado: PASSED: 20, FAILED: 0

# 2. Verificar estructura de directorios
ls -la .ralph/
# Debe mostrar: teammates, reasoning, agent-memory, logs, team-status.json

# 3. Verificar agentes creados
ls -la .claude/agents/glm5-*.md
# Debe mostrar: glm5-coder.md, glm5-reviewer.md, glm5-tester.md, glm5-orchestrator.md

# 4. Verificar scripts ejecutables
ls -la .claude/scripts/glm5-*.sh
# Todos deben tener permisos de ejecución (x)

# 5. Verificar hooks
ls -la .claude/hooks/glm5-*.sh
# Todos deben tener permisos de ejecución (x)
```

## Prueba End-to-End

```bash
# 1. Inicializar equipo
.claude/scripts/glm5-init-team.sh "e2e-test"

# 2. Spawn teammate (requiere Z_AI_API_KEY)
.claude/scripts/glm5-teammate.sh coder "Implementa una función factorial en TypeScript" "factorial-001"

# 3. Verificar reasoning capturado
cat .ralph/reasoning/factorial-001.txt

# 4. Verificar status
cat .ralph/teammates/factorial-001/status.json

# 5. Ver logs
tail .ralph/logs/teammates.log
```

## Troubleshooting

### Error: "Z_AI_API_KEY not set"

```bash
# Verificar que la variable está configurada
echo $Z_AI_API_KEY

# Si no está, agregarla a settings.json
jq '.env.Z_AI_API_KEY = "your-key"' ~/.claude-sneakpeek/zai/config/settings.json
```

### Error: "Script not executable"

```bash
# Hacer scripts ejecutables
chmod +x .claude/scripts/glm5-*.sh
chmod +x .claude/hooks/glm5-*.sh
```

### Error: "Directory not found"

```bash
# Crear estructura de directorios
mkdir -p .ralph/{teammates,reasoning,agent-memory,logs}
```

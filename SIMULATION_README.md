# 📊 Context Simulation Scripts

Scripts para probar el sistema de monitoreo de contexto y auto-compacting del Multi-Agent Ralph Loop.

## 🎯 Objetivo

Simular el aumento progresivo del uso de contexto (10% en 10%) para verificar:
- ✅ Actualización en tiempo real de la statusline
- ✅ Cambios de color según thresholds (CYAN → GREEN → YELLOW → RED)
- ✅ Activación de advertencias automáticas (75% warning, 85% critical)
- ✅ Funcionamiento del hook `context-warning.sh`
- ✅ Disparo del hook `PreCompact` cuando sea necesario

## 📁 Scripts Disponibles

| Script | Tamaño | Modo | Descripción |
|--------|--------|------|-------------|
| `simulate-context.sh` | 4.1K | Interactivo | Incrementa 10% con pausas entre cada paso |
| `simulate-context-auto.sh` | 4.8K | Automático | Incrementa 10% con delay configurable |
| `test-context-thresholds.sh` | 3.7K | Testing | Prueba un threshold específico |

## 🚀 Uso Rápido

### 1. Simulación Interactiva (Paso a Paso)

```bash
./simulate-context.sh
```

- Presiona `Enter` después de cada incremento del 10%
- Observa cómo la statusline cambia de color
- Detente en cualquier punto con `Ctrl+C`

### 2. Simulación Automática

```bash
# Delay de 2 segundos entre incrementos (default)
./simulate-context-auto.sh

# Delay de 0.5 segundos (más rápido)
./simulate-context-auto.sh 0.5

# Delay de 5 segundos (más lento)
./simulate-context-auto.sh 5
```

### 3. Prueba de Threshold Específico

```bash
# Probar warning threshold (75%)
./test-context-thresholds.sh 75

# Probar critical threshold (85%)
./test-context-thresholds.sh 85

# Probar below warning (70%)
./test-context-thresholds.sh 70
```

## 🎨 Colores de la Statusline

| Porcentaje | Color | Estado | Threshold |
|------------|-------|--------|-----------|
| 0-49% | CYAN | Low | - |
| 50-74% | GREEN | Normal | - |
| 75-84% | YELLOW | Warning | ≥75% |
| 85-100% | RED | Critical | ≥85% |

## 📋 Qué Observar

### 1. Statusline en Tiempo Real

La statusline debería mostrar el porcentaje actual:
```
⎇ main* │ 🤖 10% │ [otros datos...]
⎇ main* │ 🤖 50% │ [otros datos...]
⎇ main* │ 🤖 75% │ [otros datos...]  ← YELLOW
⎇ main* │ 🤖 90% │ [otros datos...]  ← RED
```

### 2. Hooks de Advertencia

El hook `context-warning.sh` (UserPromptSubmit) debería:
- **≥75%**: Mostrar advertencia YELLOW en la consola
- **≥85%**: Mostrar advertencia CRITICAL RED en la consola
- **≥85%**: Recomendar compactación inmediata

### 3. PreCompact Hook

El hook `pre-compact.sh` debería:
- Activarse automáticamente cuando el contexto se acerca al límite
- Guardar el estado actual en `~/.ralph/ledgers/`
- Guardar handoff en `~/.ralph/handoffs/`

## 🔍 Verificación Manual

### Ver Contexto Actual

```bash
# Ver archivo de contexto
cat ~/.ralph/projects/$(git rev-parse --show-toplevel | shasum -a 256 | awk '{print $1}')/state/glm-context.json | jq '.'

# Ver porcentaje actual
~/.claude/hooks/unified-context-tracker.sh get-percentage
```

### Restaurar Contexto Original

Los scripts crean automáticamente un backup:

```bash
# Restaurar backup de simulación
cp ~/.ralph/projects/*/state/glm-context.json.backup \
   ~/.ralph/projects/*/state/glm-context.json
```

## 📊 Estructura del Context File

```json
{
  "total_tokens": 12800,      // Tokens actuales
  "context_window": 128000,    // Ventana máxima del modelo de la sesión
  "percentage": 10,            // Porcentaje usado
  "last_updated": "2026-01-26T22:00:20Z",
  "session_start": "2026-01-26T22:00:20Z",
  "message_count": 1
}
```

## 🛠️ Troubleshooting

### La statusline no se actualiza

**Solución**: Verifica que el hook `statusline-ralph.sh` esté configurado en `settings.json`:

```json
{
  "statusLine": {
    "command": "~/.claude/scripts/statusline-ralph.sh"
  }
}
```

### No aparecen advertencias

**Solución**: Verifica que el hook `context-warning.sh` esté registrado en `settings.json`:

```bash
grep -A5 "context-warning" ~/.claude/settings.json
```

### El contexto no se restaura

**Solución**: Elimina manualmente el archivo y reinicia la sesión:

```bash
rm ~/.ralph/projects/*/state/glm-context.json
/clear
```

## 📚 Referencias

- **Arquitectura**: `ARCHITECTURE_DIAGRAM_v2.52.0.md`
- **Context Tracking**: `~/.claude/CONTEXT_TRACKING_v2.72.0.md`
- **Hooks**: `~/.claude/hooks/README.md`
- **Statusline**: `~/.claude/scripts/statusline-ralph.sh`

## 🎓 Conceptos Clave

### Project-Specific State (v2.72.0)

Cada proyecto tiene su propio directorio de estado:
```
~/.ralph/projects/<SHA256(git_root)>/state/
├── operation-counter
├── message_count
└── glm-context.json
```

### Thresholds de Advertencia

| Threshold | Porcentaje | Acción |
|-----------|------------|--------|
| Warning | 75% | Mostrar advertencia YELLOW |
| Critical | 85% | Mostrar advertencia CRITICAL RED |
| Auto-compact | ~90% | PreCompact hook guarda estado |

### Context Window

La ventana de contexto es la del modelo que ejecuta la sesión — el usuario lo elige con
`/model` o nombrándolo expresamente, y los subagentes lo heredan. El simulador lee el
tamaño de ventana del modelo activo (`.claude/lib/context-windows.sh`); no selecciona ni
sugiere ningún modelo.

---

**Versión**: 1.0.0
**Fecha**: 2026-01-26
**Parte de**: Multi-Agent Ralph Loop v2.69.1

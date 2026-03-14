# Contexto Visible en Zai - Configuración Específica v2.91.1

## Resumen

Se ha implementado una solución diferenciada para **Zai** que utiliza `systemMessage` para hacer visible el contexto en el chat, mientras que **Claude estándar** continúa con su configuración original.

## Configuración por Plataforma

### Claude Code Estándar (`~/.claude/settings.json`)

**Hook**: `session-start-context-visible.sh`

**Comportamiento**:
- Muestra el contexto completo vía stdout (visible en chat)
- Devuelve JSON con `additionalContext` (inyección silenciosa)

**Salida esperada al iniciar sesión**:
```markdown
## 📚 Contexto de Sesiones Anteriores
[... contexto completo ...]
💡 El contexto de arriba está disponible para Claude en esta sesión.
```

### Zai Cloud (`~/.cc-mirror/zai/config/settings.json`)

**Hook**: `session-start-context-zai.sh`

**Comportamiento**:
- Usa `systemMessage` para mostrar un resumen visible
- Usa `additionalContext` para inyección silenciosa del contexto completo

**Salida esperada al iniciar sesión**:
```markdown
## 📚 Contexto de Sesiones Anteriores

El contexto histórico de tu proyecto está disponible. Incluye:
- Loading: 50 observations
- Economía de tokens: Ahorro: ~35% de reducción

---

💡 **Para ver el contexto completo**, ejecuta:
./.claude/scripts/show-injected-context.sh
```

## Diferencia Clave: `systemMessage` vs `stdout`

| Aspecto | Claude Estándar | Zai |
|---------|----------------|-----|
| **Mecanismo visual** | stdout del hook | `systemMessage` en JSON |
| **Visibilidad** | Inmediata en chat | System reminder visible |
| **Contexto completo** | Visible en chat | En `additionalContext` + script |
| **Inyección silenciosa** | ✅ JSON output | ✅ `additionalContext` |

## Archivos de Hooks

| Hook | Plataforma | Propósito |
|------|-----------|-----------|
| `session-start-context-visible.sh` | Claude Estándar | Muestra contexto completo vía stdout |
| `session-start-context-zai.sh` | Zai Cloud | Usa `systemMessage` + inyección silenciosa |

## Por qué dos hooks diferentes?

Según la documentación de hooks de Zai (`~/.cc-mirror/zai/tweakcc/system-prompts/system-prompt-hooks-configuration.md`):

- **`systemMessage`**: "Display a message to the user in UI (all hooks)"
- **`additionalContext`**: "Text injected into model context"

Zai muestra el `systemMessage` como un **system reminder** visible, mientras que Claude estándar muestra el stdout directamente en el chat.

## Verificación

### Para Zai:
```bash
# Verificar que el hook correcto está configurado
grep "session-start-context-zai" ~/.cc-mirror/zai/config/settings.json

# Verificar logs
tail -20 ~/.ralph/logs/session-start-context-zai.log
```

### Para Claude Estándar:
```bash
# Verificar que el hook correcto está configurado
grep "session-start-context-visible" ~/.claude/settings.json

# Verificar logs
tail -20 ~/.ralph/logs/session-start-restore.log
```

## Troubleshooting

### Si no ves el contexto en Zai:

1. **Verifica que el hook se ejecutó**:
   ```bash
   tail -20 ~/.ralph/logs/session-start-context-zai.log
   ```

2. **Busca "system reminder"** en los system-reminders al inicio de la sesión

3. **Verifica la configuración**:
   ```bash
   jq '.hooks.SessionStart[] | select(.matcher == "*") | .hooks[2]' ~/.cc-mirror/zai/config/settings.json
   ```

### Si el contexto no se muestra en Claude estándar:

1. **Verifica que el hook se ejecutó**:
   ```bash
   tail -20 ~/.ralph/logs/session-start-restore.log
   ```

2. **Busca el contexto al inicio de la sesión** (debería aparecer antes de tu primer mensaje)

## Scripts de Ayuda

```bash
# Ver el contexto completo actual
./.claude/scripts/show-injected-context.sh

# Verificar el sistema completo
./.claude/scripts/verify-context-injection.sh
```

## Versión

- **Versión**: 2.91.1
- **Fecha**: 2026-03-05
- **Cambios**: Hook específico para Zai usando `systemMessage`

# StatusLine Fix Guide - v2.74.10

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

> **Fecha**: 2026-01-27
> **Versión**: 2.74.10
> **Autor**: Claude Code + Usuario

## Resumen Ejecutivo

Se corrigieron múltiples problemas con el statusline de Multi-Agent Ralph:

1. ✅ **Colores ANSI no funcionaban** - Los códigos de escape se mostraban literalmente
2. ✅ **Formato incorrecto de git info** - Se mostraba `git:(main*)` en lugar de `⎇ main*`
3. ✅ **Orden incorrecto de elementos** - Git info aparecía al final en lugar del principio
4. ✅ **Dobles separadores** - Se mostraban `│ │` por duplicado
5. ✅ **Barra de progreso en gris** - La barra de contexto usaba estilo DIM incorrecto

## Tabla de Contenidos

1. [Problemas Encontrados](#problemas-encontrados)
2. [Soluciones Implementadas](#soluciones-implementadas)
3. [Detalles Técnicos](#detalles-técnicos)
4. [Configuración Final](#configuración-final)
5. [Troubleshooting](#troubleshooting)

---

## Problemas Encontrados

### Problema 1: Colores ANSI No Funcionaban

**Síntoma:**
```
│ [glm-4.7] [2m█░░░░░░░░░[0m [0;36mctx:11%[0m |
```

Los códigos de escape ANSI como `[2m`, `[0m`, `[0;36m` se mostraban literalmente en lugar de interpretarse como colores.

**Causa Raíz:**
1. **Variables de color mal definidas**: Se usaba `$'\033[0;36m'` que no funciona correctamente en subshells creados por `bash -c`
2. **Configuración incorrecta**: Se agregó innecesariamente `"render": "ansi"` en settings.json
3. **Comando anidado**: Se usaba `bash -c 'bash script.sh'` creando múltiples niveles de shells

### Problema 2: Git Info en Formato Incorrecto

**Síntoma:**
```
[glm-4.7] ██████░░░░ ctx:66% │ ⏱️ 1% (~5h) │ 🔧 1% MCP (60/4000)
multi-agent-ralph-loop git:(main*)
```

La información de git aparecía al final con formato `git:(main*)` (estilo claude-hud) en lugar de `⎇ main*` (nuestro formato) al principio.

**Causa Raíz:**
1. **claude-hud no encontrado**: El script solo buscaba en `~/.claude/` y `~/.claude-sneakpeek/zai/config/`, pero claude-hud estaba en `~/.claude-code-old/`
2. **Lógica de detección**: El script evitaba duplicados cuando detectaba `git:(...)` en la salida de claude-hud

### Problema 3: Dobles Separadores

**Síntoma:**
```
│ [glm-4.7] ... | │ ⏱️ 1% ...
```

Aparecían dos barras separadoras `│ │` juntas.

**Causa Raíz:**
La variable `context_display` ya incluía `│` al principio y `|` al final, y luego se agregaba otro separador al combinar segmentos.

### Problema 4: Barra de Progreso en Gris

**Síntoma:**
La barra de progreso `██████░░░░` se mostraba en gris/diminuido.

**Causa Raíz:**
Se aplicaba el estilo `${DIM}` a la barra de progreso:
```bash
context_display="│ [${model_name}] ${DIM}${progress_bar}${RESET} ..."
```

---

## Soluciones Implementadas

### Solución 1: Funciones de Color con Command Substitution

**Antes (v2.74.6):**
```bash
CYAN=$'\033[0;36m'
GREEN=$'\033[0;32m'
```

**Después (v2.74.8+):**
```bash
# Functions that generate ANSI codes for subshell compatibility
ansi_cyan() { printf '\033[0;36m'; }
ansi_green() { printf '\033[0;32m'; }
ansi_yellow() { printf '\033[0;33m'; }
ansi_red() { printf '\033[0;31m'; }
ansi_magenta() { printf '\033[0;35m'; }
ansi_blue() { printf '\033[0;34m'; }
ansi_dim() { printf '\033[2m'; }
ansi_reset() { printf '\033[0m'; }

# Cache the codes as variables for convenience
CYAN=$(ansi_cyan)
GREEN=$(ansi_green)
YELLOW=$(ansi_yellow)
RED=$(ansi_red)
MAGENTA=$(ansi_magenta)
BLUE=$(ansi_blue)
DIM=$(ansi_dim)
RESET=$(ansi_reset)
```

**Por qué funciona:**
- `printf` interpreta las secuencias de escape en tiempo de ejecución
- El command substitution `$(...)` ejecuta la función y captura su salida
- Esto funciona a través de múltiples niveles de shells

### Solución 2: Uso Consistente de printf '%b\n'

**Antes:**
```bash
echo -e "$git_output"
echo -e "$progress_output"
echo -e "$fallback"
```

**Después:**
```bash
printf '%b\n' "$git_output"
printf '%b\n' "$progress_output"
printf '%b\n' "$fallback"
```

**Por qué funciona:**
- `printf '%b'` interpreta explícitamente secuencias de escape en backslash
- Más portable que `echo -e` que varía entre implementaciones
- Funciona correctamente cuando el script se ejecuta via settings.json

### Solución 3: Configuración Simplificada en settings.json

**Antes:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash -c 'bash /Users/alfredolopez/.../statusline-ralph.sh'",
    "render": "ansi"
  }
}
```

**Después:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/scripts/statusline-ralph.sh"
  }
}
```

**Cambios:**
1. ✅ Eliminado `bash -c '...'` - innecesario y causa problemas
2. ✅ Eliminado `"render": "ansi"` - no es necesario según docs oficiales
3. ✅ Ruta directa al script con `bash` explícito

**Nota:** Según la [documentación oficial de Claude Code](https://code.claude.com/docs/en/statusline):

> ANSI color codes are supported for styling your status line

No se requiere ninguna configuración especial para habilitar colores.

### Solución 4: Ruta de claude-hud Expandida

**Antes:**
```bash
claude_hud_dir=$(ls -td ~/.claude-sneakpeek/zai/config/plugins/cache/claude-hud/claude-hud/*/ ~/.claude/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | head -1)
```

**Después:**
```bash
claude_hud_dir=$(ls -td ~/.claude-sneakpeek/zai/config/plugins/cache/claude-hud/claude-hud/*/ ~/.claude/plugins/cache/claude-hud/claude-hud/*/ ~/.claude-code-old/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | head -1)
```

**Por qué:**
claude-hud estaba instalado en `~/.claude-code-old/` pero el script no buscaba allí.

### Solución 5: Git Info Siempre al Principio

**Antes (v2.74.5-2.74.9):**
```bash
# Detect if claude-hud already includes git info to avoid duplication
hud_has_git=$(echo "$hud_output" | grep -c "git:(" || echo "0")

# Add git_info FIRST (only if claude-hud doesn't have it)
if [[ "$hud_has_git" == "0" ]] && [[ -n "$git_info" ]]; then
    combined_segment="${git_info}"
fi
```

**Después (v2.74.10):**
```bash
# Filter out git:(...) lines from claude-hud to use our own format
hud_output=$(echo "$hud_output" | grep -v "git:(" || echo "$hud_output")

# Always use our git_info format (⎇ branch*) at the beginning
if [[ -n "$git_info" ]]; then
    combined_segment="${git_info}"
fi
```

**Por qué:**
- Queremos un formato consistente: `⎇ main*` en lugar de `git:(main*)`
- El git info debe estar siempre al principio del statusline
- Filtramos las líneas duplicadas de claude-hud

### Solución 6: Barra de Progreso Coloreada

**Antes:**
```bash
context_display="│ [${model_name}] ${DIM}${progress_bar}${RESET} ${context_color}ctx:${context_usage}%${RESET} |"
```

**Después:**
```bash
context_display="[${model_name}] ${context_color}${progress_bar}${RESET} ${context_color}ctx:${context_usage}%${RESET}"
```

**Cambios:**
1. ✅ Eliminado `${DIM}` de la barra - ahora usa `context_color`
2. ✅ Eliminado `│` inicial - se agrega al combinar segmentos
3. ✅ Eliminado `|` final - se agrega al combinar segmentos

---

## Detalles Técnicos

### Sistema de Colores

**Codificación de colores por uso de contexto:**

| Uso Contexto | Color | Código ANSI | Rango |
|--------------|-------|-------------|-------|
| Bajo (< 50%) | Cyan | `\033[0;36m` | 1-63K tokens |
| Medio (50-74%) | Verde | `\033[0;32m` | 64K-94K tokens |
| Alto (75-84%) | Amarillo | `\033[0;33m` | 96K-107K tokens |
| Crítico (≥85%) | Rojo | `\033[0;31m` | 108K-128K tokens |

**Códigos adicionales:**
- DIM (tenue): `\033[2m`
- RESET: `\033[0m`
- MAGENTA: `\033[0;35m` (para worktrees)
- BLUE: `\033[0;34m` (para iconos de progreso)

### Formato de la Barra de Progreso

**Algoritmo:**
```bash
# Cada bloque = 10%, 10 bloques totales
filled_blocks=$((context_usage / 10))  # 0-10
progress_bar=$(printf '█%.0s' $(seq 1 $filled_blocks))$(printf '░%.0s' $(seq 1 $((10 - filled_blocks))))
```

**Ejemplos:**
- 0%: `░░░░░░░░░░`
- 50%: `█████░░░░░`
- 100%: `██████████`

### Estructura del StatusLine

**Formato final (v2.74.10):**
```
⎇ branch* ↑2 │ [glm-4.7] ████████░░ ctx:69% │ ⏱️ 1% (~5h) │ 🔧 1% MCP (60/4000)
2 CLAUDE.md | 1 rules | 11 MCPs
```

**Componentes:**
1. **Git info**: `⎇ branch* ↑2` - branch, modificado, commits ahead
2. **Contexto**: `[glm-4.7] ████████░░ ctx:69%` - modelo, barra visual, porcentaje
3. **GLM Plan**: `⏱️ 1% (~5h)` - uso del plan de 5 horas
4. **GLM MCP**: `🔧 1% MCP (60/4000)` - uso mensual de MCP
5. **Línea 2**: Estadísticas de claude-hud (archivos, reglas, MCPs)

---

## Configuración Final

### settings.json

**Ubicación:** `~/.claude-sneakpeek/zai/config/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/scripts/statusline-ralph.sh"
  }
}
```

### Script: statusline-ralph.sh

**Ubicación:** `.claude/scripts/statusline-ralph.sh`

**Shebang:**
```bash
#!/bin/bash
```

**Permisos:**
```bash
chmod +x .claude/scripts/statusline-ralph.sh
```

---

## Troubleshooting

### Los colores no se muestran

**Verificar:**
1. ✅ Que el script use funciones de color con `printf`
2. ✅ Que todos los outputs usen `printf '%b\n'` o `echo -e`
3. ✅ Que NO haya `render: "ansi"` en settings.json

**Probar:**
```bash
echo '{"cwd":".","model":{"display_name":"glm-4.7"},"context_window":{"total_input_tokens":15000,"total_output_tokens":8000,"context_window_size":200000}}' | bash .claude/scripts/statusline-ralph.sh
```

### Git info no aparece o aparece en formato incorrecto

**Verificar:**
1. ✅ Que claude-hud esté instalado y el script lo encuentre
2. ✅ Que el filtro `grep -v "git:("` esté activo
3. ✅ Que `git_info` se agregue primero al `combined_segment`

**Probar:**
```bash
bash -c 'source .claude/scripts/statusline-ralph.sh && get_git_info .'
```

### Separadores dobles `│ │`

**Verificar:**
1. ✅ Que `context_display` no tenga `│` al principio
2. ✅ Que `context_display` no tenga `|` al final
3. ✅ Que los separadores se agreguen solo al combinar segmentos

### Barra de progreso en gris

**Verificar:**
1. ✅ Que la barra NO use `${DIM}`
2. ✅ Que la barra use `${context_color}` en su lugar

---

## Historial de Versiones

| Versión | Fecha | Cambios |
|---------|------|---------|
| 2.74.5 | 2026-01-27 | Reordenado: git info al principio |
| 2.74.6 | 2026-01-27 | Todos los outputs usan `printf '%b\n'` |
| 2.74.7 | 2026-01-27 | Intento con `\\033` (no funcionó) |
| 2.74.8 | 2026-01-27 | Funciones de color con command substitution |
| 2.74.9 | 2026-01-27 | Eliminado DIM de barra, eliminado `│` inicial |
| 2.74.10 | 2026-01-27 | **Solución final**: ruta claude-hud, git info siempre al principio |

---

## Referencias

- [Claude Code StatusLine Documentation](https://code.claude.com/docs/en/statusline)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [Bash printf Reference](https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#index-printf)

---

## Conclusión

Después de múltiples iteraciones, se logró un statusline completamente funcional con:

- ✅ Colores ANSI correctos
- ✅ Formato consistente de git info
- ✅ Orden lógico de elementos
- ✅ Sin separadores duplicados
- ✅ Barra de progreso coloreada según uso

**Estado Final**: ✅ COMPLETAMENTE FUNCIONAL

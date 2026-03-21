# Vault System Implementation Plan
## Sistema de Memoria Persistente con Obsidian + MCP + Session Learning Loop

**Version**: v1.1.0
**Date**: 2026-03-21
**Status**: AUDITED — Ready for Implementation
**Audit**: `.claude/plans/vault-system-audit-opus.md` (2026-03-21)
**Source research**: `docs/research/context-memory-mcp-jarvis.md`
**Scope**: Multi-agent-ralph-loop repo + global ~/.claude/ config

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Prerequisites & Dependencies](#3-prerequisites--dependencies)
4. [Phase 1: Vault Foundation](#4-phase-1-vault-foundation)
5. [Phase 2: /context Skill](#5-phase-2-context-skill)
6. [Phase 3: Session Accumulator Hook](#6-phase-3-session-accumulator-hook)
7. [Phase 4: /exit-review Skill](#7-phase-4-exit-review-skill)
8. [Phase 5: PreCompact Hook Extension](#8-phase-5-precompact-hook-extension)
9. [Phase 6: Knowledge Classification System](#9-phase-6-knowledge-classification-system)
10. [Phase 7: Security Isolation Layer](#10-phase-7-security-isolation-layer)
11. [Implementation Sequence](#11-implementation-sequence)
12. [Testing Strategy](#12-testing-strategy)
13. [File Reference Map](#13-file-reference-map)
14. [Acceptance Criteria Master List](#14-acceptance-criteria-master-list)
15. [Open Questions](#15-open-questions)

---

## 1. Executive Summary

### Problem

Claude Code es stateless por naturaleza. Cada sesión empieza desde cero — Claude no recuerda decisiones arquitectónicas, patrones aprendidos, preferencias del usuario, ni el contexto del trabajo anterior. Esto causa:

- Re-explicación repetitiva de contexto en cada sesión
- Pérdida de patrones y aprendizajes valiosos
- Inconsistencias entre sesiones (Claude comete errores ya resueltos)
- Falta de continuidad en proyectos de largo plazo

### Solución

Un sistema de memoria persistente de tres capas que convierte el filesystem local en una capa de memoria estructurada y segura:

```
GLOBAL OBSIDIAN VAULT          ~/.claude/ CONFIG         .claude/ PER-REPO
~/Obsidian/MiVault/            ~/.claude/skills/         .claude/vault/
─────────────────────          ─────────────────         ──────────────
Patrones cross-repo            /context skill            decisions/
Antipatrones del LLM           /exit-review skill        lessons/
Tool behaviors                 hooks de sesión           architecture.md
Preferencias del usuario       MCP config                current.md (scratch)
```

### Session Learning Loop

```
Sesión inicia → /context carga vault → trabajo → accumulator captura
→ sesión termina → /exit-review propone items → usuario aprueba
→ items GREEN van al vault global → items YELLOW al vault local
→ items RED se descartan → ciclo reinicia
```

### Alcance de este plan

Este plan cubre la implementación completa del sistema, estructurada en 7 fases independientes y ordenadas por dependencia. Cada fase tiene criterios de aceptación verificables.

---

## 2. Architecture Overview

### 2.1 Las Tres Capas

```
┌─────────────────────────────────────────────────────────────────────────┐
│  CAPA 1: VAULT GLOBAL (~/Documents/Obsidian/MiVault/)                   │
│  Propósito: Conocimiento cross-repo, patrones universales               │
│  Acceso: MCP filesystem server (read+write con clasificación)           │
│  Contenido: Patterns/, Antipatterns/, Workflow/, Tools/                 │
│  Owners: Solo Claude vía diálogo aprobado + usuario directamente        │
├─────────────────────────────────────────────────────────────────────────┤
│  CAPA 2: CONFIG GLOBAL (~/.claude/)                                      │
│  Propósito: Skills de ciclo de sesión, hooks globales                   │
│  Acceso: Directo (Claude Code native)                                   │
│  Contenido: /context, /exit-review skills, hooks de ciclo              │
│  Owners: Usuario + Claude (con confirmación)                            │
├─────────────────────────────────────────────────────────────────────────┤
│  CAPA 3: VAULT LOCAL (.claude/vault/ en cada repo)                      │
│  Propósito: Contexto específico del proyecto                            │
│  Acceso: MCP filesystem (path restringido al repo)                     │
│  Contenido: decisions/, lessons/, architecture.md, current.md          │
│  Owners: Solo Claude vía diálogo aprobado                               │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Flujo de Datos

```
LECTURA (inicio de sesión):
  /context skill
    ├── Lee: Vault global (_INDEX.md, Patterns/, preferences.md)
    ├── Lee: .claude/vault/architecture.md (contexto local)
    └── Lee: .claude/vault/decisions/ (últimas 7 decisiones)
    → Construye resumen de contexto en 500 tokens máximo

ESCRITURA (fin de sesión vía /exit-review):
  current.md (acumulador de sesión)
    → AskUserQuestion review
    → Clasificación GREEN/YELLOW/RED
    → GREEN → Vault global (sanitizado, sin contexto del proyecto)
    → YELLOW → .claude/vault/decisions/ (local)
    → RED → /dev/null (descartado, confirmado con nota)

ACUMULACIÓN (durante sesión, via hooks):
  PostToolUse hook (session-learning-accumulator.sh)
    → Detecta patrones significativos
    → Appends a .claude/vault/current.md
    → NO interrumpe el flujo de trabajo
```

### 2.3 Integración con el Sistema Existente

| Sistema Existente | Integración con Vault |
|-------------------|-----------------------|
| `pre-compact-handoff.sh` | Llama a session-accumulator antes de comprimir |
| `post-compact-restore.sh` | Lee current.md para restaurar contexto acumulado |
| `session-end-handoff.sh` | Trigger del /exit-review dialog |
| `claude-mem` MCP | Complementario: claude-mem para episodios, vault para patrones |
| `/autoresearch` skill | Sus mejores hallazgos van al vault como patrones GREEN |
| `orchestrator.md` agent | Lee vault al inicio de cada tarea compleja |

---

## 3. Prerequisites & Dependencies

### 3.1 Software Requerido

| Dependencia | Versión Min | Verificación | Instalación |
|-------------|-------------|--------------|-------------|
| Obsidian | 1.7.0+ | `ls ~/Applications/Obsidian.app` | https://obsidian.md |
| Claude Code | 1.0+ | `claude --version` | via npm |
| MCP filesystem server | — | `npx @modelcontextprotocol/server-filesystem --version` | `npm i -g @modelcontextprotocol/server-filesystem` |
| Node.js | 18+ | `node --version` | via nvm |
| jq | 1.6+ | `jq --version` | `brew install jq` |

### 3.2 Directorios Requeridos

```bash
# Verificar/crear antes de empezar:
VAULT_GLOBAL="$HOME/Documents/Obsidian/MiVault"
VAULT_LOCAL="$PWD/.claude/vault"
CLAUDE_GLOBAL="$HOME/.claude"

mkdir -p "$VAULT_GLOBAL/Patterns/Tools"
mkdir -p "$VAULT_GLOBAL/Patterns/Python"
mkdir -p "$VAULT_GLOBAL/Patterns/TypeScript"
mkdir -p "$VAULT_GLOBAL/Patterns/Git"
mkdir -p "$VAULT_GLOBAL/Patterns/Shell"
mkdir -p "$VAULT_GLOBAL/Antipatterns"
mkdir -p "$VAULT_GLOBAL/Workflow"
mkdir -p "$VAULT_GLOBAL/Tools"
mkdir -p "$VAULT_LOCAL/decisions"
mkdir -p "$VAULT_LOCAL/lessons"
mkdir -p "$VAULT_LOCAL/context"
```

### 3.3 Permisos MCP

El MCP filesystem server necesita acceso de lectura/escritura a ambas rutas. Ver sección 4.3 para la configuración canónica.

> **AUDIT FIX [B-01, B-03]**: La configuración MCP canónica está en sección 4.3. No se duplica aquí para evitar inconsistencias. El path de GitHub se restringe al repo específico (no al directorio padre) por seguridad.

### 3.4 .gitignore para Vault Local

```gitignore
# En cada repo que use vault local:
.claude/vault/current.md      # Scratch pad de sesión — nunca commitear
.claude/vault/lessons/        # Lessons pueden ser sensibles
# decisions/ puede commitearse si son arquitectónicas no-sensibles
```

---

## 4. Phase 1: Vault Foundation

**Objetivo**: Crear la estructura del vault global y local + configurar MCP.

**Duración estimada**: 2-3 horas
**Bloqueado por**: Nada (primera fase)
**Bloquea a**: Todas las demás fases

### 4.1 Estructura del Vault Global

Crear los siguientes archivos base:

#### `~/Documents/Obsidian/MiVault/_INDEX.md`
```markdown
# MiVault — Índice de Conocimiento Cross-Repo

> Vault de patrones, antipatrones y preferencias acumulados desde proyectos.
> Solo contiene conocimiento genérico — NUNCA datos de proyectos específicos.
> Actualizado automáticamente vía /exit-review con aprobación del usuario.

## Patrones Técnicos
- [[Patterns/Tools/claude-code]] — Comportamientos conocidos del LLM
- [[Patterns/Tools/whisper]] — Audio transcription patterns
- [[Patterns/Python/pip-isolation]] — Python environment management
- [[Patterns/Git/hook-patterns]] — Claude Code hook best practices

## Antipatrones
- [[Antipatterns/llm-assumptions]] — Lo que Claude asume incorrectamente
- [[Antipatterns/tool-gotchas]] — Errores silenciosos de herramientas

## Workflow
- [[Workflow/preferences]] — Preferencias del usuario
- [[Workflow/session-patterns]] — Patrones de sesión efectivos

## Metadatos
- Última actualización: (auto-updated)
- Total entradas: (auto-counted)
- Repos que contribuyen: multi-agent-ralph-loop, ...
```

#### `~/Documents/Obsidian/MiVault/Workflow/preferences.md`
```markdown
# Preferencias de Workflow del Usuario

## Git / Commits
- Siempre confirmar antes de `git push`
- Nunca usar `--no-verify` sin permiso explícito
- Commits en conventional commits format

## Comunicación
- Responder en español, código en inglés
- Insights educativos en formato backtick estrella
- Respuestas concisas salvo que sea tarea de planificación

## Confirmaciones
- Pedir confirmación antes de acciones destructivas
- Pedir confirmación antes de operaciones en sistemas compartidos
- Auto-aprobar operaciones locales reversibles

## Herramientas
- Preferir herramientas dedicadas sobre Bash (Read vs cat, Edit vs sed)
- Usar herramientas en paralelo cuando sean independientes

## Calidad
- 3-Fix Rule: máximo 3 intentos antes de escalar
- Quality gates antes de completar tareas
```

#### `~/Documents/Obsidian/MiVault/Antipatterns/llm-assumptions.md`
```markdown
---
tags: [antipattern, llm, claude-code]
source: multi-agent-ralph-loop
date: 2026-03-21
confidence: verified
---

# Antipatrones: Asunciones Incorrectas del LLM

## Claude Code — Comportamientos a Verificar

### npm test siempre existe
- **Asunción**: Claude asume `npm test` está configurado
- **Realidad**: Muchos repos no tienen script test definido
- **Fix**: Verificar package.json antes de ejecutar

### TypeScript: as cast seguro
- **Asunción**: Claude usa `as Type` libremente en boundaries de API
- **Realidad**: Enmascara errores en runtime
- **Fix**: Usar type guards o zod validation en boundaries

### pip install disponible globalmente
- **Asunción**: `pip install X` funciona en cualquier sistema
- **Realidad**: PEP 668 bloquea en sistemas modernos (macOS Homebrew, Ubuntu 23+)
- **Fix**: Siempre usar venv: `python3 -m venv /tmp/X-env && source .../activate`

## Agregar nuevas entradas via /exit-review (clasificación GREEN)
```

### 4.2 Estructura del Vault Local (por repo)

#### `.claude/vault/context/architecture.md` (template)
```markdown
# Arquitectura del Proyecto: [REPO_NAME]

## Stack
- Runtime:
- Framework:
- Testing:
- CI/CD:

## Estructura de Directorios
```
(actualizar al aprender el repo)
```

## Decisiones Arquitectónicas Clave
Ver: [[decisions/]]

## Configuración Especial
-

## Convenciones
- Commits: conventional commits
- Branches: feature/*, fix/*, docs/*
- Versioning: semver
```

#### `.claude/vault/current.md` (session scratch — auto-generado)
```markdown
# Session Accumulator — DO NOT COMMIT

**Session**: (auto-set por hook)
**Start**: (auto-set)
**Repo**: (auto-set)

## Aprendizajes Acumulados
<!-- El hook session-learning-accumulator.sh appends aquí -->

## Formato de entrada:
[TIMESTAMP] [GREEN|YELLOW|RED] [CATEGORY] "Descripción del aprendizaje"
Evidencia: (qué pasó que justifica esto)
```

### 4.3 MCP Config en settings.json

Agregar al `~/.claude/settings.json` existente:

```json
{
  "mcpServers": {
    "vault-filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/alfredolopez/Documents/Obsidian/MiVault",
        "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
      ],
      "env": {}
    }
  }
}
```

> **AUDIT FIX [B-01]**: Path restringido al repo específico (`multi-agent-ralph-loop`), NO al directorio padre (`Documents/GitHub`). Para soportar repos adicionales, agregar cada path explícitamente en el array de args.

> **AUDIT FIX [B-03]**: Flag `-y` es OBLIGATORIO para que npx no cuelgue esperando confirmación interactiva.

> **TODO [N-05]**: La referencia al skill `/update-config` fue removida (no existe). Agregar la config manualmente editando settings.json o crear el skill en una fase futura.

**Nota**: Agregar manualmente al archivo `~/.claude/settings.json` mergeando con la configuración existente.

### 4.4 Acceptance Criteria — Phase 1

- [ ] `~/Documents/Obsidian/MiVault/_INDEX.md` existe y es legible
- [ ] `~/Documents/Obsidian/MiVault/Workflow/preferences.md` existe con preferencias iniciales
- [ ] `~/Documents/Obsidian/MiVault/Antipatterns/llm-assumptions.md` existe con las 3 entradas
- [ ] `.claude/vault/context/architecture.md` existe en el repo (template relleno)
- [ ] MCP vault-filesystem registrado en settings.json
- [ ] `claude mcp list` muestra `vault-filesystem` como activo
- [ ] Claude puede leer `~/Documents/Obsidian/MiVault/_INDEX.md` via MCP tool call
- [ ] `.claude/vault/current.md` en .gitignore

---

## 5. Phase 2: /context Skill

**Objetivo**: Skill de carga de contexto manual que Claude ejecuta al inicio de sesión.

**Duración estimada**: 1-2 horas
**Bloqueado por**: Phase 1 (MCP debe estar configurado)

### 5.1 Arquitectura del Skill

El `/context` skill realiza una **carga paralela** de múltiples fuentes para construir el contexto completo en una sola invocación:

```
/context
    ├── [parallel] Lee: ~/Documents/Obsidian/MiVault/_INDEX.md
    ├── [parallel] Lee: ~/Documents/Obsidian/MiVault/Workflow/preferences.md
    ├── [parallel] Lee: .claude/vault/context/architecture.md
    ├── [parallel] Lee: .claude/vault/decisions/ (últimas 5, por mtime)
    ├── [parallel] Lee: .claude/vault/current.md (si existe — sesión anterior interrumpida)
    └── Sintetiza → resumen de 400-600 tokens máximo
```

### 5.2 Contenido del SKILL.md

Crear: `~/.claude/skills/context/SKILL.md`

```markdown
# /context — Vault Context Loader

Load persistent memory from vault into current session context.

## Usage
/context              # Load full context (recommended at session start)
/context --light      # Load preferences only (quick sessions)
/context --local      # Load local vault only (no global)
/context --global     # Load global vault only

## What it loads (in parallel)

### Always loaded:
- Global vault: `_INDEX.md` → What knowledge exists
- Global vault: `Workflow/preferences.md` → How user works
- Local vault: `context/architecture.md` → This repo's structure

### When available:
- Local vault: `decisions/` → Last 5 architectural decisions (by date)
- Local vault: `current.md` → Interrupted session state (if exists)

### Conditional (--full flag):
- Global vault: `Patterns/**/*.md` → All known patterns
- Global vault: `Antipatterns/**/*.md` → All known antipatterns

## Output format

After loading, produce a structured context summary:

```
CONTEXT LOADED:
├── Preferences: [N items]
├── Architecture: [repo name, stack summary]
├── Recent decisions: [N, last: YYYY-MM-DD]
├── Active patterns: [N known]
├── Interrupted session: [YES/NO]
└── Key reminders: [top 3 most relevant items]
```

## When to invoke

- Always at session start before complex tasks
- After /compact (context restored but vault not reloaded)
- When user says "recuerda" or "contexto" or "¿qué sabemos de?"

## Security

- Read-only operation — no writes
- Does not expose RED-classified content (never in vault)
- Summarizes rather than dumps raw content
```

### 5.3 Symlinks a Crear

```bash
SKILL_NAME="context"
REPO="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"

# Crear skill en repo primero
mkdir -p "$REPO/.claude/skills/context"
# (escribir SKILL.md aquí)

# Symlinks a las 6 plataformas
for dir in ~/.claude/skills ~/.codex/skills ~/.ralph/skills \
           ~/.cc-mirror/zai/config/skills ~/.cc-mirror/minimax/config/skills \
           ~/.config/agents/skills; do
  mkdir -p "$dir"
  ln -sfn "$REPO/.claude/skills/$SKILL_NAME" "$dir/$SKILL_NAME"
done
```

### 5.4 Acceptance Criteria — Phase 2

- [ ] `~/.claude/skills/context/SKILL.md` existe (via symlink al repo)
- [ ] `/context` se puede invocar desde Claude Code sin error
- [ ] Carga en paralelo los archivos (verificar con timing < 2s total)
- [ ] Output sigue el formato estructurado definido
- [ ] `--light`, `--local`, `--global` flags funcionan correctamente
- [ ] Si `current.md` existe, se avisa al usuario de sesión interrumpida
- [ ] No escribe nada (read-only verificado)

---

## 6. Phase 3: Session Accumulator Hook

**Objetivo**: Hook que acumula silenciosamente aprendizajes durante la sesión sin interrumpir el flujo de trabajo.

**Duración estimada**: 2-3 horas
**Bloqueado por**: Phase 1

### 6.1 Arquitectura del Hook

```
PostToolUse hook: session-learning-accumulator.sh
    │
    ├── Se activa después de: Bash, Edit, Write (tools relevantes)
    ├── Lee: $CLAUDE_TOOL_RESULT (resultado del tool)
    ├── Detecta: patrones significativos (errores resueltos, workarounds)
    └── Append a: .claude/vault/current.md
```

**Criterio de activación** (para no spamear el archivo):
- Solo si el tool falló y luego tuvo un fix exitoso (error → solución)
- Solo si Claude usó un approach inusual o un workaround
- Solo si se instaló/configuró algo nuevo
- NO para operaciones rutinarias (reads, edits triviales)

### 6.2 Implementación del Hook

Crear: `.claude/hooks/session-learning-accumulator.sh`

```bash
#!/usr/bin/env bash
# session-learning-accumulator.sh
# Accumulates session learnings to .claude/vault/current.md
# Triggered: PostToolUse (Bash, Edit, Write)
# EXIT 0 always — never blocks tool execution

set -euo pipefail

# --- Config ---
VAULT_LOCAL="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/vault"
CURRENT_FILE="$VAULT_LOCAL/current.md"
LOG_FILE="$HOME/.ralph/logs/accumulator.log"

# --- Guards ---
# Only run if in a git repo with vault
[[ ! -d "$VAULT_LOCAL" ]] && exit 0

# Read stdin (Claude Code passes tool result as JSON)
TOOL_INPUT=$(cat)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
TOOL_RESULT=$(echo "$TOOL_INPUT" | jq -r '.tool_result // ""' 2>/dev/null || echo "")

# Only process relevant tools
case "$TOOL_NAME" in
  Bash|Edit|Write) ;;  # Continue
  *) exit 0 ;;          # Skip other tools
esac

# --- AUDIT FIX [B-06]: RED check FIRST, before any pattern detection ---
# Check for secrets in tool content before writing anything
if printf '%s %s' "$TOOL_INPUT" "$TOOL_RESULT" | \
   grep -qiE "(api[_-]?key|secret[_-]?key|auth[_-]?token|bearer |password|private[_-]?key|access[_-]?token|sk-[a-zA-Z0-9]+|ghp_[a-zA-Z0-9]+|AKIA[0-9A-Z]{16}|eyJ[a-zA-Z0-9]|xox[baprs]-|sk_live_|sk_test_|sk-ant-|-----BEGIN.*PRIVATE KEY|mongodb://|postgres://)" 2>/dev/null; then
  # Silent discard — do NOT log the content
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] RED_DISCARDED: Secret pattern detected" >> "$LOG_FILE"
  exit 0
fi

# --- Pattern Detection ---
LEARNING_DETECTED=false
LEARNING_TEXT=""
LEARNING_TIER="YELLOW"  # Default

# Detect: Error followed by successful fix (common pattern)
if printf '%s' "$TOOL_RESULT" | grep -qiE "(error|failed|not found|exception)" 2>/dev/null; then
  LEARNING_DETECTED=true
  LEARNING_TEXT="Error encountered: $(printf '%s' "$TOOL_RESULT" | head -3 | tr '\n' ' ')"
  LEARNING_TIER="YELLOW"
fi

# Detect: Installation/configuration (likely a workaround)
if printf '%s' "$TOOL_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null | \
   grep -qiE "(pip install|npm install|brew install|venv|workaround)" 2>/dev/null; then
  LEARNING_DETECTED=true
  CMD=$(printf '%s' "$TOOL_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null | head -1)
  LEARNING_TEXT="Installation/setup: $CMD"
  LEARNING_TIER="GREEN"  # Installation patterns are cross-repo
fi

[[ "$LEARNING_DETECTED" != "true" ]] && exit 0

# --- Initialize current.md if needed ---
if [[ ! -f "$CURRENT_FILE" ]]; then
  SESSION_ID=$(date -u +%Y%m%d-%H%M%S)
  REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
  mkdir -p "$VAULT_LOCAL"
  cat > "$CURRENT_FILE" << EOF
# Session Accumulator — DO NOT COMMIT

**Session**: $SESSION_ID
**Start**: $(date -u +%Y-%m-%dT%H:%M:%SZ)
**Repo**: $REPO_NAME

## Aprendizajes Acumulados

EOF
fi

# Feature flag guard (FIX I-10): disable accumulator without editing the hook
RALPH_VAULT_ACCUMULATOR="${RALPH_VAULT_ACCUMULATOR:-true}"
[[ "$RALPH_VAULT_ACCUMULATOR" != "true" ]] && exit 0

# --- Append learning with flock for concurrent-session safety (FIX I-05/CONC-01) ---
# Agent Teams can spawn multiple teammates writing to same repo — flock prevents interleave
TIMESTAMP=$(date -u +%H:%M:%S)
LOCK_FILE="${CURRENT_FILE}.lock"
(
  flock -w 2 200 || {
    printf '[%s] WARN: flock timeout on current.md, skipping write\n' "$TIMESTAMP" >> "$LOG_FILE"
    exit 0
  }
  printf '[%s] [%s] %s\n' "$TIMESTAMP" "$LEARNING_TIER" "$LEARNING_TEXT" >> "$CURRENT_FILE"
) 200>"$LOCK_FILE"

exit 0
```

### 6.3 Registro en settings.json

> **AUDIT FIX [I-07]**: This hook must be added AFTER sanitize-secrets.js in the PostToolUse array so that sanitized (redacted) output is what gets classified. Do NOT replace existing PostToolUse hooks; append this entry to the existing array.

> **TODO [I-10]**: Wrap accumulator logic in feature flag `RALPH_VAULT_ACCUMULATOR=true` in `~/.ralph/config/features.json` for easy enable/disable, consistent with existing hooks.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/session-learning-accumulator.sh"
          }
        ]
      }
    ]
  }
}
```

### 6.4 Acceptance Criteria — Phase 3

- [ ] Hook no bloquea ninguna operación (siempre exit 0)
- [ ] `current.md` se crea automáticamente la primera vez que se detecta un aprendizaje
- [ ] Patrones RED no se escriben en ningún archivo (verificar con `grep -i secret current.md`)
- [ ] Instalaciones/workarounds se clasifican como GREEN automáticamente
- [ ] Errores se clasifican como YELLOW por defecto
- [ ] Log en `~/.ralph/logs/accumulator.log` sin contenido sensible
- [ ] Timing: hook completa en < 100ms (verificar con `time` wrapper)

---

## 7. Phase 4: /exit-review Skill

**Objetivo**: Skill que al final de sesión presenta los aprendizajes acumulados, permite clasificarlos y escribe al vault correcto con aprobación del usuario.

**Duración estimada**: 3-4 horas
**Bloqueado por**: Phases 1, 3, 6 (classifier y sanitizer son dependencias — FIX B-02)

### 7.1 Implementation Mechanism

> **AUDIT FIX [I-04]**: The /exit-review skill is a SKILL.md (instruction set for Claude), not an executable script. Claude performs these steps using MCP filesystem tools and Bash when invoked. Claude reads current.md via Read tool, pipes each item through vault-classifier.sh via Bash, applies sanitize-for-global.sh to GREEN items via Bash, then presents AskUserQuestion.

> **TODO [I-09]**: claude-mem integration in step 2 uses `mcp__plugin_claude-mem_mcp-search__get_observations` with a 24h time filter. If claude-mem is unavailable, skip gracefully.

### 7.2 Flujo del Diálogo

```
/exit-review
    │
    ├── 1. Lee current.md
    ├── 2. También lee claude-mem (observaciones recientes)
    ├── 3. Pre-clasifica cada item (GREEN/YELLOW/RED)
    ├── 4. Sanitiza items GREEN (elimina contexto del proyecto)
    ├── 5. AskUserQuestion por lotes (no item por item)
    │       Formato: lista numerada con clasificación propuesta
    │       Usuario responde: "1,3,5" para aprobar esos, "todo" o "nada"
    ├── 6. Escribe aprobados:
    │       GREEN → ~/Obsidian/MiVault/[categoria]/[archivo].md
    │       YELLOW → .claude/vault/decisions/YYYY-MM-DD.md
    ├── 7. Limpia current.md (o lo archiva con timestamp)
    └── 8. Confirma: "X items guardados en vault global, Y locales, Z descartados"
```

### 7.2 Contenido del SKILL.md

Crear: `.claude/skills/exit-review/SKILL.md`

```markdown
# /exit-review — Session Learning Consolidation

Review and persist session learnings to the vault with user approval.

## Usage
/exit-review           # Full review with classification dialog
/exit-review --quick   # Auto-approve GREEN items, only ask for YELLOW
/exit-review --skip    # Clear current.md without saving anything

## Process

### Step 1: Collect
Read .claude/vault/current.md + recent claude-mem observations.
Also include any patterns Claude identified during the session.

### Step 2: Pre-classify
Apply classification rules (see Knowledge Classification System):
- GREEN: Generic, project-agnostic, shareable patterns
- YELLOW: Project-specific, stays local
- RED: Auto-discard, never shown to user (contains sensitive data)

### Step 3: Sanitize GREEN items
Remove all project-specific context:
- Replace repo name with [REPO]
- Remove absolute paths
- Remove client/company names
- Keep only the generalizable pattern

### Step 4: Present to user (AskUserQuestion)
Show numbered list. User selects which to approve.

### Step 5: Write approved items
- GREEN → Append to appropriate ~/Obsidian/MiVault/ file
- YELLOW → Append to .claude/vault/decisions/YYYY-MM-DD.md

### Step 6: Cleanup
Archive current.md to .claude/vault/sessions/YYYY-MM-DD-HH.md
Clear current.md for next session.

## Output format after saving

Summary:
- Saved to global vault: N items (in [categories])
- Saved locally: N items (in decisions/)
- Auto-discarded (RED): N items [no content shown]
- User skipped: N items

## Classification Rules (Quick Reference)

GREEN if: no project names, no file paths, no credentials,
          reproducible in any project, describes tool behavior

YELLOW if: mentions this repo/project, specific to our setup,
           architectural decision with our context

RED if: contains API_KEY/SECRET/TOKEN/PASSWORD,
        contains client names, contains business logic,
        contains security vulnerabilities not yet fixed
```

### 7.3 Formato del Diálogo AskUserQuestion

```
REVISION DE SESION — [REPO] — [FECHA]

Encontré N aprendizajes para revisar:

GREEN (global vault — shareable):
  1. [Tools/whisper] "Audio-only MP4s rejected by Zai MCP — need black
     video stream via ffmpeg for compatibility"
  2. [Python/pip] "PEP 668 blocks system pip — always use venv isolation
     for tool installation on macOS/Ubuntu 23+"

YELLOW (local — solo este repo):
  3. [decision] "autoresearch output moved from docs/prd to .claude/plans
     for better separation from user-facing docs"

AUTO-DESCARTADOS (RED — no se muestra contenido):
  → 1 item con patrón sensible detectado. Descartado.

¿Qué items aprobar? (ej: "1,2" o "todo" o "nada" o "1,3 + editar 2")
```

### 7.4 Acceptance Criteria — Phase 4

- [ ] `/exit-review` sin args presenta diálogo completo
- [ ] Items RED nunca aparecen en el diálogo (verificado con grep)
- [ ] Items GREEN se sanitizan antes de mostrar (no contienen nombre del repo)
- [ ] AskUserQuestion se invoca una sola vez (no por cada item)
- [ ] Usuario puede responder "todo", "nada", o lista de números
- [ ] Escritura al vault global solo ocurre con aprobación explícita
- [ ] current.md se limpia/archiva tras el review
- [ ] Summary final muestra conteo por categoría
- [ ] `--quick` aprueba GREEN automáticamente sin diálogo
- [ ] `--skip` limpia sin guardar

### 7.6 Symlinks para /exit-review

> **AUDIT FIX [I-08]**: Symlink creation was missing for /exit-review skill.

```bash
SKILL_NAME="exit-review"
REPO="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"

# Symlinks to all 6 platforms
for dir in ~/.claude/skills ~/.codex/skills ~/.ralph/skills \
           ~/.cc-mirror/zai/config/skills ~/.cc-mirror/minimax/config/skills \
           ~/.config/agents/skills; do
  mkdir -p "$dir"
  ln -sfn "$REPO/.claude/skills/$SKILL_NAME" "$dir/$SKILL_NAME"
done
```

---

## 8. Phase 5: PreCompact Hook Extension

**Objetivo**: Extender el hook `pre-compact-handoff.sh` existente para activar el review de aprendizajes antes de comprimir el contexto.

**Duración estimada**: 1-2 horas
**Bloqueado por**: Phases 3, 4

### 8.1 Problema a Resolver

Cuando Claude comprime el contexto (`/compact`), la ventana de contexto anterior desaparece. Si no se hizo `/exit-review`, los aprendizajes de esa sesión se pierden. El `PreCompact` hook es la red de seguridad.

### 8.2 Modificación al Hook Existente

El hook `pre-compact-handoff.sh` ya existe. Insertar BEFORE line 238 (`log "INFO" "PreCompact hook completed successfully"`), NOT at the very end (stdout after the JSON output would never execute):

> **AUDIT FIX [I-06]**: The notice must go to the log file (not stdout, which is reserved for JSON). Claude reads hook output via the JSON response, so embed in log and rely on CLAUDE.md instruction.

```bash
# === VAULT LEARNING CONSOLIDATION ===
# Trigger mini-review before compaction to preserve learnings

VAULT_LOCAL="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/vault"
CURRENT_FILE="$VAULT_LOCAL/current.md"

if [[ -f "$CURRENT_FILE" ]] && [[ -s "$CURRENT_FILE" ]]; then
  LEARNING_COUNT=$(grep -c "^\[" "$CURRENT_FILE" 2>/dev/null || echo 0)
  if [[ "$LEARNING_COUNT" -gt 0 ]]; then
    # FIX I-06/INT-01: NEVER use echo/printf to stdout in PreCompact hooks.
    # stdout is consumed as the JSON response {"continue": true}.
    # Extra stdout output corrupts the JSON and breaks compaction.
    # Use the existing log() function (writes to logfile/stderr):
    log "INFO" "VAULT_COMPACT_NOTICE: $LEARNING_COUNT learnings pending in current.md"
    log "INFO" "Run /exit-review before or after compaction to persist them."
    # Claude will see this via SessionStart(compact) additionalContext output
  fi
fi
```

**Importante**: Los hooks no pueden usar AskUserQuestion directamente. Claude ve la salida del hook en el `additionalContext` del `SessionStart(compact)` y decide si invocar `/exit-review`.

### 8.3 Instrucción en CLAUDE.md Global

Agregar a `~/.claude/CLAUDE.md`:

```markdown
## Vault Learning — PreCompact Rule

When you see `VAULT_COMPACT_NOTICE` in PreCompact hook output:
1. ALWAYS ask user: "¿Quieres revisar los aprendizajes antes de comprimir?"
2. If yes → run /exit-review BEFORE compaction completes
3. If no → proceed with compaction (learnings in current.md survive)
```

### 8.4 Acceptance Criteria — Phase 5

- [ ] PreCompact hook detecta current.md con contenido
- [ ] Muestra conteo de aprendizajes pendientes
- [ ] No bloquea la compresión (no causa error)
- [ ] Claude interpreta VAULT_COMPACT_NOTICE y pregunta al usuario
- [ ] Si usuario dice sí, /exit-review se ejecuta antes del compaction

---

## 9. Phase 6: Knowledge Classification System

**Objetivo**: Implementar el sistema formal de clasificación GREEN/YELLOW/RED con reglas automáticas y sanitización.

**Duración estimada**: 2-3 horas
**Bloqueado por**: Phase 1 (FIX B-02 — Phase 6 precede a Phase 4, no al revés)

### 9.1 Clasificador (clasificacion.sh)

Crear: `.claude/hooks/vault-classifier.sh`

```bash
#!/usr/bin/env bash
# vault-classifier.sh
# Classifies a learning text as GREEN/YELLOW/RED
# Usage: echo "text" | vault-classifier.sh
# Output: GREEN, YELLOW, or RED on stdout

set -euo pipefail

TEXT=$(cat)

# --- RED patterns (auto-discard, highest priority) ---
# AUDIT FIX [B-04]: Aligned with sanitize-secrets.js (20+ patterns)
# AUDIT FIX [B-05]: Removed IP regex (high false-positive on version numbers)
RED_PATTERNS=(
  # Generic credential patterns
  "api[_-]?key"
  "secret[_-]?key"
  "auth[_-]?token"
  "bearer[ ]"
  "password"
  "private[_-]?key"
  "access[_-]?token"
  # Provider-specific key formats (from sanitize-secrets.js)
  "sk-[a-zA-Z0-9]{20,}"       # OpenAI key format
  "sk-ant-[a-zA-Z0-9-]{20,}"  # Anthropic key format
  "sk-proj-[a-zA-Z0-9-]{20,}" # OpenAI project key
  "ghp_[a-zA-Z0-9]{36,}"      # GitHub PAT format
  "github_pat_[a-zA-Z0-9_]{22,}" # GitHub fine-grained PAT
  "AKIA[0-9A-Z]{16}"          # AWS access key
  "aws_secret_access_key"     # AWS secret
  "eyJ[a-zA-Z0-9-_]+\.eyJ"   # JWT tokens
  "xox[baprs]-[a-zA-Z0-9-]+" # Slack tokens
  "sk_live_[a-zA-Z0-9]+"     # Stripe live keys
  "sk_test_[a-zA-Z0-9]+"     # Stripe test keys
  "SG\.[a-zA-Z0-9-_]+"       # SendGrid keys
  "-----BEGIN.*PRIVATE KEY"   # SSH/TLS private keys
  "mongodb://[^[:space:]]+"   # DB connection strings
  "postgres://[^[:space:]]+"  # DB connection strings
  "mysql://[^[:space:]]+"     # DB connection strings
  "redis://[^[:space:]]+"     # DB connection strings
  # AWS infrastructure
  "[a-z0-9]+\.amazonaws\.com" # AWS hostnames
  # PII patterns
  "client[_-]?name"
  "customer[_-]?name"
  "company[_-]?name"
  # Crypto
  "mnemonic|seed.phrase"      # Seed phrases
)

# AUDIT FIX [I-03]: Use printf instead of echo throughout
for pattern in "${RED_PATTERNS[@]}"; do
  if printf '%s' "$TEXT" | grep -qiE "$pattern" 2>/dev/null; then
    printf 'RED\n'
    exit 0
  fi
done

# --- YELLOW patterns (project-specific) ---
YELLOW_PATTERNS=(
  "/Users/[a-zA-Z]+"         # Absolute paths with username
  "ralph.loop"
  "multi.agent"
  "this repo"
  "este repo"
  "our project"
  "nuestro proyecto"
)

for pattern in "${YELLOW_PATTERNS[@]}"; do
  if printf '%s' "$TEXT" | grep -qiE "$pattern" 2>/dev/null; then
    printf 'YELLOW\n'
    exit 0
  fi
done

# --- Default: GREEN ---
printf 'GREEN\n'
exit 0
```

### 9.2 Sanitizador para GREEN (sanitize-for-global.sh)

```bash
#!/usr/bin/env bash
# sanitize-for-global.sh
# Sanitizes text before writing to global vault
# Removes project-specific context while preserving the pattern
# Usage: echo "text" | sanitize-for-global.sh
# Location: .claude/scripts/sanitize-for-global.sh (utility, not a hook)

set -euo pipefail

TEXT=$(cat)

# Get repo name for replacement
REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "REPO")
USERNAME=$(whoami)

# AUDIT FIX [B-07]: Escape sed metacharacters in variables to prevent injection
sed_escape() { printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'; }
SAFE_REPO=$(sed_escape "$REPO_NAME")
SAFE_USER=$(sed_escape "$USERNAME")

# AUDIT FIX [I-03]: Use printf instead of echo to avoid escape sequence issues
# Apply sanitizations
printf '%s\n' "$TEXT" \
  | sed "s|$SAFE_REPO|[REPO]|gi" \
  | sed "s|/Users/$SAFE_USER/[^ ]*|[PATH]|g" \
  | sed "s|$SAFE_USER|[USER]|g" \
  | sed 's|this repo|any project|gi' \
  | sed 's|nuestro repo|cualquier proyecto|gi' \
  | sed 's|our project|any project|gi'
```

> **TODO [I-11]**: This file should live at `.claude/scripts/sanitize-for-global.sh` (utility, not a hook). Update File Reference Map accordingly.

### 9.3 Reglas de Categorización por Contenido

| Patrón en el texto | Categoría sugerida | Archivo destino |
|--------------------|--------------------|-----------------|
| "Whisper", "ffmpeg", "audio" | GREEN | `Patterns/Tools/audio-processing.md` |
| "pip", "venv", "Python" | GREEN | `Patterns/Python/environment.md` |
| "TypeScript", "type", "interface" | GREEN | `Patterns/TypeScript/type-safety.md` |
| "hook", "PostToolUse", "PreCompact" | GREEN | `Patterns/Git/hook-patterns.md` |
| "Claude assume", "LLM", "modelo" | GREEN | `Antipatterns/llm-assumptions.md` |
| "decision", "arquitectura", "diseño" | YELLOW | `decisions/YYYY-MM-DD.md` |
| "configuración de este", "setting" | YELLOW | `decisions/YYYY-MM-DD.md` |

### 9.4 Acceptance Criteria — Phase 6

- [ ] `vault-classifier.sh` clasifica correctamente (tests unitarios)
- [ ] Texto con "api_key" → RED (verificado)
- [ ] Texto con repo name → YELLOW (verificado)
- [ ] Texto de patrón genérico → GREEN (verificado)
- [ ] `sanitize-for-global.sh` elimina username y paths
- [ ] Sanitizado no cambia el significado técnico del aprendizaje
- [ ] Tests: `tests/vault/test-classifier.sh` con 20+ casos de prueba

---

## 10. Phase 7: Security Isolation Layer

**Objetivo**: Garantizar que datos sensibles NUNCA lleguen al vault global bajo ninguna circunstancia.

**Duración estimada**: 2-3 horas
**Bloqueado por**: Phase 6

### 10.1 Defense in Depth

El sistema tiene 4 capas de protección contra fugas de datos sensibles:

```
CAPA 1: Session Accumulator Hook
  → Detecta patrones RED durante la sesión
  → Descarta ANTES de escribir a current.md

CAPA 2: /exit-review Classifier
  → Re-clasifica todo en current.md antes de mostrarlo
  → Items RED nunca aparecen en el diálogo

CAPA 3: Sanitizador pre-escritura
  → Aplica sanitization a todos los items GREEN
  → Elimina contexto de proyecto antes de escribir al vault global

CAPA 4: Audit log
  → Registra qué fue descartado (sin contenido sensible)
  → Permite auditoría de qué se guardó y qué no
```

### 10.2 Audit Log Format

```bash
# ~/.ralph/logs/vault-audit.log
# Formato: [timestamp] [action] [tier] [category] [hash_of_content]
# NUNCA se guarda el contenido sensible — solo el hash

[2026-03-21T10:30:00Z] DISCARDED RED secrets-pattern sha256:abc123...
[2026-03-21T10:31:00Z] SAVED GREEN tools/whisper sha256:def456...
[2026-03-21T10:31:00Z] SAVED YELLOW decisions/2026-03-21 sha256:ghi789...
[2026-03-21T10:32:00Z] SKIPPED YELLOW user-declined sha256:jkl012...
```

**Nota de privacidad**: El audit log guarda el hash del contenido (para verificar integridad) pero NUNCA el contenido en sí.

### 10.3 .gitignore Rules

```gitignore
# Añadir a .gitignore del repo:

# Vault - sensitive session data
.claude/vault/current.md
.claude/vault/sessions/
.claude/vault/lessons/

# Vault audit logs (stay local)
~/.ralph/logs/vault-audit.log

# Vault decisions may be committed (non-sensitive arch decisions)
# .claude/vault/decisions/ → commiteable con revisión manual
```

### 10.4 Validación de Seguridad

Script: `tests/vault/test-security-isolation.sh`

```bash
#!/usr/bin/env bash
# Tests that sensitive data never reaches global vault

# Test 1: API key never written
echo "api_key=sk-test-12345" | vault-classifier.sh | grep -q "RED"
echo "Test 1 (API key → RED): PASS"

# Test 2: Client name never written
echo "This is for ClienteCorp project" | vault-classifier.sh | grep -q "RED"
echo "Test 2 (Client name → RED): PASS"

# Test 3: Generic pattern classified GREEN
echo "Whisper fails with audio-only MP4 files" | vault-classifier.sh | grep -q "GREEN"
echo "Test 3 (Generic → GREEN): PASS"

# Test 4: Sanitizer removes username
echo "/Users/alfredolopez/Documents/test" | sanitize-for-global.sh | grep -qv "alfredolopez"
echo "Test 4 (Username sanitized): PASS"

# Test 5: Vault global files never contain RED patterns
if grep -rqiE "(api_key|secret|token|password)" \
   ~/Documents/Obsidian/MiVault/ 2>/dev/null; then
  echo "Test 5 (No secrets in global vault): FAIL"
  exit 1
fi
echo "Test 5 (No secrets in global vault): PASS"
```

### 10.5 Filesystem Permissions (N-01/Q7)

Ejecutar al final de Phase 7 para establecer permisos restrictivos:

```bash
# Vault local — solo owner
chmod 700 .claude/vault/
chmod 600 .claude/vault/decisions/*.md 2>/dev/null || true
chmod 600 .claude/vault/lessons/*.md 2>/dev/null || true

# Audit log — privado (N-01)
touch ~/.ralph/logs/vault-audit.log
chmod 600 ~/.ralph/logs/vault-audit.log

# Hash index — privado
touch ~/Documents/Obsidian/MiVault/.hashes
chmod 600 ~/Documents/Obsidian/MiVault/.hashes
```

### 10.6 Acceptance Criteria — Phase 7

- [ ] `tests/vault/test-security-isolation.sh` pasa todos los tests
- [ ] Vault global no contiene ningún patrón RED (verificado con grep)
- [ ] Audit log existe y registra descartados con hash, sin contenido
- [ ] `~/.ralph/logs/vault-audit.log` tiene permisos 0600 (N-01)
- [ ] `.claude/vault/` tiene permisos 700 (solo owner)
- [ ] `~/Documents/Obsidian/MiVault/.hashes` existe con permisos 0600
- [ ] .gitignore configurado correctamente en el repo
- [ ] Proceso de sanitización verificado manualmente en 5 casos reales
- [ ] Items GREEN en vault incluyen YAML frontmatter con tags/source/date (N-02)
- [ ] Dedup: segundo write del mismo item no crea duplicado en vault (N-04)

---

## 11. Implementation Sequence

### Orden Recomendado

```
Week 1: Foundation
  Day 1-2: Phase 1 (Vault structure + MCP config)
  Day 3-4: Phase 2 (/context skill)
  Day 5: Test Phase 1+2 together

Week 2: Classification & Accumulation
  Day 1-2: Phase 3 (Session accumulator hook)
  Day 3-4: Phase 6 (Classification system) [AUDIT FIX B-02: moved before Phase 4]
  Day 5: Test Phases 1-3, 6 together

Week 3: Review, Safety & Automation
  Day 1-3: Phase 4 (/exit-review skill) [now has classifier + sanitizer available]
  Day 4: Phase 5 (PreCompact hook extension)
  Day 5: Phase 7 (Security isolation + tests) + Full integration test
```

### Diagrama de Dependencias

> **AUDIT FIX [B-02]**: Phase 6 (Classification) must precede Phase 4 (/exit-review)
> because /exit-review depends on vault-classifier.sh and sanitize-for-global.sh.

```
Phase 1 (Vault Foundation)
    ├── Phase 2 (/context skill)
    ├── Phase 3 (Accumulator hook)
    └── Phase 6 (Classification system)
            └── Phase 4 (/exit-review) [depends on: Phase 1, 3, 6]
                    └── Phase 5 (PreCompact extension)
            └── Phase 7 (Security isolation)
```

### Rollout por Entorno

| Entorno | Cuándo | Cómo |
|---------|--------|------|
| Local dev (este repo) | Desde Phase 1 | Testear directamente |
| Global `~/.claude/` | Desde Phase 2 | Skills via symlinks |
| Otros repos | Después de Phase 7 | Copiar `.claude/vault/` template |

---

## 12. Testing Strategy

### 12.1 Tests por Fase

| Fase | Archivo de Test | Tipo |
|------|----------------|------|
| 1 | `tests/vault/test-vault-foundation.sh` | Smoke + structure |
| 2 | `tests/vault/test-context-skill.sh` | Functional |
| 3 | `tests/vault/test-accumulator.sh` | Unit + timing |
| 4 | `tests/vault/test-exit-review.sh` | Integration |
| 5 | `tests/vault/test-precompact.sh` | Hook behavior |
| 6 | `tests/vault/test-classifier.sh` | Unit (20+ cases) |
| 7 | `tests/vault/test-security-isolation.sh` | Security |

### 12.2 Test de Integración End-to-End

```bash
# tests/vault/test-e2e.sh
# Simula una sesión completa:
# 1. Inicializa current.md con 5 items (2 GREEN, 2 YELLOW, 1 RED)
# 2. Ejecuta el classifier sobre cada uno
# 3. Verifica clasificaciones correctas
# 4. Ejecuta sanitizador sobre GREEN items
# 5. Simula escritura al vault (modo dry-run)
# 6. Verifica que RED no llega a ningún archivo
# 7. Verifica que GREEN no contiene contexto del proyecto
# 8. Verifica que YELLOW va al directorio correcto
```

### 12.3 Privacy Test (Crítico)

```bash
# Verificar que el vault global nunca tiene info sensible
# Ejecutar después de cada sesión de prueba:

VAULT="$HOME/Documents/Obsidian/MiVault"
SENSITIVE_PATTERNS=(
  "api_key" "secret" "password" "token" "bearer"
  "alfredolopez" "ralph.loop" "multi.agent"
  "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
  if grep -rqiE "$pattern" "$VAULT" 2>/dev/null; then
    echo "PRIVACY FAIL: Pattern '$pattern' found in global vault"
    exit 1
  fi
done
echo "Privacy test: PASS — no sensitive patterns in global vault"
```

---

## 13. File Reference Map

### Archivos a Crear

| Archivo | Tipo | Fase |
|---------|------|------|
| `~/Obsidian/MiVault/_INDEX.md` | Vault global | 1 |
| `~/Obsidian/MiVault/Workflow/preferences.md` | Vault global | 1 |
| `~/Obsidian/MiVault/Antipatterns/llm-assumptions.md` | Vault global | 1 |
| `~/Obsidian/MiVault/Antipatterns/tool-gotchas.md` | Vault global | 1 |
| `.claude/vault/context/architecture.md` | Vault local | 1 |
| `.claude/skills/context/SKILL.md` | Skill | 2 |
| `.claude/hooks/session-learning-accumulator.sh` | Hook | 3 |
| `.claude/skills/exit-review/SKILL.md` | Skill | 4 |
| `.claude/hooks/vault-classifier.sh` | Utility | 6 |
| `.claude/hooks/sanitize-for-global.sh` | Utility | 6 |
| `tests/vault/test-classifier.sh` | Tests | 6 |
| `tests/vault/test-security-isolation.sh` | Tests | 7 |
| `tests/vault/test-e2e.sh` | Tests | 7 |

### Archivos a Modificar

| Archivo | Modificación | Fase |
|---------|--------------|------|
| `~/.claude/settings.json` | Agregar MCP vault-filesystem | 1 |
| `~/.claude/settings.json` | Agregar hook accumulator | 3 |
| `.claude/hooks/pre-compact-handoff.sh` | Agregar vault notice | 5 |
| `.gitignore` | Agregar .claude/vault/current.md | 1 |
| `CLAUDE.md` | Agregar vault rules y /context usage | 2 |
| `README.md` | Documentar vault system | 7 |

### Symlinks a Crear (Phase 2)

```bash
# context skill → 6 plataformas
~/.claude/skills/context → repo/.claude/skills/context
~/.codex/skills/context → repo/.claude/skills/context
~/.ralph/skills/context → repo/.claude/skills/context
# (+ 3 más)

# exit-review skill → 6 plataformas
# (misma estructura)
```

---

## 14. Acceptance Criteria Master List

### Sistema Completo — Criterios de Aceptación

**Funcionalidad Core:**
- [ ] `/context` carga vault en < 3 segundos al inicio de sesión
- [ ] Accumulator detecta y categoriza patrones durante sesión
- [ ] `/exit-review` presenta diálogo estructurado al final
- [ ] Usuario puede aprobar/rechazar items individualmente o en lote
- [ ] Items aprobados llegan al vault correcto (global vs local)
- [ ] current.md se limpia tras cada review exitoso

**Seguridad:**
- [ ] Items RED nunca aparecen en ningún diálogo
- [ ] Items RED nunca se escriben a ningún archivo
- [ ] Items GREEN son sanitizados antes de escribir al vault global
- [ ] Vault global no contiene nombres de repos, users, o paths absolutos
- [ ] Audit log registra acciones sin revelar contenido sensible
- [ ] Test suite de seguridad pasa 100%

**Continuidad:**
- [ ] PreCompact hook advierte de aprendizajes pendientes
- [ ] /context detecta sesión interrumpida (current.md con contenido)
- [ ] Compaction no borra current.md
- [ ] Múltiples repos pueden usar el mismo vault global

**Integración:**
- [ ] Compatible con sistema claude-mem existente (complementario)
- [ ] Compatible con pre-compact-handoff.sh existente
- [ ] Compatible con orchestrator.md agent
- [ ] Skills distribuidos via symlinks a las 6 plataformas

---

## 15. Open Questions

Resolved during Opus architecture audit. Full rationale in `.claude/plans/vault-system-audit-opus.md`.

1. **Vault global en git?** -- **RESOLVED: NO.** Use iCloud/Dropbox sync (Obsidian native). Git adds friction. For extra backup, add a weekly cron tar job.

2. **Granularidad del accumulator?** -- **RESOLVED: Keep conservative for v1.** Only errors + installations. Feature flag `RALPH_VAULT_ACCUMULATOR_EXTENDED=false` for future expansion.

3. **Formato de items en vault global?** -- **RESOLVED: Markdown with YAML frontmatter.** Enables Obsidian Dataview queries. Use `tags`, `source`, `date`, `confidence` fields.

4. **Retencion de sesiones archivadas?** -- **RESOLVED: 30-day retention.** Aligns with existing episodic cleanup in session-end-handoff.sh. Add similar cleanup for `.claude/vault/sessions/`.

5. **Multi-repo vault sharing?** -- **RESOLVED: SHA-256 dedup at write time.** Maintain `~/Documents/Obsidian/MiVault/.hashes` index. Skip write if hash exists.

6. **claude-mem integration?** -- **RESOLVED: Keep separate for v1.** claude-mem = ephemeral observations; vault = curated patterns. Consider `/consolidate` bridge skill in v2.

7. **Vault encryption?** -- **RESOLVED: No encryption for v1.** YELLOW items are decisions, not secrets. Use `chmod 700 .claude/vault/` for access control.

### Additional Questions (identified by audit)

8. **PreCompact hookSpecificOutput support?** -- Verify whether PreCompact hooks support `hookSpecificOutput.additionalContext`. If not, vault notice is log-only + CLAUDE.md instruction.

9. **Existing /context skill collision?** -- No collision found (verified). Consider `/vault-context` if future Claude Code built-in uses the name.

10. **sanitize-for-global.sh location?** -- Should live in `.claude/scripts/` (utility) not `.claude/hooks/`. Update File Reference Map.

---

*Plan generated: 2026-03-21 | Source: docs/research/context-memory-mcp-jarvis.md*
*Audited: 2026-03-21 | Auditor: Claude Opus | Report: .claude/plans/vault-system-audit-opus.md*
*Status: AUDITED -- Ready for Implementation (7 BLOCKING fixes applied, 11 IMPORTANT noted as TODOs)*

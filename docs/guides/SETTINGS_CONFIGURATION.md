# Guía de Configuración de Settings.json

## Tabla de Contenidos
- [Versión](#versión)
- [Descripción](#descripción)
- [Ubicación](#ubicación)
- [Estructura](#estructura)
  - [1. version](#1-version)
  - [2. permissions](#2-permissions)
  - [3. hooks](#3-hooks)
    - [UserPromptSubmit (8 hooks)](#userpromptsubmit-8-hooks)
    - [PreToolUse (25+ hooks)](#pretooluse-25-hooks)
    - [PostToolUse (35+ hooks)](#posttooluse-35-hooks)
    - [PreCompact (3 hooks)](#precompact-3-hooks)
    - [SessionStart (8 hooks)](#sessionstart-8-hooks)
    - [Stop (5 hooks)](#stop-5-hooks)
  - [4. env](#4-env)
- [Personalización](#personalización)
  - [Añadir un hook personalizado](#añadir-un-hook-personalizado)
  - [Cambiar modo de permisos](#cambiar-modo-de-permisos)
- [Troubleshooting](#troubleshooting)
  - [Los hooks no se ejecutan](#los-hooks-no-se-ejecutan)
  - [Errores de JSON](#errores-de-json)
- [Referencias](#referencias)

## Versión

**v2.82.0** - Multi-Agent Ralph Wiggum

## Descripción

Este documento describe la configuración de Claude Code para el sistema Multi-Agent Ralph.

## Ubicación

El archivo settings.json debe ubicarse en:
- macOS/Linux: `~/.claude/settings.json`
- Windows: `%USERPROFILE%\.claude\settings.json`

## Estructura

### 1. version

Versión del sistema Ralph.

```json
"version": "2.82.0"
```

### 2. permissions

Configuración de permisos de Claude Code.

| Campo | Tipo | Descripción |
|-------|------|-------------|
| defaultMode | string | "delegate" o "suggest" |
| allow.edit | boolean | Permitir edición de archivos |
| allow.bash | boolean | Permitir comandos bash |
| allow.write | boolean | Permitir escritura de archivos |
| allow.read | boolean | Permitir lectura de archivos |

### 3. hooks

Sistema de hooks automatizados por evento.

#### UserPromptSubmit (8 hooks)

Se ejecutan al enviar un prompt.

| Hook | Función |
|------|---------|
| command-router.sh | Detecta intención y sugiere comandos |
| context-warning.sh | Alerta de uso de contexto (75%, 85%) |

#### PreToolUse (25+ hooks)

Se ejecutan antes de usar una herramienta.

| Hook | Matcher | Función |
|------|---------|---------|
| smart-memory-search.sh | Task | Búsqueda paralela en memoria |
| agent-memory-auto-init.sh | Task | Inicialización de memoria de agente |
| lsa-pre-step.sh | Edit/Write | Verificación de arquitectura |
| checkpoint-smart-save.sh | Edit/Write | Guardado inteligente de checkpoints |
| pre-commit-command-validation.sh | Bash | Validación de comandos bash |

#### PostToolUse (35+ hooks)

Se ejecutan después de usar una herramienta.

| Hook | Matcher | Función |
|------|---------|---------|
| plan-sync-post-step.sh | Edit/Write | Sincronización de plan-state |
| decision-extractor.sh | Edit/Write | Extracción de decisiones arquitectónicas |
| semantic-realtime-extractor.sh | Edit/Write | Extracción semántica en tiempo real |
| status-auto-check.sh | Edit/Write | Verificación de estado automática |
| post-commit-command-verify.sh | Bash | Verificación post-comando bash |

#### PreCompact (3 hooks)

Se ejecutan antes de compactar contexto.

| Hook | Función |
|------|---------|
| pre-compact-handoff.sh | Guarda estado antes de compactación |

#### SessionStart (8 hooks)

Se ejecutan al iniciar sesión.

| Hook | Función |
|------|---------|
| session-start-ledger.sh | Carga ledger de sesión |
| session-start-restore-context.sh | Restaura contexto post-compactación |

#### Stop (5 hooks)

Se ejecutan al terminar sesión.

| Hook | Función |
|------|---------|
| sentry-report.sh | Envía reporte a Sentry |
| reflection-engine.sh | Genera resumen de reflexión |

### 4. env

Variables de entorno para agentes.

| Variable | Valor | Descripción |
|----------|-------|-------------|
| CLAUDE_CODE_AGENT_ID | ralph-primary | ID del agente |
| CLAUDE_CODE_AGENT_NAME | RalphWiggum | Nombre del agente |
| CLAUDE_CODE_TEAM_NAME | multi-agent-ralph | Nombre del equipo |
| CLAUDE_CODE_PLAN_MODE_REQUIRED | false | Auto-aprobar planes |
| CLAUDE_CODE_MAX_AGENT_ITERATIONS | 50 | Máximo de iteraciones |
| RALPH_VERSION | 2.82.0 | Versión de Ralph |
| RALPH_MODEL_PRIMARY | glm-4.7 | Modelo primario |
| RALPH_MODEL_FALLBACK | claude-sonnet | Modelo fallback |

## Personalización

### Añadir un hook personalizado

```json
{
  "matcher": "Task",
  "hooks": [
    { 
      "type": "command", 
      "command": "$HOME/.ralph/.claude/hooks/mi-hook.sh" 
    }
  ]
}
```

### Cambiar modo de permisos

```json
{
  "permissions": {
    "defaultMode": "suggest"
  }
}
```

## Troubleshooting

### Los hooks no se ejecutan

1. Verificar permisos: `chmod +x ~/.ralph/.claude/hooks/*.sh`
2. Verificar rutas: Usar `$HOME` en lugar de `~`
3. Revisar logs: `~/.ralph/logs/`

### Errores de JSON

Validar con: `jq . ~/.claude/settings.json`

## Referencias

- [AGENTS.md](../../AGENTS.md) - Referencia de agentes
- [CHANGELOG.md](../../CHANGELOG.md) - Historial de cambios

# GLM Usage Tracking v2.73.0 - Implementation Complete

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

## Overview

Sistema completo de tracking de uso para Z.AI GLM Coding Plan integrado en la statusline de Ralph.

## Características

### 1. Tracking de 5-Hour Token Quota
- **Endpoint**: `/api/monitor/usage/quota/limit`
- **Datos**: Porcentaje de uso en ventana de 5 horas
- **Display**: `⏱️ 3% (~5h)` en verde (<75%), amarillo (≥75%), rojo (≥85%)

### 2. Tracking de Monthly MCP Usage
- **Datos**: Web searches + readers usados por mes
- **Límite**: Varía por plan (Lite: 100, Pro: 1000, Max: 4000)
- **Display**: `🔧 1% MCP (60/4000)` en cyan (<75%), amarillo (≥75%)

### 3. Caching Inteligente
- **TTL**: 5 minutos entre actualizaciones
- **Rate Limit**: 30 segundos entre actualizaciones (hook)
- **Auto-refresh**: Se actualiza después de llamadas a la API

## Archivos Implementados

### 1. `~/.ralph/scripts/glm-usage-cache-manager.sh`

Script principal que:
- Llama al script `query-usage.mjs` existente
- Parsea la respuesta JSON del API
- Crea archivo cache en `~/.ralph/cache/glm-usage-cache.json`
- Formatea output para statusline

**Comandos**:
```bash
~/.ralph/scripts/glm-usage-cache-manager.sh refresh    # Actualizar cache
~/.ralph/scripts/glm-usage-cache-manager.sh get-statusline  # Output para statusline
~/.ralph/scripts/glm-usage-cache-manager.sh show          # Mostrar info detallada
```

### 2. `~/.claude/hooks/glm-usage-cache-updater.sh`

Hook que se ejecuta después de usar herramientas Bash/Edit/Write:
- Verifica si la herramienta podría llamar a la API de GLM
- Rate-limited a 30 segundos entre actualizaciones
- Actualiza cache en background (no bloquea)

### 3. `~/.claude/scripts/statusline-ralph.sh` (modificado)

Agregada función `get_glm_plan_usage()` que:
- Lee del cache manager
- Formatea con colores apropiados
- Se integra con el resto de la statusline

## Statusline Final

```
⎇ main* │ 🤖 14% · 18K/128K │ ⏱️ 3% (~5h) │ 🔧 1% MCP (60/4000) │ ⚡ 2/8 25% Main Execution
└────────┘ └──────────────────┘ └────────└────────┘ └────────┘ └──────────────┘ └────────────────┘
 Contexto   5-Hour        MCP        Ralph
Local      Quota          Quota      Progress
```

## Datos Actuales (2026-01-27)

- **5-Hour Token Quota**: 3% usado (muy bajo, excelente!)
- **Monthly MCP**: 1% usado (60/4000 búsquedas web)
- **Plan**: Max (4000 búsquedas web mensuales)

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Statusline Display                         │
│  ⏱️ 3% (~5h) │ 🔧 1% MCP (60/4000)                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────┴─────────────────────────────────────────┐
│                   glm-usage-cache-manager.sh                     │
│  - Lee cache │ - Formatea │ - Auto-refresh cada 5min    │
└─────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────┴─────────────────────────────────────────┐
│              glm-usage-cache-updater.sh (Hook)                   │
│  - Trigger: PostToolUse                                            │
│  - Rate limit: 30 segundos                                       │
│  - Actualiza: ~/.ralph/cache/glm-usage-cache.json              │
└─────────────────────────────┴─────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────┴─────────────────────────────────────────┐
│                   query-usage.mjs (EXISTENTE)                      │
│  - Endpoint: /api/monitor/usage/quota/limit                        │
│  - Devuelve: TOKENS_LIMIT + TIME_LIMIT                                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Testing

```bash
# Test manual de actualización
~/.ralph/scripts/glm-usage-cache-manager.sh refresh

# Ver cache
cat ~/.ralph/cache/glm-usage-cache.json | jq '.'

# Test statusline
echo '{"cwd": "."}' | bash ~/.claude/scripts/statusline-ralph.sh
```

## Próximos Pasos (Opcional)

1. **Hook Registration**: El hook `glm-usage-cache-updater.sh` ya está configurado en settings.json
2. **CLI Commands**: Podríamos agregar comandos `ralph usage` al script ralph
3. **Warning Hooks**: Podríamos agregar warnings cuando se excede el 75%

## Troubleshooting

Si la statusline no muestra el uso del plan:
1. Verificar que `~/.ralph/cache/glm-usage-cache.json` existe
2. Ejecutar `~/.ralph/scripts/glm-usage-cache-manager.sh refresh` manualmente
3. Revisar permisos: `ls -la ~/.ralph/scripts/glm-usage-cache-manager.sh`

## Referencias

- Z.AI GLM Coding Plan FAQ: https://docs.z.ai/devpack/faq
- OpenCode PR #6298: https://github.com/sst/opencode/pull/6298
- Documentación de comparación: `docs/LLM_USAGE_TRACKING_COMPARISON.md`
- Plan de implementación: `docs/IMPLEMENTATION_PLAN_v2.73.0.md`

---

**Versión**: 2.73.0
**Fecha**: 2026-01-27
**Estado**: ✅ Implementado y funcionando

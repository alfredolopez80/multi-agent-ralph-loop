# Complete Hooks Reference

**Versión:** 2.82.0  
**Última actualización:** Enero 2026

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Memory Management Hooks (12)](#1-memory-management-hooks-12)
3. [Auto-Learning Hooks (5)](#2-auto-learning-hooks-5)
4. [Plan State Hooks (6)](#3-plan-state-hooks-6)
5. [Context & Session Hooks (12)](#4-context--session-hooks-12)
6. [Orchestration Hooks (10)](#5-orchestration-hooks-10)
7. [Checkpointing Hooks (4)](#6-checkpointing-hooks-4)
8. [Security Hooks (6)](#7-security-hooks-6)
9. [Sentry/Observability Hooks (4)](#8-sentryobservability-hooks-4)
10. [Skills Hooks (3)](#9-skills-hooks-3)
11. [Logging & Analysis Hooks (15)](#10-logging--analysis-hooks-15)
12. [Hooks v2.82.0 - Nuevos](#hooks-v2820---nuevos)
13. [Referencias](#referencias)

---

## Resumen Ejecutivo

| Categoría | Cantidad | Estado |
|-----------|----------|--------|
| Memory Management | 12 | ✅ Activo |
| Auto-Learning | 5 | ✅ Activo |
| Plan State | 6 | ✅ Activo |
| Context & Session | 12 | ✅ Activo |
| Orchestration | 10 | ✅ Activo |
| Checkpointing | 4 | ✅ Activo |
| Security | 6 | ✅ Activo |
| Sentry/Observability | 4 | ✅ Activo |
| Skills | 3 | ✅ Activo |
| Logging & Analysis | 15 | ✅ Activo |
| **Total** | **~100** | ✅ **Activo** |

---

## 1. Memory Management Hooks (12)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| smart-memory-search | PreToolUse (Task) | Búsqueda paralela en memoria antes de orquestación | `smart-memory-search.sh` |
| memory-write-trigger | UserPromptSubmit | Detectar frases "remember" e inyectar contexto | `memory-write-trigger.sh` |
| decision-extractor | PostToolUse (Edit/Write) | Extraer decisiones arquitectónicas | `decision-extractor.sh` |
| semantic-realtime-extractor | PostToolUse (Edit/Write) | Extracción semántica en tiempo real | `semantic-realtime-extractor.sh` |
| procedural-inject | PreToolUse (Task) | Inyectar reglas procedurales aprendidas | `procedural-inject.sh` |
| agent-memory-auto-init | PreToolUse (Task) | Auto-inicializar buffers de memoria de agente | `agent-memory-auto-init.sh` |
| semantic-auto-extractor | Stop | Extraer hechos semánticos de la sesión | `semantic-auto-extractor.sh` |
| episodic-auto-convert | Stop | Convertir automáticamente episódico a procedural | `episodic-auto-convert.sh` |
| semantic-write-helper | PostToolUse | Helper para escritura de memoria semántica | `semantic-write-helper.sh` |

---

## 2. Auto-Learning Hooks (5)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| orchestrator-auto-learn | PreToolUse | Detectar brechas de conocimiento, recomendar curator | `orchestrator-auto-learn.sh` |
| curator-suggestion | UserPromptSubmit | Sugerir curator cuando la memoria está vacía | `curator-suggestion.sh` |
| curator-trigger | Manual | Trigger curator para repos de calidad | `curator-trigger.sh` |
| continuous-learning | PostToolUse | Aprendizaje continuo de patrones | `continuous-learning.sh` |

---

## 3. Plan State Hooks (6)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| auto-migrate-plan-state | SessionStart | Migrar automáticamente esquemas de plan-state | `auto-migrate-plan-state.sh` |
| plan-state-adaptive | PostToolUse | Actualizaciones adaptativas de plan-state | `plan-state-adaptive.sh` |
| plan-state-lifecycle | Multiple | Gestionar ciclo de vida de plan-state | `plan-state-lifecycle.sh` |
| plan-analysis-cleanup | PostToolUse (Task) | Limpieza después de análisis de plan | `plan-analysis-cleanup.sh` |
| todo-plan-sync | PostToolUse (TodoWrite) | Sincronizar todos con progreso de plan-state | `todo-plan-sync.sh` |

---

## 4. Context & Session Hooks (12)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| context-warning | UserPromptSubmit | Monitorear uso de contexto (75%/85% umbrales) | `context-warning.sh` |
| auto-save-context | Interval | Auto-guardar contexto de sesión | `auto-save-context.sh` |
| auto-sync-global | PostToolUse | Sincronizar estado de proyecto con global | `auto-sync-global.sh` |
| pre-compact-handoff | PreCompact | Guardar estado antes de compactación | `pre-compact-handoff.sh` |
| post-compact-restore | SessionStart | Restaurar estado después de compactación | `session-start-restore-context.sh` |
| session-start-ledger | SessionStart | Auto-cargar ledger al inicio | `session-start-ledger.sh` |
| session-start-tldr | SessionStart | Generar resumen TLDR de sesión | `session-start-tldr.sh` |
| session-start-welcome | SessionStart | Mostrar mensaje de bienvenida | `session-start-welcome.sh` |
| inject-session-context | PreToolUse | Inyectar contexto de sesión en prompts | `inject-session-context.sh` |
| context-injector | PreToolUse | Inyección adicional de contexto | `context-injector.sh` |
| unified-context-tracker | PostToolUse | Tracking unificado de contexto | `unified-context-tracker.sh` |

---

## 5. Orchestration Hooks (10)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| orchestrator-init | CLI | Inicializar sesión de orquestador | `orchestrator-init.sh` |
| orchestrator-report | Stop | Generar reporte de orquestador | `orchestrator-report.sh` |
| orchestrator-helper | Multiple | Funciones helper para orquestador | `orchestrator-helper.sh` |
| progress-tracker | PostToolUse | Trackear progreso de implementación | `progress-tracker.sh` |
| task-primitive-sync | PostToolUse | Sincronizar tareas primitivas | `task-primitive-sync.sh` |
| task-project-tracker | PostToolUse | Tracker de tareas de proyecto | `task-project-tracker.sh` |
| task-orchestration-optimizer | PreToolUse | Optimizar orquestación de tareas | `task-orchestration-optimizer.sh` |
| parallel-explore | PostToolUse | Lanzar 5 tareas de exploración concurrentes | `parallel-explore.sh` |
| recursive-decompose | PostToolUse | Trigger sub-orquestadores para tareas complejas | `recursive-decompose.sh` |
| fast-path-check | PreToolUse | Detectar tareas triviales para FAST_PATH routing | `fast-path-check.sh` |

---

## 6. Checkpointing Hooks (4)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| checkpoint-auto-save | PostToolUse | Auto-guardar checkpoint en ediciones | `checkpoint-auto-save.sh` |
| checkpoint-smart-save | PreToolUse | Smart checkpoints en ediciones riesgosas | `checkpoint-smart-save.sh` |
| checkpoint-* (comandos) | CLI | Gestión de checkpoints (save/restore/list/clear) | `commands/checkpoint-*.md` |

---

## 7. Security Hooks (6)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| sec-context-validate | PostToolUse (Edit/Write) | Validación de contexto de seguridad | `sec-context-validate.sh` |
| pre-commit-command-validation | PreToolUse (Bash) | Validar comandos pre-commit | `pre-commit-command-validation.sh` |
| post-commit-command-verify | PostToolUse (Bash) | Verificar comandos post-commit | `post-commit-command-verify.sh` |
| detect-environment | Multiple | Detección de entorno (CLI/VSCode/Cursor) | `detect-environment.sh` |
| security-full-audit | PostToolUse | Auditoría de seguridad completa | `security-full-audit.sh` |
| security-real-audit | PostToolUse | Auditoría de seguridad en tiempo real | `security-real-audit.sh` |

---

## 8. Sentry/Observability Hooks (4)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| sentry-report | Stop | Enviar reporte de sesión a Sentry | `sentry-report.sh` |
| sentry-correlation | Multiple | Mantener contexto de correlación Sentry | `sentry-correlation.sh` |
| sentry-check-status | Interval | Verificar estado de Sentry | `sentry-check-status.sh` |

---

## 9. Skills Hooks (3)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| skill-pre-warm | SessionStart | Pre-calentar caché de skills | `skill-pre-warm.sh` |
| skill-validator | PreToolUse | Validar inputs de skills | `skill-validator.sh` |

---

## 10. Logging & Analysis Hooks (15)

| Hook | Trigger | Propósito | Archivo |
|------|---------|-----------|---------|
| prompt-analyzer | UserPromptSubmit | Analizar prompts de usuario | `prompt-analyzer.sh` |
| status-auto-check | PostToolUse | Auto-verificar estado cada 5 operaciones | `status-auto-check.sh` |
| statusline-health-monitor | UserPromptSubmit | Monitoreo de salud cada 5 minutos | `statusline-health-monitor.sh` |
| periodic-reminder | Interval | Recordatorios periódicos de tareas | `periodic-reminder.sh` |
| state-sync | Interval | Sincronizar estado entre componentes | `state-sync.sh` |
| stop-verification | Stop | Verificar estado de sesión al terminar | `stop-verification.sh` |
| reflection-engine | Stop | Generar resumen de reflexión | `reflection-engine.sh` |
| adversarial-auto-trigger | PostToolUse | Auto-trigger validación adversarial | `adversarial-auto-trigger.sh` |
| auto-plan-state | PostToolUse | Auto-crear plan-state.json | `auto-plan-state.sh` |
| lsa-pre-step | PreToolUse (Edit/Write) | Verificación LSA antes de implementación | `lsa-pre-step.sh` |
| plan-sync-post-step | PostToolUse (Edit/Write) | Detección de drift después de implementación | `plan-sync-post-step.sh` |
| auto-format-prettier | PostToolUse | Auto-formateo con Prettier | `auto-format-prettier.sh` |
| console-log-detector | PostToolUse | Detectar console.log en código | `console-log-detector.sh` |
| deslop-auto-clean | PostToolUse | Limpieza automática de slop | `deslop-auto-clean.sh` |
| typescript-quick-check | PreToolUse | Check rápido de TypeScript | `typescript-quick-check.sh` |
| verification-subagent | PostToolUse | Subagente de verificación | `verification-subagent.sh` |
| glm-context-tracker | PostToolUse | Tracking de contexto GLM | `glm-context-tracker.sh` |
| glm-context-update | PostToolUse | Actualización de contexto GLM | `glm-context-update.sh` |
| glm-visual-validation | PostToolUse | Validación visual GLM | `glm-visual-validation.sh` |
| global-task-sync | PostToolUse | Sincronización global de tareas | `global-task-sync.sh` |

---

## Hooks v2.82.0 - Nuevos

| Hook | Evento | Descripción |
|------|--------|-------------|
| **command-router.sh** | UserPromptSubmit | 🆕 Routing inteligente de comandos basado en intención del usuario. Soporta 9 comandos con detección multilenguaje (ES/EN). Confidence ≥ 80%. |

---

## Referencias

- [AGENTS.md](../../AGENTS.md) - Referencia principal de agentes
- [settings.json.example](../../.claude/settings.json.example) - Configuración de hooks
- [Hook Testing Patterns](../../tests/HOOK_TESTING_PATTERNS.md) - Patrones de testing

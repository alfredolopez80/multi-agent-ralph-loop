# Multi-Agent-Ralph

![Versión](https://img.shields.io/badge/version-2.49.1-blue)
![Licencia](https://img.shields.io/badge/license-BSL%201.1-orange)
![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-purple)

> "Me fail English? That's unpossible!" - Ralph Wiggum

---

## Descripción General

**Multi-Agent-Ralph** es un sistema de orquestación sofisticado para Claude Code y OpenCode que coordina múltiples modelos de IA para entregar código validado de alta calidad mediante ciclos de refinación iterativa.

El sistema aborda el desafío fundamental de la programación asistida por IA: **asegurar calidad y consistencia en tareas complejas**. En lugar de confiar en la salida de un solo modelo de IA, Ralph orquesta múltiples agentes especializados trabajando en paralelo, con puertas de validación automáticas y debates adversarials para requisitos rigurosos.

### Lo Que Hace

- **Orquesta Múltiples Modelos de IA**: Coordina Claude (Opus/Sonnet), OpenAI Codex, Google Gemini, y MiniMax en flujos de trabajo paralelos
- **Refinación Iterativa**: Implementa el patrón "Ralph Loop" - ejecutar, validar, iterar hasta que las puertas de calidad pasen
- **Aseguramiento de Calidad**: Puertas de calidad en 9 lenguajes (TypeScript, Python, Go, Rust, Solidity, Swift, JSON, YAML, JavaScript)
- **Refinamiento de Especificación Adversarial**: Debate adversarial para endurecer especificaciones antes de la ejecución
- **Preservación de Contexto Automática**: Sistema 100% automático ledger/handoff preserva estado de sesión (v2.35)
- **Auto-Mejoramiento**: Análisis retrospectivo después de cada tarea para proponer mejoras de flujo de trabajo

### Por Qué Usarlo

| Desafío | Solución Ralph |
|---------|----------------|
| Salida de IA varía en calidad | Debate multi-modelo vía adversarial-spec |
| Un solo paso frecuentemente insuficiente | Ciclos iterativos (15-60 iteraciones) hasta VERIFIED_DONE |
| Revisión manual es cuello de botella | Puertas de calidad automáticas + humano en decisiones críticas |
| Límites de contexto | MiniMax (1M tokens) + Context7 MCP para documentación |
| Pérdida de contexto en compactación | Preservación automática ledger/handoff (85-90% reducción tokens) |
| Costos API altos | Enrutamiento optimizado (WebSearch FREE, MiniMax 8%, Opus estratégico) |

---

## Arquitectura

### Diagrama General del Sistema

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ARQUITECTURA COMPLETA RALPH v2.49.1                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    CICLO DE VIDA DE SESIÓN                            │   │
│  │   [SessionStart]                                                     │   │
│  │       │                                                               │   │
│  │       ▼                                                               │   │
│  │   ┌──────────────────────────────────────────────────────────────┐   │   │
│  │   │           BÚSQUEDA DE MEMORIA INTELIGENTE (PARALELO) v2.47   │   │   │
│  │   │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐    │   │   │
│  │   │  │claude-mem │ │  memvid   │ │ handoffs  │ │  ledgers  │    │   │   │
│  │   │  │  (MCP)    │ │  (HNSW)   │ │ (30 días) │ │CONTINUIDAD│    │   │   │
│  │   │  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘    │   │   │
│  │   │        │ PARALELO    │ PARALELO    │ PARALELO    │ PARALELO  │   │   │
│  │   │        └─────────────┴─────────────┴─────────────┘           │   │   │
│  │   │                            │                                    │   │   │
│  │   │                            ▼                                    │   │   │
│  │   │                   ┌─────────────────┐                          │   │   │
│  │   │                   │   CONTEXTO DE   │                          │   │   │
│  │   │                   │     MEMORIA     │                          │   │   │
│  │   │                   └─────────────────┘                          │   │   │
│  │   └──────────────────────────────────────────────────────────────┘   │   │
│  │                                    │                                  │   │
│  │                                    ▼                                  │   │
│  │  ┌────────────────────────────────────────────────────────────────┐  │   │
│  │  │              FLUJO DE ORQUESTADOR (12 Pasos) v2.46             │  │   │
│  │  │                                                               │  │   │
│  │  │  0.EVALUAR ───► 1.CLARIFICAR ───► 2.CLASIFICAR ───► 3.PLAN ──►│  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       │                │               │              ▼        │  │   │
│  │  │       │                │               │      ┌────────────┐   │  │   │
│  │  │       │                │               │      │   Claude   │   │  │   │
│  │  │       │                │               │      │    Code    │   │  │   │
│  │  │       │                │               │      │ Plan Mode  │   │  │   │
│  │  │       │                │               │      └────────────┘   │  │   │
│  │  │       │                │               │              │        │  │   │
│  │  │       ▼                ▼               ▼              ▼        │  │   │
│  │  │  ┌────────────────────────────────────────────────────────────────┐│  │   │
│  │  │  │              EJECUTAR-CON-SINCRONIZACIÓN (Bucle Anidado)      ││  │   │
│  │  │  │  LSA-VERIFY ──► IMPLEMENTAR ──► PLAN-SYNC ──► MICRO-GATE     ││  │   │
│  │  │  └────────────────────────────────────────────────────────────────┘│  │   │
│  │  │                                    │                               │  │   │
│  │  │                                    ▼                               │  │   │
│  │  │  ┌───────────────────────────────────────────────────────────────┐│  │   │
│  │  │  │              VALIDAR (Multi-Etapa)                           ││  │   │
│  │  │  │  CORRECCIÓN ──► CALIDAD ──► CONSISTENCIA ──► ADVERSARIAL   ││  │   │
│  │  │  │      [BLOQUEANTE]   [BLOQUEANTE]    [CONSULTIVO]  [si >= 7] ││  │   │
│  │  │  └───────────────────────────────────────────────────────────────┘│  │   │
│  │  │                                    │                               │  │   │
│  │  │                         ┌──────────┴──────────┐                    │  │   │
│  │  │                         │                     │                     │  │   │
│  │  │                         ▼                     ▼                     │  │   │
│  │  │                  ┌─────────────┐      ┌─────────────┐              │  │   │
│  │  │                  │  BUCLE DE   │      │ VERIFIED_   │              │  │   │
│  │  │                  │ ITERACIÓN   │      │    DONE     │              │  │   │
│  │  │                  │  (max 25)   │      │   (salida)  │              │  │   │
│  │  │                  └─────────────┘      └─────────────┘              │  │   │
│  │  └────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                             │
│  └─────────────────────────────────────────────────────────────────────────────┘
```

> **Diagrama Completo**: Ver `ARCHITECTURE_DIAGRAM_v2.49.1.md` para diagramas detallados (Arquitectura de Memoria, Registro de Hooks, Matriz de Herramientas, Patrón de Seguridad)

---

## Flujo de Trabajo Principal

### 1. El Patrón Ralph Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                    PATRÓN RALPH LOOP                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ EJECUTAR │───▶│   VALIDAR    │───▶│ ¿Calidad OK?    │      │
│   │  Tarea   │    │ (hooks/gates)│    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ SI         │
│                                           │         │          │
│                          ┌────────────────┘         │          │
│                          ▼                          ▼          │
│                   ┌─────────────┐          ┌──────────────┐    │
│                   │  ITERAR     │          │ VERIFIED_    │    │
│                   │(max 25/50)  │          │    DONE      │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Volver a EJECUTAR       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Flujo de Orquestación Completo (12 Pasos)

```
0. EVALUAR    → Clasificación rápida (¿trivial?)
1. CLARIFICAR → AskUserQuestion (MUST_HAVE/NICE_TO_HAVE)
2. CLASIFICAR → task-classifier (complejidad 1-10)
3. PLANEAR    → Diseño detallado
4. MODO PLAN  → EnterPlanMode (lee análisis)
5. DELEGAR    → Enrutar al modelo óptimo
6. EJECUTAR-CON-SINCRONIZACIÓN → Bucle anidado por paso:
   6a. LSA-VERIFY  → Pre-check arquitectura
   6b. IMPLEMENTAR → Ejecutar paso
   6c. PLAN-SYNC   → Detectar desviación
   6d. MICRO-GATE  → Calidad por paso (regla 3-fix)
7. VALIDAR    → Validación multi-etapa:
   7a. CALIDAD-AUDITOR → Auditoría pragmática
   7b. GATES → Puertas de calidad (9 lenguajes)
   7c. ADVERSARIAL-SPEC → Refinamiento especificación
   7d. ADVERSARIAL-PLAN → Validación cruzada Opus+Codex
8. RETROSPECT → Auto-mejoramiento
```

---

## Características Clave

### Orquestación Multi-Agente

| Característica | Descripción |
|----------------|-------------|
| **14 Agentes Especializados** | 9 núcleo + 5 revisión auxiliary |
| **Flujo de 12 Pasos** | Evaluar → Clarificar → Planificar → Ejecutar → Validar |
| **Ejecución Paralela** | Múltiples agentes trabajan simultáneamente |
| **Enrutamiento de Modelos** | Selección automática: Opus (crítico), Sonnet (estándar), MiniMax (extendido) |

**Agentes Núcleo (9)**:
`orchestrator`, `security-auditor`, `code-reviewer`, `test-architect`, `debugger`, `refactorer`, `docs-writer`, `frontend-reviewer`, `minimax-reviewer`

### Memoria Inteligente (v2.49)

```
BÚSQUEDA DE MEMORIA INTELIGENTE (PARALELO)
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│claude-mem│ │ memvid   │ │ handoffs │ │  ledgers │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │ PARALELO   │ PARALELO   │ PARALELO   │ PARALELO
     └────────────┴────────────┴────────────┘
                    ↓
         .claude/memory-context.json
```

**Tres Tipos de Memoria**:
| Tipo | Propósito | Almacenamiento |
|------|-----------|----------------|
| **Semántica** | Hechos, preferencias | `~/.ralph/memory/semantic.json` |
| **Episódica** | Experiencias (TTL 30 días) | `~/.ralph/episodes/` |
| **Procedimental** | Comportamientos aprendidos | `~/.ralph/procedural/rules.json` |

### Validación Calidad-Primero (v2.46)

```
Etapa 1: CORRECCIÓN    → Errores de sintaxis (BLOQUEANTE)
Etapa 2: CALIDAD       → Errores de tipos (BLOQUEANTE)
Etapa 2.5: SEGURIDAD   → semgrep + gitleaks (BLOQUEANTE)
Etapa 3: CONSISTENCIA  → Linting (CONSULTIVO - no bloqueante)
```

### Clasificación 3-Dimensiones (RLM)

| Dimensión | Valores |
|-----------|---------|
| **Complejidad** | 1-10 |
| **Densidad de Información** | CONSTANT / LINEAR / QUADRATIC |
| **Requisito de Contexto** | FITS / CHUNKED / RECURSIVE |

---

## Instalación Rápida

```bash
# Clonar repositorio
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Instalar
chmod +x install.sh
./install.sh
source ~/.zshrc

# Verificar
ralph integrations
```

### Requisitos

| Herramienta | Requerida | Propósito |
|-------------|-----------|-----------|
| Claude CLI | Sí | Orquestación base |
| jq | Sí | Procesamiento JSON |
| git | Sí | Control de versiones |
| GitHub CLI | Para PRs | Creación/revisión de PR |

---

## Comandos Esenciales

```bash
# Orquestación
/orchestrator "Implementar OAuth2 con Google"
ralph orch "tarea"              # Orquestación completa
ralph loop "arreglar errores"   # Loop hasta VERIFIED_DONE
/clarify                        # Clarificación intensiva

# Calidad
/gates                          # Puertas de calidad
/adversarial                    # Refinamiento de especificación

# Memoria (v2.49)
ralph memory-search "consulta"  # Búsqueda paralela
ralph fork-suggest "tarea"      # Sugerir sesiones

# Seguridad
ralph security src/             # Auditoría de seguridad
ralph security-loop src/        # Auditoría iterativa

# Git Worktree
ralph worktree "característica" # Crear worktree aislado
ralph worktree-pr <branch>      # PR con revisión

# Contexto
ralph ledger save               # Guardar estado de sesión
ralph handoff create            # Crear handoff
ralph compact                   # Guardado manual (extensiones)
```

---

## Arquitectura de Modelos

```
┌────────────────────────────────────────────────────────────┐
│  PRIMARIO (Gestionado por Sonnet)  │  SECUNDARIO (8% costo)       │
├────────────────────────────────────────────────────┼───────────────────────────────┤
│  Claude Opus/Sonnet                │  MiniMax M2.1                │
│  Codex GPT-5                       │  (Segunda opinión)           │
│  Gemini 2.5 Pro                    │  (Validación independiente)  │
├────────────────────────────────────────────────────┼───────────────────────────────┤
│  Implementación                    │  Validación                  │
│  Testing                           │  Detectar problemas perdidos │
│  Documentación                     │  Calidad Opus al 8% costo    │
└────────────────────────────────────────────────────┴───────────────────────────────┘
```

### Optimización de Costos

| Modelo | Max Iteraciones | Costo vs Claude | Caso de Uso |
|--------|-----------------|-----------------|-------------|
| Claude Opus | 25 | 100% | Revisión crítica, arquitectura |
| Claude Sonnet | 25 | 60% | Implementación estándar |
| MiniMax M2.1 | 50 | 8% | Loops extendidos, segunda opinión |
| MiniMax-lightning | 100 | 4% | Tareas muy largas |

---

## Hooks (29 Registrados)

| Tipo de Evento | Propósito |
|----------------|-----------|
| SessionStart | Preservación de contexto al inicio |
| PreCompact | Guardar estado antes de compactación |
| PostToolUse | Puertas de calidad después de Edit/Write |
| PreToolUse | Guardias de seguridad antes de Bash/Skill |
| UserPromptSubmit | Advertencias de contexto, recordatorios |
| Stop | Reportes de sesión |

---

## Documentación Adicional

| Documento | Propósito |
|-----------|-----------|
| [`CHANGELOG.md`](./CHANGELOG.md) | **Historia completa de versiones** (mejores prácticas) |
| [`ARCHITECTURE_DIAGRAM_v2.49.1.md`](./ARCHITECTURE_DIAGRAM_v2.49.1.md) | Diagramas completos de arquitectura |
| [`CLAUDE.md`](./CLAUDE.md) | Referencia rápida (compacta) |
| `tests/HOOK_TESTING_PATTERNS.md` | Patrones de testing de hooks |

> **Nota**: La documentación principal del repositorio está en INGLÉS. Este archivo README en español es para facilitar la comprensión inicial. Para contribuir o consultar detalles técnicos, consulta los documentos en inglés.

---

*"Mejor fallar de manera predecible que tener éxito de manera impredecible"* - La Filosofía de Ralph Wiggum

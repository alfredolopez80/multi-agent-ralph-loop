# Context Management Tool Coordination - v2.47

## Visión General

El sistema de context management de Ralph v2.47 coordina múltiples herramientas para garantizar preservación de contexto sin pérdida durante compactaciones y sesiones largas.

## Arquitectura de Herramientas

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CONTEXT MANAGEMENT ECOSYSTEM v2.47                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   LEDGERS    │    │   HANDOFFS   │    │  CLAUDE-MEM  │                  │
│  │ Session state│    │Context xfer  │    │ Semantic mem │                  │
│  │~/.ralph/     │    │~/.ralph/     │    │ MCP server   │                  │
│  │  ledgers/    │    │  handoffs/   │    │              │                  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘                  │
│         │                   │                   │                           │
│         └───────────────────┼───────────────────┘                           │
│                             │                                               │
│                    ┌────────▼────────┐                                      │
│                    │  ANCHORED       │ ← NEW v2.47                          │
│                    │  SUMMARY        │                                      │
│                    │  (Profiles)     │                                      │
│                    └────────┬────────┘                                      │
│                             │                                               │
│         ┌───────────────────┼───────────────────┐                           │
│         │                   │                   │                           │
│  ┌──────▼───────┐    ┌──────▼───────┐    ┌──────▼───────┐                  │
│  │ SessionStart │    │  PreCompact  │    │ PostCompact  │                  │
│  │    Hook      │    │    Hook      │    │    Hook      │                  │
│  │ (v2.47 fix)  │    │              │    │              │                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     MONITORING LAYER                                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │   │
│  │  │ operation-  │  │ message_    │  │ context-    │  │  StatusLine │  │   │
│  │  │ counter     │  │ count       │  │ warning.sh  │  │  (HUD)      │  │   │
│  │  │ (v2.47 fix) │  │ (v2.47 fix) │  │ (75%/85%)   │  │             │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Componentes y Responsabilidades

### 1. Ledger System (`~/.ralph/ledgers/`)

**Propósito**: Persistir estado de sesión estructurado

**Archivos**:
- `CONTINUITY_RALPH-{session_id}.md` - Ledger actual
- Formato: CURRENT GOAL, COMPLETED WORK, PENDING WORK, Git Status

**Cuándo se usa**:
- SessionStart: Se carga el más reciente
- PreCompact: Se guarda el estado actual
- Manual: `ralph ledger save/load/show`

**Limitaciones**:
- Solo datos estructurados (no semánticos)
- No incluye razonamiento o decisiones implícitas

### 2. Handoff System (`~/.ralph/handoffs/`)

**Propósito**: Capturar contexto rico para transferencia

**Archivos**:
- `{session_id}/handoff-{timestamp}.md`
- Incluye: Recent changes, restore commands, environment info

**Cuándo se usa**:
- PreCompact: Auto-genera con archivos modificados
- Manual: `ralph handoff create`

**Integración**:
```bash
# Crear handoff manual
ralph handoff create "Feature implementation checkpoint"

# Cargar handoff específico
ralph handoff load {session_id}
```

### 3. Claude-Mem MCP (`plugin:claude-mem`)

**Propósito**: Memoria semántica persistente con búsqueda

**Capacidades**:
- `search`: Buscar por query semántico
- `timeline`: Obtener contexto temporal
- `get_observations`: Detalles completos por ID

**Workflow de 3 capas** (crítico para eficiencia):
```yaml
# 1. Buscar (retorna índice, ~50-100 tokens/resultado)
mcp__plugin_claude-mem_mcp-search__search:
  query: "authentication implementation decisions"
  limit: 10

# 2. Timeline (contexto alrededor de un ID)
mcp__plugin_claude-mem_mcp-search__timeline:
  anchor: 11509
  depth_before: 5
  depth_after: 0

# 3. Detalles completos (SOLO IDs filtrados)
mcp__plugin_claude-mem_mcp-search__get_observations:
  ids: [11509, 11510, 11511]
```

**Ahorro**: 88% reducción de tokens vs cargar todo

### 4. Anchored Summary (`~/.ralph/state/anchored-summary.md`) - NEW v2.47

**Propósito**: Resumen estructurado que persiste decisiones críticas

**Perfiles disponibles**:
| Perfil | Secciones | Max Tokens | Uso |
|--------|-----------|------------|-----|
| minimal | GOAL, DECISIONS, PROGRESS | 400 | Tareas rápidas |
| development | + ARCHITECTURE, ERRORS_FIXED | 1000 | Default |
| debugging | + TEST_COVERAGE, CLAUDE_MEM_REFS | 800 | Debug sessions |
| security-audit | + SECURITY, DEPENDENCIES, API_CONTRACTS | 1200 | Auditorías |
| comprehensive | ALL | 2500 | Tareas multi-día |

**Comandos**:
```bash
ralph anchor generate development  # Generar con perfil
ralph anchor show                  # Ver actual
ralph anchor profiles              # Listar perfiles
ralph anchor validate              # Validar estructura
```

### 5. Context Warning Hook (`context-warning.sh`) - FIXED v2.47

**Propósito**: Monitorear uso de contexto y alertar proactivamente

**Thresholds v2.47**:
| Nivel | Threshold | Acción |
|-------|-----------|--------|
| INFO | 50% | Informativo |
| WARNING | 75% | Recomendar compactación proactiva |
| CRITICAL | 85% | Urgente - compactar inmediatamente |

**Bug corregido v2.47**:
- Problema: Contadores nunca se reseteaban → falso 100%
- Fix: Reset en cada SessionStart + paths corregidos

**Fórmula de estimación** (cuando `/context` no disponible):
```
context_pct = (operation_counter / 4) + (message_count * 2)
```

### 6. Counters (`~/.ralph/state/`)

**Archivos**:
- `operation-counter` - Incrementa por cada tool call
- `message_count` - Incrementa por cada prompt de usuario

**Reset v2.47**:
- Se resetean a 0 en cada SessionStart
- Garantiza estimación precisa por sesión

### 7. StatusLine (Claude HUD)

**Propósito**: Visibilidad en tiempo real del contexto

**Información mostrada**:
- `context_window.used_percentage` - % real de Claude Code
- Git branch con indicador de cambios
- Worktree indicator si aplica

**Configuración**:
```json
// ~/.claude/settings.json
{
  "statusLine": "script:~/.claude/scripts/statusline-git.sh"
}
```

## Flujos de Coordinación

### Flujo 1: Inicio de Sesión

```
SessionStart hook triggers
         │
         ▼
┌─────────────────────────────┐
│ 1. Reset counters           │ ← v2.47 fix
│    operation-counter = 0    │
│    message_count = 0        │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 2. Load Anchored Summary    │
│    (if exists, < 24h old)   │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 3. Load Ledger              │
│    CONTINUITY_RALPH-*.md    │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 4. Load Handoff             │
│    (if feature enabled)     │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 5. Inject claude-mem hints  │
│    (MCP search examples)    │
└─────────────────────────────┘
```

### Flujo 2: Durante la Sesión

```
User prompt received
         │
         ▼
┌─────────────────────────────┐
│ UserPromptSubmit hook       │
│ context-warning.sh executes │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ Increment message_count     │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────────┐
│ Calculate context percentage    │
│ Method 1: claude --print /ctx   │
│ Method 2: ops/4 + msgs*2        │
│ Method 3: msgs * 3 (fallback)   │
└──────────────┬──────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
    ▼ < 75%               ▼ >= 75%
┌────────────┐      ┌─────────────────┐
│ Continue   │      │ Show WARNING    │
│ normally   │      │ + recommendations│
└────────────┘      └─────────────────┘
                          │
                     ▼ >= 85%
                    ┌─────────────────┐
                    │ Show CRITICAL   │
                    │ URGENT actions  │
                    └─────────────────┘
```

### Flujo 3: Pre-Compactación

```
Context reaches auto-compact threshold (80%)
OR user runs /compact
         │
         ▼
┌─────────────────────────────┐
│ PreCompact hook triggers    │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 1. Generate Anchored Summary│
│    with current profile     │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 2. Validate with MiniMax    │
│    (if profile.validate=true)│
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 3. Save Ledger              │
│    CONTINUITY_RALPH-*.md    │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 4. Create Handoff           │
│    with recent changes      │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 5. Run context-extractor.py │
│    (rich state capture)     │
└─────────────────────────────┘
```

### Flujo 4: Post-Compactación

```
Compaction completes
         │
         ▼
┌─────────────────────────────┐
│ SessionStart:compact source │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 1. Reset counters to 0      │ ← v2.47 fix
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 2. Inject Anchored Summary  │
│    (decisions preserved)    │
└──────────────┬──────────────┘
               │
         ▼
┌─────────────────────────────┐
│ 3. Provide claude-mem hints │
│    for deep context recovery│
└─────────────────────────────┘
```

## Matriz de Herramientas por Escenario

| Escenario | Ledger | Handoff | Claude-Mem | Anchor | Warning |
|-----------|--------|---------|------------|--------|---------|
| Sesión nueva | Load | Load | Search hints | Load | Monitor |
| Trabajo normal | - | - | On-demand | - | Monitor |
| Pre-compact | Save | Create | - | Generate | Alert |
| Post-compact | Load | Load | Hints | Inject | Reset |
| Debug | - | - | Search | debugging | - |
| Security audit | - | - | Search | security-audit | - |

## Configuración de Features

```json
// ~/.ralph/config/features.json
{
  "RALPH_ENABLE_LEDGER": true,
  "RALPH_ENABLE_HANDOFF": true,
  "RALPH_ENABLE_CLAUDE_MEM": true,
  "RALPH_ENABLE_ANCHOR": true
}
```

## Comandos CLI

```bash
# Ledger
ralph ledger save           # Guardar estado
ralph ledger load           # Cargar último
ralph ledger list           # Listar todos
ralph ledger show           # Mostrar actual

# Handoff
ralph handoff create        # Crear handoff
ralph handoff load {id}     # Cargar específico
ralph handoff search {q}    # Buscar en handoffs

# Anchored Summary (v2.47)
ralph anchor generate [profile]  # Generar
ralph anchor show               # Mostrar
ralph anchor profiles           # Listar perfiles
ralph anchor validate           # Validar

# Context
ralph compact               # Compactación manual
ralph env                   # Info de entorno

# Setup
ralph setup-context-engine  # Configuración inicial
```

## Troubleshooting

### Problema: Falso 100% en context-warning

**Síntoma**: Hook muestra 100% pero StatusLine muestra 50%

**Causa**: Contadores no se reseteaban entre sesiones (pre-v2.47)

**Solución v2.47**:
1. Actualizar a v2.47: `ralph sync-global`
2. Reiniciar sesión para aplicar reset
3. Verificar: `cat ~/.ralph/state/operation-counter` debe ser bajo

### Problema: Anchored Summary vacío

**Síntoma**: Secciones sin contenido

**Causa**: Archivos fuente no existen o tienen encoding incorrecto

**Solución**:
1. Verificar `.claude/progress.md` existe
2. Verificar ledgers en `~/.ralph/ledgers/`
3. Script usa fallback de encoding automático (v2.47)

### Problema: Claude-mem no retorna resultados

**Síntoma**: Search retorna vacío

**Causa**: Query muy específico o MCP no configurado

**Solución**:
1. Usar queries más amplios
2. Verificar MCP: `ralph integrations`
3. Usar `mcp__plugin_claude-mem_mcp-search____IMPORTANT` para ver instrucciones

### Problema: Hooks no se ejecutan en VSCode/Cursor

**Síntoma**: Auto-compact no guarda contexto (GitHub #15021)

**Causa**: Extensions tienen capacidades limitadas

**Solución**:
1. Usar `/compact` skill manualmente antes de compactar
2. O ejecutar `ralph compact` desde terminal
3. context-warning.sh muestra recomendaciones específicas para extensions

## Métricas de Éxito v2.47

| Métrica | Antes | v2.47 |
|---------|-------|-------|
| Context accuracy | False 100% | Real % |
| Decision preservation | ~60% | **95%+** |
| Compaction data loss | ~40% | **<10%** |
| Session continuity | Manual | **Automatic** |
| Proactive warning | 80% threshold | **75% threshold** |
| Validation cost | N/A | **8% (MiniMax)** |

---

*Documento de coordinación v2.47 - Multi-Agent Ralph Loop*

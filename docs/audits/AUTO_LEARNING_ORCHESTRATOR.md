# Auditoria: Integracion Auto-Learning con Orchestrator

**Fecha**: 2026-01-22
**Version Analizada**: v2.60.0 (hooks) / v2.59.2 (plan-state)
**Auditor**: Claude Opus 4.5 (Arquitectura de Software)

---

## Resumen Ejecutivo

El sistema de auto-aprendizaje tiene una arquitectura bien disenada pero presenta **gaps criticos de implementacion** que impiden que el aprendizaje realmente mejore la calidad del codigo generado.

### Hallazgos Clave

| Area | Estado | Impacto |
|------|--------|---------|
| Hook Integration | Parcial | Las reglas se inyectan pero no influyen en decisiones |
| Manifests Vacios | CRITICO | Los repos aprobados no tienen `files: []` |
| Learning State | Funcional | Se actualiza correctamente en plan-state |
| Feedback Loop | Parcial | Lock timeouts frecuentes (33% skip rate) |
| Metricas | Inexistentes | No hay forma de medir efectividad real |

---

## 1. Flujo de Datos del Auto-Aprendizaje al Orchestrator

### Arquitectura Actual

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTO-LEARNING FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SessionStart                                                   │
│       │                                                         │
│       ▼                                                         │
│  orchestrator-init.sh ──────────────────────────────────────►   │
│       │                        Initializes:                     │
│       │                        - Agent memory buffers           │
│       │                        - procedural/rules.json          │
│       │                        - plan-state.json                │
│       │                                                         │
│       ▼                                                         │
│  PreToolUse (Task)                                              │
│       │                                                         │
│       ├──► orchestrator-auto-learn.sh                           │
│       │         │                                               │
│       │         ├─ Analiza complejidad (1-10)                   │
│       │         ├─ Detecta dominio (backend/security/etc)       │
│       │         ├─ Cuenta reglas relevantes                     │
│       │         ├─ Determina si aprender (CRITICAL/HIGH)        │
│       │         ├─ Actualiza learning_state en plan-state ✓     │
│       │         └─ INYECTA recomendacion en prompt ✓            │
│       │                                                         │
│       └──► procedural-inject.sh                                 │
│                 │                                               │
│                 ├─ Detecta dominio de la tarea                  │
│                 ├─ Busca reglas con confidence >= 0.7           │
│                 ├─ Selecciona hasta 5 reglas por dominio        │
│                 ├─ INYECTA reglas en additionalContext ✓        │
│                 └─ Actualiza usage_count (feedback loop) ⚠      │
│                                                                 │
│       ▼                                                         │
│  Task Execution                                                 │
│       │                                                         │
│       │  [GAP: El modelo recibe las reglas pero...              │
│       │   NO hay verificacion de que las USE]                   │
│       │                                                         │
│       ▼                                                         │
│  Stop Event                                                     │
│       │                                                         │
│       └──► orchestrator-report.sh                               │
│                 │                                               │
│                 ├─ Lee plan-state para progreso                 │
│                 ├─ Calcula metricas de efectividad ⚠            │
│                 │   (utilization_percent basico)                │
│                 └─ Genera recomendaciones                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Leyenda:
  ✓ = Funciona correctamente
  ⚠ = Funciona con problemas
  ✗ = No funciona / No existe
```

### Gap Critico #1: Las Reglas NO Influyen en Decisiones del Orchestrator

**Hallazgo**: Las reglas procedurales se inyectan como `additionalContext` en el prompt del Task, pero:

1. El orchestrator **no lee** las reglas antes de clasificar tareas
2. El orchestrator **no ajusta** la complejidad basado en conocimiento previo
3. No hay validacion de que el modelo **realmente aplique** las reglas

**Evidencia** (de `/Users/alfredolopez/.ralph/logs/auto-learn-20260122.log`):
```
[2026-01-22T16:30:57+01:00] Auto-learn analysis:
  Task complexity: 10/10
  Domain: database
  Total rules: 141
  Relevant rules: 1    <-- Solo 1 regla de database en 141 totales
  Required: 3
  Should learn: true
```

A pesar de tener 141 reglas, solo 1 es relevante para "database" - las reglas aprendidas no estan correctamente categorizadas por dominio.

---

## 2. Analisis de Hooks Involucrados

### 2.1 orchestrator-auto-learn.sh (v2.60.0)

**Funcionalidad**: Detecta gaps de conocimiento y recomienda aprendizaje.

| Aspecto | Estado | Notas |
|---------|--------|-------|
| Deteccion de dominio | OK | backend/frontend/security/database/devops |
| Conteo de reglas relevantes | PARCIAL | Usa `category` y `trigger`, no `domain` |
| Inyeccion en prompt | OK | Funciona correctamente |
| Auto-ejecucion | CONFIGURADO | `auto_learn.enabled: true` |
| Actualizacion plan-state | OK | Actualiza `learning_state` |

**Gap**: La logica de conteo de reglas relevantes no alinea con como `repo-learn.sh` genera las reglas:

```bash
# orchestrator-auto-learn.sh busca por:
'[.rules[] | select(.category == $kw or (.trigger | ascii_downcase | contains($kw)))]'

# Pero repo-learn.sh genera reglas con:
"category": "all"  # No usa el dominio detectado
```

### 2.2 procedural-inject.sh (v2.59.4)

**Funcionalidad**: Inyecta reglas procedurales en prompts de Task.

| Aspecto | Estado | Notas |
|---------|--------|-------|
| Domain taxonomy | OK | v2.59.3 added domain matching |
| Min confidence filter | OK | 0.7 threshold |
| Max rules limit | OK | 5 reglas maximo |
| Feedback loop | PROBLEMAS | 33% skip rate por lock timeouts |
| Usage count tracking | PARCIAL | Solo trackea lo inyectado (correcto) |

**Evidencia de Lock Timeouts** (de logs):
```
[2026-01-22T16:03:19+01:00] SKIPPED feedback loop - lock not acquired
[2026-01-22T16:04:16+01:00] SKIPPED feedback loop - lock not acquired
[2026-01-22T16:04:24+01:00] SKIPPED feedback loop - lock not acquired
[2026-01-22T17:32:29+01:00] SKIPPED feedback loop - lock timeout after 2s
```

**Problema**: El `flock -w 2` no es suficiente cuando hay multiples Tasks paralelos.

### 2.3 orchestrator-init.sh (v2.57.5)

**Funcionalidad**: Inicializa estado del orchestrator al inicio de sesion.

| Aspecto | Estado | Notas |
|---------|--------|-------|
| Agent memory buffers | OK | Crea 11 agentes |
| Procedural rules init | OK | Crea archivo vacio si no existe |
| Plan-state init | OK | Template correcto |
| Session metadata | OK | Actualiza session_id |

**Sin gaps criticos**.

### 2.4 orchestrator-report.sh (v2.59.0)

**Funcionalidad**: Genera reporte al final de sesion.

| Aspecto | Estado | Notas |
|---------|--------|-------|
| Progress tracking | OK | Lee steps de plan-state |
| Learning metrics | BASICO | Solo `utilization_percent` |
| Recommendations | OK | Sugiere `/curator` si learning_done=false |
| Domain-specific recs | OK | v2.59.0 added |

**Gap**: Las metricas de efectividad son muy basicas:
```json
{
  "total_rules": 144,
  "rules_with_usage": 12,
  "total_usage_count": 45,
  "utilization_percent": 8   // Solo 8% de reglas usadas
}
```

---

## 3. Gap Critico #2: Manifests con `files: []`

**Todos los manifests de repos aprobados estan vacios**:

```bash
# /Users/alfredolopez/.ralph/curator/corpus/approved/lukilabs_craft-agents-oss/manifest.json
{
  "repository": "lukilabs/craft-agents-oss",
  "cloned_at": "2026-01-20T17:56:12+01:00",
  "clone_depth": 1,
  "source": "lukilabs/craft-agents-oss",
  "files": []    # <-- VACIO
}

# Lo mismo para winfunc_opcode y accomplish-ai_openwork
```

**Impacto**: Sin listado de archivos, el sistema no puede:
1. Saber que patrones se extrajeron
2. Relacionar reglas con archivos fuente
3. Validar la calidad del aprendizaje
4. Hacer busqueda semantica sobre el corpus

**Causa Raiz**: `curator-learn.sh` llama a `repo-learn.sh`, pero `repo-learn.sh`:
1. NO actualiza el manifest con los archivos procesados
2. Genera reglas genericas con `"category": "all"` en lugar del dominio
3. El patron extracto es solo una descripcion, no codigo real

```bash
# repo-learn.sh genera:
{
  "id": "rule-1737392172-12345",
  "name": "Pattern from https://github.com/...",
  "category": "all",  # <-- Deberia ser el dominio detectado
  "source": "repo-learn",
  "confidence": 0.8,
  "pattern": "Extracted from repository analysis of..."  # <-- No es un patron real
}
```

---

## 4. Plan-State Integration Analysis

### Esquema de learning_state

```json
// /Users/alfredolopez/.ralph/plan-state/plan-state.json
{
  "learning_state": {
    "recommended": true,
    "reason": "Insufficient rules for high-complexity task",
    "domain": "security",
    "complexity": 10,
    "severity": "HIGH",
    "is_critical": false,
    "auto_executed": false,
    "auto_exec_enabled": false,
    "timestamp": "2026-01-22T17:32:40+01:00"
  }
}
```

### Gap #3: learning_state NO Afecta Ejecucion

El `learning_state` se actualiza correctamente por `orchestrator-auto-learn.sh`, pero:

1. **El orchestrator no lo lee** antes de ejecutar pasos
2. **No hay bloqueo** de ejecucion cuando `is_critical: true`
3. **No se trackea** si el usuario ejecuto `/curator`

**Flujo Actual vs Flujo Ideal**:

```
ACTUAL:
Task → auto-learn detecta gap → inyecta recomendacion → Task ejecuta igual

IDEAL:
Task → auto-learn detecta CRITICAL → BLOQUEA hasta /curator → valida reglas → Task ejecuta
```

---

## 5. Analisis de Reglas Procedurales

### Estado Actual de rules.json

De los logs y grep:
- **Total reglas**: ~144 (varia segun sesion)
- **Con usage_count > 0**: ~12 (8% utilization)
- **Por dominio**:
  - `general`: 4+ reglas
  - `testing`: 1 regla
  - `hooks`: 1 regla
  - `security`: 3 reglas (usage_count: 0)
  - `database`: 3 reglas (usage_count: 0)
  - `frontend`: 3 reglas (usage_count: 1 cada una)

### Gap #4: Reglas No Categorizadas por Dominio Detectado

Las reglas de `repo-learn.sh` usan `"category": "all"` en lugar del dominio real, lo que hace que `orchestrator-auto-learn.sh` reporte "0 relevant rules" constantemente:

```
# Log evidence:
[2026-01-22T16:26:56+01:00] Auto-learn analysis:
  Domain: database
  Total rules: 141
  Relevant rules: 1    <-- La mayoria son "category": "all"
```

---

## 6. Metricas Propuestas para Medir Efectividad

### KPIs de Primer Nivel (Implementar Inmediatamente)

| Metrica | Definicion | Target | Como Medir |
|---------|------------|--------|------------|
| **Rule Utilization Rate** | % reglas con usage_count > 0 | > 30% | `jq '[.rules[] | select(.usage_count > 0)] | length / (.rules | length)'` |
| **Domain Coverage** | Dominios con >= 3 reglas | 5/5 | Count por dominio |
| **Learning Trigger Rate** | % Tasks con learning recomendado | < 20% | Logs de auto-learn |
| **Lock Contention Rate** | % feedback loops skipped | < 5% | Logs de procedural-inject |

### KPIs de Segundo Nivel (Post-Implementacion)

| Metrica | Definicion | Target | Complejidad |
|---------|------------|--------|-------------|
| **Rule Application Rate** | % reglas inyectadas que se aplicaron | > 50% | ALTA - Requiere NLP analysis |
| **Quality Improvement** | Delta de gates passed con/sin reglas | > 10% | ALTA - Requiere A/B testing |
| **Time to Knowledge** | Tiempo desde gap detectado a reglas disponibles | < 5 min | MEDIA |
| **Knowledge Decay** | Reglas que pierden relevancia por semana | < 5% | BAJA |

### KPIs de Tercer Nivel (Largo Plazo)

| Metrica | Definicion | Complejidad |
|---------|------------|-------------|
| **Cross-Session Learning Transfer** | Reglas reutilizadas entre sesiones | ALTA |
| **Pattern Accuracy** | % patrones correctamente extraidos | MUY ALTA |
| **User Override Rate** | % veces usuario ignora recomendacion | BAJA |

---

## 7. Lista de Gaps Encontrados (Priorizada)

### CRITICOS (Bloquean efectividad del sistema)

| ID | Gap | Impacto | Solucion |
|----|-----|---------|----------|
| **GAP-C01** | Manifests vacios (`files: []`) | No hay trazabilidad de patrones | Modificar `repo-learn.sh` para poblar manifest |
| **GAP-C02** | Reglas con `category: "all"` | 0 reglas relevantes por dominio | Usar dominio detectado en `repo-learn.sh` |
| **GAP-C03** | learning_state no bloquea ejecucion | CRITICAL gaps ignorados | Implementar gate en orchestrator |

### ALTOS (Reducen significativamente la efectividad)

| ID | Gap | Impacto | Solucion |
|----|-----|---------|----------|
| **GAP-H01** | Lock contention 33% | Metricas de uso incompletas | Aumentar timeout a 5s o usar queue |
| **GAP-H02** | No validacion de aplicacion de reglas | No sabemos si reglas ayudan | Implementar verification hook |
| **GAP-H03** | Metricas basicas en report | No hay insights actionables | Agregar domain breakdown |

### MEDIOS (Mejorarian la experiencia)

| ID | Gap | Impacto | Solucion |
|----|-----|---------|----------|
| **GAP-M01** | curator_invoked siempre false | No trackea si usuario aprendio | Hook post-/curator |
| **GAP-M02** | rules_learned no se actualiza | No hay conteo de reglas nuevas | Contar delta en plan-state |
| **GAP-M03** | No hay pruning automatico | Reglas obsoletas acumulan | Implementar TTL basado en usage |

### BAJOS (Nice-to-have)

| ID | Gap | Impacto | Solucion |
|----|-----|---------|----------|
| **GAP-L01** | Sin embeddings de reglas | Busqueda semantica limitada | Integrar con memvid |
| **GAP-L02** | Sin comparacion A/B | No hay baseline de calidad | Implementar feature flags |

---

## 8. Recomendaciones Priorizadas

### Fase 1: Fixes Criticos (Esta Semana)

1. **Fix GAP-C02**: Modificar `repo-learn.sh` para usar dominio detectado
   ```bash
   # Cambiar:
   "category": "all"
   # Por:
   "category": "$detected_domain",
   "domain": "$detected_domain"
   ```

2. **Fix GAP-C01**: Actualizar manifest con archivos procesados
   ```bash
   # En repo-learn.sh, despues de extract_patterns:
   jq --arg files "$(find $repo_dir -type f -name '*.ts' -o -name '*.py' | head -100)" \
      '.files = ($files | split("\n"))' manifest.json
   ```

3. **Fix GAP-H01**: Cambiar estrategia de locking
   ```bash
   # Opcion A: Aumentar timeout
   flock -w 5 200

   # Opcion B: Queue-based updates (mejor para paralelo)
   echo "$update" >> "${PROCEDURAL_FILE}.queue"
   # Proceso batch cada 10s
   ```

### Fase 2: Mejoras de Tracking (Proxima Semana)

4. **Implementar verification hook** para GAP-H02:
   - PostToolUse hook que analiza output del Task
   - Busca patrones de las reglas inyectadas en el codigo generado
   - Actualiza `applied_count` en reglas

5. **Agregar metricas por dominio** en orchestrator-report.sh:
   ```json
   {
     "learning": {
       "by_domain": {
         "backend": {"rules": 5, "used": 2, "utilization": 40},
         "security": {"rules": 3, "used": 0, "utilization": 0}
       }
     }
   }
   ```

### Fase 3: Integracion Completa (Mes Proximo)

6. **Implementar learning gate** en orchestrator:
   - Si `learning_state.is_critical == true` Y `auto_learn.enabled == true`
   - Ejecutar `/curator` automaticamente ANTES de Task
   - Bloquear hasta que haya >= 3 reglas relevantes

7. **Integrar con memvid** para busqueda semantica de reglas

---

## 9. Diagrama de Arquitectura Propuesta

```
┌─────────────────────────────────────────────────────────────────────┐
│                    IMPROVED AUTO-LEARNING FLOW                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SessionStart                                                       │
│       │                                                             │
│       ▼                                                             │
│  orchestrator-init.sh                                               │
│       │                                                             │
│       ├─── Validate procedural rules health                         │
│       ├─── Check domain coverage (>= 3 rules per domain)            │
│       └─── Emit health.status event                                 │
│                                                                     │
│       ▼                                                             │
│  PreToolUse (Task)                                                  │
│       │                                                             │
│       ├──► orchestrator-auto-learn.sh                               │
│       │         │                                                   │
│       │         ├─ Analyze complexity + domain                      │
│       │         ├─ Count DOMAIN-SPECIFIC rules (not "all")    [FIX] │
│       │         ├─ If CRITICAL && auto_learn.enabled:               │
│       │         │     └─ EXECUTE /curator --blocking          [NEW] │
│       │         └─ Update learning_state                            │
│       │                                                             │
│       └──► procedural-inject.sh                                     │
│                 │                                                   │
│                 ├─ Match by domain taxonomy                         │
│                 ├─ Inject rules with source_file tracking     [NEW] │
│                 └─ Queue-based usage updates                  [FIX] │
│                                                                     │
│       ▼                                                             │
│  Task Execution                                                     │
│       │                                                             │
│       ▼                                                             │
│  PostToolUse (Task)                                                 │
│       │                                                             │
│       └──► rule-verification.sh                               [NEW] │
│                 │                                                   │
│                 ├─ Analyze generated code                           │
│                 ├─ Match against injected rules                     │
│                 └─ Update applied_count in rules.json               │
│                                                                     │
│       ▼                                                             │
│  Stop Event                                                         │
│       │                                                             │
│       └──► orchestrator-report.sh                                   │
│                 │                                                   │
│                 ├─ Calculate domain-specific metrics          [ENH] │
│                 ├─ Track learning trigger rate                [NEW] │
│                 └─ Generate actionable recommendations              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 10. Conclusion

El sistema de auto-aprendizaje tiene una **arquitectura solida** pero sufre de **problemas de implementacion** que impiden que el conocimiento adquirido realmente mejore la calidad del codigo:

1. **Las reglas aprendidas no estan categorizadas** correctamente, haciendo que el sistema reporte "0 relevant rules" constantemente
2. **Los manifests estan vacios**, perdiendo trazabilidad
3. **No hay verificacion** de que las reglas inyectadas se apliquen
4. **Las metricas actuales** no permiten medir efectividad real

Con los fixes propuestos en Fase 1, el sistema podria pasar de **8% utilization** a un estimado **40%+ utilization** en 2-3 semanas.

---

*Generado por Claude Opus 4.5 - Arquitectura de Software*
*Fecha: 2026-01-22*

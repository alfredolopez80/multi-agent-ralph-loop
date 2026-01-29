# Diagramas del Sistema de Learning - Orchestrator v2.81.1

**Fecha**: 2026-01-29
**Propósito**: Visualización del flujo completo del sistema de aprendizaje

---

## 📊 Diagrama 1: Arquitectura General

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR LEARNING SYSTEM                        │
│                              v2.81.1                                   │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         USER REQUEST                                   │
│                    "Implementar auth system"                           │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              STEP 1: CLASSIFICATION (orchestrator-auto-learn.sh)       │
│                                                                         │
│  • Detect complexity: 8/10                                             │
│  • Detect domain: security                                             │
│  • Count relevant rules: 1 (need ≥ 3)                                  │
│  • Update learning_state → CRITICAL                                     │
│  • Recommend: /curator --type security --lang typescript                │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
         ┌──────────────────┐          ┌──────────────────┐
         │ USER EXECUTES    │          │ USER IGNORES     │
         │ /curator         │          │ recommendation   │
         └──────────────────┘          └──────────────────┘
                    │                             │
                    ▼                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              STEP 2A: LEARNING (if user executes /curator)              │
│                                                                         │
│  2.1 DISCOVERY (curator-discovery.sh)                                  │
│      └─> Search GitHub for security repos                              │
│      └─> Find 50+ candidates                                           │
│                                                                         │
│  2.2 SCORING (curator-scoring.sh)                                       │
│      └─> Quality metrics (stars, tests, CI)                            │
│      └─> Context relevance scoring                                     │
│      └─> Filter top 20                                                 │
│                                                                         │
│  2.3 RANKING (curator-rank.sh)                                         │
│      └─> Apply max-per-org limits                                      │
│      └─> Get top 10                                                    │
│                                                                         │
│  2.4 APPROVAL (user)                                                   │
│      └─> User approves best repos                                      │
│                                                                         │
│  2.5 LEARNING (curator-learn.sh + repo-learn.sh)                      │
│      └─> Extract patterns from code                                    │
│      └─> Generate procedural rules                                     │
│      └─> Update ~/.ralph/procedural/rules.json                         │
│          {                                                             │
│            "id": "rule-1737392172-12345",                             │
│            "domain": "security",                                       │
│            "pattern": "Use JWT for stateless auth",                    │
│            "confidence": 0.9                                           │
│          }                                                             │
└─────────────────────────────────────────────────────────────────────────┘
                    │
                    │ Now have 5+ security rules
                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│          STEP 3: INJECTION (procedural-inject.sh)                      │
│                                                                         │
│  • Detect task domain: security                                        │
│  • Filter rules: confidence ≥ 0.7, domain=security                     │
│  • Select top 5 rules:                                                 │
│      - "Use JWT for stateless auth"                                     │
│      - "Implement rate limiting"                                       │
│      - "Hash passwords with bcrypt"                                   │
│      - "Validate JWT signature"                                       │
│      - "Use HTTPS only"                                                │
│  • Inject into Task prompt as additionalContext                        │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              STEP 4: TASK EXECUTION                                    │
│                                                                         │
│  Task receives prompt WITH 5 security rules injected                   │
│  └─> Model generates code:                                             │
│      - May apply the rules                                              │
│      - May ignore the rules                                             │
│                                                                         │
│  [CURRENT PROBLEM]                                                     │
│  └─> NO VERIFICATION if rules were applied                             │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│       STEP 5: REPORTING (orchestrator-report.sh)                       │
│                                                                         │
│  • Calculate metrics:                                                  │
│      - Rule utilization: 8%                                            │
│      - Rules with usage: ~100/1003                                     │
│  • Generate recommendations:                                            │
│      "Consider running /curator to improve quality"                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Diagrama 2: Estado Actual vs Estado Deseado

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CURRENT STATE (v2.81.1)                              │
│                    ⚠️ 50% INTEGRATION                                  │
└─────────────────────────────────────────────────────────────────────────┘

User Request
    │
    ▼
[Auto-detect gap]
    │
    ├────────────────────────────────────┐
    │                                    │
    ▼                                    ▼
[Recommend]                        [Execute Task]
/cursor                              WITHOUT rules
    │                                    │
    │  ⚠️ USER MAY IGNORE               │
    │                                    ▼
    │                              [Low Quality Code]
    │
    ▼
[User decides]
    │
    ├─ YES → [Learning happens]
    │         [Rules added]
    │         [But NOT auto-applied]
    │
    └─ NO → [Task continues]
              [Without best practices]

PROBLEMS:
1. ⚠️ Learning is MANUAL (user must execute /curator)
2. ⚠️ NO ENFORCEMENT (recommendations ignored)
3. ⚠️ NO VERIFICATION (rules may not be applied)
4. ⚠️ NO METRICS (don't know if rules help)
```

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DESIRED STATE (v3.0)                                │
│                    ✅ 100% INTEGRATION                                 │
└─────────────────────────────────────────────────────────────────────────┘

User Request
    │
    ▼
[Auto-detect gap]
    │
    ▼
[Check severity]
    │
    ├─ CRITICAL → [AUTO-EXECUTE /curator]
    │                [Wait for learning]
    │                [Verify rules added]
    │
    └─ HIGH → [Recommend /curator]
                 [Allow continue]

[Auto-inject rules]
    │
    ▼
[Execute Task WITH rules]
    │
    ▼
[VERIFY rules applied]
    │
    ├─ YES → [Update applied_count]
    │          [SUCCESS]
    │
    └─ NO → [Log gap]
             [Improve rules]

[Report metrics]
    • Rule utilization: 40%+
    • Application rate: 65%+
    • Quality improvement: +15%

IMPROVEMENTS:
1. ✅ AUTO-EXECUTION for CRITICAL gaps
2. ✅ ENFORCEMENT via learning gate
3. ✅ VERIFICATION of rule application
4. ✅ METRICS for effectiveness
```

---

## 📊 Diagrama 3: Hooks y Sus Relaciones

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HOOKS CHAIN                                   │
└─────────────────────────────────────────────────────────────────────────┘

SessionStart
    │
    ├─> plan-state-init.sh
    │   └─> Initialize ~/.ralph/plan-state/plan-state.json
    │
    └─> orchestrator-init.sh
        └─> Initialize agent memory buffers
            └─> Initialize ~/.ralph/procedural/rules.json

UserPromptSubmit
    │
    └─> plan-state-adaptive.sh
        └─> Create plan-state based on complexity

PreToolUse (Task)
    │
    ├─> orchestrator-auto-learn.sh ✅ CRÍTICO
    │   ├─> Detect complexity & domain
    │   ├─> Count relevant rules
    │   ├─> Update learning_state
    │   └─> Recommend /curator
    │
    ├─> procedural-inject.sh ✅ CRÍTICO
    │   ├─> Filter rules by domain
    │   ├─> Select top 5
    │   └─> Inject into prompt
    │
    └─> [FALTA] learning-gate.sh ❌ CRÍTICO
        ├─> Check if learning_state.is_critical
        ├─> AUTO-EXECUTE /curator if needed
        └─> BLOCK until sufficient rules

Task Execution
    │
    └─> Model generates code

PostToolUse (Task)
    │
    ├─> plan-sync-post-step.sh
    │   └─> Update plan-state progress
    │
    ├─> [FALTA] rule-verification.sh ❌ CRÍTICO
    │   ├─> Analyze generated code
    │   ├─> Match against injected rules
    │   └─> Update applied_count
    │
    └─> quality-gates-v2.sh
        └─> Run quality checks

Stop
    │
    └─> orchestrator-report.sh
        └─> Generate metrics & recommendations
```

---

## 📊 Diagrama 4: Flujo de Datos de Reglas

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PROCEDURAL RULES LIFECYCLE                         │
└─────────────────────────────────────────────────────────────────────────┘

REPOSITORY
    │
    ▼
repo-learn.sh
    ├─> Extract patterns (AST-based)
    ├─> Classify domain (security, backend, etc.)
    └─> Generate rule:
        {
          "id": "rule-1737392172-12345",
          "domain": "security",
          "category": "authentication",
          "pattern": "Use JWT for stateless auth",
          "confidence": 0.9,
          "source": "repo-learn",
          "usage_count": 0,
          "applied_count": 0,
          "created_at": "2026-01-29T12:00:00Z"
        }
    │
    ▼
~/.ralph/procedural/rules.json
    ├─> Store rule (atomic write + backup)
    └─> Total: 1003 rules

procedural-inject.sh
    ├─> Read rules.json
    ├─> Filter: confidence ≥ 0.7, domain matches
    ├─> Select: top 5 rules
    └─> Inject into Task prompt

Task Execution
    ├─> Receives rules in additionalContext
    └─> May or may not apply them

[FALTA] rule-verification.sh
    ├─> Should analyze generated code
    ├─> Should match against injected rules
    ├─> Should update applied_count
    └─> Should provide feedback loop

orchestrator-report.sh
    ├─> Calculate metrics:
    │   - utilization_rate = rules_with_usage / total_rules
    │   - application_rate = rules_applied / rules_injected
    └─> Generate recommendations

CURRENT STATE:
├─> 1003 rules generated
├─> ~100 rules used (10%)
├─> 0 rules verified (no verification hook)
└─> 8% utilization rate

DESIRED STATE:
├─> 1000+ rules generated
├─> ~400 rules used (40%)
├─> ~260 rules verified (65% application rate)
└─> 40% utilization rate
```

---

## 📊 Diagrama 5: Plan de Mejora por Fases

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    IMPROVEMENT ROADMAP                                 │
└─────────────────────────────────────────────────────────────────────────┘

FASE 0: Validación (Día 0)
├─> Validar hooks "obsoletos"
├─> Entender estado actual
└─> NO romper nada

FASE 1: Fixes Críticos (Día 1-2) 🔴 CRÍTICO
├─> Fix JSON corruption en curator-scoring.sh
├─> Fix syntax error en curator-ingest.sh
├─> Fix error swallowing en while loops
├─> Fix procedural memory corruption
└─> Resultado: Curator funciona correctamente

FASE 2: Integración (Día 3-5) 🟡 ALTO
├─> Crear learning-gate.sh (auto-ejecución)
├─> Crear rule-verification.sh (validación)
├─> Fix lock contention en procedural-inject.sh
├─> Actualizar manifests en repo-learn.sh
└─> Resultado: Learning se aplica automáticamente

FASE 3: Métricas (Día 6-7) 🟠 MEDIO
├─> Implementar rule utilization rate
├─> Implementar application rate
├─> Implementar quality improvement delta
├─> Implementar A/B testing framework
└─> Resultado: Medimos efectividad

FASE 4: Documentación (Día 8-9) 🟠 MEDIO
├─> Actualizar README.md
├─> Crear guía de integración
├─> Actualizar CLAUDE.md
└─> Resultado: Sistema documentado

FASE 5: Testing (Día 10-15) 🟢 NORMAL
├─> Tests unitarios
├─> Tests de integración
├─> Tests end-to-end
└─> Resultado: Sistema validado

MILESTONES:
├─> M1 (Día 2): Curator sin bugs
├─> M2 (Día 5): Learning automático
├─> M3 (Día 7): Métricas funcionando
├─> M4 (Día 10): Documentación completa
└─> M5 (Día 15): Production ready
```

---

## 📊 Resumen Visual

```
┌─────────────────────────────────────────────────────────────────┐
│                    SYSTEM STATUS                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Components:    ████░░░░░░ 50% INTEGRATED                      │
│  Quality:       ███████░░░ 70%                                 │
│  Automation:    ██░░░░░░░░ 20%                                 │
│  Documentation: ████░░░░░░ 40%                                 │
│  Testing:       ░░░░░░░░░░  0%                                 │
│                                                                 │
│  Overall:       █████░░░░░ 50% COMPLETE                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    GAPS IDENTIFIED                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔴 CRITICAL (3):                                               │
│     • Learning no se ejecuta automáticamente                    │
│     • No hay verificación de reglas aplicadas                   │
│     • Curator tiene 13 bugs críticos                            │
│                                                                 │
│  🟡 HIGH (2):                                                  │
│     • Lock contention en procedural-inject (33% skip)           │
│     • Manifests vacíos sin trazabilidad                        │
│                                                                 │
│  🟠 MEDIUM (2):                                                │
│     • No hay métricas de efectividad                           │
│     • Reglas no se validan post-ejecución                      │
│                                                                 │
│  🟢 LOW (1):                                                   │
│     • Documentación incompleta                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    IMPACT OF FIXES                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  WITHOUT fixes:                                                │
│     • 8% rule utilization                                      │
│     • 0% enforcement                                           │
│     • 0% verification                                          │
│     • Variable quality                                         │
│                                                                 │
│  WITH fixes (Fase 1-5):                                        │
│     • 40% rule utilization (5x improvement)                    │
│     • 90% enforcement in CRITICAL gaps                         │
│     • 65% application rate                                     │
│     • Consistent high quality                                 │
│     • Measurable improvements (+15%)                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Conclusión Visual

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│    ACTUAL:        Componentes aislados                         │
│       ╔═══════════╦═══════════╦═══════════╗                   │
│       ║  CURATOR  ║ REPO-LEARN║ PLAN-STATE║                   │
│       ║           ║           ║           ║                   │
│       ║  Manual   ║  Manual   ║  Passive  ║                   │
│       ╚═══════════╩═══════════╩═══════════╝                   │
│            │         │           │                            │
│            └─────────┴───────────┘                            │
│                      │                                         │
│                      ▼                                         │
│              NO HAY INTEGRACIÓN                                │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│    FUTURO:        Sistema integrado y automático                │
│       ╔═════════════════════════════════════╗                   │
│       ║                                   ║                   │
│       ║      AUTO-LEARNING SYSTEM          ║                   │
│       ║                                   ║                   │
│       ║  • Auto-detect gaps                ║                   │
│       ║  • Auto-execute curator            ║                   │
│       ║  • Auto-inject rules               ║                   │
│       ║  • Auto-verify application         ║                   │
│       ║  • Auto-measure effectiveness       ║                   │
│       ║                                   ║                   │
│       ╚═════════════════════════════════════╝                   │
│                      │                                         │
│                      ▼                                         │
│              100% INTEGRATED                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

**Próximo paso**: ¿Quieres que ejecute el script de validación de hooks o prefieres revisar primero el análisis completo?

---

*Diagramas generados para facilitar comprensión visual*
*Fecha: 2026-01-29*

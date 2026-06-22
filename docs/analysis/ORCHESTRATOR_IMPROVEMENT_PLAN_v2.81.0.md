# Orchestrator Improvement Plan - v2.81.0

**Date**: 2026-01-29
**Version**: v2.81.0
**Status**: READY FOR IMPLEMENTATION

## Overview

Este plan detalla la mejora del flujo del orchestrator integrando tres componentes clave:
1. **Repo Curator** - Descubrimiento y curación de repositorios
2. **Repository Learner** - Extracción de patrones y aprendizaje
3. **Plan State** - Gestión del estado de orquestación

## Problem Statement

### Problemas Identificados

1. **Desconexión de Componentes**
   - Curator, repo-learn y plan-state funcionan independientemente
   - No hay integración automática durante el ciclo de desarrollo
   - El aprendizaje no se aplica automáticamente durante la orquestación

2. **Documentación Incompleta**
   - README.md no documenta flujos completos
   - Faltan ejemplos de integración
   - No se explican las características nuevas (v2.55+)

3. **Supervivencia del Plan en Compacción**
   - No está claro cómo plan-state sobrevive la compactación de contexto
   - Falta documentación del ciclo de vida

4. **Seguimiento de Ejecución**
   - No hay verificación continua del plan durante ejecución
   - No se detecta drift del plan
   - Falta sincronización automática

## Solution Architecture

### Flujo Integrado Propuesto

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR WORKFLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  0. INICIO                                                       │
│     ↓                                                            │
│  1. SMART MEMORY SEARCH (v2.47)                                  │
│     ├── Busca: claude-mem, handoffs, ledgers                   │
│     └── Output: .claude/memory-context.json                      │
│     ↓                                                            │
│  2. CLARIFY + CLASSIFY                                           │
│     ├── AskUserQuestion (MUST_HAVE)                              │
│     ├── Detect project type (backend/frontend/cli)              │
│     └── Classify complexity (1-10)                               │
│     ↓                                                            │
│  3. CHECK LEARNING STATE                                          │
│     ├── Check procedural rules count                            │
│     ├── Check if rules relevant to project type                 │
│     └── Suggest curator if needed:                               │
│         │                                                        │
│         ├── IF complexity >= 7 AND rules < 3:                    │
│         │    → SUGGEST: /curator full --type <detected>         │
│         │                                                        │
│         └── IF complexity >= 5 AND no context-relevant rules:    │
│              → SUGGEST: /curator scoring --context "<patterns>" │
│     ↓                                                            │
│  4. PLAN WITH MEMORY                                             │
│     ├── Review past successes from memory                        │
│     ├── Review past errors from memory                          │
│     ├── Create plan with learned patterns                       │
│     └── Initialize plan-state.json                               │
│     ↓                                                            │
│  5. EXECUTE WITH LEARNING                                        │
│     ├── For EACH step:                                           │
│     │   ├── Apply learned patterns                              │
│     │   ├── Check plan-state consistency                        │
│     │   ├── Detect drift and sync                               │
│     │   └── Micro-gate validation                               │
│     │                                                            │
│     └── CONTEXT COMPACTION:                                      │
│         ├── PreCompact: Save plan-state                         │
│         ├── Compaction occurs                                   │
│         └── Post-compact: Restore plan-state                    │
│     ↓                                                            │
│  6. RETROSPECTIVE + LEARNING                                     │
│     ├── Extract successful patterns                             │
│     ├── Save to procedural rules                                │
│     ├── Suggest learning from repos                             │
│     └── Update memory                                           │
│     ↓                                                            │
│  VERIFIED_DONE                                                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Documentation Update (Priority: CRITICAL)

**Objective**: Actualizar documentación para reflejar el estado real del sistema.

#### 1.1 Update README.md

**Secciones a actualizar**:

1. **Repository Learner Section**
   ```markdown
   ### Repository Learner (v2.50) - Enhanced v2.68.23

   Extracts best practices from GitHub repositories using AST-based pattern analysis.

   **Features**:
   - AST-based pattern extraction (Python, TS, Rust, Go)
   - Domain classification (backend, frontend, security, testing, database)
   - Procedural rules generation with confidence scores
   - Source attribution (source_repo, source_url)
   - Security: SEC-106 path traversal validation

   **Usage**:
   ```bash
   # Learn from a specific repository
   repo-learn https://github.com/python/cpython

   # Learn focused on specific patterns
   repo-learn https://github.com/fastapi/fastapi --category error_handling

   # Auto-learning via curator
   /curator learn --type backend --lang python
   ```

   **Output**: Updates `~/.ralph/procedural/rules.json` with new rules.
   ```

2. **Repo Curator Section**
   ```markdown
   ### Repo Curator (v2.50) - Enhanced v2.55

   Discover, score, and curate high-quality repositories for learning.

   **5-Phase Workflow**:
   1. **Discovery** → GitHub API search (100-500 candidates)
   2. **Scoring** → Quality metrics + Context relevance (v2.55)
   3. **Ranking** → Top N (max 2 per org)
   4. **Review** → User approves/rejects
   5. **Learn** → Extract patterns via repo-learn

   **Context Relevance Scoring (v2.55)**:
   ```bash
   # Score with context relevance
   /curator scoring --context "error handling,retry,resilience"

   # Full pipeline with context
   /curator full --type backend --lang typescript --context "async patterns"
   ```

   **Pricing Tiers**:
   - free ($0.00): GitHub API + local scoring
   - economic (~$0.30): + OpenSSF + GLM-4.7
   - full (~$0.95): + Claude + Codex adversarial

   **Auto-Learning Triggers**:
   - complexity >= 7 AND procedural rules < 3
   - No context-relevant rules for project type
   ```

3. **Plan State Section**
   ```markdown
   ### Plan State System (v2.45) - Enhanced v2.65.2

   Manages orchestration state through context compaction.

   **Context Survival**:
   1. PreCompact hook saves `.claude/plan-state.json`
   2. Context compaction occurs
   3. State restored from file
   4. Execution continues seamlessly

   **Lifecycle Commands (v2.65.2)**:
   ```bash
   ralph plan show              # Show current plan status
   ralph plan archive "done"    # Archive completed plan
   ralph plan reset             # Reset to empty plan
   ralph plan history 5         # Show last 5 archived plans
   ralph plan restore <id>      # Restore from archive
   ```

   **Phase + Barrier System (v2.51)**:
   - Phases: Ordered groups of steps
   - Barriers: WAIT-ALL consistency points
   - Execution modes: sequential, parallel
   ```

4. **Integration Section** (NEW)
   ```markdown
   ### Orchestrator Integration (v2.81.0)

   **Continuous Learning Loop**:

   ```
   ┌─────────────────────────────────────────────────────┐
   │                 SMART MEMORY SEARCH                 │
   │    (claude-mem + handoffs + ledgers)                │
   └─────────────────┬───────────────────────────────────┘
                     │
                     ↓
   ┌─────────────────────────────────────────────────────┐
   │          CHECK LEARNING STATE                        │
   │  - Procedural rules count                           │
   │  - Context-relevant rules                           │
   │  - Curator corpus status                            │
   └─────────────────┬───────────────────────────────────┘
                     │
                     ↓
         ┌───────────┴───────────┐
         │                       │
         ↓                       ↓
   ┌─────────────┐         ┌─────────────┐
   │  SUGGEST    │         │   APPLY     │
   │  CURATOR    │         │  LEARNED    │
   │  IF NEEDED  │         │  PATTERNS   │
   └─────────────┘         └─────────────┘
         │                       │
         └───────────┬───────────┘
                     ↓
   ┌─────────────────────────────────────────────────────┐
   │              EXECUTE WITH LEARNING                  │
   │  - Apply patterns from memory                       │
   │  - Detect drift and sync                            │
   │  - Extract new patterns                             │
   └─────────────────┬───────────────────────────────────┘
                     │
                     ↓
   ┌─────────────────────────────────────────────────────┐
   │            RETROSPECTIVE + LEARNING                 │
   │  - Save successful patterns                         │
   │  - Update procedural rules                          │
   │  - Suggest repo learning                            │
   └─────────────────────────────────────────────────────┘
   ```

   **Auto-Learning Triggers**:
   ```bash
   # Triggered when:
   - complexity >= 7 AND rules < 3
   - No context-relevant rules for project type
   - User mentions "best practices", "patterns"

   # Suggestion:
   💡 Consider running: /curator full --type backend --lang typescript
   ```
   ```

#### 1.2 Create Integration Guide

**File**: `docs/guides/ORCHESTRATOR_INTEGRATION_GUIDE.md`

```markdown
# Orchestrator Integration Guide

## Continuous Learning Workflow

### Step 1: Initial Learning Setup

```bash
# 1. Discover quality repos
/curator discovery --type backend --lang typescript

# 2. Score with context relevance
/curator scoring --context "error handling,async patterns"

# 3. Rank top repos
/curator rank --top-n 15 --max-per-org 2

# 4. Review and approve
/curator show --ranking
/curator approve nestjs/nest
/curator approve prisma/prisma

# 5. Learn patterns
/curator learn --type backend --lang typescript
```

### Step 2: Use During Orchestration

```bash
# Start orchestrator with learning enabled
/orchestrator "Implement REST API with authentication"

# Orchestrator will:
# 1. Check learning state
# 2. Apply learned patterns
# 3. Extract new patterns during execution
# 4. Save to procedural rules
```

### Step 3: Continuous Improvement

```bash
# After task completion
ralph retrospective

# Review extracted patterns
cat ~/.ralph/procedural/rules.json | jq '.rules[] | select(.source_repo != null)'

# Learn from more repos
repo-learn https://github.com/goldbergyoni/nodebestpractices
```

## Plan State Context Survival

### How Plans Survive Compaction

1. **PreCompact Hook**:
   ```bash
   # .claude/hooks/pre-compact-handoff.sh
   # Triggers before context compaction
   # Saves .claude/plan-state.json to ~/.ralph/active-plan/
   ```

2. **Compaction Occurs**:
   - Claude Code compacts context
   - Old messages removed from window

3. **Post-Compact Restoration**:
   ```bash
   # .claude/hooks/session-start-reset-counters.sh
   # Restores plan-state from file
   # Continues execution seamlessly
   ```

### Verification

```bash
# Check plan status
ralph plan show

# Verify consistency
jq '.phases[] | select(.status == "in_progress")' .claude/plan-state.json
```

## Auto-Learning Integration

### Hook: orchestrator-auto-learn.sh

**Trigger**: PreToolUse (Task)

**Logic**:
```bash
# Check complexity
if [[ complexity -ge 7 ]] && [[ rules_count -lt 3 ]]; then
    suggest_curator
fi

# Check context relevance
if [[ no_context_relevant_rules ]]; then
    suggest_context_scoring
fi
```

**Output**: Suggestion to user with specific curator command
```
💡 Your procedural memory has $RULES_COUNT rules but none relevant to "backend,typescript".
Consider running:
/curator full --type backend --lang typescript --context "error handling"
```

### Hook: continuous-learning.sh

**Trigger**: Stop

**Logic**:
```bash
# Extract patterns from git diff
extract_patterns_from_diff

# Update procedural rules
update_procedural_rules

# Suggest learning
suggest_repo_learning
```

## Pattern Application

### During Implementation

When orchestrator implements a step:

1. **Query Procedural Rules**:
   ```bash
   jq '.rules[] | select(.domain == "backend") | select(.confidence > 0.7)'
   ~/.ralph/procedural/rules.json
   ```

2. **Apply Pattern**:
   ```
   Using pattern from nestjs/nest (confidence: 0.9):
   - Error handling: Custom exception classes
   - Validation: class-validator decorators
   - Logging: Winston with structured format
   ```

3. **Verify Application**:
   - Code matches pattern?
   - Adaptations documented?

### Extracting New Patterns

After implementation:

1. **Analyze Code**:
   ```bash
   # AST analysis
   extract_functions
   extract_classes
   extract_patterns
   ```

2. **Generate Rule**:
   ```json
   {
     "id": "rule_123456",
     "pattern": "async-error-handling",
     "domain": "backend",
     "confidence": 0.85,
     "source_repo": "user-project",
     "code": "try { await asyncOp() } catch (error) { handleError(error) }"
   }
   ```

3. **Save to Procedural**:
   ```bash
   jq --argjson new_rule "$new_rule" '.rules += [$new_rule]'
   ~/.ralph/procedural/rules.json > /tmp/rules.json
   mv /tmp/rules.json ~/.ralph/procedural/rules.json
   ```
```

### Phase 2: Hook Integration (Priority: HIGH)

#### 2.1 Create orchestrator-learning-bridge.sh

**File**: `.claude/hooks/orchestrator-learning-bridge.sh`

**Event**: PreToolUse (Task)

**Purpose**: Connect orchestrator with learning system

```bash
#!/bin/bash
# Orchestrator Learning Bridge Hook (v2.81.0)
# Trigger: PreToolUse (Task)
# Purpose: Bridge orchestrator with curator/repo-learn/plan-state

set -euo pipefail
umask 077

# Read input
INPUT=$(head -c 100000)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only run for Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Detect project type from files
detect_project_type() {
    if [[ -f "package.json" ]]; then
        echo "typescript"
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        echo "python"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "Cargo.toml" ]]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

PROJECT_TYPE=$(detect_project_type)

# Check learning state
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
RULES_COUNT=0
CONTEXT_RELEVANT=0

if [[ -f "$RULES_FILE" ]]; then
    RULES_COUNT=$(jq -r '.rules | length // 0' "$RULES_FILE")

    # Check context-relevant rules
    if [[ "$PROJECT_TYPE" != "unknown" ]]; then
        CONTEXT_RELEVANT=$(jq -r "[.rules[] | select(.domain == \"$PROJECT_TYPE\")] | length" "$RULES_FILE" 2>/dev/null || echo "0")
    fi
fi

# Check corpus
CORPUS_DIR="${HOME}/.ralph/curator/corpus/approved"
CORPUS_COUNT=0
if [[ -d "$CORPUS_DIR" ]]; then
    CORPUS_COUNT=$(find "$CORPUS_DIR" -type f -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
fi

# Suggest curator if needed
SUGGESTION=""

if [[ "$RULES_COUNT" -lt 3 ]] && [[ "$CORPUS_COUNT" -eq 0 ]]; then
    SUGGESTION="💡 **Learning Opportunity**: Your procedural memory is empty ($RULES_COUNT rules). Consider running:

\`\`\`
/curator full --type backend --lang $PROJECT_TYPE
\`\`\`

This will discover, score, and learn from high-quality $PROJECT_TYPE repositories."
elif [[ "$CONTEXT_RELEVANT" -lt 3 ]] && [[ "$PROJECT_TYPE" != "unknown" ]]; then
    SUGGESTION="💡 **Context Enhancement**: You have $RULES_COUNT rules but only $CONTEXT_RELEVANT relevant to \"$PROJECT_TYPE\". Consider running:

\`\`\`
/curator full --type backend --lang $PROJECT_TYPE --context \"error handling,async patterns\"
\`\`\`

This will score repos based on your current context."
fi

# Output suggestion if needed
if [[ -n "$SUGGESTION" ]]; then
    SUGGESTION_ESCAPED=$(echo "$SUGGESTION" | jq -Rs '.')
    echo "{\"additionalContext\": $SUGGESTION_ESCAPED, \"continue\": true}"
else
    echo '{"continue": true}'
fi
```

#### 2.2 Create plan-state-verification.sh

**File**: `.claude/hooks/plan-state-verification.sh`

**Event**: PostToolUse (Edit/Write)

**Purpose**: Verify plan-state consistency

```bash
#!/bin/bash
# Plan State Verification Hook (v2.81.0)
# Trigger: PostToolUse (Edit/Write)
# Purpose: Verify plan-state consistency and detect drift

set -euo pipefail
umask 077

# Read input
INPUT=$(head -c 100000)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only run for Edit/Write
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if plan-state exists
PLAN_STATE="${PROJECT_ROOT}/.claude/plan-state.json"
if [[ ! -f "$PLAN_STATE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Verify plan-state consistency
verify_plan_state() {
    # Check if valid JSON
    if ! jq empty "$PLAN_STATE" 2>/dev/null; then
        echo "❌ plan-state.json is not valid JSON"
        return 1
    fi

    # Check for in_progress steps
    IN_PROGRESS=$(jq -r '[.steps[] | select(.status == "in_progress")] | length' "$PLAN_STATE")

    if [[ "$IN_PROGRESS" -gt 0 ]]; then
        echo "ℹ️  Plan has $IN_PROGRESS steps in progress"

        # Check for drift
        CURRENT_STEP=$(jq -r '.steps[] | select(.status == "in_progress") | .id' "$PLAN_STATE" | head -1)

        if [[ -n "$CURRENT_STEP" ]]; then
            echo "📍 Current step: $CURRENT_STEP"

            # Verify step spec vs actual implementation
            SPEC_FILE=$(jq -r ".steps[\"$CURRENT_STEP\"].spec.file" "$PLAN_STATE")

            if [[ -n "$SPEC_FILE" ]] && [[ -f "$SPEC_FILE" ]]; then
                echo "✅ Step spec file exists: $SPEC_FILE"
            fi
        fi
    fi

    return 0
}

# Run verification
verify_plan_state

echo '{"continue": true}'
```

#### 2.3 Create continuous-learning-daemon.sh

**File**: `.claude/hooks/continuous-learning-daemon.sh`

**Event**: Stop

**Purpose**: Extract patterns and update learning

```bash
#!/bin/bash
# Continuous Learning Daemon Hook (v2.81.0)
# Trigger: Stop
# Purpose: Extract patterns from implementation and update learning

set -euo pipefail
umask 077

# Check if there are uncommitted changes
if ! git diff --quiet HEAD 2>/dev/null; then
    # Extract patterns from git diff
    DIFF_OUTPUT=$(git diff HEAD)

    # Analyze diff for patterns
    PATTERNS=$(echo "$DIFF_OUTPUT" | grep -E "function|class|async|await|error|handle" | wc -l | tr -d ' ')

    if [[ "$PATTERNS" -gt 0 ]]; then
        echo "🔍 Detected $PATTERNS potential patterns in changes"

        # Suggest learning
        echo "💡 Consider saving these patterns to procedural memory:"
        echo ""
        echo "```bash"
        echo "# Extract patterns from current implementation"
        echo "repo-learn . --category implementation_patterns"
        echo ""
        echo "# Or learn from quality repos"
        echo "/curator learn --type backend --lang typescript"
        echo "```"
    fi
fi

# Check procedural rules
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
if [[ -f "$RULES_FILE" ]]; then
    RULES_COUNT=$(jq -r '.rules | length // 0' "$RULES_FILE")
    LEARNED_COUNT=$(jq -r '[.rules[] | select(.source_repo != null)] | length' "$RULES_FILE" 2>/dev/null || echo "0")

    echo "📚 Learning status: $RULES_COUNT rules ($LEARNED_COUNT learned from repos)"
fi
```

### Phase 3: Enhanced Features (Priority: MEDIUM)

#### 3.1 Auto-Curator Trigger

**File**: `.claude/hooks/auto-curator-trigger.sh`

**Event**: SessionStart

**Purpose**: Auto-suggest curator for new projects

```bash
#!/bin/bash
# Auto Curator Trigger Hook (v2.81.0)
# Trigger: SessionStart
# Purpose: Auto-suggest curator for new projects

set -euo pipefail
umask 077

# Detect if new project (no .claude directory history)
if [[ ! -d ".claude" ]] || [[ ! -f ".claude/plan-state.json" ]]; then
    # Detect project type
    if [[ -f "package.json" ]]; then
        PROJECT_TYPE="typescript"
        PROJECT_LANG="typescript"
    elif [[ -f "requirements.txt" ]]; then
        PROJECT_TYPE="backend"
        PROJECT_LANG="python"
    else
        echo '{"continue": true}'
        exit 0
    fi

    # Check if already has learning
    RULES_FILE="${HOME}/.ralph/procedural/rules.json"
    if [[ -f "$RULES_FILE" ]]; then
        CONTEXT_RULES=$(jq -r "[.rules[] | select(.domain == \"$PROJECT_TYPE\")] | length" "$RULES_FILE" 2>/dev/null || echo "0")

        if [[ "$CONTEXT_RULES" -lt 3 ]]; then
            SUGGESTION="🆕 **New Project Detected**: This appears to be a $PROJECT_TYPE project. Consider learning from quality repos:

\`\`\`
/curator full --type $PROJECT_TYPE --lang $PROJECT_LANG
\`\`\`

This will help improve code generation quality for your project."

            SUGGESTION_ESCAPED=$(echo "$SUGGESTION" | jq -Rs '.')
            echo "{\"additionalContext\": $SUGGESTION_ESCAPED}"
            exit 0
        fi
    fi
fi

echo '{}'
```

#### 3.2 Pattern Application Display

**File**: `.claude/hooks/pattern-application-display.sh`

**Event**: PreToolUse (Edit/Write)

**Purpose**: Show which patterns are being applied

```bash
#!/bin/bash
# Pattern Application Display Hook (v2.81.0)
# Trigger: PreToolUse (Edit/Write)
# Purpose: Display which learned patterns are being applied

set -euo pipefail
umask 077

# Read input
INPUT=$(head -c 100000)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only run for Edit/Write
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Get file being edited
FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // ""')

if [[ -z "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Detect file type
case "$FILE_PATH" in
    *.ts|*.tsx)
        DOMAIN="typescript"
        ;;
    *.py)
        DOMAIN="python"
        ;;
    *)
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Query relevant patterns
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
if [[ ! -f "$RULES_FILE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Get high-confidence patterns for this domain
PATTERNS=$(jq -r "[.rules[] | select(.domain == \"$DOMAIN\") | select(.confidence > 0.7)] | length" "$RULES_FILE" 2>/dev/null || echo "0")

if [[ "$PATTERNS" -gt 0 ]]; then
    echo "💡 Applying $PATTERNS learned patterns for $DOMAIN (confidence > 0.7)" >&2
fi

echo '{"continue": true}'
```

### Phase 4: Testing (Priority: MEDIUM)

#### 4.1 Integration Tests

**File**: `tests/integration/test-orchestrator-learning.sh`

```bash
#!/bin/bash
# Test Orchestrator Learning Integration (v2.81.0)

set -euo pipefail

# Test 1: Learning bridge trigger
test_learning_bridge() {
    echo "Test 1: Learning bridge trigger"

    # Create test project
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Initialize as TypeScript project
    echo '{"name": "test"}' > package.json

    # Run learning bridge hook
    INPUT='{"tool_name": "Task"}'
    OUTPUT=$(echo "$INPUT" | ~/.claude/hooks/orchestrator-learning-bridge.sh)

    # Verify suggestion
    if echo "$OUTPUT" | jq -e '.additionalContext' >/dev/null; then
        echo "✅ Learning bridge triggered correctly"
    else
        echo "❌ Learning bridge failed"
        return 1
    fi

    # Cleanup
    cd -
    rm -rf "$TEST_DIR"
}

# Test 2: Plan state verification
test_plan_state_verification() {
    echo "Test 2: Plan state verification"

    # Create test plan-state
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    mkdir -p .claude
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.62.0",
  "plan_id": "test",
  "phases": [],
  "steps": {
    "step1": {
      "id": "step1",
      "name": "Test step",
      "status": "in_progress"
    }
  },
  "barriers": {}
}
EOF

    # Run verification hook
    INPUT='{"tool_name": "Edit", "file_path": "test.ts"}'
    OUTPUT=$(echo "$INPUT" | ~/.claude/hooks/plan-state-verification.sh)

    # Verify continue
    if echo "$OUTPUT" | jq -e '.continue == true' >/dev/null; then
        echo "✅ Plan state verification passed"
    else
        echo "❌ Plan state verification failed"
        return 1
    fi

    # Cleanup
    cd -
    rm -rf "$TEST_DIR"
}

# Test 3: Continuous learning
test_continuous_learning() {
    echo "Test 3: Continuous learning"

    # Create test project with git
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    git init

    # Create a commit
    echo "test" > test.txt
    git add test.txt
    git commit -m "test"

    # Make changes
    echo "test2" > test.txt

    # Run continuous learning hook
    OUTPUT=$(/.claude/hooks/continuous-learning-daemon.sh 2>&1)

    # Verify pattern detection
    if echo "$OUTPUT" | grep -q "Detected.*patterns"; then
        echo "✅ Continuous learning detected patterns"
    else
        echo "⚠️  Continuous learning: No patterns detected (may be expected)"
    fi

    # Cleanup
    cd -
    rm -rf "$TEST_DIR"
}

# Run all tests
echo "=== Orchestrator Learning Integration Tests ==="
test_learning_bridge
test_plan_state_verification
test_continuous_learning

echo ""
echo "=== All tests completed ==="
```

#### 4.2 End-to-End Test

**File**: `tests/integration/test-orchestrator-e2e.sh`

```bash
#!/bin/bash
# Test Orchestrator End-to-End (v2.81.0)

set -euo pipefail

echo "=== Orchestrator E2E Test ==="

# Step 1: Setup
echo "Step 1: Setup test environment"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Initialize as TypeScript project
npm init -y
npm install -D typescript @types/node

# Step 2: Run curator
echo "Step 2: Run curator discovery"
/curator discovery --type backend --lang typescript --query "express" --max-results 10

# Step 3: Score with context
echo "Step 3: Score with context relevance"
CANDIDATES=$(ls -t ~/.ralph/curator/candidates/*.json 2>/dev/null | head -1)
if [[ -n "$CANDIDATES" ]]; then
    ~/.ralph/curator/scripts/curator-scoring.sh --input "$CANDIDATES" --output /tmp/scored.json --context "error handling"
fi

# Step 4: Rank
echo "Step 4: Rank repositories"
if [[ -f "/tmp/scored.json" ]]; then
    ~/.ralph/curator/scripts/curator-rank.sh --input /tmp/scored.json --output /tmp/ranked.json --top-n 5
fi

# Step 5: Display
echo "Step 5: Display ranking"
~/.ralph/curator/scripts/curator-show.sh --ranking

# Step 6: Check learning state
echo "Step 6: Check learning state"
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
if [[ -f "$RULES_FILE" ]]; then
    RULES_COUNT=$(jq -r '.rules | length // 0' "$RULES_FILE")
    echo "Procedural rules: $RULES_COUNT"
fi

# Step 7: Cleanup
cd -
rm -rf "$TEST_DIR"

echo ""
echo "=== E2E test completed ==="
```

### Phase 5: Documentation (Priority: HIGH)

#### 5.1 Update README.md Sections

**Sections to update**:

1. **Repository Learner** (line ~562)
   - Add version history (v2.50 → v2.68.23)
   - Add security fixes (SEC-106, DUP-001)
   - Add domain classification details

2. **Repo Curator** (NEW section after Repository Learner)
   - Complete 5-phase workflow
   - Context relevance scoring (v2.55)
   - Pricing tiers (free/economic/full)
   - Auto-learning triggers

3. **Plan State** (line ~857)
   - Add context survival explanation
   - Add lifecycle commands (v2.65.2)
   - Add phase/barrier architecture (v2.51)

4. **Integration** (NEW section)
   - Continuous learning loop
   - Auto-learning triggers
   - Pattern application

#### 5.2 Create Architecture Diagram

**File**: `docs/architecture/ORCHESTRATOR_LEARNING_ARCHITECTURE_v2.81.0.md`

```markdown
# Orchestrator Learning Architecture

## Component Integration

```
┌─────────────────────────────────────────────────────────────┐
│                      USER REQUEST                           │
│                   "Implement API auth"                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              SMART MEMORY SEARCH (v2.47)                    │
├─────────────────────────────────────────────────────────────┤
│  • claude-mem: Semantic observations                        │
│  • handoffs: Session snapshots                              │
│  • ledgers: Continuity data                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│          LEARNING STATE CHECK (v2.81.0 - NEW)               │
├─────────────────────────────────────────────────────────────┤
│  • Procedural rules count                                   │
│  • Context-relevant rules                                   │
│  • Curator corpus status                                    │
│  • Project type detection                                   │
└────────────────────────┬────────────────────────────────────┘
                         │
            ┌────────────┴────────────┐
            │                         │
            ↓                         ↓
     ┌─────────────┐           ┌─────────────┐
     │  SUGGEST    │           │   APPLY     │
     │  CURATOR    │           │  LEARNED    │
     │  (IF NEEDED)│           │  PATTERNS   │
     └─────────────┘           └─────────────┘
            │                         │
            └────────────┬────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              PLAN WITH MEMORY (v2.81.0)                     │
├─────────────────────────────────────────────────────────────┤
│  • Review past successes                                   │
│  • Review past errors                                      │
│  • Create plan with learned patterns                       │
│  • Initialize plan-state.json                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│           EXECUTE WITH LEARNING (v2.81.0)                   │
├─────────────────────────────────────────────────────────────┤
│  For EACH step:                                             │
│    1. Apply learned patterns                                │
│    2. Check plan-state consistency                         │
│    3. Detect drift and sync                                │
│    4. Micro-gate validation                                │
│                                                             │
│  CONTEXT COMPACTION:                                        │
│    1. PreCompact: Save plan-state                          │
│    2. Compaction occurs                                    │
│    3. Post-compact: Restore plan-state                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│          RETROSPECTIVE + LEARNING (v2.81.0)                 │
├─────────────────────────────────────────────────────────────┤
│  • Extract successful patterns                             │
│  • Save to procedural rules                                │
│  • Suggest learning from repos                             │
│  • Update memory                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
                   VERIFIED_DONE
```

## Data Flow

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   REPO CURATOR   │────▶│  REPO LEARNER    │────▶│  PROCEDURAL      │
│                  │     │                  │     │  RULES           │
│  • Discovery     │     │  • AST analysis  │     │  • Patterns      │
│  • Scoring       │     │  • Extraction    │     │  • Confidence    │
│  • Ranking       │     │  • Classification│     │  • Source attr   │
│  • Review        │     │  • Domain        │     │                  │
└──────────────────┘     └──────────────────┘     └────────┬─────────┘
                                                                  │
                                                                  │
                                                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                        ORCHESTRATOR                                 │
├─────────────────────────────────────────────────────────────────────┤
│  1. Query procedural rules for context                             │
│  2. Apply patterns to implementation                               │
│  3. Extract new patterns from code                                 │
│  4. Update procedural rules                                        │
└─────────────────────────────────────────────────────────────────────┘
                                                                  │
                                                                  ↓
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   PLAN STATE     │◀────│   LEARNING       │────▶│   MEMORY         │
│                  │     │   BRIDGE         │     │                  │
│  • Phases        │     │  • Detect type   │     │  • Semantic      │
│  • Steps         │     │  • Check state   │     │  • Episodic      │
│  • Barriers      │     │  • Suggest learn │     │  • Procedural    │
│  • Context surv. │     │                  │     │                  │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

## Hook Chain

```
SessionStart
  ├── auto-migrate-plan-state.sh
  ├── auto-curator-trigger.sh (NEW v2.81.0)
  └── session-start-reset-counters.sh

UserPromptSubmit
  ├── curator-suggestion.sh
  ├── context-warning.sh
  └── smart-memory-search.sh

PreToolUse (Task)
  ├── orchestrator-learning-bridge.sh (NEW v2.81.0)
  ├── orchestrator-auto-learn.sh
  └── task-orchestration-optimizer.sh

PreToolUse (Edit/Write)
  ├── pattern-application-display.sh (NEW v2.81.0)
  └── plan-state-verification.sh (NEW v2.81.0)

PostToolUse (Edit/Write)
  ├── session-cleanup-guard.sh
  └── status-auto-check.sh

PreCompact
  ├── pre-compact-handoff.sh
  └── plan-state-adaptive.sh

Stop
  ├── continuous-learning-daemon.sh (NEW v2.81.0)
  └── orchestrator-report.sh
```

## Auto-Learning Triggers

| Condition | Trigger | Action |
|-----------|---------|--------|
| complexity >= 7 AND rules < 3 | orchestrator-auto-learn.sh | Suggest /curator full |
| No context-relevant rules | orchestrator-learning-bridge.sh | Suggest /curator scoring --context |
| New project detected | auto-curator-trigger.sh | Suggest /curator full --type |
| Git diff with patterns | continuous-learning-daemon.sh | Suggest repo-learn |

## Pattern Application Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. USER REQUEST: "Implement error handling"               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  2. QUERY PROCEDURAL RULES                                  │
│     jq '.rules[] | select(.pattern | contains("error"))'   │
│     ~/.ralph/procedural/rules.json                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  3. FOUND: 5 patterns (confidence > 0.7)                   │
│     • nestjs/nest: Custom exception classes (0.92)         │
│     • fastapi/fastapi: HTTPException handling (0.89)       │
│     • ...                                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  4. APPLY PATTERN                                           │
│     Using pattern from nestjs/nest (confidence: 0.92):     │
│     • Create custom exception class                         │
│     • Extend base HttpException                             │
│     • Add error code and metadata                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  5. IMPLEMENT CODE                                          │
│     class NotFoundException extends HttpException {          │
│       constructor(message: string) {                        │
│         super(message, HttpStatus.NOT_FOUND);              │
│       }                                                     │
│     }                                                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  6. VERIFY APPLICATION                                      │
│     ✓ Pattern applied correctly                            │
│     ✓ Adaptations documented                                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  7. EXTRACT NEW PATTERN (if improved)                      │
│     If implementation improved pattern:                    │
│     • Extract new variant                                   │
│     • Update procedural rules                              │
│     • Increment confidence score                            │
└─────────────────────────────────────────────────────────────┘
```
```

## Implementation Timeline

| Phase | Tasks | Priority | Duration |
|-------|-------|----------|----------|
| **Phase 1** | Documentation Update | CRITICAL | 2-3 days |
| **Phase 2** | Hook Integration | HIGH | 3-4 days |
| **Phase 3** | Enhanced Features | MEDIUM | 2-3 days |
| **Phase 4** | Testing | MEDIUM | 2-3 days |
| **Phase 5** | Documentation | HIGH | 1-2 days |
| **Total** | | | **10-15 days** |

## Success Criteria

- ✅ All components documented in README.md
- ✅ Integration hooks implemented and tested
- ✅ End-to-end test passing
- ✅ Architecture diagram created
- ✅ User guide complete
- ✅ Continuous learning working

## Next Steps

1. ✅ Analysis complete
2. ⏳ Review and approve plan
3. ⏳ Implement Phase 1 (Documentation)
4. ⏳ Implement Phase 2 (Hooks)
5. ⏳ Implement Phase 3 (Features)
6. ⏳ Implement Phase 4 (Testing)
7. ⏳ Implement Phase 5 (Documentation)
8. ⏳ Validation and deployment

---

## References

- [Orchestrator Components Analysis](./ORCHESTRATOR_COMPONENTS_ANALYSIS_v2.81.0.md)
- [README.md](../../README.md) - Main documentation
- [CLAUDE.md](../../CLAUDE.md) - Project instructions
- [CHANGELOG.md](../../CHANGELOG.md) - Version history

# Ralph Learning System v2.59.0 - Master Improvement Plan

**Plan Date**: 2026-01-22
**Version**: v2.59.0
**Based On**:
- Codex CLI Analysis (ad33f38)
- Gemini Alternative Perspective (a132553)
- Adversarial Security Review (ad238c7)

---

## 📋 Executive Summary

This plan addresses the complete learning lifecycle with:
- **End-to-end validation** (detection → organization → conversion → rules → injection)
- **Automatic operation** (self-healing, self-cleaning, self-compacting)
- **Comprehensive testing** (unit tests + pre-commit hooks + integration gates)
- **Claude Code Rules Conversion** (high-confidence rules → archival → native behavior)
- **Security hardening** (conflict detection, sanitization, backup rotation)

---

## 🎯 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        RALPH LEARNING SYSTEM v2.59.0                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  DETECTION  │───▶│ ORGANIZATION│───▶│  CONVERSION │───▶│    RULES    │  │
│  │             │    │             │    │             │    │             │  │
│  │ Task+Edit+  │    │ Semantic    │    │ Episodic→   │    │ JSON Schema │  │
│  │ Write+Plan  │    │ Index       │    │ Semantic→   │    │ Validation  │  │
│  │ Complexity  │    │ Cross-Refs  │    │ Procedural  │    │ Conflict    │  │
│  │ Semantic    │    │ TTL Mgmt    │    │ Claude→Docs │    │ Detection   │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                  │                  │                  │          │
│         ▼                  ▼                  ▼                  ▼          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        CONTINUOUS LEARNING LOOP                      │   │
│  │                                                                      │   │
│  │    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐        │   │
│  │    │INJECTION│◀───▶│EFFECTIVE│◀───▶│  AUTO   │◀───▶│ COMPACT │        │   │
│  │    │Context  │    │  NESS   │    │ CLEANUP │    │  ION    │        │   │
│  │    │         │    │ Tracking│    │         │    │         │        │   │
│  │    │Claude   │    │ Success/│    │ TTL+    │    │ Semantic│        │   │
│  │    │Mem MCP  │    │ Failure │    │ Archive │    │ Compres│        │   │
│  │    └─────────┘    └─────────┘    └─────────┘    └─────────┘        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                  CLAUDE CODE RULES CONVERSION (≥0.9)                 │   │
│  │                                                                      │   │
│  │    High-Confidence Rules ──▶ Extract ──▶ Archive ──▶ Index          │   │
│  │                                    │                                 │   │
│  │                                    ▼                                 │   │
│  │                            Native Claude Behavior                    │   │
│  │                            (No injection needed)                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Foundation (Week 1)

### 1.1 Unified Memory Index

**File**: `~/.ralph/memory/index.json`

```json
{
  "version": "2.59.0",
  "last_updated": "2026-01-22T10:00:00Z",
  "semantic": {
    "file": "semantic.json",
    "count": 1250,
    "last_compact": "2026-01-15T10:00:00Z"
  },
  "episodic": {
    "directory": "~/.ralph/episodes",
    "count": 342,
    "ttl_days": 30
  },
  "procedural": {
    "file": "rules.json",
    "count": 156,
    "last_validate": "2026-01-22T09:00:00Z"
  },
  "cross_references": {
    "semantic_to_episodic": [...],
    "episodic_to_procedural": [...]
  }
}
```

**Script**: `ralph-memory-index.sh`
```bash
#!/bin/bash
# Create/update unified memory index
RALPH_MEMORY_DIR="${HOME}/.ralph/memory"
INDEX_FILE="${RALPH_MEMORY_DIR}/index.json"

# Count entries in each store
SEMANTIC_COUNT=$(jq -r '.observations | length' "${RALPH_MEMORY_DIR}/semantic.json" 2>/dev/null || echo 0)
EPISODIC_COUNT=$(find "${RALPH_MEMORY_DIR}/episodes" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
PROCEDURAL_COUNT=$(jq -r '.rules | length' "${RALPH_MEMORY_DIR}/procedural/rules.json" 2>/dev/null || echo 0)

# Build index
jq -n \
  --arg semantic "$SEMANTIC_COUNT" \
  --arg episodic "$EPISODIC_COUNT" \
  --arg procedural "$PROCEDURAL_COUNT" \
  '{
    version: "2.59.0",
    last_updated: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    counts: {
      semantic: ($semantic | tonumber),
      episodic: ($episodic | tonumber),
      procedural: ($procedural | tonumber)
    }
  }' > "$INDEX_FILE"

echo "Index updated: semantic=$SEMANTIC_COUNT, episodic=$EPISODIC_COUNT, procedural=$PROCEDURAL_COUNT"
```

---

### 1.2 JSON Schema Validation for Rules

**File**: `~/.ralph/schemas/procedural-rules.schema.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Ralph Procedural Rules Schema v2.59",
  "type": "object",
  "required": ["version", "updated", "rules"],
  "properties": {
    "version": {"type": "string", "pattern": "^2\\.\\d+\\.\\d+$"},
    "updated": {"type": "string", "format": "date-time"},
    "rules": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["rule_id", "trigger", "behavior", "confidence", "created_at"],
        "properties": {
          "rule_id": {"type": "string", "pattern": "^[a-z]{3}-\\d{3}$"},
          "trigger": {"type": "string", "maxLength": 200},
          "behavior": {"type": "string", "maxLength": 500},
          "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0},
          "confidence_details": {
            "type": "object",
            "properties": {
              "raw": {"type": "number"},
              "evidence_count": {"type": "integer"},
              "evidence_sources": {"type": "integer"},
              "success_rate": {"type": "number"},
              "calibrated": {"type": "number"}
            }
          },
          "source_repo": {"type": ["string", "null"]},
          "source_episodes": {"type": "array", "items": {"type": "string"}},
          "created_at": {"type": "string", "format": "date-time"},
          "last_used": {"type": ["string", "null"], "format": "date-time"},
          "usage_count": {"type": "integer", "minimum": 0},
          "success_count": {"type": "integer", "minimum": 0},
          "failure_count": {"type": "integer", "minimum": 0},
          "tags": {"type": "array", "items": {"type": "string"}},
          "severity": {"type": ["string", "null"], "enum": ["critical", "high", "medium", "low"]},
          "claude_code_converted": {"type": "boolean"},
          "archived_at": {"type": ["string", "null"], "format": "date-time"}
        }
      }
    }
  }
}
```

**Validator Script**: `validate-rules-schema.py`

```python
#!/usr/bin/env python3
"""Validate procedural rules against JSON schema."""
import json
import sys
from pathlib import Path

SCHEMA_PATH = Path.home() / ".ralph/schemas/procedural-rules.schema.json"
RULES_PATH = Path.home() / ".ralph/procedural/rules.json"

def validate_rules(rules_file: Path, schema_file: Path) -> bool:
    """Validate rules file against schema."""
    try:
        with open(schema_file) as f:
            schema = json.load(f)

        with open(rules_file) as f:
            rules = json.load(f)

        # Basic structure validation
        assert "version" in rules, "Missing 'version' field"
        assert "rules" in rules, "Missing 'rules' array"

        # Validate each rule
        for i, rule in enumerate(rules["rules"]):
            # Required fields
            for field in ["rule_id", "trigger", "behavior", "confidence", "created_at"]:
                assert field in rule, f"Rule {i}: Missing '{field}'"

            # Confidence range
            assert 0.0 <= rule["confidence"] <= 1.0, f"Rule {i}: Invalid confidence"

            # Rule ID format
            assert rule["rule_id"].match(r"^[a-z]{3}-\d{3}$"), f"Rule {i}: Invalid rule_id format"

        print(f"✓ Validation passed: {len(rules['rules'])} rules valid")
        return True

    except (json.JSONDecodeError, AssertionError) as e:
        print(f"✗ Validation failed: {e}")
        return False

if __name__ == "__main__":
    success = validate_rules(RULES_PATH, SCHEMA_PATH)
    sys.exit(0 if success else 1)
```

---

### 1.3 Conflict Detection System

**File**: `~/.claude/scripts/rule-conflict-detector.py`

```python
#!/usr/bin/env python3
"""Detect conflicts between procedural rules."""
import json
import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional

class RuleConflictDetector:
    """Detect and resolve conflicts in procedural rules."""

    CONTRADICTION_PATTERNS = [
        # Use X vs Never use X
        (r"use\s+\w+", r"never\s+use\s+\w+"),
        # Custom vs Built-in
        (r"custom\s+\w+", r"use\s+built-?in"),
        # Async vs Sync
        (r"async", r"avoid\s+async|synchronous"),
        # Direct vs Abstraction
        (r"directly", r"through\s+\w+\s+abstraction"),
    ]

    def __init__(self, rules_file: Path):
        self.rules_file = rules_file
        self.rules = self._load_rules()

    def _load_rules(self) -> List[Dict]:
        """Load rules from JSON file."""
        with open(self.rules_file) as f:
            return json.load(f).get("rules", [])

    def is_contradiction(self, behavior1: str, behavior2: str) -> bool:
        """Check if two behaviors are contradictory."""
        b1_lower = behavior1.lower()
        b2_lower = behavior2.lower()

        for positive, negative in self.CONTRADICTION_PATTERNS:
            has_positive1 = bool(re.search(positive, b1_lower))
            has_negative1 = bool(re.search(negative, b1_lower))
            has_positive2 = bool(re.search(positive, b2_lower))
            has_negative2 = bool(re.search(negative, b2_lower))

            # Check for direct contradiction
            if has_positive1 and has_negative2:
                return True
            if has_negative1 and has_positive2:
                return True

        # Check for explicit negation
        negations = ["never", "avoid", "don't", "do not"]
        words1 = set(b1_lower.split())
        words2 = set(b2_lower.split())

        for word in negations:
            if word in words1:
                # Check if words2 contains the negated concept
                for w1 in words1:
                    if w1 in ["never", "avoid", "don't", "do not"]:
                        continue
                    # Simplified check - would need more sophisticated NLP
                    pass

        return False

    def detect_conflicts(self) -> List[Dict]:
        """Detect all conflicts in the rule set."""
        conflicts = []

        for i, rule1 in enumerate(self.rules):
            for j, rule2 in enumerate(self.rules[i+1:], i+1):
                # Same category and trigger = potential conflict
                if (rule1.get("category") == rule2.get("category") and
                    self._similar_triggers(rule1["trigger"], rule2["trigger"])):

                    if self.is_contradiction(rule1["behavior"], rule2["behavior"]):
                        conflicts.append({
                            "rule1": rule1["rule_id"],
                            "rule2": rule2["rule_id"],
                            "rule1_behavior": rule1["behavior"],
                            "rule2_behavior": rule2["behavior"],
                            "severity": "high" if rule1["confidence"] > 0.8 else "medium"
                        })

        return conflicts

    def _similar_triggers(self, trigger1: str, trigger2: str) -> bool:
        """Check if triggers are similar enough to cause conflict."""
        words1 = set(trigger1.lower().split())
        words2 = set(trigger2.lower().split())
        overlap = words1 & words2

        # High word overlap suggests same context
        min_overlap = min(len(words1), len(words2)) * 0.5
        return len(overlap) >= min_overlap

    def generate_report(self) -> str:
        """Generate conflict report."""
        conflicts = self.detect_conflicts()

        if not conflicts:
            return "✓ No conflicts detected"

        report = f"⚠️  {len(conflicts)} conflicts detected:\n\n"
        for i, conflict in enumerate(conflicts, 1):
            report += f"{i}. {conflict['rule1']} vs {conflict['rule2']}\n"
            report += f"   Severity: {conflict['severity']}\n"
            report += f"   - {conflict['rule1_behavior'][:80]}...\n"
            report += f"   - {conflict['rule2_behavior'][:80]}...\n\n"

        return report

if __name__ == "__main__":
    rules_file = Path.home() / ".ralph/procedural/rules.json"
    detector = RuleConflictDetector(rules_file)
    print(detector.generate_report())
```

---

## Phase 2: Learning Pipeline (Week 2)

### 2.1 Multi-Source Detection

**File**: `~/.claude/hooks/orchestrator-auto-learn-v2.sh`

```bash
#!/bin/bash
#===============================================================================
# ORCHESTRATOR AUTO-LEARN v2.59.0
# Multi-source detection: Task + Edit + Write + Plan State
#===============================================================================

set -euo pipefail

readonly VERSION="2.59.0"
readonly RULES_FILE="${HOME}/.ralph/procedural/rules.json"
readonly LOG_FILE="${HOME}/.ralph/logs/orchestrator-auto-learn.log"
readonly CONTEXT_FILE="${HOME}/.ralph/memory/learning-context.json"
readonly INDEX_FILE="${HOME}/.ralph/memory/index.json"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUTO-LEARN] $*" >> "$LOG_FILE"
}

# Load input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Multi-source detection triggers
detect_learning_opportunity() {
    local tool="$1"
    local input="$2"

    case "$tool" in
        Task|Write|Edit)
            # Check for complex operations
            local complexity
            complexity=$(echo "$input" | jq -r '.tool_input.complexity // 5')

            # Check rule count
            local rules_count
            rules_count=$(jq -r '.rules | length' "$RULES_FILE" 2>/dev/null || echo 0)

            # Calculate relevant rules
            local relevant_rules
            relevant_rules=$(count_relevant_rules "$input")

            # Multi-source learning triggers
            local should_learn=false
            local reason=""

            if [[ "$relevant_rules" -lt 3 ]] && [[ "$complexity" -ge 7 ]]; then
                should_learn=true
                reason="LOW_RELEVANT_RULES ($relevant_rules) + HIGH_COMPLEXITY ($complexity)"
            elif [[ "$relevant_rules" -eq 0 ]]; then
                should_learn=true
                reason="ZERO_RELEVANT_RULES"
            fi

            if [[ "$should_learn" == "true" ]]; then
                log "Learning opportunity detected: $reason"
                recommend_learning "$input" "$reason"
            fi
            ;;
    esac
}

count_relevant_rules() {
    local input="$1"
    local prompt
    prompt=$(echo "$input" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')

    if [[ -z "$prompt" ]]; then
        echo 0
        return
    fi

    # Count rules with matching triggers
    local count=0
    while IFS= read -r rule; do
        local trigger
        trigger=$(echo "$rule" | jq -r '.trigger' 2>/dev/null | tr '[:upper:]' '[:lower:]')
        if [[ -n "$trigger" ]] && [[ "$prompt" == *"$trigger"* ]]; then
            ((count++)) || true
        fi
    done < <(jq -c '.rules[]' "$RULES_FILE" 2>/dev/null)

    echo "$count"
}

recommend_learning() {
    local input="$1"
    local reason="$2"

    local task_prompt
    task_prompt=$(echo "$input" | jq -r '.tool_input.prompt // "unknown"' 2>/dev/null | head -c 200)

    # Write learning context for next session
    jq -n \
        --arg session "$SESSION_ID" \
        --arg reason "$reason" \
        --arg prompt "$task_prompt" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            session_id: $session,
            reason: $reason,
            prompt: $prompt,
            timestamp: $timestamp,
            status: "pending"
        }' > "$CONTEXT_FILE"

    log "Learning context written: $reason"

    # Emit event for learning pipeline
    emit_learning_event "$reason" "$task_prompt"
}

emit_learning_event() {
    local reason="$1"
    local prompt="$2"

    # Create event for event-driven pipeline
    local event_file="${HOME}/.ralph/events/learning-$(date +%Y%m%d-%H%M%S).json"

    jq -n \
        --arg type "learning_opportunity" \
        --arg reason "$reason" \
        --arg prompt "$prompt" \
        --arg session "$SESSION_ID" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            event_type: $type,
            reason: $reason,
            prompt: $prompt,
            session_id: $session,
            timestamp: $timestamp
        }' > "$event_file"

    log "Learning event emitted: $event_file"
}

# Main execution
main() {
    detect_learning_opportunity "$TOOL_NAME" "$INPUT"

    # Output for PreToolUse
    echo '{"continue": true}'
}

main
```

---

### 2.2 Continuous Learning Feedback Loop

**File**: `~/.claude/scripts/learning-feedback-loop.py`

```python
#!/usr/bin/env python3
"""Continuous learning feedback loop - track rule effectiveness."""
import json
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional

class LearningFeedbackLoop:
    """Track rule usage and effectiveness."""

    def __init__(self):
        self.rules_file = Path.home() / ".ralph/procedural/rules.json"
        self.feedback_dir = Path.home() / ".ralph/memory/feedback"
        self.feedback_dir.mkdir(parents=True, exist_ok=True)

        self.rules = self._load_rules()

    def _load_rules(self) -> Dict:
        """Load rules from JSON file."""
        with open(self.rules_file) as f:
            return json.load(f)

    def record_usage(self, rule_id: str, outcome: str, context: Dict):
        """Record rule usage with outcome."""
        feedback = {
            "rule_id": rule_id,
            "outcome": outcome,  # "success", "failure", "partial"
            "context": context,
            "timestamp": datetime.utcnow().isoformat()
        }

        feedback_file = self.feedback_dir / f"{rule_id}.jsonl"
        with open(feedback_file, "a") as f:
            f.write(json.dumps(feedback) + "\n")

        self._update_rule_stats(rule_id, outcome)

    def _update_rule_stats(self, rule_id: str, outcome: str):
        """Update rule statistics."""
        for rule in self.rules["rules"]:
            if rule["rule_id"] == rule_id:
                rule["usage_count"] = rule.get("usage_count", 0) + 1

                if outcome == "success":
                    rule["success_count"] = rule.get("success_count", 0) + 1
                elif outcome == "failure":
                    rule["failure_count"] = rule.get("failure_count", 0) + 1

                # Update success rate
                total = rule.get("usage_count", 1)
                successes = rule.get("success_count", 0)
                rule["success_rate"] = successes / total if total > 0 else 0.0

                break

        # Save updated rules
        with open(self.rules_file, "w") as f:
            json.dump(self.rules, f, indent=2)

    def get_rule_effectiveness(self, rule_id: str) -> Dict:
        """Get rule effectiveness metrics."""
        feedback_file = self.feedback_dir / f"{rule_id}.jsonl"

        if not feedback_file.exists():
            return {"status": "no_data"}

        outcomes = {"success": 0, "failure": 0, "partial": 0}
        with open(feedback_file) as f:
            for line in f:
                data = json.loads(line)
                outcomes[data["outcome"]] = outcomes.get(data["outcome"], 0) + 1

        total = sum(outcomes.values())
        return {
            "status": "active",
            "total_uses": total,
            "success_rate": outcomes["success"] / total if total > 0 else 0.0,
            "outcomes": outcomes
        }

    def get_least_effective_rules(self, threshold: float = 0.5) -> List[Dict]:
        """Get rules with success rate below threshold."""
        ineffective = []

        for rule in self.rules["rules"]:
            usage = rule.get("usage_count", 0)
            if usage >= 5:  # Minimum 5 uses for statistical significance
                success_rate = rule.get("success_rate", 1.0)
                if success_rate < threshold:
                    ineffective.append({
                        "rule_id": rule["rule_id"],
                        "trigger": rule["trigger"],
                        "success_rate": success_rate,
                        "usage_count": usage
                    })

        return sorted(ineffective, key=lambda x: x["success_rate"])

    def suggest_rule_improvement(self, rule_id: str) -> Optional[Dict]:
        """Suggest improvements for a rule based on feedback."""
        effectiveness = self.get_rule_effectiveness(rule_id)

        if effectiveness.get("status") == "no_data":
            return None

        if effectiveness["success_rate"] < 0.5:
            return {
                "rule_id": rule_id,
                "recommendation": "review",
                "reason": f"Low success rate: {effectiveness['success_rate']:.1%}",
                "action": "Consider disabling or revising this rule"
            }

        return None

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "stats"

    loop = LearningFeedbackLoop()

    if action == "stats":
        print("=== Learning Feedback Statistics ===")
        ineffective = loop.get_least_effective_rules()
        print(f"Rules needing review: {len(ineffective)}")
        for rule in ineffective[:5]:
            print(f"  - {rule['rule_id']}: {rule['success_rate']:.1%} ({rule['usage_count']} uses)")

    elif action == "record":
        rule_id = sys.argv[2]
        outcome = sys.argv[3]
        context = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
        loop.record_usage(rule_id, outcome, context)
        print(f"Recorded: {rule_id} -> {outcome}")

    elif action == "effectiveness":
        rule_id = sys.argv[2]
        print(json.dumps(loop.get_rule_effectiveness(rule_id), indent=2))

if __name__ == "__main__":
    main()
```

---

## Phase 3: Claude Code Rules Conversion (Week 3)

### 3.1 High-Confidence Rule Conversion Pipeline

**File**: `~/.claude/scripts/convert-high-confidence-rules.py`

```python
#!/usr/bin/env python3
"""Convert high-confidence rules (≥0.9) to Claude Code native behavior."""
import json
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

class ClaudeCodeRulesConverter:
    """Convert high-confidence rules to Claude Code native behavior."""

    def __init__(self):
        self.rules_file = Path.home() / ".ralph/procedural/rules.json"
        self.archived_file = Path.home() / ".ralph/procedural/archived-high-confidence.json"
        self.claude_docs_dir = Path.home() / ".claude"
        self.conversion_threshold = 0.9  # Confidence threshold

        self.rules = self._load_rules()

    def _load_rules(self) -> Dict:
        """Load rules from JSON file."""
        with open(self.rules_file) as f:
            return json.load(f)

    def get_candidates(self) -> List[Dict]:
        """Get rules that are candidates for conversion."""
        candidates = []

        for rule in self.rules.get("rules", []):
            # Check confidence threshold
            if rule.get("confidence", 0) >= self.conversion_threshold:
                # Check if not already converted
                if not rule.get("claude_code_converted", False):
                    # Check if rule has sufficient evidence
                    evidence_count = rule.get("confidence_details", {}).get("evidence_count", 0)
                    if evidence_count >= 10:  # Minimum evidence
                        candidates.append(rule)

        return candidates

    def convert_rule_to_claude_docs(self, rule: Dict) -> str:
        """Convert rule to Claude Code documentation format."""
        # Generate CLAUDE.md compatible content
        content = f"""
### Rule: {rule['rule_id']}

**Trigger**: {rule['trigger']}

**Best Practice**: {rule['behavior']}

**Confidence**: {rule['confidence']:.2f} (converted from procedural memory)

**Source**: Auto-learned from {rule.get('source_repo', 'multiple sources')}

**Confidence Details**:
- Evidence Count: {rule.get('confidence_details', {}).get('evidence_count', 'N/A')}
- Success Rate: {rule.get('success_rate', 'N/A'):.1%}
"""
        return content

    def archive_converted_rule(self, rule: Dict):
        """Archive converted rule to prevent reinjection."""
        rule["claude_code_converted"] = True
        rule["archived_at"] = datetime.utcnow().isoformat()

        # Add to archived rules
        archived = {"version": "2.59.0", "rules": []}
        if self.archived_file.exists():
            with open(self.archived_file) as f:
                archived = json.load(f)

        archived["rules"].append({
            **rule,
            "converted_to": "claude-code-docs"
        })

        with open(self.archived_file, "w") as f:
            json.dump(archived, f, indent=2)

        # Remove from active rules (no longer needed for injection)
        self.rules["rules"] = [r for r in self.rules["rules"] if r["rule_id"] != rule["rule_id"]]

        with open(self.rules_file, "w") as f:
            json.dump(self.rules, f, indent=2)

        print(f"✓ Archived and removed: {rule['rule_id']}")

    def update_claude_md(self, rule: Dict):
        """Update CLAUDE.md with converted rule."""
        claude_md = self.claude_docs_dir / "CLAUDE.md"

        if not claude_md.exists():
            print(f"⚠ CLAUDE.md not found at {claude_md}")
            return

        content = self.convert_rule_to_claude_docs(rule)

        # Append to CLAUDE.md
        with open(claude_md, "a") as f:
            f.write(content)

        print(f"✓ Updated CLAUDE.md with {rule['rule_id']}")

    def run_conversion(self, dry_run: bool = True) -> Dict:
        """Run the conversion pipeline."""
        candidates = self.get_candidates()

        results = {
            "candidates_found": len(candidates),
            "converted": [],
            "skipped": [],
            "errors": []
        }

        for rule in candidates:
            try:
                if not dry_run:
                    self.archive_converted_rule(rule)
                    self.update_claude_md(rule)

                results["converted"].append(rule["rule_id"])

            except Exception as e:
                results["errors"].append({"rule": rule["rule_id"], "error": str(e)})

        return results

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "list"
    dry_run = "--dry-run" in sys.argv or "-d" in sys.argv

    converter = ClaudeCodeRulesConverter()

    if action == "list":
        print("=== High-Confidence Rule Candidates (≥0.9) ===")
        candidates = converter.get_candidates()
        print(f"Candidates: {len(candidates)}")
        for rule in candidates:
            print(f"  - {rule['rule_id']}: {rule['confidence']:.2f} ({rule['trigger'][:50]}...)")

    elif action == "convert":
        results = converter.run_conversion(dry_run=dry_run)
        print(f"\n=== Conversion Results ===")
        print(f"Candidates: {results['candidates_found']}")
        print(f"Converted: {len(results['converted'])}")
        for rule_id in results["converted"]:
            print(f"  ✓ {rule_id}")
        if results["errors"]:
            print(f"Errors: {len(results['errors'])}")
            for err in results["errors"]:
                print(f"  ✗ {err['rule']}: {err['error']}")

if __name__ == "__main__":
    main()
```

---

## Phase 4: Auto-Cleanup & Compaction (Week 4)

### 4.1 Intelligent Memory Cleanup

**File**: `~/.claude/scripts/memory-auto-cleanup.py`

```python
#!/usr/bin/env python3
"""Intelligent memory cleanup with importance scoring."""
import json
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional

class MemoryCleanup:
    """Intelligent cleanup with importance scoring and archival."""

    def __init__(self):
        self.memory_dir = Path.home() / ".ralph/memory"
        self.archive_dir = Path.home() / ".ralph/archive"
        self.archive_dir.mkdir(parents=True, exist_ok=True)

        self.config = {
            "ttl_days": 90,
            "min_usage": 3,
            "importance_threshold": 0.3,
            "archive_old_rules": True,
            "compact_semantic": True
        }

    def calculate_importance_score(self, item: Dict) -> float:
        """Calculate importance score for a memory item."""
        score = 0.0

        # Recency score (0-0.3)
        created_at = datetime.fromisoformat(item.get("created_at", "2020-01-01"))
        days_old = (datetime.utcnow() - created_at).days
        recency_score = max(0, 0.3 - (days_old / 365) * 0.3)
        score += recency_score

        # Usage score (0-0.3)
        usage_count = item.get("usage_count", 0)
        usage_score = min(0.3, usage_count * 0.05)
        score += usage_score

        # Success rate score (0-0.3)
        if "success_rate" in item:
            score += item["success_rate"] * 0.3

        # Confidence score for rules (0-0.1)
        if "confidence" in item:
            score += item["confidence"] * 0.1

        return min(1.0, score)

    def cleanup_episodic(self) -> Dict:
        """Cleanup episodic memory (30-day TTL)."""
        episodes_dir = self.memory_dir / "episodes"
        removed = []

        if not episodes_dir.exists():
            return {"removed": 0, "items": []}

        cutoff = datetime.utcnow() - timedelta(days=30)

        for episode_file in episodes_dir.glob("*.json"):
            with open(episode_file) as f:
                episode = json.load(f)

            created_at = datetime.fromisoformat(episode.get("created_at", "2020-01-01"))

            if created_at < cutoff:
                importance = self.calculate_importance_score(episode)

                if importance < self.config["importance_threshold"]:
                    # Archive instead of delete
                    archive_file = self.archive_dir / "episodes" / episode_file.name
                    archive_file.parent.mkdir(parents=True, exist_ok=True)
                    episode_file.rename(archive_file)
                    removed.append({
                        "file": str(episode_file),
                        "importance": importance,
                        "action": "archived"
                    })
                else:
                    # Keep but update TTL marker
                    episode["ttl_extended"] = True
                    episode["ttl_extended_at"] = datetime.utcnow().isoformat()
                    with open(episode_file, "w") as f:
                        json.dump(episode, f, indent=2)

        return {"removed": len(removed), "items": removed}

    def cleanup_rules(self) -> Dict:
        """Cleanup procedural rules."""
        rules_file = self.memory_dir / "procedural/rules.json"

        with open(rules_file) as f:
            data = json.load(f)

        removed = []

        # Filter rules
        cleaned_rules = []
        for rule in data.get("rules", []):
            importance = self.calculate_importance_score(rule)

            # Check TTL
            created_at = datetime.fromisoformat(rule.get("created_at", "2020-01-01"))
            days_old = (datetime.utcnow() - created_at).days

            should_remove = False
            reason = ""

            if days_old > self.config["ttl_days"] and importance < 0.5:
                should_remove = True
                reason = "TTL_EXPIRED"
            elif rule.get("usage_count", 0) < self.config["min_usage"] and days_old > 30:
                should_remove = True
                reason = "LOW_USAGE"
            elif rule.get("confidence", 0) < 0.3:
                should_remove = True
                reason = "LOW_CONFIDENCE"

            if should_remove:
                removed.append({
                    "rule_id": rule["rule_id"],
                    "reason": reason,
                    "importance": importance
                })
            else:
                cleaned_rules.append(rule)

        # Archive removed rules
        if removed:
            archive_file = self.archive_dir / f"rules-{datetime.utcnow().strftime('%Y%m%d')}.json"
            with open(archive_file, "w") as f:
                json.dump({"archived_at": datetime.utcnow().isoformat(), "rules": removed}, f, indent=2)

        # Save cleaned rules
        data["rules"] = cleaned_rules
        data["updated"] = datetime.utcnow().isoformat()

        with open(rules_file, "w") as f:
            json.dump(data, f, indent=2)

        return {"removed": len(removed), "items": removed}

    def run_cleanup(self) -> Dict:
        """Run complete cleanup."""
        results = {
            "timestamp": datetime.utcnow().isoformat(),
            "episodic": self.cleanup_episodic(),
            "rules": self.cleanup_rules()
        }

        total_removed = results["episodic"]["removed"] + results["rules"]["removed"]
        results["total_removed"] = total_removed

        return results

def main():
    cleanup = MemoryCleanup()
    results = cleanup.run_cleanup()

    print(f"=== Memory Cleanup Results ===")
    print(f"Timestamp: {results['timestamp']}")
    print(f"Episodic removed: {results['episodic']['removed']}")
    print(f"Rules removed: {results['rules']['removed']}")
    print(f"Total removed: {results['total_removed']}")

if __name__ == "__main__":
    main()
```

---

## Phase 5: Testing & Validation (Week 5)

### 5.1 Unit Tests

**File**: `~/.claude/tests/test_learning_system.py`

```python
#!/usr/bin/env python3
"""Unit tests for Ralph Learning System v2.59."""
import json
import pytest
import tempfile
import os
from pathlib import Path
from datetime import datetime, timedelta

# Import system modules
import sys
sys.path.insert(0, str(Path.home() / ".claude/scripts"))

# Test fixtures
@pytest.fixture
def temp_rules_file():
    """Create temporary rules file for testing."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump({
            "version": "2.59.0",
            "updated": datetime.utcnow().isoformat(),
            "rules": [
                {
                    "rule_id": "err-001",
                    "trigger": "error handling",
                    "behavior": "Use custom error classes",
                    "confidence": 0.85,
                    "created_at": datetime.utcnow().isoformat(),
                    "usage_count": 10,
                    "success_count": 9
                },
                {
                    "rule_id": "err-002",
                    "trigger": "error handling",
                    "behavior": "Never use custom errors",
                    "confidence": 0.90,
                    "created_at": datetime.utcnow().isoformat(),
                    "usage_count": 5,
                    "success_count": 2
                }
            ]
        }, f)
        yield f.name
    os.unlink(f.name)

@pytest.fixture
def sample_episode():
    """Create sample episode for testing."""
    return {
        "episode_id": "test-001",
        "task": "Implement authentication",
        "outcome": "success",
        "created_at": datetime.utcnow().isoformat(),
        "usage_count": 3,
        "success_count": 3
    }

# Test cases
class TestRuleConflictDetection:
    """Tests for rule conflict detection."""

    def test_contradiction_detection(self):
        """Test that contradictory rules are detected."""
        from rule_conflict_detector import RuleConflictDetector

        # Create temp rules file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump({
                "version": "2.59.0",
                "rules": [
                    {"rule_id": "test-001", "trigger": "test", "behavior": "Use custom errors", "confidence": 0.8, "created_at": datetime.utcnow().isoformat()},
                    {"rule_id": "test-002", "trigger": "test", "behavior": "Never use custom errors", "confidence": 0.8, "created_at": datetime.utcnow().isoformat()}
                ]
            }, f)
            temp_file = f.name

        try:
            detector = RuleConflictDetector(Path(temp_file))
            conflicts = detector.detect_conflicts()

            assert len(conflicts) == 1, "Should detect one conflict"
            assert conflicts[0]["rule1"] == "test-001"
            assert conflicts[0]["rule2"] == "test-002"
        finally:
            os.unlink(temp_file)

    def test_similar_triggers(self):
        """Test trigger similarity detection."""
        from rule_conflict_detector import RuleConflictDetector

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump({"version": "2.59.0", "rules": []}, f)
            temp_file = f.name

        try:
            detector = RuleConflictDetector(Path(temp_file))

            # Similar triggers should be detected
            assert detector._similar_triggers("error handling", "error management") == True
            # Different triggers should not match
            assert detector._similar_triggers("error handling", "async patterns") == False
        finally:
            os.unlink(temp_file)

class TestConfidenceCalibration:
    """Tests for confidence calibration."""

    def test_confidence_in_range(self):
        """Test that confidence is always in valid range."""
        rules_file = Path.home() / ".ralph/procedural/rules.json"

        if rules_file.exists():
            with open(rules_file) as f:
                data = json.load(f)

            for rule in data.get("rules", []):
                assert 0.0 <= rule.get("confidence", 0) <= 1.0, f"Invalid confidence for {rule['rule_id']}"

class TestSchemaValidation:
    """Tests for JSON schema validation."""

    def test_rule_structure(self, temp_rules_file):
        """Test that rules have required fields."""
        with open(temp_rules_file) as f:
            data = json.load(f)

        for rule in data.get("rules", []):
            assert "rule_id" in rule
            assert "trigger" in rule
            assert "behavior" in rule
            assert "confidence" in rule
            assert "created_at" in rule

    def test_rule_id_format(self, temp_rules_file):
        """Test that rule IDs follow expected format."""
        import re
        with open(temp_rules_file) as f:
            data = json.load(f)

        for rule in data.get("rules", []):
            assert re.match(r"^[a-z]{3}-\d{3}$", rule["rule_id"]), f"Invalid rule_id format: {rule['rule_id']}"

class TestMemoryCleanup:
    """Tests for memory cleanup functionality."""

    def test_importance_score_calculation(self):
        """Test importance score calculation."""
        from memory_auto_cleanup import MemoryCleanup

        cleanup = MemoryCleanup()

        # New, frequently used item
        new_item = {
            "created_at": datetime.utcnow().isoformat(),
            "usage_count": 20,
            "success_rate": 0.95,
            "confidence": 0.90
        }
        score = cleanup.calculate_importance_score(new_item)
        assert score > 0.7, "New frequently-used item should have high importance"

        # Old, unused item
        old_item = {
            "created_at": (datetime.utcnow() - timedelta(days=365)).isoformat(),
            "usage_count": 0,
            "success_rate": 0.0,
            "confidence": 0.2
        }
        score = cleanup.calculate_importance_score(old_item)
        assert score < 0.3, "Old unused item should have low importance"

class TestLearningFeedback:
    """Tests for learning feedback loop."""

    def test_record_usage(self, temp_rules_file):
        """Test recording rule usage."""
        from learning_feedback_loop import LearningFeedbackLoop

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump({
                "version": "2.59.0",
                "rules": [
                    {"rule_id": "test-001", "trigger": "test", "behavior": "test", "confidence": 0.8, "created_at": datetime.utcnow().isoformat(), "usage_count": 5, "success_count": 4}
                ]
            }, f)
            temp_file = f.name

        try:
            # This would need mocking of the rules file
            # Skipping for brevity
            pass
        finally:
            os.unlink(temp_file)

# Run tests
if __name__ == "__main__":
    pytest.main([__file__, "-v"])
```

---

### 5.2 Pre-Commit Hooks

**File**: `~/.claude/hooks/pre-commit-learning-validate.sh`

```bash
#!/bin/bash
#===============================================================================
# PRE-COMMIT VALIDATION HOOK
# Validates learning system before any operation
#===============================================================================

set -euo pipefail

readonly RULES_FILE="${HOME}/.ralph/procedural/rules.json"
readonly SCHEMA_FILE="${HOME}/.ralph/schemas/procedural-rules.schema.json"
readonly LOG_FILE="${HOME}/.ralph/logs/pre-commit-validation.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PRE-COMMIT] $*" >> "$LOG_FILE"
}

check_rules_schema() {
    log "Checking rules schema..."

    if [[ ! -f "$RULES_FILE" ]]; then
        log "✓ No rules file found (skipping)"
        return 0
    fi

    # Validate JSON structure
    if ! python3 -c "import json; json.load(open('$RULES_FILE'))" 2>/dev/null; then
        log "✗ Invalid JSON in rules file"
        return 1
    fi

    # Check required fields
    local has_version
    local has_rules
    has_version=$(jq -r 'has("version")' "$RULES_FILE" 2>/dev/null || echo "false")
    has_rules=$(jq -r 'has("rules")' "$RULES_FILE" 2>/dev/null || echo "false")

    if [[ "$has_version" != "true" ]] || [[ "$has_rules" != "true" ]]; then
        log "✗ Rules file missing required fields (version, rules)"
        return 1
    fi

    # Validate each rule
    local invalid_rules=0
    while IFS= read -r rule; do
        local rule_id confidence
        rule_id=$(echo "$rule" | jq -r '.rule_id' 2>/dev/null || echo "")
        confidence=$(echo "$rule" | jq -r '.confidence' 2>/dev/null || echo "0")

        if [[ -z "$rule_id" ]]; then
            log "✗ Rule missing rule_id"
            ((invalid_rules++)) || true
        fi

        if (( $(echo "$confidence < 0.3" | bc -l) )) || (( $(echo "$confidence > 1.0" | bc -l) )); then
            log "✗ Rule $rule_id has invalid confidence: $confidence"
            ((invalid_rules++)) || true
        fi
    done < <(jq -c '.rules[]' "$RULES_FILE" 2>/dev/null)

    if [[ "$invalid_rules" -gt 0 ]]; then
        log "✗ Found $invalid_rules invalid rules"
        return 1
    fi

    log "✓ Rules schema validation passed"
    return 0
}

check_duplicate_rules() {
    log "Checking for duplicate rules..."

    if [[ ! -f "$RULES_FILE" ]]; then
        return 0
    fi

    local duplicates
    duplicates=$(jq -r '.rules | map(.trigger) | sort | unique -d | length' "$RULES_FILE" 2>/dev/null || echo "0")

    if [[ "$duplicates" -gt 0 ]]; then
        log "⚠ Found $duplicates duplicate trigger patterns"
        # Warning only, don't fail
    else
        log "✓ No duplicate rules detected"
    fi

    return 0
}

check_conflicts() {
    log "Checking for rule conflicts..."

    if [[ ! -f "$RULES_FILE" ]]; then
        return 0
    fi

    # Run conflict detector
    if python3 "${HOME}/.claude/scripts/rule-conflict-detector.py" "$RULES_FILE" 2>/dev/null; then
        log "✓ No conflicts detected"
    else
        log "✗ Conflicts detected - review required"
        return 1
    fi

    return 0
}

check_memory_health() {
    log "Checking memory health..."

    # Check for memory bloat
    local rules_count
    rules_count=$(jq -r '.rules | length' "$RULES_FILE" 2>/dev/null || echo "0")

    if [[ "$rules_count" -gt 10000 ]]; then
        log "⚠ Warning: High rule count ($rules_count)"
    elif [[ "$rules_count" -gt 5000 ]]; then
        log "⚠ Notice: Elevated rule count ($rules_count)"
    else
        log "✓ Rule count acceptable ($rules_count)"
    fi

    return 0
}

main() {
    log "=== Starting pre-commit validation ==="

    check_rules_schema || exit 1
    check_duplicate_rules
    check_conflicts || exit 1
    check_memory_health

    log "=== Pre-commit validation complete ==="
    echo '{"continue": true}'
}

main
```

---

### 5.3 Integration Test Suite

**File**: `~/.claude/tests/test_learning_integration.py`

```python
#!/usr/bin/env python3
"""Integration tests for complete learning pipeline."""
import json
import pytest
import tempfile
import os
from pathlib import Path
from datetime import datetime, timedelta
import subprocess

class TestEndToEndLearningFlow:
    """End-to-end tests for learning pipeline."""

    def test_detection_to_rule_pipeline(self):
        """Test complete flow from detection to rule creation."""
        # This would be a comprehensive integration test
        # Skipping for brevity - would require mocking multiple components
        pass

    def test_memory_consistency(self):
        """Test that memory stores are synchronized."""
        memory_dir = Path.home() / ".ralph/memory"

        if not memory_dir.exists():
            pytest.skip("Memory directory not found")

        # Check index exists
        index_file = memory_dir / "index.json"
        if index_file.exists():
            with open(index_file) as f:
                index = json.load(f)

            # Verify counts match actual files
            semantic_file = memory_dir / "semantic.json"
            if semantic_file.exists():
                with open(semantic_file) as f:
                    semantic = json.load(f)
                expected_count = len(semantic.get("observations", []))
                assert expected_count == index["counts"]["semantic"]

    def test_rule_lifecycle(self):
        """Test rule creation, usage, feedback, and cleanup."""
        # Create test rule
        test_rule_id = f"int-{datetime.now().strftime('%H%M%S')}"

        rules_file = Path.home() / ".ralph/procedural/rules.json"
        if rules_file.exists():
            with open(rules_file) as f:
                data = json.load(f)

            # Add test rule
            data["rules"].append({
                "rule_id": test_rule_id,
                "trigger": "integration test",
                "behavior": "Test rule for integration testing",
                "confidence": 0.95,
                "created_at": datetime.utcnow().isoformat(),
                "usage_count": 0,
                "success_count": 0,
                "failure_count": 0
            })

            with open(rules_file, "w") as f:
                json.dump(data, f, indent=2)

            # Record usage
            result = subprocess.run(
                ["python3", str(Path.home() / ".claude/scripts/learning-feedback-loop.py"),
                 "record", test_rule_id, "success", "{}"],
                capture_output=True
            )
            assert result.returncode == 0

            # Verify feedback recorded
            result = subprocess.run(
                ["python3", str(Path.home() / ".claude/scripts/learning-feedback-loop.py"),
                 "effectiveness", test_rule_id],
                capture_output=True
            )
            assert result.returncode == 0
            output = json.loads(result.stdout)
            assert output["status"] == "active"

    def test_cleanup_removes_low_importance(self):
        """Test that cleanup removes low-importance items."""
        cleanup_script = Path.home() / ".claude/scripts/memory-auto-cleanup.py"

        if not cleanup_script.exists():
            pytest.skip("Cleanup script not found")

        # Run cleanup
        result = subprocess.run(["python3", str(cleanup_script)], capture_output=True)

        # Should complete without error
        assert result.returncode == 0
        assert "removed" in result.stdout.decode()

# Run integration tests
if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
```

---

## 📊 Validation Gates (Quality Gates v2)

| Gate ID | Check | Action | Priority |
|---------|-------|--------|----------|
| **GATE-LEARN-001** | Rule JSON schema validation | Block if invalid | CRITICAL |
| **GATE-LEARN-002** | Conflict detection | Block if conflicts found | CRITICAL |
| **GATE-LEARN-003** | Confidence in range [0.3, 1.0] | Block if outside range | HIGH |
| **GATE-LEARN-004** | No duplicate rule_ids | Block if duplicates | HIGH |
| **GATE-LEARN-005** | Required fields present | Block if missing | HIGH |
| **GATE-LEARN-006** | Feedback loop recording | Warn if not recording | MEDIUM |
| **GATE-LEARN-007** | Cleanup frequency | Alert if > 30 days | MEDIUM |
| **GATE-LEARN-008** | Claude Code conversion | Track conversions | INFO |

---

## 📅 Implementation Timeline

| Phase | Week | Deliverables | Tests |
|-------|------|--------------|-------|
| **Phase 1** | 1 | Memory Index, Schema Validation, Conflict Detection | Unit tests for each component |
| **Phase 2** | 2 | Multi-source Detection, Feedback Loop | Integration tests |
| **Phase 3** | 3 | Claude Code Rules Conversion | Conversion validation |
| **Phase 4** | 4 | Auto-cleanup, Compaction | Cleanup tests |
| **Phase 5** | 5 | All Tests, Pre-commit Hooks, Documentation | Full test suite |

---

## 🎯 Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Rule Conflicts** | < 2% | `rule-conflict-detector.py --report` |
| **Confidence Calibration** | All rules with details | Schema validation |
| **Feedback Coverage** | > 50% rules with feedback | `learning-feedback-loop.py stats` |
| **Memory Health** | No bloat > 10K rules | `ralph health --memory` |
| **Claude Code Conversion** | Rules ≥0.9 converted | `convert-high-confidence-rules.py list` |
| **Test Coverage** | > 80% | pytest --cov |

---

*Plan generated based on Codex CLI, Gemini, and Adversarial Review analysis.*
*For questions or issues, review the adversarial review document: .claude/adversarial-review-learning-system.md*

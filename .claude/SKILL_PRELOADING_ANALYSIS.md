# Skill Preloading Analysis: Claude Code Skills vs. Ralph Loop Learning System v2.59

> **Analysis Date**: 2026-01-22
> **Version**: v2.59.0
> **Reference**: [Builder.io: Agent Skills, Rules, and Commands](https://www.builder.io/blog/agent-skills-rules-commands)

---

## Executive Summary

This document analyzes two distinct approaches for injecting knowledge into Claude Code subagents:

| Approach | Location | Mechanism | Activation |
|----------|----------|-----------|------------|
| **Skill Preloading** | `~/.claude/skills/` | Context-aware auto-loading | Automatic when task matches description |
| **Procedural Injection** | `~/.ralph/procedural/rules.json` | Hook-based injection | PreToolUse hook on Task tool |

**Key Finding**: The Learning System v2.59 procedural rules injection is fundamentally different from skill preloading. They serve complementary purposes and can be combined in a hybrid approach.

---

## 1. Claude Code Skills Architecture

### 1.1 Skill Structure

Skills in Claude Code follow a standardized structure:

```
skill-name/
├── skill.yaml              # Metadata (name, description, triggers, allowed-tools)
├── SKILL.md                # Full documentation and guidance
└── references/             # Additional reference materials
    └── *.md
```

**Example skill.yaml**:
```yaml
name: curator-repo-learn
description: |
  Curator quality repositories and learn best practices from GitHub.
  Provides commands for discovery, scoring, ranking, and pattern extraction.
triggers:
  - "curate quality repositories"
  - "discover best practice repos"
  - "learn from github repository"
allowed_tools:
  - Bash
  - Read
  - Grep
version: "1.0.0"
```

### 1.2 Skill Activation Lifecycle

From Context7 documentation on Claude Code:

> **Skills are loaded when task context matches the skill description.** Claude Code autonomously activates skills based on the task context provided by the user. This means that when a user's task matches the description or intent of a registered skill, Claude Code will leverage that skill to assist in completing the task.

```
User Task → Intent Matching → Skill Activation → Context Injection
```

### 1.3 Skill Characteristics

| Characteristic | Description |
|----------------|-------------|
| **Activation** | Automatic based on task description matching |
| **Scope** | Broad knowledge domains (e.g., "React best practices") |
| **Persistence** | Skills are static files; content doesn't change per session |
| **Tool Access** | Explicitly listed in `allowed-tools` |
| **Size** | Can be large (multi-file documentation) |
| **Versioning** | Semantic versioning in skill.yaml |
| **Source** | Often from external repositories (Vercel, Anthropic, community) |

---

## 2. Ralph Loop Learning System v2.59

### 2.1 Procedural Rules Structure

The Learning System stores 314 rules (as of analysis) in `~/.ralph/procedural/rules.json`:

```json
{
  "version": "2.57.5",
  "rules": [
    {
      "rule_id": "hook-json-format-sec039",
      "trigger": "Writing or modifying Claude Code hooks that output JSON",
      "behavior": "CRITICAL: Use correct JSON format per hook type...",
      "confidence": 1.0,
      "source_repo": "claude-code-official-docs",
      "tags": ["security", "hooks", "json-format"]
    }
  ]
}
```

### 2.2 Procedural Injection Hook

The `procedural-inject.sh` hook (v2.57.5) operates on **every Task tool invocation**:

```bash
# Hook: PreToolUse (Task)
# Triggers: Every time a subagent is spawned

# Flow:
1. Parse task description, prompt, and subagent_type
2. Load rules from ~/.ralph/procedural/rules.json
3. Match rules based on trigger keywords (3+ characters)
4. Filter by confidence threshold (default: 0.7)
5. Limit to 5 rules max
6. Inject matched rules via additionalContext JSON field
```

### 2.3 Learning System Characteristics

| Characteristic | Description |
|----------------|-------------|
| **Activation** | Hook-based, on every Task invocation |
| **Scope** | Fine-grained behavioral patterns (specific actions) |
| **Persistence** | Dynamic, learned from past sessions |
| **Tool Access** | No tool restrictions (injects into existing context) |
| **Size** | Compact (avg 50-100 words per rule) |
| **Versioning** | Track updates via `updated` field |
| **Source** | Learned from incidents, auto-extraction, curator |

---

## 3. Comparison Matrix

| Dimension | Skill Preloading | Procedural Injection |
|-----------|------------------|----------------------|
| **When Activated** | Task description matches skill | Every Task tool call |
| **Context Cost** | Full skill content (variable) | 5 rules max (~500 tokens) |
| **Update Frequency** | Manual skill updates | Automatic from learning |
| **Granularity** | Broad domain knowledge | Specific behavioral rules |
| **Tool Control** | Explicit allowed-tools | Injects into existing tools |
| **Persistence** | Static files | Dynamic JSON database |
| **Confidence Scoring** | No confidence, binary match | 0.0-1.0 confidence filter |
| **Source Tracking** | skill.yaml metadata | source_repo, source_episodes |
| **Security Model** | Tool whitelisting | Sanitization, escape |
| **Failure Mode** | Skill not matched | No rules match |

### 3.1 Context Cost Analysis

**Skill Preloading**:
- Vercel React Best Practices: ~45KB of content
- Blender MCP Expert: ~30KB
- Curator Repo-Learn: ~4KB

**Procedural Injection**:
- 5 rules max, ~100 words each: ~500 tokens
- Configurable via `~/.ralph/config/memory-config.json`

**Winner**: Procedural injection for token efficiency

### 3.2 Match Accuracy

**Skill Preloading**:
- Matches on skill description and triggers
- Binary: either matches or doesn't

**Procedural Injection**:
- Keyword matching on triggers
- Confidence threshold filtering (default 0.7)
- Tag-based filtering possible

**Winner**: Procedural injection for fine-grained control

### 3.3 Learning Capability

**Skill Preloading**:
- Static knowledge from external sources
- Manual updates required
- No learning from local sessions

**Procedural Injection**:
- Auto-learns from incidents (e.g., hook format fixes)
- Auto-extracts from git diff (episodic rules)
- Curator pipeline for repository learning

**Winner**: Procedural injection for adaptive learning

---

## 4. Builder.io Framework Comparison

From the referenced article, the framework distinguishes between:

### 4.1 Rules
- **Always applied**
- **Always pay context cost**
- Example: "Always escape user input in SQL queries"

### 4.2 Commands
- **Explicit invocation**
- **Pay when used**
- Example: `/test-runner run-coverage`

### 4.3 Skills
- **Optional knowledge**
- **Agent discovers and loads when needed**
- Example: Skill triggers on "React performance optimization"

**Mapping to Ralph Loop**:

| Builder.io | Ralph Loop Equivalent | Context Cost |
|------------|----------------------|--------------|
| Rules | Procedural Rules | Per-task (~500 tokens) |
| Commands | Slash commands | Per-invocation |
| Skills | Claude Code Skills | Per-match (variable) |

---

## 5. Hybrid Approach Proposal

### 5.1 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Subagent Context Injection                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐    ┌──────────────────────────────────┐   │
│  │  Claude Code    │    │  Ralph Loop Learning System      │   │
│  │  Skills         │    │  v2.59 Procedural Injection     │   │
│  │                 │    │                                  │   │
│  │ - Broad domain  │    │ - Fine-grained behaviors        │   │
│  │ - Static content│    │ - Dynamic learning              │   │
│  │ - Auto-match    │    │ - Hook-based injection          │   │
│  └────────┬────────┘    └───────────────┬──────────────────┘   │
│           │                             │                      │
│           └──────────┬──────────────────┘                      │
│                      ↓                                         │
│           ┌───────────────────────┐                            │
│           │  Context Aggregation  │                            │
│           │                       │                            │
│           │ - Deduplication       │                            │
│           │ - Priority ordering   │                            │
│           │ - Token budgeting     │                            │
│           └───────────┬───────────┘                            │
│                       ↓                                        │
│           ┌───────────────────────┐                            │
│           │  Subagent Prompt      │                            │
│           └───────────────────────┘                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Implementation Strategy

#### Phase 1: Deduplication Layer
```bash
# Create ~/.claude/hooks/skill-procedural-dedupe.sh
# PreToolUse hook that:
# 1. Receives both skill content and procedural rules
# 2. Removes duplicate patterns
# 3. Orders by: Procedural (high confidence) > Skills > Episodic
```

#### Phase 2: Token Budgeting
```json
// ~/.ralph/config/memory-config.json
{
  "context_budget": {
    "procedural_max_tokens": 500,
    "skill_max_tokens": 2000,
    "episodic_max_tokens": 300,
    "total_max_tokens": 2800
  }
}
```

#### Phase 3: Smart Triggers
```bash
# Only inject procedural rules when:
# 1. Task complexity >= 5 (from plan-state)
# 2. No matching skill exists
# 3. OR skill match confidence < threshold
```

### 5.3 Recommended Configuration

```json
{
  "hybrid_mode": {
    "enabled": true,
    "skill_preload": {
      "enabled": true,
      "match_threshold": 0.8
    },
    "procedural_inject": {
      "enabled": true,
      "min_confidence": 0.7,
      "max_rules": 5,
      "skip_if_skill_matched": false
    },
    "priority_order": [
      "procedural_critical",
      "procedural_high",
      "skills",
      "procedural_medium",
      "episodic"
    ]
  }
}
```

---

## 6. Use Case Recommendations

### 6.1 When to Use Skill Preloading

| Use Case | Example | Why Skills |
|----------|---------|------------|
| **Domain expertise** | "React performance optimization" | Vercel React Best Practices skill |
| **Tool mastery** | "Blender 3D operations" | Blender MCP Expert skill |
| **Framework guidance** | "Next.js API routes" | Next.js patterns skill |
| **External best practices** | "AWS serverless patterns" | AWS CDK skill |

### 6.2 When to Use Procedural Injection

| Use Case | Example | Why Procedural |
|----------|---------|----------------|
| **Session-specific knowledge** | "Hook format changed in v2.57" | Learned from incidents |
| **Project patterns** | "This codebase uses factory pattern" | Auto-extracted |
| **Error recovery** | "When Context7 fails, try direct search" | Behavioral rules |
| **Security patterns** | "Never commit unescaped user input" | Critical rules |

### 6.3 Combined Workflow

```
User: "Implement authentication with JWT for my React app"

1. Skill Match: vercel-react-best-practices (React + JWT)
2. Skill Match: backend-development (authentication patterns)
3. Procedural Injection: security-auth-rules (high confidence)
4. Procedural Injection: jwt-best-practices (from learned patterns)
5. Result: Combined context with both broad skills + specific rules
```

---

## 7. Efficiency Validation

### 7.1 Codex CLI Analysis

The Codex CLI (gpt-5.2-codex) approach favors explicit prompting over implicit context injection. The procedural injection approach aligns well because:

- Rules are injected as explicit guidance text
- Limited to 5 rules prevents context overflow
- Confidence threshold ensures quality

### 7.2 Gemini CLI Analysis

Gemini CLI's tool integration model complements procedural rules because:

- Rules can specify which tools to prefer
- Behavioral rules can guide tool selection
- Confidence scores help with tool dispatch

### 7.3 Adversarial Review

For adversarial testing (dual-model validation):

| Approach | Adversarial Benefit |
|----------|-------------------|
| Skills | Static content, harder to manipulate |
| Procedural | Dynamic, can be validated per-session |
| Hybrid | Best of both: static reference + dynamic validation |

### 7.4 Context7 Integration

Context7 provides authoritative documentation. Procedural rules can reference Context7 queries:

```json
{
  "rule_id": "verify-test-expectations",
  "trigger": "When tests fail after hook changes",
  "behavior": "FIRST verify test expectations are correct against official documentation (use Context7 MCP). Tests can be corrupted with wrong expectations.",
  "confidence": 1.0
}
```

---

## 8. Implementation Roadmap

### 8.1 Immediate Actions

1. **Document the hybrid approach** in CLAUDE.md
2. **Update memory-config.json** with hybrid configuration schema
3. **Create deduplication hook** to prevent rule conflicts

### 8.2 Short-term (v2.60)

1. **Implement token budgeting** for context aggregation
2. **Add priority ordering** for rule/skill conflicts
3. **Create visualization** of context injection flow

### 8.3 Long-term (v2.61+)

1. **ML-based matching** for skill/rule selection
2. **Cross-session learning** from adversarial reviews
3. **Automatic skill suggestion** based on rule patterns

---

## 9. Conclusion

### Key Findings

1. **Skills and Procedural Rules serve different purposes**:
   - Skills: Broad, static domain knowledge
   - Procedural Rules: Fine-grained, dynamic behavioral patterns

2. **Procedural Injection is more efficient for token usage**:
   - 5 rules max vs. potentially large skill files
   - Confidence filtering reduces noise

3. **Skills provide better external knowledge integration**:
   - Vercel, AWS, and other vendor skills are authoritative
   - Static content ensures consistency

4. **Hybrid approach optimizes both**:
   - Skills for domain expertise
   - Procedural for session-specific learning
   - Deduplication prevents conflicts

### Recommendations

1. **Keep both systems operational** - they are complementary
2. **Implement deduplication layer** to prevent conflicts
3. **Add token budgeting** to prevent context overflow
4. **Document the interaction** for future maintenance

---

## References

- [Builder.io: Agent Skills, Rules, and Commands](https://www.builder.io/blog/agent-skills-rules-commands)
- [Claude Code Documentation (Context7)](https://context7.com/anthropics/claude-code)
- [Ralph Loop v2.58.0 Documentation](/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md)
- [Procedural Injection Hook](/Users/alfredolopez/.claude/hooks/procedural-inject.sh)
- [Procedural Rules Database](/Users/alfredolopez/.ralph/procedural/rules.json)
- [Skill Example: Vercel React Best Practices](/Users/alfredolopez/.claude/skills/vercel-react-best-practices/skill.yaml)

---

*Generated by Ralph Loop Analysis Agent*
*Session: skill-preloading-analysis-20260122*

# Learning System Integration Guide

**Version**: v2.81.2
**Last Updated**: 2026-01-29
**Status**: ✅ Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Usage](#usage)
6. [API Reference](#api-reference)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)

---

## Overview

The Learning System automatically improves code quality by:

1. **Discovering** quality repositories from GitHub
2. **Extracting** best practices and patterns
3. **Generating** procedural rules with confidence scores
4. **Applying** rules automatically during development
5. **Validating** that rules were actually used

### Key Benefits

- ✅ **Automatic Execution**: No manual intervention needed
- ✅ **Quality Focused**: Only learns from high-quality repositories
- ✅ **Domain Aware**: Classifies patterns by technical domain
- ✅ **Context Relevant**: Prioritizes patterns matching your current task
- ✅ **Metrics Tracked**: Utilization rate and effectiveness measured

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    LEARNING SYSTEM ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Curator    │───▶│    Learner   │───▶│   Rules      │      │
│  │              │    │              │    │   (1003+)     │      │
│  │ • Discovery  │    │ • AST        │    │              │      │
│  │ • Scoring    │    │ • Classify   │    │ • Domain     │      │
│  │ • Ranking    │    │ • Extract    │    │ • Confidence │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                                      │               │
│         ▼                                      ▼               │
│  ┌──────────────┐                      ┌──────────────┐         │
│  │    Gate      │                      │  Verification │         │
│  │              │                      │              │         │
│  │ • Auto-exec  │                      │ • Pattern    │         │
│  │ • Detect     │                      │ • Metrics    │         │
│  │ • Recommend  │                      │ • Feedback   │         │
│  └──────────────┘                      └──────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Components

#### 1. Repo Curator

**Purpose**: Find and score quality repositories from GitHub

**Pipeline**:
1. **Discovery**: GitHub API search with filters
2. **Scoring**: Quality metrics + context relevance
3. **Ranking**: Top N with max-per-org limits

**Scripts**:
- `curator-discovery.sh` (v2.0.0) - 5 fixes applied
- `curator-scoring.sh` (v2.0.0) - 5 fixes applied
- `curator-rank.sh` (v2.0.0) - 5 fixes applied

#### 2. Repository Learner

**Purpose**: Extract patterns and generate procedural rules

**Process**:
1. Clone/acquire repository
2. AST-based pattern extraction
3. Domain classification
4. Rule generation with confidence
5. Deduplication and storage

#### 3. Auto-Learning Hooks

**learning-gate.sh** (v1.0.0):
- Trigger: PreToolUse (Task)
- Detects: Empty or insufficient procedural memory
- Action: Recommends /curator execution
- Blocks: High complexity tasks without rules

**rule-verification.sh** (v1.0.0):
- Trigger: PostToolUse (TaskUpdate)
- Analyzes: Modified code for rule patterns
- Updates: Rule metrics (applied_count, skipped_count)
- Reports: Utilization rate and ghost rules

---

## Installation

### Prerequisites

```bash
# Required tools
bash >= 4.0
jq >= 1.6
git >= 2.0
curl >= 7.0

# Optional but recommended
gh (GitHub CLI) - For enhanced GitHub API access
```

### Setup

1. **Clone the repository** (if not already done):
```bash
cd ~/.ralph/curator
```

2. **Verify scripts are executable**:
```bash
chmod +x ~/.ralph/curator/scripts/*.sh
ls -l ~/.ralph/curator/scripts/
```

3. **Verify hooks are registered**:
```bash
grep "learning-gate" ~/.claude-sneakpeek/zai/config/settings.json
grep "rule-verification" ~/.claude-sneakpeek/zai/config/settings.json
```

4. **Check learning state**:
```bash
cat ~/.ralph/learning/state.json
```

Expected output:
```json
{
  "version": "1.0.0",
  "last_updated": "2026-01-29T21:30:00Z",
  "is_critical": false,
  "statistics": {
    "total_rules": 1003,
    "with_domain": 148,
    "with_usage": 146
  }
}
```

---

## Configuration

### Memory Configuration

Edit `~/.ralph/config/memory-config.json`:

```json
{
  "procedural": {
    "inject_to_prompts": true,
    "min_confidence": 0.7,
    "max_rules_per_injection": 5
  },
  "learning": {
    "auto_execute": true,
    "min_complexity_for_gate": 3,
    "block_critical_without_rules": true
  }
}
```

### Curator Configuration

Edit `~/.ralph/curator/config.json`:

```json
{
  "github": {
    "api_token": "YOUR_TOKEN_HERE",
    "max_results_per_page": 100,
    "rate_limit_delay": 1.0
  },
  "scoring": {
    "min_quality_score": 50,
    "context_boost": 10
  },
  "ranking": {
    "default_top_n": 50,
    "max_per_org": 3
  }
}
```

---

## Usage

### Basic Workflow

```bash
# 1. Discover repositories
/curator discovery --type backend --lang typescript --max-results 100

# 2. Score with context
/curator scoring --context "error handling,retry,resilience"

# 3. Rank top results
/curator rank --top-n 20 --max-per-org 2

# 4. View results
/curator show --type backend --lang typescript

# 5. Approve repos
/curator approve nestjs/nest
/curator approve --all

# 6. Learn patterns
/curator learn --all
```

### Context Relevance Scoring

Prioritize repositories based on your current task:

```bash
# For fault-tolerant systems
/curator scoring --context "error handling,retry,resilience"

# For security-focused projects
/curator scoring --context "security,authentication,encryption"

# For test coverage
/curator scoring --context "testing,coverage,ci/cd"
```

### Domain-Specific Discovery

```bash
# Backend frameworks
/curator discovery --type backend --lang typescript

# Frontend libraries
/curator discovery --type frontend --lang javascript

# Full-stack applications
/curator discovery --type fullstack --lang typescript
```

---

## API Reference

### Commands

#### `/curator discovery`

Discover repositories via GitHub API.

```bash
/curator discovery [OPTIONS]
```

**Options**:
- `--type <type>`: Repository type (backend, frontend, fullstack, library, framework)
- `--lang <lang>`: Programming language
- `--query <query>`: Custom search query
- `--max-results <n>`: Maximum results (default: 100, max: 1000)
- `--tier <tier>`: Pricing tier (free, economic, full)
- `--output <file>`: Output file (default: candidates/repos.json)

**Example**:
```bash
/curator discovery --type backend --lang typescript --query "microservice" --max-results 200
```

#### `/curator scoring`

Score repositories with quality metrics and context relevance.

```bash
/curator scoring [OPTIONS]
```

**Options**:
- `--input <file>`: Input file (required)
- `--context <context>`: Context keywords (comma-separated)
- `--tier <tier>`: Pricing tier
- `--verbose`: Verbose output

**Example**:
```bash
/curator scoring --input candidates/repos.json --context "error handling,security"
```

#### `/curator rank`

Rank repositories with quality metrics and max-per-org limits.

```bash
/curator rank [OPTIONS]
```

**Options**:
- `--input <file>`: Input file (required)
- `--output <file>`: Output file
- `--top-n <n>`: Number of top repos (default: 50)
- `--max-per-org <n>`: Maximum per organization (default: 3)
- `--sort-by <metric>`: Sort by (quality, context, combined)
- `--order <order>`: Order (asc, desc)

**Example**:
```bash
/curator rank --input candidates/scored.json --top-n 20 --max-per-org 2
```

#### `/curator approve`

Approve repositories for learning.

```bash
/curator approve [REPO] [--all]
```

**Examples**:
```bash
/curator approve nestjs/nest
/curator approve --all
```

#### `/curator learn`

Extract patterns from approved repositories.

```bash
/curator learn [OPTIONS]
```

**Options**:
- `--type <type>`: Repository type
- `--lang <lang>`: Programming language
- `--repo <repo>`: Specific repository
- `--all`: Learn from all approved repos

**Example**:
```bash
/curator learn --type backend --lang typescript --all
```

### Hooks

#### learning-gate.sh

**Trigger**: PreToolUse (Task)

**Purpose**: Auto-execute /curator when memory is empty

**Behavior**:
- Detects task complexity
- Checks for relevant rules
- Recommends /curator if needed
- Blocks high complexity tasks without rules

**Configuration**:
```json
{
  "learning": {
    "auto_execute": true,
    "min_complexity_for_gate": 3,
    "block_critical_without_rules": true
  }
}
```

#### rule-verification.sh

**Trigger**: PostToolUse (TaskUpdate)

**Purpose**: Verify rules were applied in code

**Behavior**:
- Analyzes modified files
- Searches for rule patterns
- Updates rule metrics
- Reports utilization rate

**Metrics**:
- `applied_count`: Times rule was used
- `skipped_count`: Times rule was ignored
- `utilization_rate`: Percentage of rules applied

---

## Troubleshooting

### Issue: learning-gate.sh recommends /curator but I have rules

**Cause**: Rules exist but don't match task domain

**Solution**:
```bash
# Check rule domains
jq '.rules[] | .domain' ~/.ralph/procedural/rules.json | sort | uniq -c

# Learn rules for specific domain
/curator discovery --type <your-domain> --lang typescript
/curator learn --all
```

### Issue: rule-verification.sh reports 0% utilization

**Cause**: Patterns not matching in generated code

**Solution**:
```bash
# Check rule patterns
jq '.rules[0] | {pattern, keywords, domain}' ~/.ralph/procedural/rules.json

# Verify with test file
echo "try { } catch (e) { }" > /tmp/test.ts
grep -i "try.*catch" /tmp/test.ts
```

### Issue: GitHub API rate limit

**Cause**: Too many API requests

**Solution**:
```bash
# Check rate limit
curl -I "https://api.github.com/search/repositories?q=test"

# Use authentication (higher limits)
export GITHUB_TOKEN="your_token"
gh auth login

# Reduce max-results
/curator discovery --max-results 50
```

### Issue: Hooks not executing

**Cause**: Hooks not registered in settings.json

**Solution**:
```bash
# Verify registration
grep "learning-gate" ~/.claude-sneakpeek/zai/config/settings.json

# Check file exists
ls -l ~/.claude/hooks/learning-gate.sh

# Check permissions
chmod +x ~/.claude/hooks/learning-gate.sh
```

---

## Best Practices

### 1. Start with Free Tier

```bash
# Test with free tier first
/curator discovery --tier free --max-results 10
```

### 2. Use Context Relevance

```bash
# Prioritize based on current task
/curator scoring --context "error handling,security"
```

### 3. Approve Selectively

```bash
# Review before approving
/curator show --type backend

# Approve only high-quality repos
/curator approve nestjs/nest
/curator approve <other-high-quality-repo>
```

### 4. Monitor Utilization

```bash
# Check rule utilization
jq '[.rules[] | select(.applied_count > 0)] | length' ~/.ralph/procedural/rules.json

# View top applied rules
jq '.rules | sort_by(.applied_count // 0) | reverse | .[0:10]' ~/.ralph/procedural/rules.json
```

### 5. Regular Learning Cycles

```bash
# Monthly learning cycle
/curator discovery --type backend --lang typescript
/curator scoring
/curator rank --top-n 50
/curator show
/curator approve --all
/curator learn --all
```

---

## Performance Metrics

### Current System Stats

```
Total Rules:      1003
With Domain:      148 (14.7%)
With Usage:       146 (14.5%)
Applied Count:    Tracking active
Utilization Rate: Measured automatically
```

### Target Metrics

- **Utilization Rate**: >60% (rules applied / rules injected)
- **Domain Coverage**: >80% (domains with rules)
- **Application Rate**: >40% (rules with applied_count > 0)

---

## FAQ

**Q: How often should I run /curator?**

A: Recommended monthly or when starting a new project domain.

**Q: Can I use my own repositories?**

A: Yes, use `/curator ingest --repo <org/repo> --approve`

**Q: What if I disagree with a rule?**

A: Rules have confidence scores. Low-confidence rules can be ignored.

**Q: Does this work offline?**

A: Discovery requires internet, but rule application is offline.

**Q: How do I disable auto-learning?**

A: Set `inject_to_prompts: false` in `~/.ralph/config/memory-config.json`

---

## Support

- **Issues**: GitHub Issues
- **Documentation**: `docs/implementation/`
- **Tests**: `tests/integration/`, `tests/functional/`

---

**Version**: v2.81.2
**Last Updated**: 2026-01-29
**Status**: ✅ Production Ready

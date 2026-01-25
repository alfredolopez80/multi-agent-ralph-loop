---
# VERSION: 2.69.0
name: curator
prefix: "@curator"
category: tools
color: green
description: "Discover, score, and curate high-quality repositories for Ralph's learning system"
argument-hint: "<subcommand> [options]"
---

Discover, score, and curate high-quality repositories for Ralph's learning system. Builds a corpus of enterprise-grade code patterns from top repositories.

[Extended thinking: The curator system implements a 4-stage pipeline: Discovery (GitHub API search) → Scoring (quality metrics) → Ranking (top N, max 2 per org) → Ingest (clone to corpus). After user approval, learning extracts patterns and updates Procedural Memory with source attribution. Supports 3 pricing tiers: free ($0), economic (~$0.30 with MiniMax), full (~$0.95 with Claude+Codex).]

## Phase 1: Discovery

### 1. Parse User Query
- Extract: --type (backend/frontend/cli/library), --lang (typescript/python/go/rust), --tier (free/economic/full), --query (custom), --top-n (default 10)
- Default: --type backend --lang typescript --tier economic

### 2. Execute Discovery
- Use Bash tool with command: `bash ~/.claude/scripts/curator-discovery.sh --type $TYPE --lang $LANG --query "$QUERY" --output ~/.ralph/curator/candidates/discovery_$(date +%Y%m%d_%H%M%S).json`
- Expected output: JSON file with 100-500 candidate repositories

## Phase 2: Scoring

### 3. Calculate Quality Scores
- Use Bash tool with command: `bash ~/.claude/scripts/curator-scoring.sh --input $CANDIDATES_FILE --output $SCORED_FILE --tier $TIER`
- Scoring includes: stars, issues ratio, tests presence, CI/CD, documentation

## Phase 3: Ranking

### 4. Generate Rankings
- Use Bash tool with command: `bash ~/.claude/scripts/curator-rank.sh --input $SCORED_FILE --output $RANKING_FILE --top-n $TOP_N --max-per-org 2`
- Constraint: Maximum 2 repositories per organization

## Phase 4: User Review

### 5. Display Ranking
- Use Bash tool with command: `bash ~/.claude/scripts/curator-queue.sh`
- Show: ranking file location, top repos with scores

### 6. Wait for User Approval
- Prompt user: "Review the ranking and approve repos for learning:"
- Commands: `/curator approve owner/repo` or `/curator approve --all`

## Phase 5: Ingest & Learn

### 7. Ingest Approved Repos
- For each approved repo: `bash ~/.claude/scripts/curator-ingest.sh --repo $REPO --approve`

### 8. Execute Learning
- Use Bash tool with command: `bash ~/.claude/scripts/curator-learn.sh --repo $REPO`
- Updates: ~/.ralph/procedural/rules.json with new rules including source_repo attribution

## Pricing Tier Logic

### Free Tier ($0.00)
- GitHub API search only
- Local scoring heuristics
- No LLM calls

### Economic Tier (~$0.30)
- GitHub API + OpenSSF Scorecard
- MiniMax for validation
- Fallback to free if MiniMax unavailable

### Full Tier (~$0.95)
- GitHub API + OpenSSF
- Claude + Codex adversarial validation
- Falls back to economic if tools unavailable

## Output Examples

### Discovery Output
```
=== Discovery Summary ===
Type: backend
Language: typescript
Query: org:github topic:api typescript stars:>1000
Candidates found: 250
Output: ~/.ralph/curator/candidates/backend_typescript_20260119.json
```

### Ranking Output
```
=== Ranking Summary ===
Top 10 repositories:
  1. nestjs/nest (score: 9.2, stars: 75000)
  2. prisma/prisma (score: 8.9, stars: 32000)
  3. ...
```

### Status Output
```
========================================
      Repo Curator Queue
========================================
  Pending:   3
  Approved:  5
  Rejected:  2

⏳ Pending Review
  ----------------------------------------
  ⏳ prisma/prisma (150 files)
  ...

✅ Approved
  ----------------------------------------
  ✅ nestjs/nest (250 files) 2026-01-19
  ...
```

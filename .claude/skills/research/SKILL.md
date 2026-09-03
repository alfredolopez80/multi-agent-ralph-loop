---
# VERSION: 3.0.0
name: research
description: "Comprehensive research skill using the native WebSearch and WebFetch tools plus Context7 for library documentation"
---

# Research Skill - Multi-Agent Ralph

**Provider-neutral research** - Uses the harness's native `WebSearch` and `WebFetch` tools for
open-web research and Context7 for library/framework documentation.

Based on the principle that research should be thorough, well-sourced, and actionable.

## Quick Start

```bash
# Via skill invocation
/research Latest React 19 patterns and best practices

# Via CLI
ralph research "TypeScript 5.0 performance optimizations"

# Focus on specific sources
/research "Next.js App Router" --sources github,docs
```

## Principles

- **Native tools first**: `WebSearch` for discovery, `WebFetch` for retrieval.
- **Context7 for library docs**: `resolve-library-id` then `query-docs` — authoritative,
  version-aware, and cheaper than scraping a docs site.
- **Additional MCP search servers are optional**: use one for what it can *fetch* that the
  native tools cannot (a site-specific extractor, a paywalled-format reader). Never route to a
  server because of who provides it, and never treat one as the default.
- **Model-agnostic**: the model is whatever the session runs; this skill never selects one.

## Available Tools

### 1. WebSearch (primary discovery)

**Purpose:** Find candidate sources for a topic.

**Optimal patterns:**
```yaml
# Good: specific, time-bounded
WebSearch:
  query: "React 19 useOptimistic hook examples 2025"

# Good: error-focused debugging
WebSearch:
  query: "TypeError cannot read property undefined Next.js 15"

# Good: domain-scoped documentation search
WebSearch:
  query: "Claude Code MCP configuration"
  allowed_domains: ["docs.claude.com"]

# Bad: too vague
WebSearch:
  query: "javascript"   # too broad, be specific
```

### 2. WebFetch (content retrieval)

**Purpose:** Fetch and analyze the full content of a specific page.

**When to use:**
- Deep-dive into an article found via `WebSearch`
- Reading a documentation page end to end
- Exploring a GitHub repository page (README, issue, PR)
- API reference analysis

```yaml
WebFetch:
  url: "${DOC_URL}"
  prompt: "Extract the configuration options and their defaults"
```

### 3. Context7 (library and framework documentation)

**Purpose:** Current, version-aware docs for a named library, framework, SDK, or CLI —
preferred over open-web search whenever the subject is a specific library.

```yaml
# 1. Resolve the library
resolve-library-id:
  libraryName: "next.js"

# 2. Query its docs
query-docs:
  context7CompatibleLibraryID: "${RESOLVED_ID}"
  query: "App Router route handlers"
```

### 4. Local code search

`Grep` and `Glob` for anything inside the repository. Never use a web search to answer a
question the codebase can answer.

## Research Workflow (5 Steps)

### Step 1: INITIAL SEARCH

```yaml
WebSearch:
  query: "${TOPIC} overview guide 2025"
```

If the topic is a named library, start at Context7 instead of the open web.

### Step 2: REFINE & DEEPEN

```yaml
WebSearch:
  query: "${SPECIFIC_ASPECT} implementation ${TOPIC}"
```

### Step 3: FETCH CONTENT

```yaml
# Documentation and articles
WebFetch:
  url: "${DOC_URL}"
  prompt: "Summarize the ${SPECIFIC_ASPECT} section with code examples"

# Library reference
query-docs:
  context7CompatibleLibraryID: "${RESOLVED_ID}"
  query: "${SPECIFIC_ASPECT}"
```

### Step 4: SYNTHESIZE

Compile findings into a structured report:
- **Summary**: Key findings in 2-3 sentences
- **Sources**: All URLs with brief descriptions
- **Details**: Relevant code snippets and explanations
- **Recommendations**: Suggested approach based on research
- **Related Topics**: Areas for further exploration

### Step 5: PERSIST

Save research to memory for future reference:
```bash
ralph ledger save research "Research on ${TOPIC}: [key findings]"
```

## Research Templates

### Technology Research

```yaml
# 1. Official docs — Context7 when the subject is a named library
resolve-library-id:
  libraryName: "${TECH}"

# 2. Best practices
WebSearch:
  query: "${TECH} best practices 2025"

# 3. Real-world examples
WebSearch:
  query: "${TECH} examples github"
```

### Error Research

```yaml
# 1. Exact error message
WebSearch:
  query: "${ERROR_MESSAGE} ${FRAMEWORK}"

# 2. Stack Overflow solutions
WebSearch:
  query: "site:stackoverflow.com ${ERROR_MESSAGE}"

# 3. GitHub issues
WebSearch:
  query: "site:github.com ${ERROR_MESSAGE}"
```

### Security Research

```yaml
# 1. CVE lookup
WebSearch:
  query: "CVE ${VERSION} vulnerability"

# 2. Security advisories
WebSearch:
  query: "${PACKAGE} security advisory 2025"

# 3. Advisory detail
WebFetch:
  url: "${ADVISORY_URL}"
  prompt: "Affected versions, severity, and the fixed release"
```

## Integration with Ralph Loop

```yaml
# Research phase in orchestrator
Task:
  prompt: |
    Research latest patterns for $TOPIC using WebSearch for discovery and
    WebFetch for the sources worth reading in full. Use Context7 for any
    named library. Compile findings into a structured report with sources.

# Code research
Task:
  prompt: |
    Search for $TOPIC implementation examples on GitHub using WebSearch,
    then WebFetch the repositories worth reading.
    Identify best patterns and anti-patterns.
```

## When to Use Each Tool

| Scenario | Recommended Tool |
|----------|------------------|
| General web search | `WebSearch` |
| Reading a specific page or article | `WebFetch` |
| Library / framework / SDK documentation | Context7 (`resolve-library-id` → `query-docs`) |
| GitHub repositories | `WebSearch` to locate, `WebFetch` to read |
| Content the native tools cannot retrieve | Any configured search MCP server, chosen for what it fetches |
| Code search in repo | `Grep`, `Glob` (never web search) |

## Anti-Patterns

- **Too broad queries**: "javascript" - always be specific
- **Skipping sources**: Always cite URLs
- **Ignoring recency**: Say the year/version for fast-moving topics
- **Single source**: Cross-reference multiple sources
- **No synthesis**: Don't just list results, analyze them
- **Missing memory**: Save learnings for future sessions
- **Provider preference**: Never pick a search backend by vendor; pick it by what it can fetch

## Output Format

Structure research reports as:

```markdown
# Research: [TOPIC]

**Date**: YYYY-MM-DD
**Sources**: X articles analyzed

## Summary
[2-3 sentence key findings]

## Key Findings
1. [Finding 1]
   - Source: [URL]
   - Details: [Explanation]

2. [Finding 2]
   - Source: [URL]
   - Details: [Explanation]

## Code Examples
```language
// Relevant code snippets
```

## Recommendations
1. [Recommendation 1]
2. [Recommendation 2]

## Related Topics
- [Topic for further research]

## Sources
1. [Title](URL) - [Brief description]
2. [Title](URL) - [Brief description]
```

## CLI Commands

```bash
# Standard research
ralph research "topic description"

# With source focus
ralph research "topic" --sources github,docs
```

## Related Skills

- `/orchestrator` - Full orchestration with research phase
- `/smart-fork` - Pattern extraction from external repos
- `/clarify` - Requirement clarification with research

## Agent Teams Integration

**Optimal Scenario**: B (Pure Custom Subagents)

### Why Scenario B for Research
- **Independent execution**: Research is mostly self-contained
- **Specialization > Coordination**: Tool expertise matters more than inter-agent coordination
- **Simpler setup**: No team overhead for single-purpose research tasks
- **Tool restrictions**: ralph-researcher has read-only research tools (WebSearch, WebFetch)

### Scenario Analysis
| Criterion | Weight | Score | Rationale |
|-----------|--------|-------|-----------|
| Coordination Need | 25% | 3/10 | Research is independent |
| Specialization Need | 25% | 9/10 | Specialized web tools required |
| Quality Gate Need | 20% | 5/10 | Moderate validation needs |
| Tool Restriction Need | 15% | 8/10 | Read-only tools important |
| Scalability | 15% | 7/10 | Scales with topic complexity |
| **Total** | 100% | **7.5/10** | Scenario B optimal |

### Workflow
```yaml
# Scenario B: Direct spawn without TeamCreate
Task(subagent_type="ralph-researcher", prompt="Research ${TOPIC}")
→ Execute with research tools
→ Compile structured report
→ Return findings
```

### Usage

**Direct Spawn (Recommended)**:
```yaml
Task:
  subagent_type: "ralph-researcher"
  prompt: |
    Research ${TOPIC} using:
    1. WebSearch for initial discovery
    2. WebFetch for the sources worth reading in full
    3. Context7 for any named library's documentation
    Compile into structured report with all sources.
```

**Parallel Research (Multiple Topics)**:
```yaml
# Spawn multiple researchers for different topics
Task(subagent_type="ralph-researcher", prompt="Research React 19 features")
Task(subagent_type="ralph-researcher", prompt="Research TypeScript 5.5")
Task(subagent_type="ralph-researcher", prompt="Research Node.js performance")
# Results aggregated independently
```

## References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Web Search Tool Documentation](https://platform.claude.com/docs/en/agents-and-tools/tool-use/web-search-tool)

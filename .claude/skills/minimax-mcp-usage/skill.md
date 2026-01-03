---
name: minimax-mcp-usage
description: "Optimal patterns for MiniMax MCP tools (web_search + understand_image)"
---

# MiniMax MCP Usage Patterns (v2.24)

This skill documents optimal usage patterns for MiniMax MCP tools.

## Available Tools

### 1. mcp__MiniMax__web_search

**Purpose:** Web search with 8% cost of alternatives

**Input:**
```yaml
query: string  # 3-5 keywords, include year for recent topics
```

**Output:**
```json
{
  "organic": [{ "title", "link", "snippet", "date" }],
  "related_searches": [{ "query" }]
}
```

**Optimal Patterns:**

```yaml
# Good: Specific, time-bounded
mcp__MiniMax__web_search:
  query: "React 19 useOptimistic hook examples 2025"

# Good: Error-focused
mcp__MiniMax__web_search:
  query: "TypeError cannot read property undefined Next.js"

# Bad: Too vague
mcp__MiniMax__web_search:
  query: "javascript"  # Too broad
```

### 2. mcp__MiniMax__understand_image

**Purpose:** Image analysis for debugging and review

**Input:**
```yaml
prompt: string       # Clear, specific question about the image
image_source: string # Local path (no @) or HTTPS URL
```

**Optimal Patterns:**

```yaml
# Good: Specific analysis request
mcp__MiniMax__understand_image:
  prompt: "Identify the exact error message and stack trace in this screenshot"
  image_source: "/tmp/error.png"

# Good: UI review
mcp__MiniMax__understand_image:
  prompt: "List all accessibility violations in this form design"
  image_source: "./mockup.png"

# Bad: Vague prompt
mcp__MiniMax__understand_image:
  prompt: "What's this?"  # Too vague
  image_source: "./image.png"
```

## Integration with Ralph Loop

```yaml
# Research phase: Use web_search
Task:
  prompt: |
    Research latest patterns for $TOPIC using mcp__MiniMax__web_search.
    Compile findings into structured report.

# Debugging phase: Use understand_image
Task:
  prompt: |
    Analyze error screenshot at $PATH using mcp__MiniMax__understand_image.
    Identify root cause and suggest fixes.
```

## Cost Analysis

| Operation | MiniMax MCP | Gemini CLI | Savings |
|-----------|-------------|------------|---------|
| Web search | ~$0.008 | ~$0.06 | 87% |
| Image analysis | ~$0.01 | N/A | New capability |

## When NOT to Use

| Scenario | Alternative |
|----------|-------------|
| US-only search | WebSearch (free) |
| Code search | ast-grep MCP (v2.23) |
| Long-form generation | Gemini CLI (1M context) |
| Real-time data | Native WebFetch |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "API key invalid" | Check MINIMAX_API_KEY in ~/.claude.json |
| "Image too large" | Compress to <20MB |
| "Format not supported" | Convert to JPEG/PNG/WebP |
| "No results" | Refine query with more keywords |

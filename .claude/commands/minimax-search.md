---
name: minimax-search
description: "Web search via MiniMax MCP (8% cost, Opus quality)"
argument-hint: "<query>"
---

# /minimax-search - MiniMax MCP Web Search (v2.24)

Search the web using MiniMax MCP tool with 8% of Gemini's cost.

## Usage

```
/minimax-search "React 19 new features"
/minimax-search "TypeScript satisfies operator examples"
```

## Execution

When `/minimax-search` is invoked:

### Step 1: Optimize Query

```yaml
# Add current year for time-sensitive queries
# Today's date is available - use it for recent topics
query_optimized = query + " 2025"  # if time-sensitive
```

### Step 2: Execute MCP Tool

```yaml
mcp__MiniMax__web_search:
  query: "<optimized_query>"
```

### Step 3: Process Results

The tool returns:
```json
{
  "organic": [
    {
      "title": "Result title",
      "link": "https://...",
      "snippet": "Description...",
      "date": "2025-01-03"
    }
  ],
  "related_searches": [
    { "query": "Related query suggestion" }
  ]
}
```

### Step 4: Follow Up (if needed)

For full article content, use WebFetch:

```yaml
WebFetch:
  url: "<link_from_results>"
  prompt: "Extract the relevant information about <topic>"
```

## Query Tips

| Pattern | Example | Result |
|---------|---------|--------|
| Keywords + Year | "React 19 features 2025" | Recent info |
| Technology + Pattern | "OpenTelemetry traces Python" | Implementation |
| Error + Framework | "CORS error Next.js 15" | Solutions |
| "exact phrase" | "satisfies operator" | Exact matches |

## When to Use

- **Documentation lookup**: Latest API docs, framework features
- **Error debugging**: Search for error messages
- **Best practices**: Current industry patterns
- **Competitive analysis**: Compare technologies

## Cost Comparison

| Tool | Cost | Quality |
|------|------|---------|
| MiniMax MCP | ~8% | 74% SWE-bench |
| Gemini CLI | ~60% | Variable |
| WebSearch (native) | Free | US-only |

**Recommendation**: Use MiniMax MCP for international queries, WebSearch for US-based.

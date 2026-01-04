---
name: research
description: "Web research using WebSearch (native) with MiniMax fallback (v2.25)"
argument-hint: "<query>"
---

# /research

Web research using WebSearch (native, FREE) with MiniMax MCP fallback (8% cost).

## v2.25 Search Hierarchy

| Priority | Tool | Cost |
|----------|------|------|
| 1 | WebSearch (native) | FREE |
| 2 | MiniMax MCP | 8% |

**Note**: Gemini CLI is NOT used for research (too expensive). Only use Gemini CLI for short, punctual tasks.

## Execution

Research the following query using this priority:

1. **FIRST**: Use the WebSearch tool (native Claude tool, free - included in Claude Max 20x)
2. **FALLBACK**: If WebSearch fails or returns no results, use mcp__MiniMax__web_search (8% cost - MiniMax Coding Plans)

Query: $ARGUMENTS

Return results as markdown with:
- Summary of findings
- Key sources (with clickable links)
- Relevant code examples if applicable

## CLI Alternative
```bash
ralph research "$ARGUMENTS"
```

## Related Commands
- `/library-docs` - For library/framework documentation (uses Context7 MCP)
- `/minimax-search` - Direct MiniMax web search

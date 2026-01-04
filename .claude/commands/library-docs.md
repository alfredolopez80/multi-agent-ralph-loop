---
name: library-docs
description: "Search library/framework documentation via Context7 MCP (v2.25)"
argument-hint: "<library> <query>"
---

# /library-docs

Search indexed library documentation using Context7 MCP.

## When to Use

- Searching for React, Next.js, Vue, Angular docs
- Looking up TypeScript features
- Finding API documentation for popular libraries
- Getting code examples from official docs

## v2.25 Search Strategy

| Query Type | Tool | Cost |
|------------|------|------|
| Library/Framework docs | Context7 MCP | Optimized |
| Fallback | MiniMax MCP | 8% |

## Execution

Search library documentation using Context7 MCP:

1. **Step 1**: Use `mcp__plugin_context7_context7__resolve-library-id` with:
   - libraryName: Extract library name from query (e.g., "React", "Next.js", "TypeScript")
   - query: The full user query for relevance ranking

2. **Step 2**: Use `mcp__plugin_context7_context7__query-docs` with:
   - libraryId: The resolved ID from step 1
   - query: The specific question

3. **Fallback**: If Context7 doesn't have the library, use mcp__MiniMax__web_search

Query: $ARGUMENTS

Return documentation excerpts with:
- Code examples from official docs
- API references if applicable
- Best practices and recommendations

## Examples

```
/library-docs React 19 useTransition hook
/library-docs Next.js 15 server actions
/library-docs TypeScript satisfies operator
/library-docs Tailwind CSS flexbox utilities
```

## Supported Libraries (Examples)

- **Frontend**: React, Next.js, Vue, Angular, Svelte
- **Languages**: TypeScript, JavaScript, Python, Go, Rust
- **Backend**: Node.js, Express, Fastify, Django
- **CSS**: Tailwind CSS, Chakra UI
- **Databases**: PostgreSQL, MongoDB, Redis

## CLI Alternative
```bash
ralph library "React 19 useTransition"
ralph lib "Next.js 15 app router"
ralph docs "TypeScript generics"
```

## Related Commands
- `/research` - General web research (WebSearch + MiniMax)
- `/minimax-search` - Direct MiniMax web search

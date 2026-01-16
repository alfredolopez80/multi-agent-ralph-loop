---
# VERSION: 2.43.0
name: browse
prefix: "@browse"
category: research
color: blue
description: "Browser automation with dev-browser (17% faster, 39% cheaper than Playwright)"
argument-hint: "<url>"
---

# /browse

Browser automation using dev-browser skill.

## v2.25 Benchmarks

| Metric | dev-browser | Playwright MCP |
|--------|-------------|----------------|
| Speed | **+17%** | Baseline |
| Cost | **-39%** | Baseline |
| Success Rate | 100% | 100% |
| Turns | 29 | 51 |

## Execution

Use the dev-browser skill to:
1. Navigate to: $ARGUMENTS
2. Take accessibility snapshot
3. Return structured page content

## Actions

You can specify an action after the URL:
- `--snapshot` - Take accessibility snapshot (default)
- `--screenshot` - Take visual screenshot
- `--pdf` - Export page as PDF
- `--interactive` - Interactive browser control

## Examples

```
/browse https://example.com
/browse https://docs.react.dev --screenshot
/browse localhost:3000 --interactive
```

## CLI Alternative
```bash
ralph browse "https://example.com" --snapshot
ralph browse "https://docs.react.dev" --screenshot
```

## Related Commands
- `/research` - Web research (WebSearch + MiniMax)
- `/library-docs` - Library documentation (Context7)

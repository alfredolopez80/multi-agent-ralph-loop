---
# VERSION: 2.66.8
name: docs
prefix: "@docs"
category: research
color: blue
description: "Access Claude Code documentation from local mirror with auto-updates"
argument-hint: "[topic] or [-t] [topic]"
---

# Claude Code Documentation Command

Execute the Claude Code Docs helper script at ~/.claude-code-docs/claude-docs-helper.sh

## Usage

- `/docs` - List all available documentation topics
- `/docs <topic>` - Read specific documentation with link to official docs
- `/docs -t` - Check sync status without reading a doc
- `/docs -t <topic>` - Check freshness then read documentation
- `/docs whats new` - Show recent documentation changes (or "what's new")
- `/docs changelog` - Read official Claude Code release notes

## Available Topics

| Category | Topics |
|----------|--------|
| **Getting Started** | overview, quickstart, setup, features-overview |
| **Core Features** | hooks, hooks-guide, mcp, memory, skills, sub-agents |
| **Configuration** | settings, model-config, terminal-config, network-config |
| **IDE Integration** | vs-code, jetbrains, devcontainer |
| **Cloud Providers** | amazon-bedrock, google-vertex-ai, microsoft-foundry |
| **CI/CD** | github-actions, gitlab-ci-cd, headless |
| **Security** | security, sandboxing, iam, data-usage |
| **Advanced** | plugins, plugins-reference, statusline, output-styles |
| **Troubleshooting** | troubleshooting, costs, monitoring-usage |

## Examples

```bash
# Read hooks documentation
/docs hooks

# Check for updates and read MCP docs
/docs -t mcp

# See recent changes
/docs what's new

# Check Claude Code release notes
/docs changelog
```

## Output Format

When reading a doc:
```
COMMUNITY MIRROR: https://github.com/ericbuess/claude-code-docs
OFFICIAL DOCS: https://docs.anthropic.com/en/docs/claude-code

[Documentation content...]

Official page: https://docs.anthropic.com/en/docs/claude-code/<topic>
```

## Auto-Updates

Documentation automatically syncs with GitHub when accessed (~0.4s check).
The helper script handles all updates transparently.

## Installation

If not installed, run:
```bash
curl -fsSL https://raw.githubusercontent.com/ericbuess/claude-code-docs/main/install.sh | bash
```

Execute: ~/.claude-code-docs/claude-docs-helper.sh "$ARGUMENTS"

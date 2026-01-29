# Gemini CLI Command Reference

Complete reference for Gemini CLI v0.22.0+

## Installation

```bash
npm install -g @google/gemini-cli
# Or without installing:
npx @google/gemini-cli
```

## Authentication

```bash
# Option 1: API Key
export GEMINI_API_KEY=your_key

# Option 2: OAuth (interactive)
gemini  # First run prompts for auth
```

## Command Line Flags

### Essential Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--yolo` | `-y` | Auto-approve all tool calls |
| `--output-format` | `-o` | Output: `text`, `json`, `stream-json` |
| `--model` | `-m` | Model selection |

### Session Management

| Flag | Short | Description |
|------|-------|-------------|
| `--resume` | `-r` | Resume session by index or "latest" |
| `--list-sessions` | | List available sessions |
| `--delete-session` | | Delete session by index |

### Execution Options

| Flag | Short | Description |
|------|-------|-------------|
| `--sandbox` | `-s` | Run in isolated sandbox |
| `--approval-mode` | | `default`, `auto_edit`, or `yolo` |
| `--timeout` | | Request timeout in ms |
| `--checkpointing` | | Enable file change snapshots |

### Context & Tools

| Flag | Description |
|------|-------------|
| `--include-directories` | Add directories to workspace |
| `--allowed-tools` | Restrict available tools |
| `--allowed-mcp-server-names` | Restrict MCP servers |

### Extensions (v0.22.0+)

| Flag | Short | Description |
|------|-------|-------------|
| `--list-extensions` | `-l` | List installed extensions |
| `extensions install <url>` | | Install extension from GitHub |
| `extensions uninstall <name>` | | Remove extension |

### Other Options

| Flag | Short | Description |
|------|-------|-------------|
| `--debug` | `-d` | Enable debug output |
| `--version` | `-v` | Show version |
| `--help` | `-h` | Show help |
| `--prompt-interactive` | `-i` | Interactive mode with initial prompt |

## Output Formats

### Text (`-o text`)

```bash
gemini "prompt" -o text
# Returns: Human-readable response
```

### JSON (`-o json`)

```bash
gemini "prompt" -o json
```

Returns structured data:
```json
{
  "response": "The actual response content",
  "stats": {
    "models": {
      "gemini-3-pro": {
        "api": {
          "totalRequests": 3,
          "totalErrors": 0,
          "totalLatencyMs": 5000
        },
        "tokens": {
          "prompt": 1500,
          "candidates": 500,
          "total": 2000,
          "cached": 800,
          "thoughts": 150,
          "tool": 50
        }
      }
    },
    "tools": {
      "totalCalls": 2,
      "totalSuccess": 2,
      "totalFail": 0,
      "byName": {
        "google_web_search": {
          "count": 1,
          "success": 1,
          "durationMs": 3000
        }
      }
    }
  }
}
```

### Stream JSON (`-o stream-json`)

Real-time newline-delimited JSON events for monitoring long tasks.

## Model Selection

| Model | Use Case | Context |
|-------|----------|---------|
| `gemini-3-pro` | Complex tasks (default) | 1M tokens |
| `gemini-2.5-flash` | Quick tasks, lower latency | Large |
| `gemini-2.5-flash-lite` | Fastest, simplest tasks | Medium |

## Interactive Commands

In interactive mode, available slash commands:

| Command | Purpose |
|---------|---------|
| `/help` | Show available commands |
| `/tools` | List available tools |
| `/stats` | Show token usage (enhanced in v0.22.0) |
| `/stats model` | Detailed token and cache breakdown |
| `/compress` | Summarize context to save tokens |
| `/restore` | Restore file checkpoints |
| `/chat save <tag>` | Save conversation |
| `/chat resume <tag>` | Resume conversation |
| `/memory show` | Display GEMINI.md context |
| `/memory refresh` | Reload context files |
| `/settings` | Access settings (enable Preview Features) |

## Quota & Stats (v0.22.0+)

View comprehensive usage statistics:
```
/stats       # Overview for all models
/stats model # Detailed breakdown per model
```

Shows:
- Token usage across all models
- Cache efficiency metrics
- Quota remaining

## Piping & Scripting

### Pipe Input

```bash
echo "What is 2+2?" | gemini -o text
cat file.txt | gemini "summarize this" -o text
```

### File Reference Syntax

Reference files with `@`:
```bash
gemini "Review @./src/main.js for bugs" -o text
```

### Multi-file References (v0.22.0+)

Drag & drop multiple files automatically prefixed with `@`:
```bash
gemini "Review @file1.js @file2.js @file3.js" -o text
```

### Shell Command Execution

In interactive mode, prefix with `!`:
```
> !git status
```

## Keyboard Shortcuts (Interactive)

| Shortcut | Function |
|----------|----------|
| `Ctrl+L` | Clear screen |
| `Ctrl+V` | Paste from clipboard |
| `Ctrl+Y` | Toggle YOLO mode |
| `Ctrl+X` | Open in external editor |

## Rate Limits

### Free Tier Limits
- 60 requests per minute
- 1000 requests per day

### Rate Limit Behavior
- CLI auto-retries with exponential backoff
- Message: `"quota will reset after Xs"`
- Typical wait: 1-5 seconds

### Mitigation Strategies
1. Use `gemini-2.5-flash` for simple tasks
2. Batch operations into single prompts
3. Run long tasks in background

## Configuration Files

### Settings Location

Priority order (highest first):
1. `/etc/gemini-cli/settings.json` (system)
2. `~/.gemini/settings.json` (user)
3. `.gemini/settings.json` (project)

### Example Settings

```json
{
  "security": {
    "auth": {
      "selectedType": "oauth-personal"
    }
  },
  "general": {
    "previewFeatures": true,
    "vimMode": false,
    "checkpointing": true
  },
  "mcpServers": {}
}
```

### Enable Gemini 3 (Free Tier)

Set `previewFeatures: true` in settings or via `/settings` interactive command.

## Error Reports

Full error reports saved to:
```
/var/folders/.../gemini-client-error-*.json
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "API key not found" | Set `GEMINI_API_KEY` env var |
| "Rate limit exceeded" | Wait for auto-retry or use Flash |
| "Context too large" | Use `.geminiignore` or be specific |
| "Tool call failed" | Check JSON stats for details |
| "Extension not found" | Verify URL and re-install |

# Claude-Sneakpeek StatusLine Integration Guide

> **Version**: 2.74.10
> **Date**: 2026-01-27
> **Claude-Sneakpeek**: https://github.com/mikekelly/claude-sneakpeek
> **Claude-HUD**: https://github.com/ericbuess/claude-hud

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [StatusLine Script](#statusline-script)
6. [Troubleshooting](#troubleshooting)
7. [Integration Details](#integration-details)

---

## Overview

This guide explains how to integrate the Multi-Agent Ralph statusline with the **claude-sneakpeek** variant of Claude Code and **claude-hud** plugin.

### What is claude-sneakpeek?

**claude-sneakpeek** is a fork/variant of Claude Code that uses the Z.ai (GLM) API instead of the default Anthropic API. Key differences:

| Feature | Standard Claude Code | claude-sneakpeek |
|---------|---------------------|------------------|
| **Config Location** | `~/.claude/` | `~/.claude-sneakpeek/zai/config/` |
| **API Provider** | Anthropic | Z.ai (GLM-4.7) |
| **Settings File** | `~/.claude/settings.json` | `~/.claude-sneakpeek/zai/config/settings.json` |
| **Plugins** | `~/.claude/plugins/` | `~/.claude-sneakpeek/zai/config/plugins/` |

### What is claude-hud?

**claude-hud** is a plugin for Claude Code that displays real-time metrics in the statusline:
- Model name and context usage
- Token counts
- Directory information
- File/dependency counts

---

## Prerequisites

1. **claude-sneakpeek installed**: Verify with:
   ```bash
   ls -la ~/.claude-sneakpeek/zai/config/
   ```

2. **claude-hud installed**: Check for installation:
   ```bash
   ls -la ~/.claude-code-old/plugins/cache/claude-hud/
   # Or
   ls -la ~/.claude-sneakpeek/zai/config/plugins/cache/claude-hud/
   ```

3. **jq installed**: For JSON parsing:
   ```bash
   brew install jq
   ```

---

## Installation

### Step 1: Install Multi-Agent Ralph

```bash
git clone https://github.com/your-username/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop
```

### Step 2: Make StatusLine Script Executable

```bash
chmod +x .claude/scripts/statusline-ralph.sh
```

### Step 3: Verify Script Works

Test the script manually:
```bash
echo '{"cwd":".","model":{"display_name":"glm-4.7"},"context_window":{"total_input_tokens":15000,"total_output_tokens":8000,"context_window_size":200000}}' | bash .claude/scripts/statusline-ralph.sh
```

Expected output (with colors):
```
⎇ main* │ [glm-4.7] █░░░░░░░░░ ctx:11% │ ⏱️ 1% (~5h) │ 🔧 1% MCP (60/4000)
```

---

## Configuration

### settings.json Location

For **claude-sneakpeek**, the configuration file is at:
```
~/.claude-sneakpeek/zai/config/settings.json
```

### StatusLine Configuration

Add the following to your `settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /Users/yourusername/Documents/GitHub/multi-agent-ralph-loop/.claude/scripts/statusline-ralph.sh"
  }
}
```

**Important Notes:**
1. ✅ **No `-c` flag needed**: Just use `bash /path/to/script.sh`
2. ✅ **No `render: "ansi"` needed**: ANSI codes work automatically
3. ✅ **Use absolute path**: Or relative to your home directory

### Full Example settings.json

```json
{
  "alwaysThinkingEnabled": true,
  "env": {
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7",
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_API_KEY": "your-api-key-here",
    "Z_AI_API_KEY": "your-zai-key-here"
  },
  "statusLine": {
    "type": "command",
    "command": "bash /Users/yourusername/Documents/GitHub/multi-agent-ralph-loop/.claude/scripts/statusline-ralph.sh"
  },
  "enabledPlugins": {
    "claude-hud@claude-hud": true
  },
  "language": "English"
}
```

---

## StatusLine Script

### How It Works

The statusline script receives JSON input via stdin:

```json
{
  "cwd": "/current/working/directory",
  "model": {
    "id": "glm-4.7",
    "display_name": "glm-4.7"
  },
  "context_window": {
    "total_input_tokens": 15000,
    "total_output_tokens": 8000,
    "context_window_size": 200000,
    "used_percentage": 11.5
  }
}
```

### Key Components

#### 1. Color Functions (v2.74.8+)

```bash
# Functions that generate ANSI codes for subshell compatibility
ansi_cyan() { printf '\033[0;36m'; }
ansi_green() { printf '\033[0;32m'; }
ansi_yellow() { printf '\033[0;33m'; }
ansi_red() { printf '\033[0;31m'; }

# Cache as variables
CYAN=$(ansi_cyan)
GREEN=$(ansi_green)
YELLOW=$(ansi_yellow)
RED=$(ansi_red)
```

**Why this works:**
- `printf` interprets escape sequences at runtime
- Command substitution `$(...)` executes function and captures output
- Works through multiple shell levels (required for settings.json execution)

#### 2. Git Info Display

```bash
get_git_info() {
    # Get branch name
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)

    # Check for uncommitted changes
    if ! git -C "$cwd" diff --quiet HEAD &>/dev/null; then
        status_icon="*"
    fi

    # Build output: ⎇ main*
    git_output="${GREEN}⎇ ${branch}${status_icon}${RESET}"
    printf '%b\n' "$git_output"
}
```

#### 3. Context Progress Bar

```bash
# Calculate usage percentage
context_usage=$((total_used * 100 / context_size))

# Generate visual bar (10 blocks)
filled_blocks=$((context_usage / 10))
progress_bar=$(printf '█%.0s' $(seq 1 $filled_blocks))$(printf '░%.0s' $(seq 1 $((10 - filled_blocks))))

# Color coding
if [[ $context_usage -lt 50 ]]; then
    context_color="$CYAN"
elif [[ $context_usage -lt 75 ]]; then
    context_color="$GREEN"
elif [[ $context_usage -lt 85 ]]; then
    context_color="$YELLOW"
else
    context_color="$RED"
fi
```

#### 4. Claude-HUD Integration

```bash
# Search in multiple locations for claude-hud
claude_hud_dir=$(ls -td \
    ~/.claude-sneakpeek/zai/config/plugins/cache/claude-hud/claude-hud/*/ \
    ~/.claude/plugins/cache/claude-hud/claude-hud/*/ \
    ~/.claude-code-old/plugins/cache/claude-hud/claude-hud/*/ \
    2>/dev/null | head -1)

# Run claude-hud and filter out duplicate git info
if [[ -n "$claude_hud_dir" ]]; then
    hud_output=$(echo "$stdin_data" | node "${claude_hud_dir}dist/index.js" 2>/dev/null)
    # Filter out their git:(...) format to use our ⎇ format
    hud_output=$(echo "$hud_output" | grep -v "git:(" || echo "$hud_output")
fi
```

### Final Output Format

```
⎇ main* ↑2 │ [glm-4.7] ████████░░ ctx:69% │ ⏱️ 1% (~5h) │ 🔧 1% MCP (60/4000)
2 CLAUDE.md | 1 rules | 11 MCPs
```

**Components:**
| Component | Description | Example |
|-----------|-------------|---------|
| Git info | Branch, status, ahead count | `⎇ main* ↑2` |
| Model | Current model name | `[glm-4.7]` |
| Context | Visual bar + percentage | `████████░░ ctx:69%` |
| Plan | 5-hour plan usage | `⏱️ 1% (~5h)` |
| MCP | Monthly MCP usage | `🔧 1% MCP (60/4000)` |
| Line 2 | claude-hud metrics | `2 CLAUDE.md \| 1 rules \| 11 MCPs` |

---

## Troubleshooting

### Colors Not Showing

**Symptom:** ANSI codes display literally like `[2m█░░░░[0m`

**Solutions:**

1. **Check color functions use `printf`:**
   ```bash
   grep "printf '\\033" .claude/scripts/statusline-ralph.sh
   ```

2. **Verify all outputs use `printf '%b\n'`:**
   ```bash
   grep "printf '%b\\\\n'" .claude/scripts/statusline-ralph.sh
   ```

3. **Remove `render: "ansi"` from settings.json** (not needed)

4. **Test manually:**
   ```bash
   echo '{"cwd":".","model":{"display_name":"glm-4.7"},"context_window":{"total_input_tokens":15000,"total_output_tokens":8000,"context_window_size":200000}}' | bash .claude/scripts/statusline-ralph.sh
   ```

### Git Info Missing or Wrong Format

**Symptom:** Git info shows `git:(main*)` instead of `⎇ main*`, or appears at end

**Solutions:**

1. **Check claude-hud is found:**
   ```bash
   ls -la ~/.claude-code-old/plugins/cache/claude-hud/claude-hud/*/dist/index.js
   ```

2. **Verify git info is added first:**
   ```bash
   grep -A5 "Add git_info FIRST" .claude/scripts/statusline-ralph.sh
   ```

3. **Check git:(...) filter is active:**
   ```bash
   grep "grep -v \"git:(" .claude/scripts/statusline-ralph.sh
   ```

### Double Separators │ │

**Symptom:** Two separators appear together

**Solution:** Check that `context_display` doesn't include leading `│` or trailing `|`:
```bash
grep "context_display=" .claude/scripts/statusline-ralph.sh | grep -v "│\| |"
```

Should be:
```bash
context_display="[${model_name}] ${context_color}${progress_bar}${RESET} ..."
```

### Progress Bar is Gray

**Symptom:** Bar `██████░░░░` appears gray/dim

**Solution:** Remove `${DIM}` from bar:
```bash
grep "progress_bar" .claude/scripts/statusline-ralph.sh | grep DIM
```

Should be:
```bash
context_display="[${model_name}] ${context_color}${progress_bar}${RESET} ..."
```

NOT:
```bash
context_display="[${model_name}] ${DIM}${progress_bar}${RESET} ..."  # WRONG
```

### Claude-HUD Not Found

**Symptom:** Git info shows `git:(main*)` format (claude-hud default)

**Solution:** Add your claude-hud location to the search paths:
```bash
claude_hud_dir=$(ls -td \
    ~/.claude-sneakpeek/zai/config/plugins/cache/claude-hud/claude-hud/*/ \
    ~/.claude/plugins/cache/claude-hud/claude-hud/*/ \
    ~/.claude-code-old/plugins/cache/claude-hud/claude-hud/*/ \
    ~/.your-custom-path/here/*/ \
    2>/dev/null | head -1)
```

---

## Integration Details

### Claude-Sneakpeek Specifics

#### Configuration Directory Structure

```
~/.claude-sneakpeek/zai/config/
├── settings.json              # Main configuration
├── .claude.json              # Legacy format (unused)
├── hooks/                    # Hook scripts
├── skills/                   # Custom skills
├── projects/                 # Session files
└── plugins/                  # Installed plugins
    └── cache/
        └── claude-hud/
            └── claude-hud/
                └── 0.1.0/
                    └── dist/
                        └── index.js
```

#### Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `CLAUDE_CONFIG_DIR` | Config directory | `~/.claude-sneakpeek/zai/config` |
| `ANTHROPIC_BASE_URL` | API endpoint | `https://api.z.ai/api/anthropic` |
| `ANTHROPIC_API_KEY` | API key | `your-key-here` |
| `Z_AI_API_KEY` | Z.ai specific key | `your-zai-key` |

#### Model Configuration

```json
{
  "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
  "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
  "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7"
}
```

### Claude-HUD Integration

#### How Claude-HUD Works

1. **Receives JSON** via stdin (same as statusline script)
2. **Parses** context_window, model, workspace data
3. **Generates** multi-line output with metrics
4. **Displays** in statusline below main line

#### Claude-HUD Output Format

```
[model] ████████░░ 69% /path/to/project
git:(main*) 2 files | 5 rules | 10 MCPs
```

#### Our Integration Strategy

1. **Find claude-hud** in multiple possible locations
2. **Run it** and capture output
3. **Filter out** `[model]` line (we show our own context)
4. **Filter out** `git:(...)` line (we show our own format)
5. **Keep** remaining metrics (files, rules, MCPs)

```bash
# Filter out duplicate lines
hud_output=$(echo "$hud_output" | grep -vF "[${model_name}]")
hud_output=$(echo "$hud_output" | grep -v "git:(")
```

### Multi-Variant Support

The statusline script supports multiple Claude Code variants:

| Variant | Config Path | Detected |
|---------|-------------|----------|
| **Standard** | `~/.claude/` | ✅ |
| **claude-sneakpeek** | `~/.claude-sneakpeek/zai/config/` | ✅ |
| **claude-code-old** | `~/.claude-code-old/` | ✅ |

```bash
# Search all variants
claude_hud_dir=$(ls -td \
    ~/.claude-sneakpeek/zai/config/plugins/cache/claude-hud/claude-hud/*/ \
    ~/.claude/plugins/cache/claude-hud/claude-hud/*/ \
    ~/.claude-code-old/plugins/cache/claude-hud/claude-hud/*/ \
    2>/dev/null | head -1)
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.74.10 | 2026-01-27 | **Final**: Git info always at beginning, claude-hud filtered |
| 2.74.9 | 2026-01-27 | Fixed DIM on bar, removed leading │ |
| 2.74.8 | 2026-01-27 | Color functions with printf for subshell compatibility |
| 2.74.5 | 2026-01-27 | Git info reordered to beginning |
| 2.74.2 | 2026-01-27 | Initial claude-hud integration |

---

## References

- [Claude Code StatusLine Docs](https://code.claude.com/docs/en/statusline)
- [claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek)
- [claude-hud](https://github.com/ericbuess/claude-hud)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)

---

## Summary

This guide provides a complete, reproducible process for integrating the Multi-Agent Ralph statusline with:

1. ✅ **claude-sneakpeek** - Z.ai GLM API variant
2. ✅ **claude-hud** - Real-time metrics plugin
3. ✅ **Proper ANSI colors** - Using functions with printf
4. ✅ **Consistent git format** - Always `⎇ branch*` at beginning
5. ✅ **Multi-variant support** - Works with standard, sneakpeek, and old variants

**Status:** ✅ **Fully Functional and Documented**

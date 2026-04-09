# Ralph Library Modules (`lib/`)

Modular bash libraries extracted from the monolithic `scripts/ralph` CLI (8,264 lines, 134 functions). Each module is independently sourceable and guarded against double-loading.

## Quick Start

```bash
# Source everything at once
source lib/loader.sh

# Or source individual modules
source lib/common.sh
source lib/circuit_breaker.sh
```

## Modules

### `common.sh` — Core Utilities

Shared foundations used by all other modules.

| Function | Purpose |
|----------|---------|
| `log_info`, `log_success`, `log_warn`, `log_error` | Colored log output |
| `ralph_repo_root [dir]` | Find repo root from any nested path |
| `load_ralphrc [dir]` | Load `.ralphrc` project config with defaults |
| `has_cmd <cmd>` | Check if command exists (no output) |
| `require_cmd <cmd> [purpose]` | Require command or error with message |
| `check_cmds <cmd...>` | Check multiple commands, return missing list |

**Variables exported:**
- `RALPH_HOME` — `~/.ralph` (global state)
- `RALPH_CLAUDE_DIR` — `~/.claude`
- `RALPH_INSTALL_DIR` — `~/.local/bin`
- Color constants: `RED`, `GREEN`, `BLUE`, `YELLOW`, `CYAN`, `NC`

### `security.sh` — Security Utilities

Input validation and security hardening.

| Function | Purpose |
|----------|---------|
| `init_secure_tmpdir` | Create secure temp dir with unpredictable name |
| `validate_path <path> [purpose]` | Block traversal, injection, null bytes |
| `validate_text_input <text> [purpose] [max_len]` | Validate free-form user input |
| `escape_for_shell <string>` | Safe shell escaping via `printf %q` |
| `log_security <action> <reason> [context] [detail]` | JSON audit log entry |

**Side effects:**
- Sets `umask 077` (user-only file creation)
- Appends to `~/.ralph/security-audit.log`

### `circuit_breaker.sh` — Loop Safeguard

Prevents runaway loops by detecting stagnation. Based on [Michael Nygard's circuit breaker pattern](https://martinfowler.com/bliki/CircuitBreaker.html), adapted from [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code).

**States:**
```
CLOSED (normal) ──→ HALF_OPEN (monitoring) ──→ OPEN (halted)
     ↑                      │                       │
     └──────────────────────┘                       │
          (progress detected)                       │
     ↑                                              │
     └──────────────────────────────────────────────┘
               (cooldown elapsed + progress)
```

| Function | Purpose |
|----------|---------|
| `cb_init` | Initialize or recover state from disk |
| `cb_can_execute` | Returns 0 if loop may continue |
| `cb_record_result <loop#> <files_changed> <has_errors>` | Record iteration outcome, trigger transitions |
| `cb_reset [reason]` | Reset to CLOSED state |
| `cb_status` | Print current state to stdout |
| `cb_state` | Return state string (CLOSED/HALF_OPEN/OPEN) |

**Configuration (via `.ralphrc` or environment):**

| Variable | Default | Purpose |
|----------|---------|---------|
| `CB_NO_PROGRESS_THRESHOLD` | 3 | Loops without file changes before OPEN |
| `CB_SAME_ERROR_THRESHOLD` | 5 | Repeated errors before OPEN |
| `CB_COOLDOWN_MINUTES` | 30 | Minutes before auto-recovery attempt |
| `CB_AUTO_RESET` | false | Reset to CLOSED on startup |

**Usage in a loop:**
```bash
source lib/loader.sh
load_ralphrc
cb_init

for i in $(seq 1 25); do
    cb_can_execute || { cb_status; break; }

    # ... do work ...
    files_changed=$(git diff --stat | wc -l)
    has_errors="false"

    cb_record_result "$i" "$files_changed" "$has_errors" || break
done
```

**State persistence:** JSON at `~/.ralph/state/circuit_breaker.json`

### `loader.sh` — Module Loader

Sources all modules in dependency order. Use this as the single entry point:

```bash
RALPH_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
source "$RALPH_LIB/loader.sh"
```

## Per-Project Configuration (`.ralphrc`)

Initialize a project with `scripts/ralph-init`:

```bash
ralph-init --name my-app --type python
```

This creates `.ralphrc` (sourced by `load_ralphrc()`) and `.ralph/` state directory. See `templates/ralphrc.template` for all available settings.

## Migration Path

The existing `scripts/ralph` monolith works unchanged. To incrementally adopt modules:

1. Add `source lib/loader.sh` near the top of `scripts/ralph`
2. Replace inline function definitions with module equivalents
3. Remove duplicated code from `scripts/ralph`
4. Repeat per function group

Target module extraction order:
1. Logging + colors (already in `common.sh`)
2. Security functions (already in `security.sh`)
3. Memory search (`cmd_memory_search`, `cmd_fork_suggest`, `cmd_memory_stats`)
4. Worktree commands (`cmd_worktree*`)
5. Plan commands (`cmd_plan*`)
6. Quality gates (`cmd_gates`, `cmd_security`, `cmd_bugs`)

## Design Principles

- **Double-source guard**: Each module checks `_RALPH_LIB_*_LOADED` before executing
- **No side effects on source**: Modules define functions and variables, but don't execute commands (except `security.sh` setting `umask`)
- **Portable**: No hardcoded paths; uses `$HOME`, `dirname`, `pwd`
- **macOS + Linux**: Avoids GNU-only flags (`realpath -m`, `date -d`)

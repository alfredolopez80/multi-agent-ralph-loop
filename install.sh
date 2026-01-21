#!/usr/bin/env bash
# install.sh - Multi-Agent Ralph Wiggum v2.24.1 Global Installer
# Installs ralph CLI globally and integrates with Claude Code
# v2.24.1: Security hardening (CWE-20, CWE-22, CWE-94, CWE-1325)
# v2.24: MiniMax MCP integration (web_search + understand_image), 87% cost savings
# v2.23: AST-grep integration for structural code search (~75% token savings)
# v2.22: Tool validation (startup + on-demand), 9 language quality gates
# v2.21: Self-update, pre-merge validation, integrations health check
# v2.20: Git worktree + PR workflow with multi-agent review (Claude + Codex)
# v2.19: Security hardening (VULN-001 to VULN-008 fixes), improved file permissions

set -euo pipefail

# SECURITY: Ensure all created files are user-only by default (VULN-008)
umask 077

VERSION="2.24.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation directories
INSTALL_DIR="${HOME}/.local/bin"
RALPH_DIR="${HOME}/.ralph"
CLAUDE_DIR="${HOME}/.claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECK
# ═══════════════════════════════════════════════════════════════════════════════
check_dependencies() {
    echo ""
    log_info "Checking dependencies..."

    local MISSING=()
    local OPTIONAL_MISSING=()

    # Required
    command -v jq &>/dev/null || MISSING+=("jq")
    command -v curl &>/dev/null || MISSING+=("curl")

    # Optional but recommended
    command -v claude &>/dev/null || OPTIONAL_MISSING+=("claude (Claude Code CLI)")
    command -v codex &>/dev/null || OPTIONAL_MISSING+=("codex (Codex CLI)")
    command -v gemini &>/dev/null || OPTIONAL_MISSING+=("gemini (Gemini CLI)")
    command -v wt &>/dev/null || OPTIONAL_MISSING+=("wt (WorkTrunk - for git worktree workflow)")
    command -v gh &>/dev/null || OPTIONAL_MISSING+=("gh (GitHub CLI - for PR workflow)")

    # Language-specific (optional)
    command -v npx &>/dev/null || OPTIONAL_MISSING+=("npx (Node.js - for TypeScript/ESLint)")
    command -v pyright &>/dev/null || OPTIONAL_MISSING+=("pyright (Python type checker)")
    command -v ruff &>/dev/null || OPTIONAL_MISSING+=("ruff (Python linter)")

    if [ ${#MISSING[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${MISSING[*]}"
        echo ""
        echo "  Install them with:"
        echo "    brew install ${MISSING[*]}"
        echo ""
        exit 1
    fi

    log_success "Required dependencies OK"

    if [ ${#OPTIONAL_MISSING[@]} -gt 0 ]; then
        log_warn "Optional dependencies not found:"
        for dep in "${OPTIONAL_MISSING[@]}"; do
            echo "    - $dep"
        done
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# BACKUP EXISTING CONFIG
# ═══════════════════════════════════════════════════════════════════════════════
backup_existing() {
    local BACKUP_DIR="${RALPH_DIR}/backups/$(date +%Y%m%d_%H%M%S)"

    if [ -d "${CLAUDE_DIR}/agents" ] || [ -d "${CLAUDE_DIR}/commands" ] || [ -f "${CLAUDE_DIR}/settings.json" ]; then
        log_info "Backing up existing Claude Code config..."
        mkdir -p "$BACKUP_DIR"

        [ -d "${CLAUDE_DIR}/agents" ] && cp -r "${CLAUDE_DIR}/agents" "$BACKUP_DIR/" 2>/dev/null || true
        [ -d "${CLAUDE_DIR}/commands" ] && cp -r "${CLAUDE_DIR}/commands" "$BACKUP_DIR/" 2>/dev/null || true
        [ -d "${CLAUDE_DIR}/skills" ] && cp -r "${CLAUDE_DIR}/skills" "$BACKUP_DIR/" 2>/dev/null || true
        [ -d "${CLAUDE_DIR}/hooks" ] && cp -r "${CLAUDE_DIR}/hooks" "$BACKUP_DIR/" 2>/dev/null || true
        [ -f "${CLAUDE_DIR}/settings.json" ] && cp "${CLAUDE_DIR}/settings.json" "$BACKUP_DIR/" 2>/dev/null || true

        log_success "Backup saved to: $BACKUP_DIR"
        # Store backup dir for potential restore
        LAST_BACKUP_DIR="$BACKUP_DIR"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MERGE SETTINGS (CRITICAL: Never overwrite, always merge)
# ═══════════════════════════════════════════════════════════════════════════════
merge_settings() {
    local RALPH_SETTINGS="${SCRIPT_DIR}/.claude/settings.json"
    local USER_SETTINGS="${CLAUDE_DIR}/settings.json"
    local TEMP_MERGED="${CLAUDE_DIR}/.settings.merged.tmp"

    # If no existing user settings, just copy ours
    if [ ! -f "$USER_SETTINGS" ]; then
        cp "$RALPH_SETTINGS" "$USER_SETTINGS"
        log_success "Settings installed (new file)"
        return 0
    fi

    log_info "Merging settings (preserving your existing configuration)..."

    # Validate both files are valid JSON
    if ! jq empty "$USER_SETTINGS" 2>/dev/null; then
        log_warn "Existing settings.json is invalid JSON - backing up and replacing"
        cp "$USER_SETTINGS" "${USER_SETTINGS}.invalid.bak"
        cp "$RALPH_SETTINGS" "$USER_SETTINGS"
        return 0
    fi

    # Deep merge using jq:
    # 1. Preserve ALL user settings
    # 2. Add our permissions (array union, no duplicates)
    # 3. Add our hooks (merge hook arrays, no duplicates)
    # 4. Preserve $schema from our file for validation

    jq -s '
    # Helper to merge hook arrays by matcher (no duplicates)
    def merge_hooks(a; b):
        if (a | type) == "array" and (b | type) == "array" then
            # Both are arrays - combine and deduplicate by matcher
            (a + b) | group_by(.matcher) | map(
                .[0] + {
                    hooks: ([.[].hooks] | add | unique_by(.command))
                }
            )
        elif (a | type) == "array" then a
        elif (b | type) == "array" then b
        else [] end;

    # $user is .[0], $ralph is .[1]
    .[0] as $user | .[1] as $ralph |

    # Start with user settings as base
    $user |

    # Add schema from ralph if user does not have one
    (if .["$schema"] then . else . + {"$schema": $ralph["$schema"]} end) |

    # Merge permissions.allow arrays (union, no duplicates)
    .permissions.allow = (
        (($user.permissions.allow // []) + ($ralph.permissions.allow // [])) | unique
    ) |

    # Merge permissions.deny arrays if they exist (union, no duplicates)
    (if ($user.permissions.deny // $ralph.permissions.deny) then
        .permissions.deny = ((($user.permissions.deny // []) + ($ralph.permissions.deny // [])) | unique)
    else . end) |

    # Merge hooks.PreToolUse
    .hooks.PreToolUse = merge_hooks($user.hooks.PreToolUse; $ralph.hooks.PreToolUse) |

    # Merge hooks.PostToolUse
    .hooks.PostToolUse = merge_hooks($user.hooks.PostToolUse; $ralph.hooks.PostToolUse) |

    # Ensure we dont have null values
    del(..|nulls)
    ' "$USER_SETTINGS" "$RALPH_SETTINGS" > "$TEMP_MERGED" 2>/dev/null

    # Validate merged result
    if jq empty "$TEMP_MERGED" 2>/dev/null; then
        mv "$TEMP_MERGED" "$USER_SETTINGS"
        log_success "Settings merged successfully:"
        log_success "  - Your existing settings: PRESERVED"
        log_success "  - Ralph permissions: ADDED"
        log_success "  - Ralph hooks: ADDED"
    else
        rm -f "$TEMP_MERGED"
        log_error "Failed to merge settings. Your settings are unchanged."
        log_warn "You may need to manually add Ralph hooks to your settings.json"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# CREATE DIRECTORIES
# ═══════════════════════════════════════════════════════════════════════════════
create_directories() {
    log_info "Creating directories..."

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$RALPH_DIR"/{config,improvements/backups,logs}
    mkdir -p "$CLAUDE_DIR"/{agents,commands,skills,hooks}

    log_success "Directories created"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CLI SCRIPTS
# ═══════════════════════════════════════════════════════════════════════════════
install_scripts() {
    log_info "Installing CLI scripts..."

    # Copy ralph and mmc
    cp "${SCRIPT_DIR}/scripts/ralph" "$INSTALL_DIR/ralph"
    cp "${SCRIPT_DIR}/scripts/mmc" "$INSTALL_DIR/mmc"

    # Make executable
    chmod +x "$INSTALL_DIR/ralph"
    chmod +x "$INSTALL_DIR/mmc"

    log_success "CLI scripts installed to $INSTALL_DIR"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL VERCEL REACT BEST PRACTICES SKILL
# ═══════════════════════════════════════════════════════════════════════════════
install_vercel_react_skill() {
    log_info "Installing Vercel React Best Practices skill..."

    local REACT_SKILL_DIR="${CLAUDE_DIR}/skills/react-best-practices"
    local REACT_SKILL_URL="https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices"

    # Create the skill directory
    mkdir -p "$REACT_SKILL_DIR"

    # Download the SKILL.md file from Vercel agent-skills repo
    local SKILL_URL="https://raw.githubusercontent.com/vercel-labs/agent-skills/main/skills/react-best-practices/SKILL.md"

    if command -v curl &>/dev/null; then
        if curl -fsSL "$SKILL_URL" -o "${REACT_SKILL_DIR}/SKILL.md" 2>/dev/null; then
            log_success "React Best Practices skill installed from Vercel"
            log_info "  Source: $REACT_SKILL_URL"
            return 0
        fi
    fi

    # Fallback: Create skill file manually if download fails
    cat > "${REACT_SKILL_DIR}/SKILL.md" << 'SKILLEOF'
---
name: react-best-practices
description: When the user wants to write, review, or improve React code. Use when you see React, JSX, React hooks, or any frontend framework patterns. This skill provides Vercel's best practices for building high-quality React applications.
---

# React Best Practices

You are an expert React developer following Vercel's best practices for building high-quality React applications.

## Core Principles

### 1. Component Design

**Prefer Composition Over Inheritance**
```jsx
// GOOD: Composition
function Card({ children }) {
  return <div className="card">{children}</div>;
}
function UserCard({ user }) {
  return (
    <Card>
      <Avatar src={user.avatar} />
      <Name name={user.name} />
    </Card>
  );
}

// AVOID: Deep nesting or inheritance
class UserCard extends React.Component { ... }
```

**Small, Focused Components**
Each component should do one thing well. If a component grows too large, split it.

```jsx
// GOOD: Focused components
function UserAvatar({ src, alt }) {
  return <img src={src} alt={alt} className="avatar" />;
}
function UserInfo({ user }) {
  return (
    <div>
      <UserAvatar src={user.avatar} alt={user.name} />
      <span>{user.name}</span>
    </div>
  );
}
```

### 2. React Hooks

**Use Functional Updates**
```jsx
// GOOD
const [count, setCount] = useState(0);
setCount(prev => prev + 1);

// AVOID
setCount(count + 1); // May use stale value
```

**Use useEffect Correctly**
```jsx
// GOOD: Proper cleanup
useEffect(() => {
  const subscription = subscribe(id, handleChange);
  return () => {
    subscription.unsubscribe();
  };
}, [id]);

// AVOID: Missing cleanup
useEffect(() => {
  subscribe(id, handleChange);
}, [id]);
```

**Custom Hooks for Reusable Logic**
```jsx
// GOOD: Extract logic to custom hook
function useDataFetching(url) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(url).then(setData).finally(() => setLoading(false));
  }, [url]);

  return { data, loading };
}

function UserProfile({ userId }) {
  const { data: user, loading } = useDataFetching(`/api/users/${userId}`);
  if (loading) return <Spinner />;
  return <UserInfo user={user} />;
}
```

### 3. Performance

**Use useMemo and useCallback Appropriately**
```jsx
// GOOD: Memoize expensive computations
const expensiveValue = useMemo(() => {
  return compute(a, b);
}, [a, b]);

// GOOD: Memoize callbacks
const handleClick = useCallback(() => {
  doSomething(id);
}, [id]);
```

**Lazy Loading with React.lazy and Suspense**
```jsx
// GOOD: Code splitting
const HeavyComponent = lazy(() => import('./HeavyComponent'));

function MyComponent() {
  return (
    <Suspense fallback={<Loading />}>
      <HeavyComponent />
    </Suspense>
  );
}
```

**Virtualize Long Lists**
```jsx
// GOOD: Use react-window for long lists
import { FixedSizeList as List } from 'react-window';

function Row({ index, style }) {
  return <div style={style}>{items[index]}</div>;
}

function VirtualList({ items }) {
  return <List height={600} itemCount={items.length} itemSize={35} width="100%" />;
}
```

### 4. State Management

**Use the Right State Strategy**
```jsx
// GOOD: Local state for UI
const [isOpen, setIsOpen] = useState(false);

// GOOD: Derived state from props
function UserProfile({ user }) {
  const fullName = `${user.firstName} ${user.lastName}`; // Derived, no state needed
  return <div>{fullName}</div>;
}

// GOOD: State machines for complex state
const [state, send] = useMachine(userMachine);
```

**Avoid Prop Drilling with Context**
```jsx
// GOOD: Use Context for deeply nested consumers
const ThemeContext = createContext('light');

function App() {
  return (
    <ThemeContext.Provider value="dark">
      <Toolbar />
    </ThemeContext.Provider>
  );
}

function Toolbar() {
  const theme = useContext(ThemeContext); // No props needed
  return <button className={theme}>OK</button>;
}
```

### 5. Error Handling

**Error Boundaries**
```jsx
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true };
  }

  componentDidCatch(error, info) {
    logError(error, info.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return <Fallback />;
    }
    return this.props.children;
  }
}

// Usage
<ErrorBoundary>
  <Widget />
</ErrorBoundary>
```

### 6. Testing

**Test Behavior, Not Implementation**
```jsx
// GOOD: Test user behavior
test('shows loading then user data', async () => {
  render(<UserProfile userId="123" />);
  expect(screen.getByText('Loading...')).toBeInTheDocument();
  await waitFor(() => expect(screen.getByText('John')).toBeInTheDocument());
});

// AVOID: Testing implementation details
test('calls useUser hook', () => {
  const { result } = renderHook(() => useUser('123'));
  expect(result.current.isLoading).toBe(true);
});
```

### 7. TypeScript Integration

**Use TypeScript for Safety**
```tsx
// GOOD: Well-typed components
interface ButtonProps {
  variant: 'primary' | 'secondary';
  onClick: () => void;
  children: React.ReactNode;
}

function Button({ variant, onClick, children }: ButtonProps) {
  return <button className={variant}>{children}</button>;
}

// GOOD: Generic components
function List<T>({ items, render }: ListProps<T>) {
  return (
    <ul>
      {items.map(item => <li key={item.id}>{render(item)}</li>)}
    </ul>
  );
}
```

### 8. Accessibility

**Use Semantic HTML**
```jsx
// GOOD: Semantic elements
<nav>...</nav>
<main>...</main>
<article>...</article>
<button onClick={handleClick}>Submit</button>

// AVOID: Non-semantic
<div onClick={handleClick}>Submit</div>
```

**Add ARIA Attributes When Needed**
```jsx
// GOOD: Accessible
<button aria-expanded={isOpen} aria-haspopup="menu">
  Menu
</button>

<input
  type="text"
  aria-label="Search"
  aria-describedby="search-help"
  id="search"
/>
<span id="search-help">Enter keywords to search</span>
```

### 9. Server Components (Next.js)

**Use Server Components by Default**
```tsx
// This is a Server Component - runs on server
async function Page({ params }) {
  const data = await db.user.findUnique({ where: { id: params.id } });
  return <UserCard user={data} />;
}
```

**Use 'use client' Sparingly**
```tsx
// Only use 'use client' when you need:
// - useState, useEffect, useRef
// - Event handlers (onClick, onChange)
// - Client-side lifecycle (onMount, onUnmount)

'use client';
'use client';

function Counter() {
  const [count, setCount] = useState(0); // Needs 'use client'
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}
```

### 10. Project Structure

```
src/
├── app/                    # Next.js App Router
│   ├── page.tsx           # Route: /
│   ├── layout.tsx         # Root layout
│   └── users/             # Route: /users
│       ├── page.tsx
│       └── [id]/
│           └── page.tsx
├── components/            # Shared components
│   ├── ui/               # Generic UI (Button, Input)
│   └── features/         # Feature-specific components
├── hooks/                 # Custom hooks
├── lib/                   # Utilities, API clients
├── types/                 # TypeScript types
└── styles/                # Global styles
```

## Code Style

1. **File Naming**: PascalCase for components, camelCase for hooks
2. **Component Order**: Props → State → Effects → Handlers → Render
3. **Imports**: React → External → Internal → CSS/Assets
4. **Props Destructure** for clarity

## When Helping Users

1. **Explain the "Why"** - Don't just write code, explain the reasoning
2. **Show Examples** - Provide before/after comparisons
3. **Consider Performance** - Suggest optimizations when appropriate
4. **Error Handling** - Always handle edge cases
5. **Accessibility** - Ensure your code is accessible
6. **Testing** - Suggest how to test what you write

## Triggers

This skill activates when:
- User asks about React, JSX, or React hooks
- User wants to build or improve React components
- User mentions Next.js, Remix, or other React frameworks
- User asks about React patterns or best practices
SKILLEOF

    log_success "React Best Practices skill created (fallback mode)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CLAUDE CODE COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════════
install_claude_components() {
    log_info "Installing Claude Code components..."

    # Agents
    if [ -d "${SCRIPT_DIR}/.claude/agents" ]; then
        cp -r "${SCRIPT_DIR}/.claude/agents/"* "${CLAUDE_DIR}/agents/" 2>/dev/null || true
        log_success "Agents installed ($(ls -1 "${CLAUDE_DIR}/agents/" 2>/dev/null | wc -l | tr -d ' ') files)"
    fi

    # Commands
    if [ -d "${SCRIPT_DIR}/.claude/commands" ]; then
        cp -r "${SCRIPT_DIR}/.claude/commands/"* "${CLAUDE_DIR}/commands/" 2>/dev/null || true
        log_success "Commands installed ($(ls -1 "${CLAUDE_DIR}/commands/" 2>/dev/null | wc -l | tr -d ' ') files)"
    fi

    # Skills (from project)
    if [ -d "${SCRIPT_DIR}/.claude/skills" ]; then
        cp -r "${SCRIPT_DIR}/.claude/skills/"* "${CLAUDE_DIR}/skills/" 2>/dev/null || true
        log_success "Project skills installed"
    fi

    # Vercel React Best Practices skill (external)
    install_vercel_react_skill

    # Hooks (with proper permissions)
    if [ -d "${SCRIPT_DIR}/.claude/hooks" ]; then
        cp -r "${SCRIPT_DIR}/.claude/hooks/"* "${CLAUDE_DIR}/hooks/" 2>/dev/null || true
        # Make all hook scripts executable (both .sh and .py)
        chmod +x "${CLAUDE_DIR}/hooks/"*.sh 2>/dev/null || true
        chmod +x "${CLAUDE_DIR}/hooks/"*.py 2>/dev/null || true
        log_success "Hooks installed:"
        log_success "  - git-safety-guard.py (blocks destructive git commands)"
        log_success "  - quality-gates.sh (9-language validation)"
    fi

    # Merge settings.json (CRITICAL: preserve user's existing settings)
    if [ -f "${SCRIPT_DIR}/.claude/settings.json" ]; then
        merge_settings
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CODEX CONFIG (Safe merge)
# ═══════════════════════════════════════════════════════════════════════════════
install_codex_config() {
    if [ ! -d "${SCRIPT_DIR}/.codex" ]; then
        return 0
    fi

    log_info "Installing Codex CLI config..."
    mkdir -p "${HOME}/.codex/skills"

    local CODEX_INSTRUCTIONS="${HOME}/.codex/instructions.md"
    local RALPH_CODEX_INSTRUCTIONS="${SCRIPT_DIR}/.codex/instructions.md"
    local RALPH_MARKER="# === RALPH WIGGUM CODEX CONFIG ==="

    # Handle instructions.md
    if [ -f "$RALPH_CODEX_INSTRUCTIONS" ]; then
        if [ -f "$CODEX_INSTRUCTIONS" ]; then
            # Check if Ralph section already exists
            if grep -q "$RALPH_MARKER" "$CODEX_INSTRUCTIONS" 2>/dev/null; then
                log_info "Codex instructions already contain Ralph config"
            else
                # Append Ralph config to existing
                log_info "Appending Ralph config to existing Codex instructions..."
                {
                    echo ""
                    echo "$RALPH_MARKER"
                    echo "# Added by Ralph Wiggum v${VERSION}"
                    echo "# Do not edit between markers - will be updated on reinstall"
                    echo ""
                    cat "$RALPH_CODEX_INSTRUCTIONS"
                    echo ""
                    echo "# === END RALPH WIGGUM CODEX CONFIG ==="
                } >> "$CODEX_INSTRUCTIONS"
                log_success "Codex instructions merged (your existing config preserved)"
            fi
        else
            # No existing instructions, just copy
            cp "$RALPH_CODEX_INSTRUCTIONS" "$CODEX_INSTRUCTIONS"
            log_success "Codex instructions installed (new file)"
        fi
    fi

    # Copy skills (these are safe to overwrite as they're Ralph-specific)
    if [ -d "${SCRIPT_DIR}/.codex/skills" ]; then
        cp -r "${SCRIPT_DIR}/.codex/skills/"* "${HOME}/.codex/skills/" 2>/dev/null || true
        log_success "Codex skills installed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL GEMINI CONFIG (Safe merge)
# ═══════════════════════════════════════════════════════════════════════════════
install_gemini_config() {
    if [ ! -d "${SCRIPT_DIR}/.gemini" ]; then
        return 0
    fi

    log_info "Installing Gemini CLI config..."
    mkdir -p "${HOME}/.gemini"

    local GEMINI_CONFIG="${HOME}/.gemini/GEMINI.md"
    local RALPH_GEMINI_CONFIG="${SCRIPT_DIR}/.gemini/GEMINI.md"
    local RALPH_MARKER="# === RALPH WIGGUM GEMINI CONFIG ==="

    # Handle GEMINI.md
    if [ -f "$RALPH_GEMINI_CONFIG" ]; then
        if [ -f "$GEMINI_CONFIG" ]; then
            # Check if Ralph section already exists
            if grep -q "$RALPH_MARKER" "$GEMINI_CONFIG" 2>/dev/null; then
                log_info "Gemini config already contains Ralph config"
            else
                # Append Ralph config to existing
                log_info "Appending Ralph config to existing Gemini config..."
                {
                    echo ""
                    echo "$RALPH_MARKER"
                    echo "# Added by Ralph Wiggum v${VERSION}"
                    echo "# Do not edit between markers - will be updated on reinstall"
                    echo ""
                    cat "$RALPH_GEMINI_CONFIG"
                    echo ""
                    echo "# === END RALPH WIGGUM GEMINI CONFIG ==="
                } >> "$GEMINI_CONFIG"
                log_success "Gemini config merged (your existing config preserved)"
            fi
        else
            # No existing config, just copy
            cp "$RALPH_GEMINI_CONFIG" "$GEMINI_CONFIG"
            log_success "Gemini config installed (new file)"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# INSTALL CONFIG FILES
# ═══════════════════════════════════════════════════════════════════════════════
install_config() {
    log_info "Installing configuration..."

    # Copy models.json
    cp "${SCRIPT_DIR}/config/models.json" "${RALPH_DIR}/config/"

    log_success "Configuration installed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURE SHELL (Safe update with markers)
# ═══════════════════════════════════════════════════════════════════════════════
configure_shell() {
    log_info "Configuring shell..."

    local SHELL_RC=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [ -z "$SHELL_RC" ]; then
        log_warn "No .zshrc or .bashrc found - add PATH manually"
        return 0
    fi

    local START_MARKER="# >>> RALPH WIGGUM START >>>"
    local END_MARKER="# <<< RALPH WIGGUM END <<<"

    # Check if Ralph section already exists
    if grep -q "$START_MARKER" "$SHELL_RC" 2>/dev/null; then
        # Remove old Ralph section and replace with new
        log_info "Updating existing Ralph shell config..."
        # Create temp file without Ralph section
        local TEMP_RC="${SHELL_RC}.ralph.tmp"
        sed "/$START_MARKER/,/$END_MARKER/d" "$SHELL_RC" > "$TEMP_RC"
        mv "$TEMP_RC" "$SHELL_RC"
    fi

    # Append new Ralph section
    cat >> "$SHELL_RC" << RCEOF

$START_MARKER
# Ralph Wiggum v${VERSION} - Multi-Agent Orchestration
# This section is managed by Ralph - do not edit manually
# To update: reinstall Ralph or edit and remove markers

export PATH="\$HOME/.local/bin:\$PATH"

# Ralph aliases
alias rh='ralph'
alias rho='ralph orch'
alias rhr='ralph review'
alias rhp='ralph parallel'
alias rhs='ralph security'
alias rhb='ralph bugs'
alias rhu='ralph unit-tests'
alias rhf='ralph refactor'
alias rhres='ralph research'
alias rhm='ralph minimax'
alias rhg='ralph gates'
alias rha='ralph adversarial'
alias rhl='ralph loop'
alias rhc='ralph clarify'
alias rhret='ralph retrospective'
alias rhi='ralph improvements'

# MiniMax aliases
alias mm='mmc'
alias mml='mmc --loop 30'
alias mmlight='mmc --lightning'
$END_MARKER
RCEOF
    log_success "Shell aliases configured in $SHELL_RC"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFY INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════════
verify_installation() {
    log_info "Verifying installation..."

    local ERRORS=0

    [ -x "$INSTALL_DIR/ralph" ] && log_success "ralph CLI installed" || { log_error "ralph not found"; ((ERRORS++)); }
    [ -x "$INSTALL_DIR/mmc" ] && log_success "mmc CLI installed" || { log_error "mmc not found"; ((ERRORS++)); }
    [ -d "${CLAUDE_DIR}/agents" ] && log_success "Agents directory OK" || { log_error "Agents missing"; ((ERRORS++)); }
    [ -d "${CLAUDE_DIR}/commands" ] && log_success "Commands directory OK" || { log_error "Commands missing"; ((ERRORS++)); }
    [ -x "${CLAUDE_DIR}/hooks/git-safety-guard.py" ] && log_success "Git Safety Guard installed (ACTIVE)" || log_warn "Git Safety Guard may need chmod +x"
    [ -x "${CLAUDE_DIR}/hooks/quality-gates.sh" ] && log_success "Quality Gates installed" || log_warn "Quality Gates may need chmod +x"
    [ -f "${CLAUDE_DIR}/settings.json" ] && log_success "Settings with hooks configured" || log_warn "Settings.json missing"
    [ -d "${RALPH_DIR}/logs" ] && log_success "Hybrid logging directory ready" || log_warn "Logs directory missing"



    # Verify curator and repo-learn scripts
    log_info "Running post-installation tests..."

    if [ -x "${RALPH_DIR}/curator/curator.sh" ]; then
        log_success "curator.sh installed"
    else
        log_error "curator.sh not found or not executable"
        ((ERRORS++))
    fi

    if [ -x "${RALPH_DIR}/scripts/repo-learn.sh" ]; then
        log_success "repo-learn.sh installed"
    else
        log_error "repo-learn.sh not found or not executable"
        ((ERRORS++))
    fi

    # Run validation script if available
    if [ -x "${RALPH_DIR}/tests/validate_commands.sh" ]; then
        log_info "Running validation tests..."
        if "${RALPH_DIR}/tests/validate_commands.sh" > /dev/null 2>&1; then
            log_success "All validation tests passed"
        else
            log_warn "Some validation tests failed - check ${RALPH_DIR}/logs/"
            ((ERRORS++))
        fi
    fi

    # Verify commands work
    if "$INSTALL_DIR/ralph" repo-learn --help > /dev/null 2>&1; then
        log_success "ralph repo-learn command works"
    else
        log_error "ralph repo-learn command failed"
        ((ERRORS++))
    fi

    if "$INSTALL_DIR/ralph" curator > /dev/null 2>&1; then
        log_success "ralph curator command works"
    else
        log_error "ralph curator command failed"
        ((ERRORS++))
    fi
    return $ERRORS
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  🎭 Multi-Agent Ralph Wiggum v${VERSION} - Global Installer"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  This will install:"
    echo "    • ralph CLI to ~/.local/bin/"
    echo "    • mmc (MiniMax wrapper) to ~/.local/bin/"
    echo "    • 9 agents to ~/.claude/agents/"
    echo "    • 15 commands to ~/.claude/commands/"
    echo "    • 5 skills to ~/.claude/skills/ (including React Best Practices from Vercel)"
    echo "    • Git Safety Guard (blocks destructive commands) - ALWAYS ACTIVE"
    echo "    • Quality Gates (9-language validation) - Manual via 'ralph gates'"
    echo "    • Git Worktree + PR Workflow (v2.20) - 'ralph worktree'"
    echo "    • Hybrid usage logging (global + per-project)"
    echo "    • Security hardening (VULN-001 to VULN-008 fixes) - v2.19"
    echo "    • Shell aliases to ~/.zshrc or ~/.bashrc"
    echo ""

    read -p "  Continue? [Y/n] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
        echo "  Aborted."
        exit 0
    fi

    echo ""

    check_dependencies
    backup_existing
    create_directories
    install_scripts
    install_claude_components
    install_codex_config
    install_gemini_config
    install_config
    configure_shell

    echo ""

    if verify_installation; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "  ${GREEN}✅ INSTALLATION COMPLETE${NC}"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "  Next steps:"
        echo ""
        echo "  1. Reload your shell:"
        echo "     ${CYAN}source ~/.zshrc${NC}  (or ~/.bashrc)"
        echo ""
        echo "  2. (Optional) Configure MiniMax for 2-4x iterations:"
        echo "     ${CYAN}mmc --setup${NC}"
        echo ""
        echo "  3. Start using Ralph:"
        echo "     ${CYAN}ralph help${NC}"
        echo "     ${CYAN}ralph orch \"Your task here\"${NC}"
        echo ""
        echo "  4. Run quality gates manually when needed:"
        echo "     ${CYAN}ralph gates${NC}"
        echo ""
        echo "  5. View usage statistics (hybrid logging):"
        echo "     ${CYAN}mmc --stats all${NC}      # Global + project"
        echo "     ${CYAN}mmc --stats project${NC}  # This repo only"
        echo ""
        echo "  6. (v2.20) Install WorkTrunk for git worktree workflow:"
        echo "     ${CYAN}brew install max-sixty/worktrunk/wt${NC}"
        echo "     ${CYAN}wt config shell install${NC}"
        echo "     ${CYAN}ralph worktree \"your feature\"${NC}"
        echo ""
        echo "  To uninstall:"
        echo "     ${CYAN}ralph --uninstall${NC}  or  ${CYAN}./uninstall.sh${NC}"
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
    else
        echo ""
        log_error "Installation completed with errors. Check messages above."
        exit 1
    fi
}

main "$@"

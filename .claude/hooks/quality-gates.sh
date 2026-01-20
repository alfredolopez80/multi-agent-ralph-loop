#!/usr/bin/env bash
# quality-gates.sh - Quality validation hook for Ralph Wiggum
#
# This hook runs quality checks on the codebase.
# EXIT 0 = Success (non-blocking)
# EXIT 2 = Failure (blocks completion until fixed)
#
# IMPORTANT: This hook should only block when explicitly requested
# via /gates, /review, /adversarial, or ralph gates commands.

# VERSION: 2.57.0
set -e

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Check if we should run in blocking mode
# Set RALPH_GATES_BLOCKING=1 to enable blocking on failure
BLOCKING_MODE="${RALPH_GATES_BLOCKING:-0}"

# Colors (disabled if not interactive)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log_check() { echo -e "  → $1... "; }
log_pass() { echo -e "${GREEN}✓${NC}"; }
log_fail() { echo -e "${RED}✗${NC}"; }
log_skip() { echo -e "${YELLOW}○${NC} (skipped)"; }
log_warn() { echo -e "${YELLOW}⚠${NC} ($1)"; }

check_command() {
    command -v "$1" &>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════════
# QUALITY CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

FAILED=()
WARNINGS=()

echo ""
echo "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo "  🔍 Running Quality Gates"
echo "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# TypeScript
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "tsconfig.json" ]; then
    echo -n "  → TypeScript (tsc --noEmit)... "
    if check_command npx; then
        if npx tsc --noEmit 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("TypeScript")
        fi
    else
        log_warn "npx not found"
        WARNINGS+=("TypeScript: npx not installed")
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# ESLint
# ─────────────────────────────────────────────────────────────────────────────
if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.cjs" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
    echo -n "  → ESLint... "
    if check_command npx; then
        if npx eslint . --max-warnings 0 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("ESLint")
        fi
    else
        log_warn "npx not found"
        WARNINGS+=("ESLint: npx not installed")
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Python - Pyright
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    echo -n "  → Python (pyright)... "
    if check_command pyright; then
        if pyright 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("Python/Pyright")
        fi
    else
        log_warn "pyright not found"
        WARNINGS+=("Python: pyright not installed")
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Python - Ruff
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    echo -n "  → Python (ruff)... "
    if check_command ruff; then
        if ruff check . 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("Python/Ruff")
        fi
    else
        log_warn "ruff not found"
        WARNINGS+=("Python: ruff not installed")
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Go
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "go.mod" ]; then
    echo -n "  → Go (go vet)... "
    if check_command go; then
        if go vet ./... 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("Go")
        fi
    else
        log_warn "go not found"
        WARNINGS+=("Go: go not installed")
    fi

    echo -n "  → Go (staticcheck)... "
    if check_command staticcheck; then
        if staticcheck ./... 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("Go/staticcheck")
        fi
    else
        log_warn "staticcheck not found"
        WARNINGS+=("Go: staticcheck not installed")
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Rust
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "Cargo.toml" ]; then
    echo -n "  → Rust (clippy)... "
    if check_command cargo; then
        if cargo clippy --all-targets --all-features -- -D warnings 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("Rust")
        fi
    else
        log_warn "cargo not found"
        WARNINGS+=("Rust: cargo not installed")
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Solidity - Foundry
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "foundry.toml" ]; then
    echo -n "  → Solidity (forge build)... "
    if check_command forge; then
        if forge build 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("Solidity/Foundry")
        fi
    else
        log_warn "forge not found"
        WARNINGS+=("Solidity: forge not installed")
    fi

    echo -n "  → Solidity (solhint)... "
    if check_command solhint; then
        if solhint 'contracts/**/*.sol' 'src/**/*.sol' 2>/dev/null; then
            log_pass
        else
            log_warn "lint issues"
            WARNINGS+=("Solidity: solhint warnings")
        fi
    else
        log_warn "solhint not found"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Solidity - Hardhat
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "hardhat.config.js" ] || [ -f "hardhat.config.ts" ]; then
    echo -n "  → Solidity (hardhat compile)... "
    if check_command npx; then
        if npx hardhat compile 2>/dev/null; then
            log_pass
        else
            log_fail
            FAILED+=("Solidity/Hardhat")
        fi
    else
        log_warn "npx not found"
        WARNINGS+=("Solidity: npx not installed")
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Swift
# ─────────────────────────────────────────────────────────────────────────────
if [ -f "Package.swift" ]; then
    echo -n "  → Swift (swiftlint)... "
    if check_command swiftlint; then
        if swiftlint lint --quiet 2>/dev/null; then
            log_pass
        else
            log_warn "lint issues"
            WARNINGS+=("Swift: swiftlint warnings")
        fi
    else
        log_warn "swiftlint not found"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# JSON Validation
# ─────────────────────────────────────────────────────────────────────────────
JSON_FILES=$(find . -maxdepth 2 -name "*.json" -not -path "./node_modules/*" -not -path "./.git/*" 2>/dev/null | head -20)
if [ -n "$JSON_FILES" ]; then
    echo -n "  → JSON validation... "
    if check_command jq; then
        json_valid=true
        while IFS= read -r f; do
            [ -f "$f" ] || continue
            if ! jq empty "$f" 2>/dev/null; then
                json_valid=false
                break
            fi
        done <<< "$JSON_FILES"
        if [ "$json_valid" = true ]; then
            log_pass
        else
            log_fail
            FAILED+=("JSON")
        fi
    else
        log_warn "jq not found"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# YAML Validation
# ─────────────────────────────────────────────────────────────────────────────
YAML_FILES=$(find . -maxdepth 2 \( -name "*.yaml" -o -name "*.yml" \) -not -path "./node_modules/*" -not -path "./.git/*" 2>/dev/null | head -10)
if [ -n "$YAML_FILES" ]; then
    echo -n "  → YAML validation... "
    if check_command yamllint; then
        if yamllint -d relaxed . 2>/dev/null; then
            log_pass
        else
            log_warn "lint issues"
            WARNINGS+=("YAML: yamllint warnings")
        fi
    else
        log_warn "yamllint not found"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# GitHub Actions
# ─────────────────────────────────────────────────────────────────────────────
if [ -d ".github/workflows" ]; then
    echo -n "  → GitHub Actions... "
    if check_command actionlint; then
        if actionlint 2>/dev/null; then
            log_pass
        else
            log_warn "lint issues"
            WARNINGS+=("GitHub Actions: actionlint warnings")
        fi
    else
        log_warn "actionlint not found"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# RESULTS
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "  ${RED}✗ QUALITY GATES FAILED${NC}"
    echo ""
    echo "  Failed checks:"
    for f in "${FAILED[@]}"; do
        echo "    • $f"
    done

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "  Warnings:"
        for w in "${WARNINGS[@]}"; do
            echo "    • $w"
        done
    fi

    echo ""
    echo "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

    # Only block if in blocking mode
    if [ "$BLOCKING_MODE" = "1" ]; then
        echo ""
        echo "  ${YELLOW}⚠ BLOCKING: Fix errors before completing the task${NC}"
        echo ""
        exit 2
    else
        echo ""
        echo "  ${YELLOW}ℹ Non-blocking mode. Run 'ralph gates' for blocking validation.${NC}"
        echo ""
        exit 0
    fi
else
    echo "  ${GREEN}✓ ALL QUALITY GATES PASSED${NC}"

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo "  Warnings (non-blocking):"
        for w in "${WARNINGS[@]}"; do
            echo "    • $w"
        done
    fi

    echo "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    exit 0
fi

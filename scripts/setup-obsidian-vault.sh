#!/usr/bin/env bash
# setup-obsidian-vault.sh — Automated vault setup (Steps 1-6 from plan)
# VERSION: 3.0.0
#
# Creates the vault structure, optionally installs Obsidian, and configures git backup.
# The vault is created OUTSIDE the public repo (private, per-developer).
#
# Usage: ./scripts/setup-obsidian-vault.sh [--with-obsidian] [--with-git]

set -euo pipefail

VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
WITH_OBSIDIAN=false
WITH_GIT=false

# Parse args
for arg in "$@"; do
    case "$arg" in
        --with-obsidian) WITH_OBSIDIAN=true ;;
        --with-git) WITH_GIT=true ;;
        --help|-h)
            echo "Usage: $0 [--with-obsidian] [--with-git]"
            echo "  --with-obsidian  Install Obsidian via Homebrew (optional)"
            echo "  --with-git       Initialize git + create private GitHub repo"
            exit 0
            ;;
    esac
done

echo "=== Vault Setup v3.0 ==="
echo "Vault directory: $VAULT_DIR"
echo ""

# Step 1: Install Obsidian (optional)
if [[ "$WITH_OBSIDIAN" == true ]]; then
    echo "Step 1: Installing Obsidian..."
    if command -v brew &>/dev/null; then
        brew install --cask obsidian 2>/dev/null || echo "Obsidian already installed or brew failed"
    else
        echo "  Homebrew not found. Download Obsidian from https://obsidian.md/download"
    fi
else
    echo "Step 1: Skipping Obsidian install (use --with-obsidian to install)"
fi

# Step 2: Create vault structure (3 layers + Karpathy pipeline)
echo ""
echo "Step 2: Creating vault structure..."

# Global layer (GREEN — cross-project)
mkdir -p "$VAULT_DIR/global/raw/articles"
mkdir -p "$VAULT_DIR/global/raw/papers"
mkdir -p "$VAULT_DIR/global/raw/images"
mkdir -p "$VAULT_DIR/global/wiki/typescript"
mkdir -p "$VAULT_DIR/global/wiki/react"
mkdir -p "$VAULT_DIR/global/wiki/security"
mkdir -p "$VAULT_DIR/global/wiki/testing"
mkdir -p "$VAULT_DIR/global/wiki/agent-engineering"
mkdir -p "$VAULT_DIR/global/wiki/architecture"
mkdir -p "$VAULT_DIR/global/output/slides"
mkdir -p "$VAULT_DIR/global/output/reports"
mkdir -p "$VAULT_DIR/global/decisions"

# Projects layer (YELLOW — per-project)
mkdir -p "$VAULT_DIR/projects"

# Templates
mkdir -p "$VAULT_DIR/_templates"

echo "  Created 3-layer structure: global/ + projects/ + _templates/"

# Step 3: Create index files
echo ""
echo "Step 3: Creating index files..."

cat > "$VAULT_DIR/_vault-index.md" << 'EOF'
# Vault Index

## Global Knowledge
- [Global Wiki](global/wiki/) — Cross-project patterns and learnings
- [Raw Sources](global/raw/) — Unprocessed articles, papers, images
- [Decisions](global/decisions/) — Architecture Decision Records
- [Output](global/output/) — Generated reports, slides

## Projects
- [Project Index](projects/_project-index.md)

## Templates
- [Vault Entry Template](_templates/vault-entry.md)
EOF

cat > "$VAULT_DIR/projects/_project-index.md" << 'EOF'
# Project Index

Projects are created automatically when you work in a repo with vault integration.
Each project has: raw/, wiki/, lessons/, decisions/
EOF

cat > "$VAULT_DIR/global/wiki/_index.md" << 'EOF'
# Global Wiki Index

Auto-maintained by `/vault index` command.
EOF

echo "  Created _vault-index.md, _project-index.md, wiki/_index.md"

# Step 4: Create templates
echo ""
echo "Step 4: Creating templates..."

cat > "$VAULT_DIR/_templates/vault-entry.md" << 'EOF'
---
type: {{type}}
source: {{source}}
date: {{date}}
tags: []
classification: GREEN
confidence: 0.3
sessions_confirmed: 1
category: general
---

# {{title}}

## Context


## Content


## Links

EOF

echo "  Created vault-entry.md template"

# Step 5: Configure Obsidian (if installed)
if [[ -d "/Applications/Obsidian.app" ]] || [[ "$WITH_OBSIDIAN" == true ]]; then
    echo ""
    echo "Step 5: Configuring Obsidian..."
    mkdir -p "$VAULT_DIR/.obsidian"

    # Create minimal Obsidian config
    cat > "$VAULT_DIR/.obsidian/app.json" << 'EOF'
{
  "showLineNumber": true,
  "spellcheck": false,
  "readableLineLength": true,
  "strictLineBreaks": false
}
EOF
    echo "  Obsidian config created. Open Obsidian -> 'Open folder as vault' -> $VAULT_DIR"
else
    echo ""
    echo "Step 5: Obsidian not installed (optional). Vault works as plain markdown."
fi

# Step 6: Git initialization (optional)
if [[ "$WITH_GIT" == true ]]; then
    echo ""
    echo "Step 6: Initializing git..."
    cd "$VAULT_DIR"

    if [[ ! -d ".git" ]]; then
        git init
        git branch -M main

        # .gitignore for Obsidian
        cat > .gitignore << 'GITIGNORE'
# Obsidian workspace cache (regenerable, causes conflicts)
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache/

# OS files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.swp
GITIGNORE

        git add -A
        git commit -m "vault: initial structure"

        echo "  Git initialized. To create private GitHub repo:"
        echo "  gh repo create vault-knowledge-base --private --source=. --remote=origin --push"
    else
        echo "  Git already initialized."
    fi
else
    echo ""
    echo "Step 6: Skipping git init (use --with-git to initialize)"
fi

echo ""
echo "=== Vault Setup Complete ==="
echo ""
echo "Vault location: $VAULT_DIR"
echo "Next steps:"
echo "  1. Open a Claude Code session in any project"
echo "  2. The session-accumulator hook will capture learnings"
echo "  3. Run /exit-review at session end to classify learnings"
echo "  4. Run /vault compile periodically to build the wiki"
echo "  5. vault-graduation hook auto-promotes learnings to rules"

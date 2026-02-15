#!/bin/bash
# Reinstall all incomplete plugins from claude-plugins-official
# Run this script from a terminal (not inside Claude Code)
# Generated: 2026-02-15

set -e

# All plugins that had incomplete installations
PLUGINS=(
    # LSP Plugins (10)
    "pyright-lsp"
    "typescript-lsp"
    "gopls-lsp"
    "clangd-lsp"
    "rust-analyzer-lsp"
    "csharp-lsp"
    "swift-lsp"
    "lua-lsp"
    "php-lsp"
    "kotlin-lsp"
    # Other incomplete plugins
    "plugin-dev"
)

echo "=========================================="
echo "  Plugin Reinstallation Script"
echo "  Total: ${#PLUGINS[@]} plugins"
echo "=========================================="
echo ""

success=0
failed=0

for plugin in "${PLUGINS[@]}"; do
    echo -n "Installing $plugin... "
    if claude plugin install "$plugin@claude-plugins-official" 2>&1; then
        echo "✅"
        ((success++))
    else
        echo "❌"
        ((failed++))
    fi
done

echo ""
echo "=========================================="
echo "  Results: $success OK / $failed FAILED"
echo "=========================================="
echo ""
echo "Verify with: /plugin list"

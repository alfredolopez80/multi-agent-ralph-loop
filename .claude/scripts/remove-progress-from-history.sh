#!/bin/bash
# Script to remove .claude/progress.md from git history permanently
# Date: 2026-01-29
# Version: 1.0.0

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Git History Cleanup - Remove .claude/progress.md              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  WARNING: This will REWRITE git history"
echo "   - All commit hashes will change"
echo "   - You will need to force push to remote"
echo "   - Make sure all collaborators are aware"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Aborted by user"
    exit 1
fi

# Backup current state
BACKUP_DIR="$HOME/.ralph/backups/git-cleanup-$(date +%Y%m%d-%H%M%S)"
echo ""
echo "📦 Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -r .git "$BACKUP_DIR/"

# Run git filter-repo
echo ""
echo "🔧 Running git filter-repo to remove .claude/progress.md..."
git filter-repo \
    --path .claude/progress.md \
    --invert-paths \
    --force

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Summary:"
echo "   - File removed from all commits"
echo "   - Commit hashes have changed"
echo "   - Backup saved at: $BACKUP_DIR"
echo ""
echo "🚀 Next steps:"
echo "   1. Review changes: git log --oneline -10"
echo "   2. Force push to remote: git push origin --force --all"
echo "   3. Update any PRs or branches"
echo ""

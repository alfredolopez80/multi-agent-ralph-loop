#!/bin/bash
# .claude/scripts/glm5-init-team.sh
# Initialize team status for GLM-5 agent teams (project-scoped)
# Version: 2.84.1

set -e

# === Get Project Root ===
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# === Directories ===
RALPH_DIR="${PROJECT_ROOT}/.ralph"
TEAM_STATUS="${RALPH_DIR}/team-status.json"

# === Create Directory Structure ===
mkdir -p "${RALPH_DIR}/teammates"
mkdir -p "${RALPH_DIR}/reasoning"
mkdir -p "${RALPH_DIR}/agent-memory"
mkdir -p "${RALPH_DIR}/logs"

# === Initialize Team Status ===
TEAM_NAME="${1:-ralph-team-$(date +%Y%m%d)}"

cat > "$TEAM_STATUS" << EOF
{
  "team_name": "${TEAM_NAME}",
  "project": "${PROJECT_ROOT}",
  "created": "$(date -Iseconds)",
  "completed_tasks": [],
  "pending_tasks": [],
  "active_teammates": 0,
  "version": "2.84.0"
}
EOF

echo "✅ Team status initialized: ${TEAM_STATUS}"
echo "📁 Project root: ${PROJECT_ROOT}"
echo "🏷️  Team name: ${TEAM_NAME}"
echo ""
echo "Directory structure created:"
echo "  ${RALPH_DIR}/teammates/   - Teammate status files"
echo "  ${RALPH_DIR}/reasoning/   - GLM-5 reasoning outputs"
echo "  ${RALPH_DIR}/agent-memory/ - Agent memory storage"
echo "  ${RALPH_DIR}/logs/        - Activity logs"

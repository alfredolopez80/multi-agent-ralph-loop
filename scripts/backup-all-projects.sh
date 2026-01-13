#!/bin/bash
#
# backup-all-projects.sh - Backup de configuraciones .claude de todos los proyectos
# Multi-Agent Ralph v2.40
#
# Este script crea backups de las carpetas .claude de los 21 proyectos
# antes de ejecutar la consolidación global.
#

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
BACKUP_DIR="${HOME}/.ralph/backups/$(date +%Y%m%d_%H%M%S)"
GITHUB_DIR="${HOME}/Documents/GitHub"

# Lista de proyectos conocidos
PROJECTS=(
    "A2UI"
    "cybersecurity_model"
    "david-game"
    "deployer-safe-palmera2"
    "edge_csigma_finance"
    "etoro"
    "gitbook"
    "helix"
    "Hodlprotocol-web"
    "HODLTradeAPI"
    "keyper-infra"
    "mica-act"
    "multi-agent-ralph-loop"
    "palmera-hypersig-api"
    "palmera-notif-serv"
    "Palmera-safe-transaction-service"
    "programmatic-deployment-service"
    "quantconnect"
    "research-arbitrage-bot"
    "robinhood"
    "safe-shield"
)

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

backup_project() {
    local project_name="$1"
    local project_path="${GITHUB_DIR}/${project_name}"
    local claude_dir="${project_path}/.claude"
    local backup_path="${BACKUP_DIR}/${project_name}"

    if [ ! -d "$project_path" ]; then
        log_warning "Project not found: $project_name"
        return 1
    fi

    if [ ! -d "$claude_dir" ]; then
        log_warning "No .claude directory in: $project_name"
        return 1
    fi

    # Crear directorio de backup
    mkdir -p "$backup_path"

    # Copiar .claude completo
    cp -r "$claude_dir" "$backup_path/"

    # Crear manifest con información del backup
    cat > "${backup_path}/MANIFEST.json" << EOF
{
    "project": "$project_name",
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "source_path": "$claude_dir",
    "backup_path": "$backup_path",
    "files_count": $(find "$claude_dir" -type f | wc -l | tr -d ' '),
    "total_size": "$(du -sh "$claude_dir" 2>/dev/null | cut -f1)"
}
EOF

    log_success "Backed up: $project_name"
    return 0
}

main() {
    echo "========================================"
    echo "  Multi-Agent Ralph v2.40"
    echo "  Project Backup Script"
    echo "========================================"
    echo ""

    # Crear directorio de backup
    mkdir -p "$BACKUP_DIR"
    log_info "Backup directory: $BACKUP_DIR"
    echo ""

    local success_count=0
    local fail_count=0
    local skip_count=0

    for project in "${PROJECTS[@]}"; do
        if backup_project "$project"; then
            ((success_count++))
        else
            ((skip_count++))
        fi
    done

    # También buscar proyectos adicionales no en la lista
    log_info "Scanning for additional projects..."
    while IFS= read -r -d '' claude_dir; do
        project_path=$(dirname "$claude_dir")
        project_name=$(basename "$project_path")

        # Skip si ya está en la lista
        if [[ " ${PROJECTS[*]} " =~ " ${project_name} " ]]; then
            continue
        fi

        log_info "Found additional project: $project_name"
        if backup_project "$project_name"; then
            ((success_count++))
        else
            ((skip_count++))
        fi
    done < <(find "$GITHUB_DIR" -maxdepth 4 -type d -name ".claude" -print0 2>/dev/null)

    # Crear índice global de backups
    cat > "${BACKUP_DIR}/INDEX.json" << EOF
{
    "backup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "backup_dir": "$BACKUP_DIR",
    "projects_backed_up": $success_count,
    "projects_skipped": $skip_count,
    "restore_command": "ralph restore-backup $BACKUP_DIR"
}
EOF

    echo ""
    echo "========================================"
    echo "  Backup Complete"
    echo "========================================"
    echo ""
    log_success "Projects backed up: $success_count"
    log_warning "Projects skipped: $skip_count"
    echo ""
    log_info "Backup location: $BACKUP_DIR"
    log_info "Total size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
    echo ""
    log_info "To restore: ralph restore-backup $BACKUP_DIR"
    echo ""
}

# Ejecutar
main "$@"

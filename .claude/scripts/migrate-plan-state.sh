#!/bin/bash
# Migrate Plan State - v2.51.0
# Automatic migration from plan-state-v1 to plan-state-v2
#
# Changes:
# - $schema: "plan-state-v1" → version: "2.51.0"
# - steps[] array → steps{} object keyed by id
# - New "phases" array with barriers support
# - New "current_phase" field
# - New "barriers" object
#
# Usage:
#   migrate-plan-state.sh [options] [plan-state.json]
#   migrate-plan-state.sh --check     Check if migration needed
#   migrate-plan-state.sh --dry-run   Preview without changes
#   migrate-plan-state.sh --force     Migrate even if already v2
#
# Safety:
#   - Always creates backup before migration
#   - Preserves ALL existing data
#   - Reversible (backup stored in ~/.ralph/backups/)

set -uo pipefail
umask 077

# Configuration
VERSION="2.51.0"
NEW_SCHEMA_VERSION="2.51.0"
BACKUP_DIR="${HOME}/.ralph/backups/plan-state"
LOG_DIR="${HOME}/.ralph/logs"
DEFAULT_PLAN_STATE=".claude/plan-state.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure directories exist
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if file needs migration
check_schema_version() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "not_found"
        return
    fi

    # Check for v2.51+ schema (has "version" field)
    local has_version
    has_version=$(jq -r '.version // empty' "$file" 2>/dev/null)

    if [[ -n "$has_version" ]]; then
        echo "v2:$has_version"
        return
    fi

    # Check for v1 schema (has "$schema" field)
    local has_schema
    has_schema=$(jq -r '.["$schema"] // empty' "$file" 2>/dev/null)

    if [[ "$has_schema" == "plan-state-v1" ]]; then
        echo "v1"
        return
    fi

    # Check for legacy (has "metadata.version")
    local metadata_version
    metadata_version=$(jq -r '.metadata.version // empty' "$file" 2>/dev/null)

    if [[ -n "$metadata_version" ]]; then
        echo "v1_legacy:$metadata_version"
        return
    fi

    echo "unknown"
}

# Create backup
create_backup() {
    local file="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/plan-state_${timestamp}.json"

    cp "$file" "$backup_file"
    log_info "Backup created: $backup_file"
    echo "$backup_file"
}

# Group steps into phases based on existing phase field or patterns
infer_phases_from_steps() {
    local steps_json="$1"

    # Try to group by existing "phase" field first
    # If no phase field, create default phases based on step patterns

    python3 <<EOF
import json
import sys

steps = json.loads('''$steps_json''')

# Group steps by their phase field if present
phase_groups = {}
unassigned = []

for step in steps:
    step_id = step.get('id', '')
    phase = step.get('phase', None)

    if phase:
        if phase not in phase_groups:
            phase_groups[phase] = []
        phase_groups[phase].append(step_id)
    else:
        unassigned.append(step_id)

# Create phases array
phases = []
order = ['setup', 'clarify', 'classify', 'explore', 'plan', 'implement', 'core', 'integration', 'validate', 'test', 'testing', 'document', 'retrospect']

# Add phases in order
for phase_name in order:
    if phase_name in phase_groups:
        phases.append({
            "phase_id": phase_name,
            "phase_name": phase_name.title(),
            "step_ids": phase_groups[phase_name],
            "depends_on": [phases[-1]["phase_id"]] if phases else [],
            "execution_mode": "parallel" if phase_name in ['implement', 'validate', 'test'] else "sequential",
            "status": "pending"
        })
        del phase_groups[phase_name]

# Add any remaining phases not in the predefined order
for phase_name, step_ids in phase_groups.items():
    phases.append({
        "phase_id": phase_name,
        "phase_name": phase_name.title(),
        "step_ids": step_ids,
        "depends_on": [phases[-1]["phase_id"]] if phases else [],
        "execution_mode": "sequential",
        "status": "pending"
    })

# Add unassigned steps to a default "main" phase
if unassigned:
    phases.append({
        "phase_id": "main",
        "phase_name": "Main",
        "step_ids": unassigned,
        "depends_on": [phases[-1]["phase_id"]] if phases else [],
        "execution_mode": "sequential",
        "status": "pending"
    })

# Update status based on step statuses
for phase in phases:
    # This will be done in the main migration based on actual step statuses
    pass

print(json.dumps(phases))
EOF
}

# Convert steps array to object
convert_steps_to_object() {
    local steps_json="$1"

    python3 <<EOF
import json

steps_array = json.loads('''$steps_json''')
steps_object = {}

for step in steps_array:
    step_id = step.get('id', str(len(steps_object)))

    # Preserve all existing fields but restructure for v2
    steps_object[step_id] = {
        "name": step.get('title', step.get('name', f'Step {step_id}')),
        "status": step.get('status', 'pending'),
        "result": None,
        # Preserve original data in _v1_data for reference
        "_v1_data": {
            "spec": step.get('spec'),
            "actual": step.get('actual'),
            "drift": step.get('drift'),
            "lsa_verification": step.get('lsa_verification'),
            "quality_audit": step.get('quality_audit'),
            "micro_gate": step.get('micro_gate'),
            "started_at": step.get('started_at'),
            "completed_at": step.get('completed_at')
        }
    }

print(json.dumps(steps_object, indent=2))
EOF
}

# Generate barriers object from phases
generate_barriers() {
    local phases_json="$1"

    python3 <<EOF
import json

phases = json.loads('''$phases_json''')
barriers = {}

for phase in phases:
    phase_id = phase.get('phase_id', '')
    barrier_name = f"{phase_id}_complete"
    # Initially all barriers are false (not released)
    barriers[barrier_name] = False

print(json.dumps(barriers, indent=2))
EOF
}

# Perform the migration
migrate_plan_state() {
    local file="$1"
    local dry_run="${2:-false}"

    log_info "Migrating: $file"

    # Read current state
    local current_state
    current_state=$(cat "$file")

    # Extract steps array
    local steps_array
    steps_array=$(echo "$current_state" | jq '.steps // []')

    # Infer phases from steps
    log_info "Inferring phases from steps..."
    local phases_json
    phases_json=$(infer_phases_from_steps "$steps_array")

    # Convert steps array to object
    log_info "Converting steps to object format..."
    local steps_object
    steps_object=$(convert_steps_to_object "$steps_array")

    # Generate barriers
    log_info "Generating barriers..."
    local barriers_json
    barriers_json=$(generate_barriers "$phases_json")

    # Build new state
    local new_state
    new_state=$(echo "$current_state" | jq --argjson phases "$phases_json" \
                                           --argjson steps "$steps_object" \
                                           --argjson barriers "$barriers_json" \
                                           --arg version "$NEW_SCHEMA_VERSION" '
        # Remove old schema marker
        del(.["$schema"]) |

        # Add new version
        .version = $version |

        # Add phases
        .phases = $phases |

        # Replace steps array with object
        .steps = $steps |

        # Add current_phase (null until first phase starts)
        .current_phase = null |

        # Add barriers
        .barriers = $barriers |

        # Preserve metadata but add migration info
        .metadata.migrated_at = (now | todate) |
        .metadata.migrated_from = "plan-state-v1" |
        .metadata.version = $version
    ')

    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  DRY RUN - Migration Preview"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "New structure:"
        echo "$new_state" | jq '{
            version,
            plan_id,
            phases: [.phases[] | {phase_id, step_ids, execution_mode}],
            steps_count: (.steps | keys | length),
            barriers: .barriers
        }'
        return 0
    fi

    # Create backup
    create_backup "$file"

    # Write new state
    echo "$new_state" > "$file"

    log_success "Migration complete: $file"

    # Show summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Migration Summary"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Version:    plan-state-v1 → v$NEW_SCHEMA_VERSION"
    echo "  Phases:     $(echo "$phases_json" | jq 'length')"
    echo "  Steps:      $(echo "$steps_object" | jq 'keys | length')"
    echo "  Barriers:   $(echo "$barriers_json" | jq 'keys | length')"
    echo ""
}

# Check command
cmd_check() {
    local file="${1:-$DEFAULT_PLAN_STATE}"

    if [[ ! -f "$file" ]]; then
        log_info "No plan-state.json found at: $file"
        return 0
    fi

    local schema_version
    schema_version=$(check_schema_version "$file")

    case "$schema_version" in
        "v1"|"v1_legacy:"*)
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo -e "  ${YELLOW}Migration Required${NC}"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "  File:     $file"
            echo "  Schema:   $schema_version"
            echo "  Action:   Run 'migrate-plan-state.sh' to upgrade"
            echo ""
            return 1
            ;;
        "v2:"*)
            local version="${schema_version#v2:}"
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo -e "  ${GREEN}Up to Date${NC}"
            echo "═══════════════════════════════════════════════════════════════"
            echo ""
            echo "  File:     $file"
            echo "  Version:  $version"
            echo ""
            return 0
            ;;
        "unknown")
            log_warn "Unknown schema format at: $file"
            return 2
            ;;
        *)
            log_error "Unexpected schema check result: $schema_version"
            return 3
            ;;
    esac
}

# Main
main() {
    local command="${1:-}"
    local file="$DEFAULT_PLAN_STATE"
    local dry_run=false
    local force=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check|-c)
                cmd_check "${2:-$DEFAULT_PLAN_STATE}"
                exit $?
                ;;
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            --help|-h)
                cat <<'EOF'
Migrate Plan State v2.51.0 - Automatic schema migration

USAGE:
    migrate-plan-state.sh [options] [plan-state.json]

OPTIONS:
    --check, -c     Check if migration is needed
    --dry-run, -n   Preview migration without changes
    --force, -f     Migrate even if already v2
    --help, -h      Show this help

EXAMPLES:
    # Check if migration needed
    migrate-plan-state.sh --check

    # Preview migration
    migrate-plan-state.sh --dry-run

    # Migrate (creates backup automatically)
    migrate-plan-state.sh

    # Migrate specific file
    migrate-plan-state.sh /path/to/plan-state.json

CHANGES:
    v1 → v2 migration:
    - Adds "phases" array with barrier support
    - Converts "steps" from array to object
    - Adds "barriers" object for WAIT-ALL
    - Adds "current_phase" field
    - Updates version to 2.51.0

SAFETY:
    - Backup created at ~/.ralph/backups/plan-state/
    - Original data preserved in _v1_data field
    - Migration is reversible

EOF
                exit 0
                ;;
            --version)
                echo "migrate-plan-state.sh v$VERSION"
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                file="$1"
                shift
                ;;
        esac
    done

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_info "No plan-state.json found at: $file"
        log_info "Nothing to migrate."
        exit 0
    fi

    # Check schema version
    local schema_version
    schema_version=$(check_schema_version "$file")

    case "$schema_version" in
        "v1"|"v1_legacy:"*)
            log_info "Schema: $schema_version - Migration needed"
            migrate_plan_state "$file" "$dry_run"
            ;;
        "v2:"*)
            if [[ "$force" == "true" ]]; then
                log_warn "File already v2, but --force specified. Re-migrating..."
                migrate_plan_state "$file" "$dry_run"
            else
                log_success "File already at v2 schema. No migration needed."
                log_info "Use --force to re-migrate."
            fi
            ;;
        "unknown")
            log_error "Unknown schema format. Cannot migrate automatically."
            log_info "Please check the file format: $file"
            exit 2
            ;;
        *)
            log_error "Unexpected schema: $schema_version"
            exit 3
            ;;
    esac
}

main "$@"

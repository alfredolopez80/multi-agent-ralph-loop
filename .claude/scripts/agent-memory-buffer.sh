#!/bin/bash
# VERSION: 2.54.0
# v2.54: Added handoff_id tracking and source_agent for unified state management
# Script: agent-memory-buffer.sh
# Purpose: Agent-scoped memory buffers for isolated agent context
#
# Architecture (based on LlamaIndex AgentWorkflow pattern):
#   - Each agent has its own isolated memory buffer
#   - Memory persists during agent lifecycle
#   - Selective transfer during handoffs
#   - TTL-based expiration for episodic entries
#
# Usage:
#   source agent-memory-buffer.sh
#   agent_memory init <agent_id>
#   agent_memory write <agent_id> <type> <content>
#   agent_memory read <agent_id> [type]
#   agent_memory transfer <from_agent> <to_agent> [filter]
#   agent_memory clear <agent_id>
#   agent_memory list
#   agent_memory gc                    # Garbage collect expired entries

set -uo pipefail
umask 077

VERSION="2.54.0"
MEMORY_BASE="${HOME}/.ralph/agent-memory"
DEFAULT_TTL_HOURS=24
LOG_FILE="${HOME}/.ralph/logs/agent-memory.log"

# v2.54: State Coordinator integration
STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"

mkdir -p "$MEMORY_BASE" "$(dirname "$LOG_FILE")" 2>/dev/null

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Get agent memory directory
get_agent_dir() {
    local agent_id="$1"
    echo "${MEMORY_BASE}/${agent_id}"
}

# Initialize agent memory buffer
cmd_init() {
    local agent_id="${1:-}"

    if [[ -z "$agent_id" ]]; then
        echo "Error: Agent ID required"
        echo "Usage: agent_memory init <agent_id>"
        return 1
    fi

    local agent_dir
    agent_dir=$(get_agent_dir "$agent_id")
    mkdir -p "$agent_dir"/{semantic,episodic,working}

    # Initialize metadata
    cat > "${agent_dir}/metadata.json" << EOF
{
    "agent_id": "$agent_id",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "last_activity": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "$VERSION",
    "entry_count": 0,
    "memory_types": ["semantic", "episodic", "working"]
}
EOF

    log "Initialized memory buffer for agent: $agent_id"
    echo "Memory buffer initialized for agent: $agent_id"
    echo "Location: $agent_dir"
}

# Write to agent memory buffer
# v2.54: Added optional handoff_id and source_agent for tracking
cmd_write() {
    local agent_id="${1:-}"
    local mem_type="${2:-}"
    local content="${3:-}"
    local handoff_id="${4:-}"       # v2.54: Optional handoff ID
    local source_agent="${5:-}"     # v2.54: Optional source agent (who wrote this)

    if [[ -z "$agent_id" || -z "$mem_type" ]]; then
        echo "Error: Agent ID and memory type required"
        echo "Usage: agent_memory write <agent_id> <type> <content> [handoff_id] [source_agent]"
        echo "Types: semantic, episodic, working"
        return 1
    fi

    # Validate memory type
    case "$mem_type" in
        semantic|episodic|working) ;;
        *)
            echo "Error: Invalid memory type: $mem_type"
            echo "Valid types: semantic, episodic, working"
            return 1
            ;;
    esac

    local agent_dir
    agent_dir=$(get_agent_dir "$agent_id")

    # Auto-initialize if needed
    if [[ ! -d "$agent_dir" ]]; then
        cmd_init "$agent_id" > /dev/null
    fi

    # Read content from stdin if not provided
    if [[ -z "$content" ]]; then
        content=$(cat)
    fi

    # Generate entry ID
    local entry_id
    entry_id=$(date +%s%N | md5sum | cut -c1-12)
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Calculate expiration for episodic entries
    local expires_at=""
    if [[ "$mem_type" == "episodic" ]]; then
        expires_at=$(date -u -v+${DEFAULT_TTL_HOURS}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
                     date -u -d "+${DEFAULT_TTL_HOURS} hours" +%Y-%m-%dT%H:%M:%SZ)
    fi

    # Create entry
    # v2.54: Include handoff_id and source_agent in metadata for traceability
    local entry_file="${agent_dir}/${mem_type}/${entry_id}.json"
    local handoff_json="null"
    local source_json="null"
    [[ -n "$handoff_id" ]] && handoff_json="\"$handoff_id\""
    [[ -n "$source_agent" ]] && source_json="\"$source_agent\""

    cat > "$entry_file" << EOF
{
    "entry_id": "$entry_id",
    "agent_id": "$agent_id",
    "type": "$mem_type",
    "content": $(echo "$content" | jq -Rs .),
    "created_at": "$timestamp",
    "expires_at": $(if [[ -n "$expires_at" ]]; then echo "\"$expires_at\""; else echo "null"; fi),
    "metadata": {
        "source": "agent_memory_write",
        "version": "$VERSION",
        "handoff_id": $handoff_json,
        "source_agent": $source_json
    }
}
EOF

    # Update metadata
    local current_count
    current_count=$(jq -r '.entry_count // 0' "${agent_dir}/metadata.json" 2>/dev/null || echo "0")
    jq --arg ts "$timestamp" --argjson cnt "$((current_count + 1))" \
       '.last_activity = $ts | .entry_count = $cnt' \
       "${agent_dir}/metadata.json" > "${agent_dir}/metadata.json.tmp" && \
       mv "${agent_dir}/metadata.json.tmp" "${agent_dir}/metadata.json"

    log "Written to $agent_id/$mem_type: $entry_id"
    echo "$entry_id"
}

# Read from agent memory buffer
cmd_read() {
    local agent_id="${1:-}"
    local mem_type="${2:-all}"
    local format="${3:-json}"

    if [[ -z "$agent_id" ]]; then
        echo "Error: Agent ID required"
        echo "Usage: agent_memory read <agent_id> [type] [format]"
        return 1
    fi

    local agent_dir
    agent_dir=$(get_agent_dir "$agent_id")

    if [[ ! -d "$agent_dir" ]]; then
        echo "Error: No memory buffer for agent: $agent_id"
        return 1
    fi

    local entries=()
    local types_to_read=()

    if [[ "$mem_type" == "all" ]]; then
        types_to_read=("semantic" "episodic" "working")
    else
        types_to_read=("$mem_type")
    fi

    # Collect entries (use nullglob for safe glob expansion)
    shopt -s nullglob
    for type in "${types_to_read[@]}"; do
        local type_dir="${agent_dir}/${type}"
        if [[ -d "$type_dir" ]]; then
            for entry_file in "$type_dir"/*.json; do
                if [[ -f "$entry_file" ]]; then
                    entries+=("$(cat "$entry_file")")
                fi
            done
        fi
    done
    shopt -u nullglob

    # Output based on format
    if [[ "$format" == "json" ]]; then
        printf '%s\n' "${entries[@]}" | jq -s '.'
    else
        # Plain text format
        for entry in "${entries[@]}"; do
            local type content created_at
            type=$(echo "$entry" | jq -r '.type')
            content=$(echo "$entry" | jq -r '.content')
            created_at=$(echo "$entry" | jq -r '.created_at')
            echo "=== [$type] $created_at ==="
            echo "$content"
            echo ""
        done
    fi
}

# Transfer memory between agents (for handoffs)
# v2.54: Added optional handoff_id for traceability
cmd_transfer() {
    local from_agent="${1:-}"
    local to_agent="${2:-}"
    local filter="${3:-relevant}"  # all, relevant, working
    local handoff_id="${4:-}"      # v2.54: Optional handoff ID for tracing

    if [[ -z "$from_agent" || -z "$to_agent" ]]; then
        echo "Error: Source and target agent IDs required"
        echo "Usage: agent_memory transfer <from_agent> <to_agent> [filter] [handoff_id]"
        echo "Filters: all, relevant, working"
        return 1
    fi

    local from_dir to_dir
    from_dir=$(get_agent_dir "$from_agent")
    to_dir=$(get_agent_dir "$to_agent")

    if [[ ! -d "$from_dir" ]]; then
        echo "Error: No memory buffer for source agent: $from_agent"
        return 1
    fi

    # Auto-initialize target if needed
    if [[ ! -d "$to_dir" ]]; then
        cmd_init "$to_agent" > /dev/null
    fi

    local transferred=0
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Enable nullglob for safe glob expansion
    shopt -s nullglob

    # v2.54: Include handoff_id in metadata during transfers
    local handoff_arg=""
    [[ -n "$handoff_id" ]] && handoff_arg="$handoff_id"

    case "$filter" in
        all)
            # Transfer all entries
            for type in semantic episodic working; do
                if [[ -d "${from_dir}/${type}" ]]; then
                    for entry_file in "${from_dir}/${type}"/*.json; do
                        if [[ -f "$entry_file" ]]; then
                            local entry_id
                            entry_id=$(basename "$entry_file" .json)
                            local new_id="${entry_id}-xfer"

                            jq --arg agent "$to_agent" \
                               --arg source "$from_agent" \
                               --arg ts "$timestamp" \
                               --arg hoff "$handoff_arg" \
                               '.agent_id = $agent |
                                .metadata.transferred_from = $source |
                                .metadata.transferred_at = $ts |
                                .metadata.handoff_id = (if $hoff == "" then null else $hoff end)' \
                               "$entry_file" > "${to_dir}/${type}/${new_id}.json"

                            ((transferred++))
                        fi
                    done
                fi
            done
            ;;
        working)
            # Transfer only working memory
            if [[ -d "${from_dir}/working" ]]; then
                for entry_file in "${from_dir}/working"/*.json; do
                    if [[ -f "$entry_file" ]]; then
                        local entry_id
                        entry_id=$(basename "$entry_file" .json)
                        local new_id="${entry_id}-xfer"

                        jq --arg agent "$to_agent" \
                           --arg source "$from_agent" \
                           --arg ts "$timestamp" \
                           --arg hoff "$handoff_arg" \
                           '.agent_id = $agent |
                            .metadata.transferred_from = $source |
                            .metadata.transferred_at = $ts |
                            .metadata.handoff_id = (if $hoff == "" then null else $hoff end)' \
                           "$entry_file" > "${to_dir}/working/${new_id}.json"

                        ((transferred++))
                    fi
                done
            fi
            ;;
        relevant)
            # Transfer semantic + recent working (default handoff)
            # Semantic memory (always transfer)
            if [[ -d "${from_dir}/semantic" ]]; then
                for entry_file in "${from_dir}/semantic"/*.json; do
                    if [[ -f "$entry_file" ]]; then
                        local entry_id
                        entry_id=$(basename "$entry_file" .json)
                        local new_id="${entry_id}-xfer"

                        jq --arg agent "$to_agent" \
                           --arg source "$from_agent" \
                           --arg ts "$timestamp" \
                           --arg hoff "$handoff_arg" \
                           '.agent_id = $agent |
                            .metadata.transferred_from = $source |
                            .metadata.transferred_at = $ts |
                            .metadata.handoff_id = (if $hoff == "" then null else $hoff end)' \
                           "$entry_file" > "${to_dir}/semantic/${new_id}.json"

                        ((transferred++))
                    fi
                done
            fi

            # Recent working memory (last 10 entries)
            if [[ -d "${from_dir}/working" ]]; then
                local count=0
                local working_files
                working_files=($(ls -t "${from_dir}/working"/*.json 2>/dev/null | head -10))
                for entry_file in "${working_files[@]}"; do
                    if [[ -f "$entry_file" ]]; then
                        local entry_id
                        entry_id=$(basename "$entry_file" .json)
                        local new_id="${entry_id}-xfer"

                        jq --arg agent "$to_agent" \
                           --arg source "$from_agent" \
                           --arg ts "$timestamp" \
                           --arg hoff "$handoff_arg" \
                           '.agent_id = $agent |
                            .metadata.transferred_from = $source |
                            .metadata.transferred_at = $ts |
                            .metadata.handoff_id = (if $hoff == "" then null else $hoff end)' \
                           "$entry_file" > "${to_dir}/working/${new_id}.json"

                        ((transferred++))
                        ((count++))
                    fi
                done
            fi
            ;;
    esac

    shopt -u nullglob

    # Create transfer record
    # v2.54: Include handoff_id for traceability
    local transfer_id
    transfer_id=$(date +%s%N | md5sum | cut -c1-8)
    local handoff_json="null"
    [[ -n "$handoff_id" ]] && handoff_json="\"$handoff_id\""

    cat >> "${MEMORY_BASE}/transfers.log" << EOF
{"transfer_id":"$transfer_id","from":"$from_agent","to":"$to_agent","filter":"$filter","entries":$transferred,"timestamp":"$timestamp","handoff_id":$handoff_json}
EOF

    log "Transferred $transferred entries from $from_agent to $to_agent (filter: $filter, handoff: ${handoff_id:-none})"
    echo "Transferred $transferred entries from $from_agent to $to_agent"
    echo "Filter: $filter"
    [[ -n "$handoff_id" ]] && echo "Handoff: $handoff_id"
}

# Clear agent memory buffer
cmd_clear() {
    local agent_id="${1:-}"
    local mem_type="${2:-all}"

    if [[ -z "$agent_id" ]]; then
        echo "Error: Agent ID required"
        echo "Usage: agent_memory clear <agent_id> [type]"
        return 1
    fi

    local agent_dir
    agent_dir=$(get_agent_dir "$agent_id")

    if [[ ! -d "$agent_dir" ]]; then
        echo "No memory buffer for agent: $agent_id"
        return 0
    fi

    if [[ "$mem_type" == "all" ]]; then
        rm -rf "$agent_dir"
        log "Cleared all memory for agent: $agent_id"
        echo "Cleared all memory for agent: $agent_id"
    else
        rm -rf "${agent_dir}/${mem_type}"
        mkdir -p "${agent_dir}/${mem_type}"
        log "Cleared $mem_type memory for agent: $agent_id"
        echo "Cleared $mem_type memory for agent: $agent_id"
    fi
}

# List all agents with memory buffers
cmd_list() {
    echo "=== Agent Memory Buffers ==="
    echo ""

    if [[ ! -d "$MEMORY_BASE" ]]; then
        echo "No agent memory buffers found"
        return 0
    fi

    local count=0
    for agent_dir in "$MEMORY_BASE"/*/; do
        if [[ -d "$agent_dir" ]]; then
            local agent_id
            agent_id=$(basename "$agent_dir")

            # Skip non-agent directories
            if [[ "$agent_id" == "transfers.log" ]]; then
                continue
            fi

            local metadata_file="${agent_dir}/metadata.json"
            if [[ -f "$metadata_file" ]]; then
                local created last_activity entry_count
                created=$(jq -r '.created_at // "unknown"' "$metadata_file")
                last_activity=$(jq -r '.last_activity // "unknown"' "$metadata_file")
                entry_count=$(jq -r '.entry_count // 0' "$metadata_file")

                echo "Agent: $agent_id"
                echo "  Created: $created"
                echo "  Last Activity: $last_activity"
                echo "  Entries: $entry_count"
                echo ""
                ((count++))
            fi
        fi
    done

    echo "Total: $count agents with memory buffers"
}

# Garbage collect expired entries
cmd_gc() {
    local now
    now=$(date -u +%s)
    local cleaned=0

    echo "Running garbage collection..."

    shopt -s nullglob
    for agent_dir in "$MEMORY_BASE"/*/; do
        if [[ -d "$agent_dir" ]]; then
            local agent_id
            agent_id=$(basename "$agent_dir")

            # Check episodic entries for expiration
            if [[ -d "${agent_dir}/episodic" ]]; then
                for entry_file in "${agent_dir}/episodic"/*.json; do
                    if [[ -f "$entry_file" ]]; then
                        local expires_at
                        expires_at=$(jq -r '.expires_at // empty' "$entry_file")

                        if [[ -n "$expires_at" && "$expires_at" != "null" ]]; then
                            local expires_ts
                            expires_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$expires_at" +%s 2>/dev/null || \
                                        date -d "$expires_at" +%s 2>/dev/null || echo "0")

                            if [[ "$now" -gt "$expires_ts" && "$expires_ts" -gt 0 ]]; then
                                rm -f "$entry_file"
                                ((cleaned++))
                            fi
                        fi
                    fi
                done
            fi
        fi
    done
    shopt -u nullglob

    log "Garbage collection completed: $cleaned entries cleaned"
    echo "Cleaned $cleaned expired entries"
}

# v2.54: Find entries by handoff ID (for traceability)
cmd_find_handoff() {
    local handoff_id="${1:-}"

    if [[ -z "$handoff_id" ]]; then
        echo "Error: Handoff ID required"
        echo "Usage: agent_memory find-handoff <handoff_id>"
        return 1
    fi

    echo "=== Entries for Handoff: $handoff_id ==="
    echo ""

    local found=0
    shopt -s nullglob

    for agent_dir in "$MEMORY_BASE"/*/; do
        if [[ -d "$agent_dir" ]]; then
            local agent_id
            agent_id=$(basename "$agent_dir")
            [[ "$agent_id" == "transfers.log" ]] && continue

            for type in semantic episodic working; do
                if [[ -d "${agent_dir}/${type}" ]]; then
                    for entry_file in "${agent_dir}/${type}"/*.json; do
                        if [[ -f "$entry_file" ]]; then
                            local entry_hoff
                            entry_hoff=$(jq -r '.metadata.handoff_id // empty' "$entry_file" 2>/dev/null)
                            if [[ "$entry_hoff" == "$handoff_id" ]]; then
                                local entry_id content created_at
                                entry_id=$(jq -r '.entry_id' "$entry_file")
                                content=$(jq -r '.content' "$entry_file" | head -c 80)
                                created_at=$(jq -r '.created_at' "$entry_file")

                                echo "Agent: $agent_id | Type: $type | Entry: $entry_id"
                                echo "  Created: $created_at"
                                echo "  Content: ${content}..."
                                echo ""
                                ((found++))
                            fi
                        fi
                    done
                fi
            done
        fi
    done

    shopt -u nullglob

    # Also check transfer log
    if [[ -f "${MEMORY_BASE}/transfers.log" ]]; then
        echo "=== Transfers for Handoff: $handoff_id ==="
        grep "\"handoff_id\":\"$handoff_id\"" "${MEMORY_BASE}/transfers.log" 2>/dev/null | while read -r line; do
            local from to filter entries ts
            from=$(echo "$line" | jq -r '.from')
            to=$(echo "$line" | jq -r '.to')
            filter=$(echo "$line" | jq -r '.filter')
            entries=$(echo "$line" | jq -r '.entries')
            ts=$(echo "$line" | jq -r '.timestamp')

            echo "Transfer: $from → $to ($filter, $entries entries) @ $ts"
            ((found++))
        done
    fi

    echo ""
    echo "Total entries found: $found"
}

# Show statistics
cmd_stats() {
    echo "=== Agent Memory Statistics ==="
    echo ""

    local total_agents=0
    local total_entries=0
    local total_size=0

    for agent_dir in "$MEMORY_BASE"/*/; do
        if [[ -d "$agent_dir" ]]; then
            local agent_id
            agent_id=$(basename "$agent_dir")

            # Skip non-agent items
            [[ -f "$agent_dir" ]] && continue

            ((total_agents++))

            # Count entries
            for type in semantic episodic working; do
                if [[ -d "${agent_dir}/${type}" ]]; then
                    local type_count
                    type_count=$(find "${agent_dir}/${type}" -name "*.json" 2>/dev/null | wc -l)
                    total_entries=$((total_entries + type_count))
                fi
            done
        fi
    done

    # Calculate total size
    if [[ -d "$MEMORY_BASE" ]]; then
        total_size=$(du -sh "$MEMORY_BASE" 2>/dev/null | cut -f1)
    fi

    echo "Total Agents: $total_agents"
    echo "Total Entries: $total_entries"
    echo "Total Size: ${total_size:-0}"
    echo "Location: $MEMORY_BASE"
}

# Main entry point
agent_memory() {
    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        init)           cmd_init "$@" ;;
        write)          cmd_write "$@" ;;
        read)           cmd_read "$@" ;;
        transfer)       cmd_transfer "$@" ;;
        find-handoff)   cmd_find_handoff "$@" ;;  # v2.54
        clear)          cmd_clear "$@" ;;
        list)           cmd_list "$@" ;;
        gc)             cmd_gc "$@" ;;
        stats)          cmd_stats "$@" ;;
        version)        echo "agent-memory-buffer.sh v$VERSION" ;;
        help|"")
            echo "Agent Memory Buffer - v$VERSION"
            echo "(v2.54: Integrated with State Coordinator for unified state management)"
            echo ""
            echo "Usage: agent_memory <command> [args]"
            echo ""
            echo "Commands:"
            echo "  init <agent_id>                        Initialize memory buffer"
            echo "  write <agent> <type> <text> [hoff_id]  Write to memory with optional handoff tracking"
            echo "  read <agent> [type]                    Read from memory (default: all)"
            echo "  transfer <from> <to> [filter] [hoff]   Transfer memory with optional handoff ID"
            echo "  find-handoff <handoff_id>              Find entries by handoff ID (v2.54)"
            echo "  clear <agent> [type]                   Clear memory (default: all)"
            echo "  list                                   List all agents with buffers"
            echo "  gc                                     Garbage collect expired entries"
            echo "  stats                                  Show memory statistics"
            echo "  version                                Show version"
            echo ""
            echo "Memory Types:"
            echo "  semantic   - Persistent facts and knowledge"
            echo "  episodic   - Experiences with TTL (${DEFAULT_TTL_HOURS}h default)"
            echo "  working    - Current task context"
            echo ""
            echo "Transfer Filters:"
            echo "  all        - Transfer all memory"
            echo "  relevant   - Semantic + recent working (default for handoffs)"
            echo "  working    - Only working memory"
            echo ""
            echo "Examples:"
            echo "  agent_memory init security-auditor"
            echo "  agent_memory write security-auditor semantic 'Found SQL injection in auth.py'"
            echo "  agent_memory transfer security-auditor code-reviewer relevant hoff_20260119_001"
            echo "  agent_memory find-handoff hoff_20260119_001"
            echo "  agent_memory read code-reviewer"
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Run 'agent_memory help' for usage"
            return 1
            ;;
    esac
}

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    agent_memory "$@"
fi

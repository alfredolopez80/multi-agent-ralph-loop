#!/bin/bash
# .claude/scripts/glm5-agent-memory.sh
# Manages agent-scoped memory for GLM-5 teammates (project-scoped)
# Version: 2.84.1

set -e

# === Configuration ===
AGENT_ID="${1:-}"
SCOPE="${2:-project}"  # user, project, local
ACTION="${3:-}"        # init, write, read, transfer, gc

# === Get Project Root ===
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"

# === Memory Directory (project-scoped) ===
MEMORY_DIR="${PROJECT_ROOT}/.ralph/agent-memory/${AGENT_ID}"
LOGS_DIR="${PROJECT_ROOT}/.ralph/logs"

mkdir -p "$LOGS_DIR"

# === Logging ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AgentMemory] [$AGENT_ID] $1" >> "${LOGS_DIR}/memory.log"
}

# === Initialize Memory for Agent ===
init_memory() {
    mkdir -p "$MEMORY_DIR"/{semantic,episodic,working}

    # Initialize memory files
    echo '{"created": "'$(date -Iseconds)'", "agent_id": "'${AGENT_ID}'"}' > "${MEMORY_DIR}/semantic.jsonl"
    echo '{"created": "'$(date -Iseconds)'", "agent_id": "'${AGENT_ID}'"}' > "${MEMORY_DIR}/episodic.jsonl"
    echo '{"created": "'$(date -Iseconds)'", "agent_id": "'${AGENT_ID}'"}' > "${MEMORY_DIR}/working.jsonl"

    log "Initialized memory for ${AGENT_ID} in project scope"
    echo "✅ Memory initialized for ${AGENT_ID}"
}

# === Write to Memory ===
write_memory() {
    local type="$1"
    local content="$2"

    if [[ ! "$type" =~ ^(semantic|episodic|working)$ ]]; then
        echo "Error: Invalid memory type. Use: semantic, episodic, or working"
        return 1
    fi

    local entry=$(cat <<EOF
{"timestamp": "$(date -Iseconds)", "content": $(echo "$content" | jq -Rs .), "type": "${type}"}
EOF
)

    echo "$entry" >> "${MEMORY_DIR}/${type}.jsonl"
    log "Wrote to ${type} memory (${#content} chars)"
}

# === Read from Memory ===
read_memory() {
    local type="$1"

    if [[ ! "$type" =~ ^(semantic|episodic|working|all)$ ]]; then
        echo "Error: Invalid memory type. Use: semantic, episodic, working, or all"
        return 1
    fi

    if [ "$type" = "all" ]; then
        for t in semantic episodic working; do
            if [ -f "${MEMORY_DIR}/${t}.jsonl" ]; then
                echo "=== ${t} ==="
                cat "${MEMORY_DIR}/${t}.jsonl"
            fi
        done
    else
        if [ -f "${MEMORY_DIR}/${type}.jsonl" ]; then
            cat "${MEMORY_DIR}/${type}.jsonl"
        else
            echo "[]"
        fi
    fi
}

# === Transfer Memory to Another Agent ===
transfer_memory() {
    local target="$1"

    if [ -z "$target" ]; then
        echo "Error: Target agent ID required"
        return 1
    fi

    local target_dir="${PROJECT_ROOT}/.ralph/agent-memory/${target}"

    if [ -d "$MEMORY_DIR" ]; then
        mkdir -p "$target_dir"

        # Transfer semantic memory (persistent knowledge)
        if [ -f "${MEMORY_DIR}/semantic.jsonl" ]; then
            cp "${MEMORY_DIR}/semantic.jsonl" "${target_dir}/"
            log "Transferred semantic memory to ${target}"
        fi

        echo "✅ Memory transferred to ${target}"
    else
        echo "Error: No memory found for ${AGENT_ID}"
    fi
}

# === Garbage Collection ===
gc_memory() {
    local days="${1:-30}"

    # Remove episodic entries older than N days
    if [ -f "${MEMORY_DIR}/episodic.jsonl" ]; then
        local cutoff=$(date -d "-${days} days" +%s 2>/dev/null || date -v-${days}d +%s)

        # Filter old entries (simplified - keeps recent)
        local temp_file=$(mktemp)
        while IFS= read -r line; do
            local timestamp=$(echo "$line" | jq -r '.timestamp // empty')
            if [ -n "$timestamp" ]; then
                local entry_epoch=$(date -d "$timestamp" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$timestamp" +%s 2>/dev/null)
                if [ -n "$entry_epoch" ] && [ "$entry_epoch" -ge "$cutoff" ]; then
                    echo "$line" >> "$temp_file"
                fi
            fi
        done < "${MEMORY_DIR}/episodic.jsonl"

        mv "$temp_file" "${MEMORY_DIR}/episodic.jsonl"
        log "GC completed (retained ${days} days)"
        echo "✅ Garbage collection completed"
    fi
}

# === Main ===
case "$ACTION" in
    "init")
        init_memory
        ;;
    "write")
        write_memory "$4" "$5"
        ;;
    "read")
        read_memory "$4"
        ;;
    "transfer")
        transfer_memory "$4"
        ;;
    "gc")
        gc_memory "${4:-30}"
        ;;
    *)
        echo "GLM-5 Agent Memory Manager v2.84.0"
        echo ""
        echo "Usage: glm5-agent-memory.sh <agent_id> <scope> <action> [args]"
        echo ""
        echo "Actions:"
        echo "  init                              Initialize memory for agent"
        echo "  write <type> <content>            Write to memory"
        echo "  read <type|all>                   Read from memory"
        echo "  transfer <target_agent>           Transfer memory to another agent"
        echo "  gc [days]                         Garbage collect old entries"
        echo ""
        echo "Memory Types: semantic, episodic, working"
        ;;
esac

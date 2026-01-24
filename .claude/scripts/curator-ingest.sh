#!/bin/bash
# Repo Curator Ingest Script v2.57.0
# Ingests repository content to local corpus for learning
#
# Usage: curator-ingest.sh --repo <owner/repo> [--output-dir <dir>] [--approve] [--source <source>]
#
# Without --approve, ingests to staging area for review
# With --approve, moves directly to approved corpus
#
# Security fixes v2.57.0:
#   SEC-011: Strict allowlist sanitization in sanitize_dir()
#   SEC-012: Stricter repo format validation (allow dots, prevent injection)
#   SEC-013: Block suspicious path sequences (.., /., ./)
#   SEC-014: Use jq for JSON generation instead of heredocs
#   SEC-015: Path traversal prevention in file copy
#   SEC-016: Verify resolved paths stay within target directory

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CORPUS_DIR="${CURATOR_DIR}/corpus"
STAGING_DIR="${CORPUS_DIR}/staging"
APPROVED_DIR="${CORPUS_DIR}/approved"
REJECTED_DIR="${CORPUS_DIR}/rejected"
LOGS_DIR="${CURATOR_DIR}/logs"

# Default values
REPO=""
OUTPUT_DIR=""
APPROVE=false
SOURCE=""
CLONE_DEPTH=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --approve)
                APPROVE=true
                shift
                ;;
            --source)
                SOURCE="$2"
                shift 2
                ;;
            --depth)
                CLONE_DEPTH="$2"
                # SEC-010: Validate depth is numeric
                if [[ ! "$CLONE_DEPTH" =~ ^[0-9]+$ ]]; then
                    log_error "Invalid depth: must be numeric"
                    exit 1
                fi
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Repo Curator Ingest Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --repo <owner/repo>   Repository to ingest (required)
  --output-dir <dir>    Output directory (auto-generated if empty)
  --approve             Skip staging, go directly to approved
  --source <source>     Source attribution for rules (optional)
  --depth <n>           Clone depth (default: 1)
  --help, -h            Show this help

Examples:
  $(basename "$0") --repo nestjs/nest --approve
  $(basename "$0") --repo prisma/prisma --source "enterprise-db-patterns"
EOF
}

# Sanitize repo name for directory
# v2.57.0 SEC-011: Strict allowlist sanitization to prevent injection
sanitize_dir() {
    local repo="$1"
    # Only allow alphanumeric, underscore, hyphen - remove everything else
    echo "$repo" | tr '/' '_' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-'
}

# Get file patterns to include
get_include_patterns() {
    cat << 'EOF'
**/*.py
**/*.js
**/*.ts
**/*.tsx
**/*.java
**/*.go
**/*.rs
**/*.rb
**/*.php
**/*.c
**/*.cpp
**/*.h
**/*.hpp
**/*.md
**/*.json
**/*.yaml
**/*.yml
EOF
}

# Get exclude patterns
get_exclude_patterns() {
    cat << 'EOF'
**/node_modules/**
**/dist/**
**/build/**
**/.git/**
**/*.min.js
**/*.min.css
**/*.pyc
**/__pycache__/**
**/.venv/**
**/venv/**
EOF
}

# Clone and ingest repository
ingest_repo() {
    local repo="$1"
    local target_dir="$2"

    log_info "Ingesting repository: $repo"
    log_info "Target directory: $target_dir"

    # Create target directory
    mkdir -p "$target_dir"

    # SEC-009: Use mktemp for secure temp directories
    local tmp_clone
    tmp_clone=$(mktemp -d "${CURATOR_DIR}/.tmp_clone_XXXXXX")

    # Clone repository
    local clone_url="https://github.com/$repo.git"

    if command -v git &>/dev/null; then
        log_info "Cloning $repo (depth=$CLONE_DEPTH)..."

        if git clone --depth "$CLONE_DEPTH" --bare "$clone_url" "$tmp_clone" 2>&1; then
            log_info "Clone successful"
        else
            log_warn "Clone failed, trying full clone..."
            if git clone "$clone_url" "$tmp_clone" 2>&1; then
                log_info "Full clone successful"
            else
                log_error "Failed to clone repository"
                rm -rf "$tmp_clone"
                return 1
            fi
        fi

        # Create a sparse checkout if possible
        cd "$tmp_clone"

        # Generate manifest
        # v2.57.0 SEC-014: Use jq for safe JSON generation instead of heredoc
        local manifest_file="${target_dir}/manifest.json"
        local clone_timestamp
        clone_timestamp=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
        jq -n \
            --arg repo "$repo" \
            --arg cloned_at "$clone_timestamp" \
            --argjson clone_depth "$CLONE_DEPTH" \
            --arg source "${SOURCE:-$repo}" \
            '{repository: $repo, cloned_at: $cloned_at, clone_depth: $clone_depth, source: $source, files: []}' \
            > "$manifest_file"

        # List all tracked files
        # SEC-009: Use mktemp for secure temp files
        local files_file
        files_file=$(mktemp "${CURATOR_DIR}/.tmp_files_XXXXXX")
        git ls-files > "$files_file"

        # Process files and copy relevant ones
        local include_patterns
        include_patterns=$(get_include_patterns)
        local exclude_patterns
        exclude_patterns=$(get_exclude_patterns)

        local file_count=0
        local skipped_count=0

        while IFS= read -r file; do
            [[ -z "$file" ]] && continue

            # Check if file matches include patterns
            local include=false
            while IFS= read -r pattern; do
                [[ -z "$pattern" ]] && continue
                if [[ "$file" == $pattern ]]; then
                    include=true
                    break
                fi
            done <<< "$include_patterns"

            if [[ "$include" == "false" ]]; then
                skipped_count=$((skipped_count + 1))
                continue
            fi

            # Check if file matches exclude patterns
            local exclude=false
            while IFS= read -r pattern; do
                [[ -z "$pattern" ]] && continue
                if [[ "$file" == $pattern ]]; then
                    exclude=true
                    break
                fi
            done <<< "$exclude_patterns"

            if [[ "$exclude" == "true" ]]; then
                skipped_count=$((skipped_count + 1))
                continue
            fi

            # Copy file preserving structure
            # v2.57.0 SEC-015: Prevent path traversal attacks
            # Validate file path doesn't escape target directory
            if [[ "$file" =~ \.\. ]] || [[ "$file" =~ ^/ ]]; then
                log_warn "Skipping suspicious path: $file"
                skipped_count=$((skipped_count + 1))
                continue
            fi

            local target_file="${target_dir}/${file}"

            # SEC-016: Verify resolved path is within target_dir
            local resolved_dir
            resolved_dir=$(cd "$(dirname "$target_file")" 2>/dev/null && pwd) || {
                mkdir -p "$(dirname "$target_file")"
                resolved_dir=$(cd "$(dirname "$target_file")" && pwd)
            }

            if [[ "$resolved_dir" != "${target_dir}"* ]]; then
                log_warn "Path traversal blocked: $file"
                skipped_count=$((skipped_count + 1))
                continue
            fi

            if [[ -f "$file" ]]; then
                cp "$file" "$target_file"
                file_count=$((file_count + 1))

                # Add to manifest
                local file_size
                file_size=$(stat -f%z "$target_file" 2>/dev/null || stat -c%s "$target_file" 2>/dev/null || echo "0")
                jq --arg f "$file" --argjson s "$file_size" '.files += [{filename: $f, size: $s}]' "$manifest_file" > "${manifest_file}.tmp" && mv "${manifest_file}.tmp" "$manifest_file"
            fi
        done < "$files_file"

        rm -f "$files_file"

        # Clean up clone
        cd /
        rm -rf "$tmp_clone"

        log_success "Ingested $file_count files (skipped $skipped_count)"
        echo "$file_count" > "${target_dir}/.ingest_count"
        echo "$repo" > "${target_dir}/.repo_name"

    else
        log_error "Git not found, cannot clone repository"
        rm -rf "$tmp_clone"
        return 1
    fi
}

# Main function
main() {
    parse_args "$@"

    if [[ -z "$REPO" ]]; then
        log_error "Repository is required (--repo)"
        exit 1
    fi

    # Validate repo format
    # v2.57.0 SEC-012: Stricter validation - allow dots but prevent injection
    # GitHub allows: alphanumeric, hyphen, underscore, dot (but not starting with dot)
    if [[ ! "$REPO" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
        log_error "Invalid repository format: $REPO (expected owner/repo)"
        exit 1
    fi

    # SEC-013: Additional check - no consecutive dots or special sequences
    if [[ "$REPO" =~ \.\.|/\.|\./ ]]; then
        log_error "Invalid repository format: suspicious path sequence in $REPO"
        exit 1
    fi

    # Ensure directories exist
    mkdir -p "$CORPUS_DIR" "$STAGING_DIR" "$APPROVED_DIR" "$REJECTED_DIR" "$LOGS_DIR"

    # Generate output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        local sanitized
        sanitized=$(sanitize_dir "$REPO")
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        OUTPUT_DIR="${STAGING_DIR}/${sanitized}_${timestamp}"
    fi

    # Run ingestion
    if ingest_repo "$REPO" "$OUTPUT_DIR"; then
        if [[ "$APPROVE" == "true" ]]; then
            # Move to approved
            local approved_dir
            approved_dir=$(sanitize_dir "$REPO")
            mv "$OUTPUT_DIR" "${APPROVED_DIR}/${approved_dir}"
            log_success "Repository $REPO ingested and approved"
            echo "${APPROVED_DIR}/${approved_dir}"
        else
            # Keep in staging
            log_success "Repository $REPO ingested to staging"
            echo "$OUTPUT_DIR"
        fi
    else
        log_error "Failed to ingest repository"
        exit 1
    fi
}

main "$@"

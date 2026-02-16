#!/bin/bash
# glm5-subagent-stop.sh - DEPRECATED: Use subagent-stop-universal.sh instead
# VERSION: 2.90.1
# DEPRECATED: v2.90.1 - Replaced by model-agnostic subagent-stop-universal.sh
# This file is kept for backward compatibility only.
# All SubagentStop logic is now in subagent-stop-universal.sh

exec "$(dirname "$0")/subagent-stop-universal.sh" "$@"

#!/usr/bin/env bash
# Test: k8s-context-guard-v2 port-forward tier (PF-TIER / gap #45)
# Runner: tests/security/fixtures/k8s_port_forward_runner.py
# Purpose: enforce user policy that `kubectl port-forward` is tier ASK when a
#          valid --context is declared, and DENY (kubectl_context_required)
#          when --context is missing. The verified-minikube allow shortcut
#          is bypassed for port-forward because a tunnel exposes the local
#          machine to the cluster side and the user must confirm explicitly.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/security/fixtures/k8s_port_forward_runner.py"

echo "🔍 k8s guard port-forward tier regression matrix (PF-TIER)"
echo "============================================================"
echo ""

if python3 "$RUNNER"; then
    echo ""
    echo "✅ PASS: port-forward gated as ASK with valid context, DENY without"
    exit 0
else
    echo ""
    echo "❌ FAIL: port-forward tier regression in k8s-context-guard-v2 (PF-TIER)"
    exit 1
fi

#!/usr/bin/env bash
# Verificación mínima del context-guard reescrito.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$REPO_ROOT/.claude/hooks/k8s-context-guard.sh"
fails=0
ran=0

run() {  # run <cmd> <expected 0|2> <why> [allowlist]
  local cmd="$1" want="$2" why="$3" allow="${4:-^kind-}"
  ran=$((ran+1))
  local payload
  payload=$(python3 -c "import json,sys;print(json.dumps({'hook_event_name':'PreToolUse','tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))" "$cmd")
  local out rc
  out=$(printf '%s' "$payload" | K8S_GUARD_ALLOWED_CONTEXTS="$allow" bash "$GUARD" 2>&1); rc=$?
  if [[ "$rc" == "$want" ]]; then
    printf '  PASS  [%s] %-58s # %s\n' "$rc" "${cmd:0:58}" "$why"
  else
    printf '  FAIL  [got %s want %s] %-46s # %s\n' "$rc" "$want" "${cmd:0:46}" "$why"
    fails=$((fails+1))
  fi
}

echo "=== los 5 casos de la verificación mínima ==="
run 'kubectl kustomize deploy/overlays/minikube' 0 'render local, no contacta cluster'
run 'kubectl --context=clerum-selfhosted-643dceb apply -f x.yaml' 0 'contexto en allowlist' '^kind-,^clerum-'
run 'kubectl --context=gke_proj_region_prod apply -f x.yaml' 2 'prod, aunque current-context sea kind'
run 'kubectl apply -f x.yaml' 2 'sin --context y current-context no permitido'
printf 'cat > notes.md <<EOF\nUse kubectl apply to deploy\nEOF\n' > /tmp/_hd.txt
run "$(cat /tmp/_hd.txt)" 0 'heredoc que solo escribe la palabra kubectl'

echo
echo "=== casos adicionales ==="
run 'kustomize build overlays/minikube' 0 'render local'
run 'helm template mychart' 0 'render local'
run 'kubectl apply -f x.yaml --dry-run=client' 0 'validacion client-side'
run 'kubectl config get-contexts' 0 'lee kubeconfig local'
run 'kubectl get pods' 0 'lectura pura'
run 'kubectl delete ns foo' 2 'mutacion sin contexto permitido'
run 'kubectl --context=minikube apply -f x.yaml' 0 'minikube en allowlist' '^kind-,^minikube$'
run 'kubectl --context=minikube apply -f x.yaml' 2 'minikube NO en allowlist' '^kind-'
run 'echo "kubectl apply -f x.yaml"' 0 'mencion dentro de comillas'
run 'ls -la' 0 'comando ajeno'
run 'sudo kubectl --context=kind-dev apply -f x.yaml' 0 'wrapper sudo, contexto permitido'
run 'ls && kubectl --context=gke_prod delete ns x' 2 'invocacion tras &&'

echo
echo "=== bypasses reportados por la auditoria de seguridad (2026-07-31) ==="
PROD="gke_proj_region_prod"
DEL="delete namespace critical-ns"
# Blocker 1: un wrapper de shell llevaba el comando dentro de comillas, que el propio
# guard blanqueaba antes de escanear -> el escaner solo veia el wrapper.
run "bash -c \"kubectl --context=$PROD $DEL\"" 2 'wrapper bash -c'
run "sh -c 'kubectl --context=$PROD $DEL'" 2 'wrapper sh -c'
run "eval \"kubectl --context=$PROD $DEL\"" 2 'wrapper eval'
run "sudo bash -c \"kubectl --context=$PROD $DEL\"" 2 'sudo + wrapper'
# Blocker 2: kubectl aplica el ULTIMO --context; el guard leia el primero.
run "kubectl --context=kind-decoy --context=$PROD apply -f x.yaml" 2 'flag repetido con decoy delante'
run "kubectl --context=kind-a get pods && kubectl --context=$PROD $DEL" 2 'cadena con decoy de lectura'
run "kubectl --context=kind-a get pods && kubectl --context=kind-b apply -f x.yaml" 0 'cadena, ambos permitidos' '^kind-'
# Over-blocking corregido: editar el kubeconfig local no contacta ningun cluster.
run 'kubectl config use-context kind-dev' 0 'use-context es local'
run 'helm list --all-namespaces' 0 'helm list es lectura'

echo
if [[ "$ran" -eq 0 ]]; then echo "FATAL: cero casos ejecutados — no se puede declarar exito"; exit 1; fi
[[ "$fails" -eq 0 ]] && echo "TODOS OK ($ran casos)" || { echo "$fails FALLOS de $ran"; exit 1; }

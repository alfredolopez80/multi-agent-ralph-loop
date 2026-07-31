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
echo "=== fail-open por exencion global vs por-segmento (2026-07-31, bug-hunt) ==="
# Una exencion (kustomize build / --dry-run=client) en UN segmento NO debe eximir a un
# hermano que muta un cluster real. Antes se evaluaba is_cluster_free sobre la cadena
# entera, asi que el idioma GitOps canonico colaba un apply destructivo a produccion.
run "kustomize build overlays/prod | kubectl --context=$PROD apply -f -" 2 'render cluster-free NO exime al apply a prod'
run "kubectl kustomize overlays/prod | kubectl --context=$PROD apply -f -" 2 'kubectl kustomize NO exime al apply a prod'
run "helm template ./chart && kubectl --context=$PROD apply -f rendered.yaml" 2 'helm template NO exime al apply a prod'
run "kubectl --context=$PROD apply --dry-run=client -f x.yaml; kubectl --context=$PROD apply -f x.yaml" 2 'dry-run NO exime al apply real a prod'
# Y las exenciones legitimas por-segmento siguen permitidas:
run 'kustomize build overlays/prod' 0 'kustomize build solo sigue exento'
run "kubectl --context=$PROD apply --dry-run=client -f x.yaml" 0 'dry-run solo sigue exento'
run "kustomize build overlays/dev | kubectl --context=kind-dev apply -f -" 0 'render + apply a contexto permitido' '^kind-'

echo
echo "=== eval sin comillas evadia el scanner (2026-07-31, bug-hunt) ==="
# `eval` faltaba en la lista de wrappers benignos, asi que `eval kubectl ...` (sin comillas)
# dejaba first_token=eval y el guard no veia el kubectl.
run "eval kubectl --context=$PROD delete pod foo" 2 'eval sin comillas NO evade'
run "eval \"kubectl --context=$PROD delete pod foo\"" 2 'eval con comillas sigue bloqueado'
run "builtin kubectl --context=$PROD delete pod foo" 2 'builtin no evade'
run 'eval kubectl --context=kind-dev get pods' 0 'eval a contexto permitido + lectura sigue OK'
# Dobles wrappers: el limpiador de un solo paso dejaba el segundo wrapper como first_token.
run "eval eval kubectl --context=$PROD apply -f x.yaml" 2 'doble eval NO evade'
run "command eval kubectl --context=$PROD apply -f x.yaml" 2 'command+eval NO evade'
run "eval eval kubectl --context=kind-dev get pods" 0 'doble eval a contexto permitido OK'
# 7+ wrappers superan cualquier cota: un segmento que sigue envuelto tras el strip se fuerza
# a enforcement de contexto (fail-closed) en vez de asumirse benigno.
run "eval eval eval eval eval eval eval kubectl --context=$PROD apply -f x" 2 'eval x7 NO evade'
run "command command command command command command command kubectl --context=$PROD apply -f x" 2 'command x7 NO evade'
run "sudo command eval env time nice nohup kubectl --context=$PROD apply -f x" 2 '7 wrappers distintos NO evade'
run "eval echo hola" 0 'comando NO-k8s muy envuelto no se sobre-bloquea'
# Wrappers con argumento posicional/replacement que dejaban el arg como first_token.
run "echo x | xargs -I {} kubectl --context=$PROD delete ns foo" 2 'xargs -I {} (con espacio) NO evade'
run "timeout 5 kubectl --context=$PROD delete ns foo" 2 'timeout con duracion NO evade'
run "timeout 5s kubectl --context=$PROD delete ns foo" 2 'timeout 5s NO evade'
run "stdbuf -oL kubectl --context=$PROD delete ns foo" 2 'stdbuf NO evade'
run 'echo "deploy with kubectl later"' 0 'kubectl dentro de string NO se sobre-bloquea'
# Wrappers de scheduling/locking que dejaban el kubectl detras del wrapper o de su lockfile.
run "watch kubectl --context=$PROD delete ns victim" 2 'watch NO evade'
run "setsid kubectl --context=$PROD delete ns victim" 2 'setsid NO evade'
run "flock /tmp/lock kubectl --context=$PROD delete ns victim" 2 'flock + lockfile NO evade'
run "flock -n /tmp/lock kubectl --context=$PROD apply -f x.yaml" 2 'flock -n + lockfile NO evade'
run 'watch kubectl --context=kind-dev get pods' 0 'watch a contexto permitido + lectura OK'

echo
echo "=== paridad con las copias que realmente se ejecutan ==="
# Los 26 casos de arriba corren contra la copia VERSIONADA. El hook que Claude Code carga
# es una copia instalada en el arbol del plugin (el plugin se auto-registra, no pasa por
# settings.json), asi que la suite podia estar verde mientras la copia viva conservaba los
# bypasses. Ocurrio: el 2026-07-31 las dos copias instaladas seguian con el --context de
# primera coincidencia y sin unwrap_shell_wrappers, con todos los casos en verde.
# Ahora la deriva falla aqui, en voz alta.
INSTALLER="$REPO_ROOT/scripts/install-k8s-context-guard.sh"
if [[ ! -x "$INSTALLER" ]]; then
  echo "FATAL: falta $INSTALLER — la paridad no se puede comprobar"; exit 1
fi
if ! mapfile -t INSTALLED < <(find "$HOME/.claude/plugins" -name "context-guard.sh" -type f 2>/dev/null); then
  INSTALLED=()
fi
if [[ "${#INSTALLED[@]}" -eq 0 ]]; then
  echo "  SKIP   el plugin k8s no esta instalado en esta maquina (nada que pueda derivar)"
else
  ran=$((ran+1))
  if "$INSTALLER" --check >/dev/null 2>&1; then
    echo "  OK     las ${#INSTALLED[@]} copias instaladas coinciden con la versionada"
  else
    fails=$((fails+1))
    echo "  FALLO  copias instaladas derivadas — el guard que corre NO es el que se testea:"
    "$INSTALLER" --check 2>&1 | sed 's/^/           /'
    echo "           corrige con: bash scripts/install-k8s-context-guard.sh"
  fi
fi

echo
if [[ "$ran" -eq 0 ]]; then echo "FATAL: cero casos ejecutados — no se puede declarar exito"; exit 1; fi
[[ "$fails" -eq 0 ]] && echo "TODOS OK ($ran casos)" || { echo "$fails FALLOS de $ran"; exit 1; }

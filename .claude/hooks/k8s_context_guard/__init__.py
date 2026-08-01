"""k8s-context-guard: contextual guard for kubectl/helm/minikube.

Ported from codex-ralph-vault-loop (.codex/hooks/shared/) to Claude Code, then hardened:
command-wrapper peeling (sudo/timeout/eval/…), command-substitution detection, factual
minikube detection (profile-list + local-endpoint), and helm --kube-context routing.
kustomize is intentionally NOT covered (`kustomize build` is read-only, never hits a cluster).

Decision model (exact-match classification, deny > ask > allow):
  1. kubectl WITHOUT --context (read OR write), or dynamic --context  -> deny
  2. read WITH a valid --context                                      -> allow
  3. factually-verified minikube                                     -> allow (complete delete -> ask)
  4. context in AGENTS.md prod: list, or obvious-prod pattern         -> deny
  5. context in AGENTS.md dev: list                                   -> ask
  6. unknown WITH a prior memory clarification                        -> ask (confirm)
  7. undeclared remote / opaque wrapper (eval, alt-shell, $()/backtick) -> deny/ask (fail-closed)
"""

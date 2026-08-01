"""k8s-context-guard: contextual guard for kubectl/helm/minikube/kustomize.

Ported from codex-ralph-vault-loop (.codex/hooks/shared/) to Claude Code.

Decision model (exact-match classification, deny > ask > allow):
  1. kubectl write without --context, or dynamic --context  -> deny
  2. pure read                                               -> allow
  3. factually-verified minikube                            -> allow (full delete -> ask)
  4. context in AGENTS.md prod: list, or obvious-prod pattern -> deny
  5. context in AGENTS.md dev: list                          -> ask
  6. unknown WITH a prior memory clarification               -> ask (confirm)
  7. anything else (undeclared remote)                       -> deny (fail-closed)
"""

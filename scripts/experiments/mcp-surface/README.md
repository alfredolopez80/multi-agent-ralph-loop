# mcp-surface — MCP PreToolUse surface experiment (PR3-C3a)

Reproducible evidence for the `mcp-egress` gap of `.claude/security/SECURITY_BASELINE.json`.

**Question it answers**: does the active harness expose MCP tool calls to
`PreToolUse` hooks (with `mcp__<server>__<tool>` names and `tool_input`
arguments), and does the `mcp__.*` hook matcher target them?

**Verdict (2026-08-31, Claude Code 2.1.251): YES** — full detail in
`docs/security/MCP_SURFACE_EXPERIMENT_PR3-C3a.md`.

## Run

```bash
bash scripts/experiments/mcp-surface/run-experiment.sh A   # all-tools logger
bash scripts/experiments/mcp-surface/run-experiment.sh B   # mcp__.* matcher logger
```

- Run A must capture BOTH the Bash control probe and the MCP call. If Bash is
  missing, the hook never loaded and the run proves nothing (instrument failure,
  not "no surface").
- Run B must capture ONLY the MCP call (negative control: Bash/ToolSearch absent).

Evidence lands in `results/pr3-c3a-run/` (gitignored): generated settings, hook
logs (JSONL), nested session outputs. The experiment settings are generated at
run time because the hook path is absolute and machine-specific.

## Why this is NOT in tests/run-all-unit-tests.sh

Each run launches a nested headless Claude session (minutes, network, auth) —
not CI-eligible. This directory is versioned EVIDENCE: the manifest's
`mcp-egress` entry cites it as `proven_by` and names this runner as the way to
reproduce the proof.

## Components

| file | role |
|---|---|
| `hook-logger.sh` | PreToolUse probe: appends every event (JSONL) to `$MCP_SURFACE_LOG`, allows by silence |
| `run-experiment.sh` | generates settings at run time, launches the nested session, snapshots evidence |

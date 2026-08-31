# MCP PreToolUse Surface — Experiment Report (PR3-C3a, gap `mcp-egress`)

Date: 2026-08-31 · Version under test: Claude Code 2.1.251 · Instrument: `scripts/experiments/mcp-surface/`

## Verdict

**YES — the active harness exposes MCP tool calls to `PreToolUse` hooks, with the full
`mcp__<server>__<tool>` name and the `tool_input` arguments visible in the event payload.
The `mcp__.*` hook matcher selects exactly those tools.** The `mcp-egress` gap is therefore
resolvable on the NATIVE permission surface (no guard code); its entry in
`SECURITY_BASELINE.json` is `control-declarado` as of v1.4.0.

## Design (two runs, two controls)

Each run launches a nested headless Claude session (`claude --settings <generated> -p …`)
inside a scratch directory, with a temporary PreToolUse hook that logs every event to a JSONL
file and allows by silence:

- **Run A** — hook without matcher. Probes: one Bash `echo` (positive control) + one harmless
  MCP call (`mcp__context7__resolve-library-id`, `query='react'`). If Bash is not captured,
  the hook never loaded and the run proves nothing — an empty log cannot distinguish
  "no surface" from "broken instrument".
- **Run B** — hook with `"matcher": "mcp__.*"`. Same probes. The Bash control and ToolSearch
  calls must NOT appear (negative control).

Evidence is written to `results/pr3-c3a-run/` (gitignored). Reproduce:

```bash
bash scripts/experiments/mcp-surface/run-experiment.sh A
bash scripts/experiments/mcp-surface/run-experiment.sh B
```

## Evidence (2026-08-31 runs, verbatim fields from the hook logs)

Run A captured 3 events for this run: the **Bash control**
(`tool_input.command = "echo control-probe-ok"`), one `ToolSearch`, and the **MCP call**:

```json
{"hook_event_name":"PreToolUse","tool_name":"mcp__context7__resolve-library-id",
 "tool_input":{"libraryName":"react","query":"react"},"permission_mode":"auto", …}
```

Run B captured **exactly one event** — the MCP call above — with no Bash and no ToolSearch
entries: the `mcp__.*` matcher discriminates MCP from non-MCP tools.

Together: the payload gives server identity, tool identity and full arguments **before
execution** — everything a deterministic egress policy needs.

## Native permission surfaces for `mcp__*`

1. **Live settings rule**: the user's ACTIVE `~/.claude/settings.json` already carries
   `permissions.deny: ["mcp__milk_tea_server__claim_milk_tea_coupon", …]` — the
   `mcp__<server>__<tool>` rule syntax is supported and in production use on this version.
2. **Hook matcher**: `"matcher": "mcp__.*"` proven by Run B above.
3. Docs note: `docs.claude.com` `iam.md` / `settings.md` (fetched 2026-08-31) do not document
   the `mcp__*` rule syntax in their .md exports; authority for this report is the live
   settings rule + the experiment.

## Policy vs mechanism

The mechanism (surface + syntax) is proven and declared in the manifest. The SERVER LIST to
deny is **policy** and stays with the user's active settings — the manifest declares the
mechanism, not the list.

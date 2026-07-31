---
# VERSION: 3.1.0
name: adversarial
description: Apply adversarial opposite-analysis to plans, specs, architecture, code changes, and claims. Use when the user asks for adversarial review, opposing analysis, contrarian review, or red-team reasoning.
---

# Adversarial

Use this skill to challenge a plan, claim, implementation, or review from the strongest useful opposing position. This is not a default security scan and not a generic model vote. The main agent (orchestrator) remains final owner of decisions, edits, synthesis, and verification.

This skill narrows the original multi-agent security analyzer into opposite-analysis. It is harness-agnostic: the main agent — whether Claude Code or Codex — stays the decision owner. It defaults to assumption testing, counterargument generation, failure-mode discovery, and concise next actions.

## Trigger

Use when the user says `adversarial`, `analisis opuesto`, `opposing analysis`, `contrarian review`, `red-team this`, `challenge this plan`, `strongest counterargument`, `security review of this change`.

## Core Workflow

1. State the claim or plan being challenged in one sentence.
2. List the assumptions it depends on.
3. Ask what would make each assumption false in the current repo/runtime.
4. Identify the highest-impact failure modes first.
5. Separate proven issues from plausible risks.
6. Recommend one concrete next action: keep, adjust, defer, validate, or revert.

## Aristotle Integration

For non-trivial work, run a compact Aristotle First Principles pass — the same five phases the orchestrator uses — turned toward the opposing position:

1. **Assumption Autopsy** — list every assumption the claim or plan depends on.
2. **Irreducible Truths** — strip the assumptions; keep only what survives in the current repo/runtime.
3. **Reconstruction from Zero** — rebuild the strongest counter-position from those truths alone.
4. **Assumption vs Truth Map** — separate what is proven from what is merely assumed.
5. **The Aristotelian Move** — the single highest-leverage next action: keep, adjust, defer, validate, or revert.

## Agent Teams Integration

Adversarial review depends on **independent** perspectives: two passes that share a
starting frame tend to share its blind spots. Agent Teams provides that independence by
giving each lens its own context, so no teammate inherits the framing of another.

Spawn teammates in parallel, one per lens, so no teammate sees another's reasoning
before forming its own:

```yaml
TeamCreate:
  team_name: "adversarial-${TARGET}"
  description: "Independent opposing analysis of ${CLAIM}"

# Each lens challenges the claim from a different angle, in parallel
Task:
  subagent_type: "ralph-security"
  team_name: "adversarial-${TARGET}"
  run_in_background: true
  prompt: "Attack ${CLAIM} from a security standpoint. What breaks under a hostile input?"

Task:
  subagent_type: "ralph-reviewer"
  team_name: "adversarial-${TARGET}"
  run_in_background: true
  prompt: "Attack ${CLAIM} from correctness. Which assumption is false in this repo?"

Task:
  subagent_type: "ralph-tester"
  team_name: "adversarial-${TARGET}"
  run_in_background: true
  prompt: "Find the case that falsifies ${CLAIM}. Prefer a reproducible failure."
```

**Disagreement is the signal.** Where the teammates converge, the claim is probably
sound; where they diverge, that is the part worth investigating. Synthesis stays with
the main agent — teammates supply positions, not verdicts.

Use a single local pass instead of a team when the claim is small enough that three
perspectives would restate one another.

## Security Mode

Use security mode when the target is auth, permissions, input validation, network boundaries, data exposure, sandboxing, supply chain, or deployment risk.

Security mode sequence: reconnaissance, defense profile, attack vectors, evidence check, severity, fix direction. Findings must be grounded in file paths, code behavior, tests, config, or runtime evidence.

## Output Shapes

For a plan/spec/decision:

```text
Verdict: keep | adjust | defer | revert | validate first
Strongest counterargument: ...
Evidence: ...
Main risk: ...
Next action: ...
```

## Guardrails

- Do not mutate files during report-only/read-only adversarial review.
- Do not ask subagents to request approvals directly.
- Do not create findings without evidence.
- Do not recommend broad rewrites when a small validation or revert resolves the risk.

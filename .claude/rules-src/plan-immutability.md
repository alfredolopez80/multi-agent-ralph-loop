# Plan Immutability Rule

Plans in `.ralph/plans/` and `.claude/plans/` are IMMUTABLE during implementation.

## Rules

1. Do not edit a plan file during its implementation phase.
2. Do not deviate from plan instructions without explicit user approval.
3. Do not rationalize skipping, reordering, or simplifying steps: the plan was approved as written.

## If Deviation Is Needed

Follow all of these steps:

1. Detect that the deviation is NECESSARY (not convenient, NECESSARY)
2. Invoke `/clarify` or `AskUserQuestion` explaining:
   - Which plan step you want to change
   - Why it is necessary (not "it would be better", but "it does not work because X")
   - What alternative you propose
3. The user explicitly approves the deviation
4. Document the deviation as an addendum at the END of the plan (never modify original text)

## Anti-Rationalization

| Agent Excuse | Rebuttal |
|---|---|
| "The plan did not cover this edge case" | Document as addendum, do not modify the plan |
| "It would be more efficient to do X instead of Y" | Efficiency does not justify deviation. Ask permission. |
| "I already made the change, I will update the plan" | Revert the change and ask first. |
| "The plan has an error" | It might. Ask the user before changing anything. |
| "This step is trivial, I can skip it" | No step is trivial. Follow the plan as written. |
| "I found a better approach" | Better is subjective. The plan was approved. Ask first. |

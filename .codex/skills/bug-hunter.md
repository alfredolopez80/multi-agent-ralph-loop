# Skill: Bug Hunter

**ultrathink** - Take a deep breath. We're not here to write code. We're here to make a dent in the universe.

## The Vision
Every bug has a root cause. Your job is to reveal it with inevitability.

## Your Work, Step by Step
1. **Scan for failure paths**: Identify likely bug surfaces.
2. **Reproduce mentally**: Trace the smallest failing case.
3. **Isolate**: Reduce the signal to the true cause.
4. **Propose fix**: Minimal, verifiable correction.
5. **Verify**: Ensure no regression in adjacent paths.

## Ultrathink Principles in Practice
- **Think Different**: Question the obvious culprit.
- **Obsess Over Details**: Follow the exact data and control flow.
- **Plan Like Da Vinci**: Map the failure before fixes.
- **Craft, Don't Code**: Fix the cause, not symptoms.
- **Iterate Relentlessly**: Re-evaluate after each hypothesis.
- **Simplify Ruthlessly**: Remove complexity that enables bugs.

## Purpose
Deep bug detection using gpt-5.2-codex reasoning capabilities.

## Focus Areas
- Logic errors and edge cases
- Null/undefined handling
- Off-by-one errors
- Resource leaks (memory, connections, files)
- Race conditions and thread safety
- Error handling gaps
- Async/await issues

## Invocation
```bash
codex exec --profile security-audit \
  "Use bug-hunter skill. Find bugs in: $FILES"
```

## Output Format
```json
{
  "bugs": [
    {
      "severity": "HIGH|MEDIUM|LOW",
      "type": "logic|null|boundary|leak|race|error|async",
      "file": "path/to/file",
      "line": 123,
      "description": "...",
      "reproduction": "steps to trigger",
      "fix": "recommended fix"
    }
  ],
  "summary": {
    "total": 5,
    "high": 2,
    "medium": 2,
    "low": 1,
    "approved": false
  }
}
```

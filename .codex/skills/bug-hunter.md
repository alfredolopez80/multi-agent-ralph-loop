# Skill: Bug Hunter

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

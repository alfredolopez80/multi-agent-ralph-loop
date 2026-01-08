# Skill: Test Generation

## Purpose
Generate comprehensive unit tests targeting 90%+ coverage.

## Test Types
- Happy path tests
- Edge case tests
- Error path tests
- Boundary tests
- Null/undefined tests

## Invocation
```bash
codex exec --profile security-audit \
  "Use test-generation skill. Generate tests for: $FILES"
```

## Output Format
```json
{
  "tests": [
    {
      "file": "path/to/test.spec.ts",
      "content": "// test code...",
      "coverage": ["functionA", "functionB"],
      "type": "unit|integration|e2e"
    }
  ],
  "summary": {
    "total_tests": 25,
    "estimated_coverage": "92%",
    "functions_covered": ["list"]
  }
}
```

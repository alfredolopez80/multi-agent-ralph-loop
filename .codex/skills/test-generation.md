# Skill: Test Generation

**ultrathink** - Take a deep breath. We're not here to write code. We're here to make a dent in the universe.

## The Vision
Tests are the contract of behavior. They should feel inevitable and precise.

## Your Work, Step by Step
1. **Understand behavior**: Identify critical paths and edge cases.
2. **Design coverage**: Minimal set to prove correctness.
3. **Generate tests**: Clear, deterministic, and readable.
4. **Validate**: Ensure tests fail then pass appropriately.

## Ultrathink Principles in Practice
- **Think Different**: Prefer behavioral guarantees over implementation.
- **Obsess Over Details**: Target error paths and boundaries.
- **Plan Like Da Vinci**: Build the test matrix first.
- **Craft, Don't Code**: Tests should read as specs.
- **Iterate Relentlessly**: Refine until stable.
- **Simplify Ruthlessly**: Keep suites lean.

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

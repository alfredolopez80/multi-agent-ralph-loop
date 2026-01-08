# Skill: Ask Questions If Underspecified

## Purpose
Ensure clarity before proceeding with complex analysis or implementation.

## When to Use
- Complex security audits with unclear scope
- Bug hunting in large codebases
- Test generation with ambiguous requirements

## Process
1. Analyze the task requirements
2. Identify ambiguities
3. Categorize as MUST_HAVE or NICE_TO_HAVE
4. If MUST_HAVE questions exist, return them before proceeding

## Invocation
```bash
codex exec --profile security-audit \
  "Use ask-questions-if-underspecified skill. 
   Task: $TASK
   If clear, proceed with analysis. If not, ask clarifying questions."
```

## Output Format
```json
{
  "status": "clear|needs_clarification",
  "questions": {
    "must_have": [
      "Question 1?",
      "Question 2?"
    ],
    "nice_to_have": [
      {"question": "Optional question?", "assumption": "default value"}
    ]
  },
  "understanding": "Summary of current understanding",
  "proceed": true|false
}
```

## Examples

### Security Audit Clarification
```json
{
  "status": "needs_clarification",
  "questions": {
    "must_have": [
      "Should I include dependency vulnerabilities (npm audit)?",
      "Is this code handling PII or financial data?"
    ],
    "nice_to_have": [
      {"question": "Check for rate limiting?", "assumption": "yes"}
    ]
  }
}
```

# Skill: Ask Questions If Underspecified

**ultrathink** - Take a deep breath. We're not here to write code. We're here to make a dent in the universe.

## The Vision
Clarity is the foundation of inevitable solutions. Every question should narrow the path to truth.

## Your Work, Step by Step
1. **Analyze requirements**: Identify missing inputs and ambiguities.
2. **Separate MUST vs NICE**: Block on essentials, assume the rest.
3. **Ask precisely**: Short, concrete questions with defaults.
4. **Confirm understanding**: Summarize before proceeding.

## Ultrathink Principles in Practice
- **Think Different**: Question hidden assumptions.
- **Obsess Over Details**: Align questions with real constraints.
- **Plan Like Da Vinci**: Build the question set before asking.
- **Craft, Don't Code**: Precision over volume.
- **Iterate Relentlessly**: Refine questions as context evolves.
- **Simplify Ruthlessly**: Ask only what matters.

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

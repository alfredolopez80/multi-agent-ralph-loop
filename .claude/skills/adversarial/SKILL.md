---
name: adversarial
description: Adversarial validation system using dual-model cross-validation for critical implementations. Use when: validating complex code changes, cross-reviewing security-sensitive implementations, adversarial testing of edge cases, or when maximum code quality assurance is needed. Triggers: 'adversarial review', 'validate with adversarial', 'cross-validation', 'adversarial testing'.
---

# Adversarial Skill

Adversarial validation system that uses dual-model cross-validation to ensure code quality and correctness.

## When to Use

- **Security Reviews**: Validating authentication, authorization, and data handling
- **Critical Implementations**: Payment processing, crypto operations, core infrastructure
- **Complex Refactoring**: Large-scale code changes where correctness is paramount
- **Edge Case Testing**: Finding and validating edge cases that might be missed
- **Code Quality Gates**: Pre-commit validation for high-risk changes

## How It Works

1. **Dual Model Analysis**: Two different AI models analyze the code independently
2. **Cross-Validation**: Models compare findings and challenge each other's assessments
3. **Adversarial Testing**: Models attempt to find flaws in each other's analysis
4. **Consensus Building**: Final report only includes findings both models agree on

## Usage

```bash
/adversarial "Review this authentication code"
/adversarial "Validate this payment processing implementation"
/adversarial "Find edge cases in this error handling"
```

## Output

The adversarial skill produces:
- **Consensus Findings**: Issues both models agree on
- **Confidence Levels**: How certain the models are about each finding
- **Recommendations**: Specific actions to address identified issues
- **Validation Status**: Whether the implementation passes quality gates

## Integration

Works with:
- `/orchestrator` - For full workflow validation
- `/code-reviewer` - For standard code reviews
- `/security-auditor` - For security-specific reviews

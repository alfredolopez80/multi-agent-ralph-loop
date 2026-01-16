---
# VERSION: 2.43.0
name: refactor
prefix: "@ref"
category: review
color: red
description: "Systematic code refactoring via Codex - DRY, SOLID, Clean Code principles"
argument-hint: "<path>"
---

# /refactor - Systematic Code Refactoring Command

This command implements systematic code refactoring using Codex GPT-5.2 for improved code quality, maintainability, and adherence to software engineering principles.

## Overview

The `/refactor` command analyzes code for opportunities to improve:
- **Code smells**: Duplicated code, long methods, large classes, primitive obsession
- **SOLID violations**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **Clean Code**: Meaningful names, small functions, minimal complexity
- **Design patterns**: Apply appropriate patterns where beneficial

## When to Use

Invoke `/refactor` when you encounter:

1. **Code Smells**
   - Duplicated code blocks (DRY violations)
   - Methods longer than 20-30 lines
   - Classes with more than one responsibility
   - Nested conditionals (>3 levels deep)
   - Primitive obsession (using primitives instead of objects)
   - Data clumps (same group of data passed around)

2. **SOLID Violations**
   - Single Responsibility: Class/function doing multiple things
   - Open/Closed: Code that requires modification to extend
   - Liskov Substitution: Subclasses not substitutable for base
   - Interface Segregation: Fat interfaces with unused methods
   - Dependency Inversion: High-level depending on low-level modules

3. **Technical Debt**
   - Code that "works but feels wrong"
   - Hard-to-test code
   - Code with many conditional branches
   - God objects/classes
   - Feature envy (method using more of another class than its own)

## Refactoring Patterns

Common refactoring patterns applied:

### 1. Extract Method
```typescript
// Before
function processOrder(order) {
  // Calculate total
  let total = 0;
  for (const item of order.items) {
    total += item.price * item.quantity;
  }

  // Apply discount
  if (order.customer.isPremium) {
    total *= 0.9;
  }

  // Save to database
  db.save(order);
}

// After
function processOrder(order) {
  const total = calculateTotal(order);
  const discounted = applyDiscount(total, order.customer);
  saveOrder(order);
}

function calculateTotal(order) {
  return order.items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

function applyDiscount(total, customer) {
  return customer.isPremium ? total * 0.9 : total;
}
```

### 2. Extract Class
```typescript
// Before
class User {
  name: string;
  email: string;
  street: string;
  city: string;
  zipCode: string;
}

// After
class User {
  name: string;
  email: string;
  address: Address;
}

class Address {
  street: string;
  city: string;
  zipCode: string;
}
```

### 3. Replace Conditional with Polymorphism
```typescript
// Before
function getSpeed(vehicle) {
  switch(vehicle.type) {
    case 'car': return vehicle.enginePower * 2;
    case 'bike': return vehicle.pedalPower * 3;
    case 'plane': return vehicle.thrust * 10;
  }
}

// After
interface Vehicle {
  getSpeed(): number;
}

class Car implements Vehicle {
  getSpeed() { return this.enginePower * 2; }
}

class Bike implements Vehicle {
  getSpeed() { return this.pedalPower * 3; }
}

class Plane implements Vehicle {
  getSpeed() { return this.thrust * 10; }
}
```

### 4. Inline Method/Variable
```typescript
// Before
function getRating(driver) {
  return moreThanFiveLateDeliveries(driver) ? 2 : 1;
}

function moreThanFiveLateDeliveries(driver) {
  return driver.lateDeliveries > 5;
}

// After
function getRating(driver) {
  return driver.lateDeliveries > 5 ? 2 : 1;
}
```

### 5. Rename Method/Variable
```typescript
// Before
function calc(d, h) {
  return d * h * 0.5;
}

// After
function calculateTriangleArea(base, height) {
  return base * height * 0.5;
}
```

### 6. Move Method/Field
```typescript
// Before
class Account {
  overdraftCharge() {
    if (this.type.isPremium()) {
      return this.daysOverdrawn * 2.5;
    }
    return this.daysOverdrawn * 1.75;
  }
}

// After - moved to AccountType
class AccountType {
  overdraftCharge(daysOverdrawn) {
    if (this.isPremium()) {
      return daysOverdrawn * 2.5;
    }
    return daysOverdrawn * 1.75;
  }
}

class Account {
  overdraftCharge() {
    return this.type.overdraftCharge(this.daysOverdrawn);
  }
}
```

## Principles Applied

### DRY (Don't Repeat Yourself)
- Eliminate duplicated code through extraction
- Create reusable functions/classes
- Use inheritance/composition appropriately

### SOLID
- **S**: One class, one responsibility
- **O**: Open for extension, closed for modification
- **L**: Derived classes must be substitutable
- **I**: Many client-specific interfaces > one general
- **D**: Depend on abstractions, not concretions

### Clean Code
- Functions do one thing well
- Meaningful names (no comments needed)
- Minimal arguments (<=3 ideal)
- No side effects
- Command-Query Separation

## CLI Execution

```bash
# Refactor specific file
ralph refactor src/services/user-service.ts

# Refactor directory
ralph refactor src/models/

# Refactor with specific focus
ralph refactor src/utils/ --focus "extract-method,dry"

# Full project refactoring (use with caution)
ralph refactor .
```

## Task Tool Invocation

The `/refactor` command uses Codex GPT-5.2 via the Task tool:

```yaml
Task:
  subagent_type: "refactorer"
  model: "sonnet"  # Sonnet manages the Codex call
  run_in_background: true
  description: "Codex: Refactor $PATH for code quality"
  prompt: |
    Execute via Codex CLI:
    cd /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop && \
    codex exec -m gpt-5.2-codex -C . "
      Analyze and refactor: $PATH

      Focus on:
      1. DRY violations - extract duplicated code
      2. SOLID violations - improve class/function design
      3. Code smells - long methods, complex conditionals
      4. Meaningful names - improve clarity
      5. Extract methods - break down complex functions

      Apply refactoring patterns:
      - Extract Method/Class
      - Replace Conditional with Polymorphism
      - Rename for clarity
      - Move Method/Field
      - Inline where appropriate

      CRITICAL:
      - Preserve all existing functionality (no behavior changes)
      - Run tests after each refactoring
      - Apply Ralph Loop: iterate until quality gates pass
      - Maximum 15 iterations (Codex)

      Output:
      - List of refactorings applied
      - Before/after code snippets
      - Rationale for each change
      - Test results confirmation
    "
```

## Safety Guarantees

### Behavior Preservation
- **Zero functionality changes**: Refactoring MUST NOT alter behavior
- **Tests pass before and after**: All existing tests must remain green
- **Semantic equivalence**: Same inputs produce same outputs

### Incremental Changes
- **One refactoring at a time**: Apply, test, commit
- **Rollback capability**: Each step is reversible
- **Git safety**: Uses git worktree isolation when appropriate

### Quality Validation
- **Automatic quality gates**: Runs language-specific linters
- **Test suite execution**: Ensures no regressions
- **Type checking**: Validates type safety (TypeScript, Python, etc.)

## Output Format

```
## Refactoring Report: src/services/user-service.ts

### Code Smells Detected
- Long method: `processUserRegistration` (45 lines)
- Duplicated code: Email validation logic (3 occurrences)
- Primitive obsession: Using string for email instead of EmailAddress type

### Refactorings Applied

#### 1. Extract Method: validateEmail
**Before**:
```typescript
if (!email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
  throw new Error('Invalid email');
}
```

**After**:
```typescript
function validateEmail(email: string): void {
  if (!email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
    throw new Error('Invalid email');
  }
}
```

**Rationale**: Eliminate duplication (DRY), improve testability

#### 2. Extract Class: EmailAddress
**Before**:
```typescript
class User {
  email: string;
}
```

**After**:
```typescript
class EmailAddress {
  constructor(private readonly value: string) {
    this.validate();
  }

  private validate(): void {
    if (!this.value.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
      throw new Error('Invalid email');
    }
  }
}

class User {
  email: EmailAddress;
}
```

**Rationale**: Primitive obsession fix, encapsulate validation

#### 3. Split Method: processUserRegistration
**Before**: 45 lines, 3 responsibilities
**After**: 3 methods (validateInput, createUser, sendWelcomeEmail), 10-15 lines each
**Rationale**: Single Responsibility Principle

### Quality Gates: PASSED
- TypeScript compilation: ✓ No errors
- ESLint: ✓ No violations
- Tests: ✓ 42/42 passed
- Coverage: ✓ 94% (was 91%)

### Summary
- **Refactorings**: 5 applied
- **Code quality**: Improved from B to A
- **Test coverage**: +3%
- **Lines of code**: 145 → 132 (more readable)
```

## Integration with Ralph Loop

The refactoring process follows the Ralph Loop pattern:

```
1. EXECUTE → Apply refactoring pattern
2. VALIDATE → Run quality gates (tsc, eslint, tests)
3. Quality Passed? → NO → ITERATE (max 15 times)
                   → YES → VERIFIED_DONE
```

## Related Commands

- `/bugs` - Find bugs before refactoring to ensure clean baseline
- `/unit-tests` - Generate tests before refactoring for safety net
- `/full-review` - Comprehensive code review including refactoring opportunities
- `/code-reviewer` - Lighter review focused on specific areas
- `/security` - Security audit (should be run after major refactoring)

## Anti-Patterns

❌ Don't refactor without tests (create safety net first)
❌ Don't change behavior while refactoring (separate concerns)
❌ Don't refactor everything at once (incremental changes)
❌ Don't optimize prematurely (refactor for clarity first)
❌ Don't ignore failing tests (must pass before and after)
❌ Don't skip code review (get second opinion on major refactorings)

## Example Workflows

### Workflow 1: Safe Refactoring
```bash
# Step 1: Ensure tests exist
ralph unit-tests src/services/user-service.ts

# Step 2: Run tests to establish baseline
npm test

# Step 3: Refactor
ralph refactor src/services/user-service.ts

# Step 4: Verify tests still pass
npm test

# Step 5: Code review
ralph review src/services/user-service.ts
```

### Workflow 2: Large-Scale Refactoring
```bash
# Step 1: Create isolated worktree
ralph worktree "Refactor user module"

# Step 2: Refactor in isolation
ralph refactor src/user/

# Step 3: Quality gates
ralph gates

# Step 4: Multi-agent review
ralph worktree-pr refactor-user-module

# Step 5: Merge after approval
ralph worktree-merge <pr-number>
```

## Notes

- **Model**: Uses Codex GPT-5.2 (best for code understanding and refactoring)
- **Background**: Runs in background for large refactorings
- **Iterations**: Max 15 (Codex) per Ralph Loop pattern
- **Safety**: Always preserves behavior, never breaks tests
- **Cost**: ~60% of Claude Opus (efficient for refactoring tasks)

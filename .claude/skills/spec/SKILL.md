---
# VERSION: 3.0.0
name: spec
description: "Produce a verifiable technical specification before coding. 6 mandatory sections: Interfaces, Behaviors, Invariants (from Aristotle Phase 2), File Plan, Test Plan, Exit Criteria (executable bash commands + expected results). Use when: (1) before implementing features with complexity > 4, (2) as Step 1.5 in orchestrator workflow, (3) when requirements need formalization. Triggers: /spec, 'create spec', 'write specification', 'technical spec'."
argument-hint: "<feature description>"
user-invocable: true
---

# Spec — Verifiable Technical Specification v3.0

Produce a specification that is **executable** — Exit Criteria are bash commands that pass/fail.

## When to Use

- Orchestrator Step 1.5: for tasks with complexity > 4
- `/task-batch` Phase 3: for tasks with complexity > 6
- Any time before coding a non-trivial feature

## 6 Mandatory Sections

### 1. Interfaces

Define all public APIs, function signatures, type definitions:

```
Function: authenticateUser(email: string, password: string): Promise<AuthResult>
Type: AuthResult = { token: string, expiresAt: Date, user: UserProfile }
Endpoint: POST /api/auth/login → 200 AuthResult | 401 ErrorResponse
```

### 2. Behaviors

Define expected behaviors as given-when-then:

```
GIVEN a valid user with email "test@test.com"
WHEN authenticateUser("test@test.com", "correct-password") is called
THEN returns AuthResult with valid JWT token expiring in 24h

GIVEN an invalid password
WHEN authenticateUser("test@test.com", "wrong-password") is called
THEN throws AuthError with code "INVALID_CREDENTIALS"
```

### 3. Invariants

Built from Aristotle Phase 2 (Irreducible Truths):

```
INV-1: A token MUST expire (no infinite tokens)
INV-2: Password MUST never appear in logs or responses
INV-3: Rate limit: max 5 failed attempts per IP per minute
INV-4: Session tokens are cryptographically random (min 256 bits)
```

### 4. File Plan

Exactly which files will be created/modified:

```
CREATE: src/auth/authenticate.ts (main logic)
CREATE: src/auth/types.ts (AuthResult, AuthError types)
MODIFY: src/routes/index.ts (add /api/auth/login route)
CREATE: tests/auth/authenticate.test.ts (unit tests)
CREATE: tests/auth/authenticate.integration.test.ts (integration)
```

### 5. Test Plan

What tests will verify the specification:

```
UNIT:
- authenticateUser with valid credentials → returns token
- authenticateUser with invalid password → throws AuthError
- authenticateUser with non-existent user → throws AuthError
- Token expiry is exactly 24 hours from creation

INTEGRATION:
- POST /api/auth/login with valid body → 200
- POST /api/auth/login with wrong password → 401
- POST /api/auth/login 6 times rapidly → 429 (rate limited)
```

### 6. Exit Criteria

**Executable bash commands** with expected results. The spec is DONE when all pass:

```bash
# EC-1: Type check passes
npx tsc --noEmit
# Expected: exit 0

# EC-2: Unit tests pass
npm test -- --grep "authenticate"
# Expected: exit 0, all tests pass

# EC-3: Login endpoint returns 200 for valid credentials
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test123"}'
# Expected: 200

# EC-4: Login endpoint returns 401 for invalid credentials
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"wrong"}'
# Expected: 401

# EC-5: No password in logs
grep -r "password" logs/ | grep -v "test" | grep -v ".spec.md"
# Expected: no matches (exit 1)
```

## Output Format

The spec is written to `<feature-name>.spec.md` in the project root or `docs/specs/` directory.

## Integration with Orchestrator

```
Step 0: EVALUATE (Aristotle phases)
  → Invariants from Phase 2 feed into Section 3
Step 1: CLARIFY
Step 1.5: SPECIFY (this skill) ← for complexity > 4
Step 2: CLASSIFY
Step 3: PLAN (uses spec as input)
```

## Anti-Rationalization

| Excuse | Rebuttal |
|---|---|
| "The feature is too simple for a spec" | If complexity > 4, it gets a spec. Period. |
| "I'll write the spec after coding" | Spec comes BEFORE code. That's the point. |
| "Exit criteria are too rigid" | They're the definition of done. Make them right. |
| "I can't write exit criteria without coding first" | Write the behavior first, exit criteria follow. |
| "The spec will slow me down" | A wrong implementation is slower than a spec. |

## Template

See: `docs/templates/SPEC.md.template` (auto-created on first `/spec` invocation)

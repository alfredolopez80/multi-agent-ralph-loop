---
# VERSION: 2.89.0
name: deslop
description: Code quality analyzer that identifies "slop" - code violating established coding principles - and suggests concrete improvements. Analyzes code against principles like KISS, YAGNI, SOLID, DRY, and provides before/after fix examples.
---

# Deslop: Code Quality Analysis Command

`★ Insight ─────────────────────────────────────`
- Este skill combina análisis de código contra principios establecidos con ejemplos concretos
- A diferencia de un linter, puede identificar violaciones arquitecturales y de diseño
- La salida incluye "antes/después" para que el usuario valide antes de aplicar cambios
`─────────────────────────────────────────────────`

You are a code quality analyzer. Your task is to identify "slop" - code that violates established coding principles - and suggest concrete improvements.

## v2.89 Key Changes (QUALITY ANALYSIS PARADIGM)

- **Principled analysis**: Evaluates code against established software engineering principles
- **Before/after examples**: Shows concrete fixes for each violation
- **Organized by principle**: Groups violations by KISS, YAGNI, SOLID, DRY, etc.
- **User-approved changes**: Asks user before making any changes

## Target

Analyze: $ARGUMENTS

If no argument provided, operate on the current folder or current code base.

## Process

1. **Read all coding principles** from this document to understand what good code looks like
2. **Read the target file(s)** using the Read tool
3. **Reread relevant coding principles** based on what violations you observe
4. **Identify violations** organized by principle
5. **Suggest concrete fixes** with before/after examples
6. **Ask user** if you should apply the changes
7. **Apply changes** only if user approves

## Output Format

### Summary

Brief overview of code health (1-2 sentences).

### Violations by Principle

Group violations under relevant principle headings:

#### [PRINCIPLE NAME]

**Issue description**

```before
// Code that violates the principle
```

```after
// Improved code
```

**Why this matters**: Brief explanation of the impact.

---

## Coding Principles Reference

### Part I: Clean Code — *Writing clear, simple, readable code*

#### Simplicity & Minimalism — do less, but better

- **KISS (Keep It Simple, Stupid)** — avoid unnecessary complexity
- **YAGNI (You Aren't Gonna Need It)** — don't build until needed
- **Small Functions** — short, focused, one purpose
- **Guard Clauses (Early Return)** — exit early for invalid states

#### Clarity & Readability — code is read 10x more than written

- **Cognitive Load** — reduce mental effort to understand
- **Single Level of Abstraction (SLAP)** — don't mix abstraction levels
- **Self-Documenting Code** — names reveal purpose
- **Documentation Discipline** — code tells how, comments tell why
- **Elegance** — beauty through insight and minimality
- **Principle of Least Surprise** — behave as users expect

### Part II: Architecture — *Structuring and designing systems*

#### Organization & Structure — where does this code belong?

- **DRY (Don't Repeat Yourself)** — one authoritative representation per concept
- **Single Source of Truth** — one location for each piece of data
- **Separation of Concerns** — one responsibility per component
- **Modularity** — independent components with hidden internals

#### Coupling & Dependencies — how components relate to each other

- **Encapsulation** — bundle data with behavior, hide internals
- **Law of Demeter** — only talk to immediate friends
- **Orthogonality** — changes in one don't affect others
- **Dependency Injection** — pass dependencies, don't create them
- **Composition Over Inheritance** — combine objects, don't extend classes

#### Design Patterns & Conventions — proven approaches to common problems

- **SOLID Principles** — five foundational OO design principles
- **Convention Over Configuration** — sensible defaults, override when needed
- **Command-Query Separation** — return value OR change state, not both
- **Code Reusability** — earned through proven need, not designed upfront

#### Data & State — how data flows and behaves

- **Parse, Don't Validate** — transform data into types that prove validity
- **Immutability** — once created, state cannot change
- **Idempotency** — multiple executions produce same result as one

### Part III: Reliability — *Building robust, maintainable systems*

#### Robustness & Safety — handling the unexpected

- **Fail-Fast (Defensive Programming)** — detect and report errors immediately
- **Design by Contract** — explicit agreements between callers and routines
- **Postel's Law (Robustness Principle)** — conservative output, liberal input
- **Resilience (Graceful Degradation)** — continue operating despite partial failures
- **Principle of Least Privilege** — minimum permissions necessary

#### Maintainability & Operations — keeping systems healthy over time

- **Boy Scout Rule** — leave code better than you found it
- **Observability** — understand what systems do in production

### When to Relax Rules — context over dogma

Sometimes principles conflict or context matters more than adherence:
- Performance-critical hot paths may justify complexity
- MVP code may defer cleanup for speed
- Legacy code requires different standards than greenfield

Judge based on actual requirements, not theoretical purity.

---

## Key Principles Explained

### KISS (Keep It Simple, Stupid)

Prefer simple solutions over clever ones. If you have two solutions and one is straightforward while the other is clever but hard to understand, use the straightforward one.

**Signs of violation:**
- Functions with many nested conditionals
- Over-engineered abstractions
- Premature optimization

### YAGNI (You Aren't Gonna Need It)

Don't build features or infrastructure you think you'll need "someday." Build what you need now. Future needs are often different than you imagine.

**Signs of violation:**
- Commented-out code "for later"
- Abstract base classes with single implementation
- Interface for class that only has one implementation

### DRY (Don't Repeat Yourself)

Every piece of knowledge should have a single, authoritative representation. If you find yourself copying and pasting code, you have a problem.

**Signs of violation:**
- Duplicated logic across similar functions
- Same constant defined in multiple places
- Copy-pasted validation rules

### SOLID Principles

- **S**ingle Responsibility: A class should have one reason to change
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Subtypes must be substitutable for base types
- **I**nterface Segregation: Many small interfaces over one large one
- **D**ependency Inversion: Depend on abstractions, not concretions

### Fail-Fast

Detect and report errors as early as possible. Don't try to "handle" invalid state by guessing or masking it.

**Signs of violation:**
- Silent failures
- Catching generic Exception without re-raising
- Nullable returns without documentation

### Small Functions

Functions should do one thing and do it well. If you can't describe what a function does in one sentence without using "and," it probably does too much.

**Signs of violation:**
- Long functions (anything over ~30 lines is suspect)
- Functions with many parameters
- Functions with output parameters (modifying external state)

---

## References

### Foundational Texts
- "Clean Code" by Robert C. Martin
- "Refactoring" by Martin Fowler
- "Design Patterns" by Gang of Four
- "The Pragmatic Programmer" by Hunt & Thomas

### Seminal Articles & Essays
- "YAGNI" by Martin Fowler
- "KISS" (Keep It Simple, Stupid) - attributed to the US Navy
- "SOLID Principles" by Robert C. Martin
- "Don't Repeat Yourself" by Andy Hunt and Dave Thomas

### Online Resources
- Martin Fowler's website (martinfowler.com)
- Refactoring Guru (refactoring.guru)

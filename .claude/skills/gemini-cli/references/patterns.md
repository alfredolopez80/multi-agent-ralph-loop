# Gemini CLI Integration Patterns

Advanced patterns for orchestrating Gemini CLI from Claude Code.

## Pattern 1: Generate-Review-Fix Cycle

The most reliable pattern for quality code generation.

```bash
# Step 1: Generate
gemini "Create [code description]" --yolo -o text

# Step 2: Self-review
gemini "Review [generated file] for bugs and security issues" -o text

# Step 3: Fix issues
gemini "Fix these issues in [file]: [list]. Apply now." --yolo -o text
```

### Why It Works
- Different "mindset" for generation vs review
- Self-correction catches common mistakes
- Security vulnerabilities often caught in review phase

### Example

```bash
# Generate
gemini "Create a user authentication module with bcrypt and JWT" --yolo -o text

# Review
gemini "Review auth.js for security vulnerabilities" -o text
# Output: "Found XSS risk, missing input validation, weak JWT secret"

# Fix
gemini "Fix in auth.js: XSS risk, add input validation, use env var for JWT secret. Apply now." --yolo -o text
```

---

## Pattern 2: JSON Output for Programmatic Processing

```bash
gemini "[prompt]" -o json 2>&1
```

### Parsing Response

```javascript
const result = JSON.parse(output);
const content = result.response;
const tokenUsage = result.stats.models["gemini-3-pro"].tokens.total;
const toolCalls = result.stats.tools.byName;
```

### Use Cases
- Extracting specific data from responses
- Monitoring token usage
- Tracking tool call success/failure
- Building automation pipelines

---

## Pattern 3: Background Execution

For long-running tasks:

```bash
# Start in background
gemini "[long task]" --yolo -o text 2>&1 &
echo $!  # Get PID

# Parallel tasks
gemini "Create frontend" --yolo -o text 2>&1 &
gemini "Create backend" --yolo -o text 2>&1 &
gemini "Create tests" --yolo -o text 2>&1 &
wait
```

### When to Use
- Code generation for large projects
- Documentation generation
- Multiple independent tasks

---

## Pattern 4: Model Selection Strategy

### Decision Tree

```
Is the task complex (architecture, multi-file, deep analysis)?
├── Yes → Use default (Gemini 3 Pro)
└── No → Is speed critical?
    ├── Yes → Use gemini-2.5-flash
    └── No → Is it trivial (formatting, simple query)?
        ├── Yes → Use gemini-2.5-flash-lite
        └── No → Use gemini-2.5-flash
```

### Examples

```bash
# Complex: Architecture analysis
gemini "Analyze codebase architecture" -o text

# Quick: Simple formatting
gemini "Format this JSON" -m gemini-2.5-flash -o text

# Trivial: One-liner
gemini "What is 2+2?" -m gemini-2.5-flash -o text
```

---

## Pattern 5: Rate Limit Handling

### Approach 1: Auto-Retry (Default)
CLI retries automatically with backoff.

### Approach 2: Different Model Quotas

```bash
# High priority: Use Pro
gemini "[important task]" --yolo -o text

# Lower priority: Use Flash (different quota)
gemini "[less critical task]" -m gemini-2.5-flash -o text
```

### Approach 3: Batch Operations

```bash
# Instead of multiple calls
gemini "Create file A" --yolo
gemini "Create file B" --yolo
gemini "Create file C" --yolo

# Single call
gemini "Create files A, B, and C with [specs]. Create all now." --yolo
```

### Approach 4: Sequential with Delays

```bash
gemini "[task 1]" --yolo -o text
sleep 2
gemini "[task 2]" --yolo -o text
```

---

## Pattern 6: Context Enrichment

### File References

```bash
gemini "Based on @./package.json and @./src/index.js, suggest improvements" -o text
```

### Project Context (GEMINI.md)

Create `.gemini/GEMINI.md`:
```markdown
# Project Overview
This is a React app using TypeScript.

## Coding Standards
- Use functional components
- Prefer hooks over classes
- All functions need JSDoc
```

### Explicit Context in Prompt

```bash
gemini "Given this context:
- Project uses React 18 with TypeScript
- State management: Zustand
- Styling: Tailwind CSS

Create a user profile component." --yolo -o text
```

---

## Pattern 7: Validation Pipeline

### Steps

1. **Syntax Check**
   ```bash
   node --check generated.js
   tsc --noEmit generated.ts
   ```

2. **Security Scan**
   - Check for innerHTML with user input (XSS)
   - Look for eval() or Function() calls
   - Verify input validation

3. **Functional Test**
   - Run generated tests
   - Manual smoke test

4. **Style Check**
   ```bash
   eslint generated.js
   prettier --check generated.js
   ```

### Automated Validation

```bash
gemini "Create utility functions" --yolo -o text
node --check utils.js && eslint utils.js && npm test
```

---

## Pattern 8: Incremental Refinement

Build complex outputs in stages:

```bash
# Stage 1: Core structure
gemini "Create basic Express server with /api/users routes" --yolo -o text

# Stage 2: Add feature
gemini "Add authentication middleware to server.js" --yolo -o text

# Stage 3: Add another feature
gemini "Add rate limiting to server.js" --yolo -o text

# Stage 4: Review all
gemini "Review server.js for issues and optimize" -o text
```

### Benefits
- Easier to debug issues
- Each stage validates before continuing
- Clear audit trail

---

## Pattern 9: Cross-Validation with Claude

### Claude Generates → Gemini Reviews

```bash
# 1. Claude writes code (using Claude Code tools)
# 2. Gemini reviews
gemini "Review this code for bugs and security: [code]" -o text
```

### Gemini Generates → Claude Reviews

```bash
# 1. Gemini generates
gemini "Create [code]" --yolo -o text
# 2. Claude reviews the output
```

### Different Perspectives
- Claude: Strong on reasoning, complex instructions
- Gemini: Strong on current web knowledge, codebase investigation

---

## Pattern 10: Session Continuity

Multi-turn workflows with sessions:

```bash
# Initial task
gemini "Analyze this codebase architecture" -o text

# List sessions
gemini --list-sessions

# Continue with follow-up
echo "What patterns did you find?" | gemini -r 1 -o text

# Further refinement
echo "Focus on authentication flow" | gemini -r 1 -o text
```

### Use Cases
- Iterative analysis
- Building on previous context
- Debugging sessions

---

## Pattern 11: Conductor Extension Workflow (v0.22.0+)

Measure twice, implement once:

```bash
# Install Conductor
gemini extensions install https://github.com/gemini-cli-extensions/conductor

# Planning phase
gemini "Use Conductor to plan user authentication:
- Requirements: OAuth2, JWT tokens, session management
- Security: bcrypt, rate limiting, CSRF protection
- Database: PostgreSQL with Prisma" -o text

# Implementation follows plan
gemini "Implement the Conductor plan for authentication. Apply now." --yolo -o text
```

---

## Anti-Patterns to Avoid

### Don't: Expect Immediate Execution
YOLO mode doesn't prevent planning prompts.

**Do**: Use forceful language ("Apply now", "Start immediately")

### Don't: Ignore Rate Limits
Hammering the API wastes time on retries.

**Do**: Use appropriate models, batch operations

### Don't: Trust Output Blindly
Gemini can make mistakes, especially with security.

**Do**: Always validate generated code

### Don't: Over-Specify in Single Prompt
Extremely long prompts can confuse the model.

**Do**: Use incremental refinement for complex tasks

### Don't: Forget Context Limits
Even with 1M tokens, context can overflow.

**Do**: Use .geminiignore, be specific about files

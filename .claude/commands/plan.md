---
# VERSION: 2.50.0
name: plan
prefix: "@@plan"
category: tools
color: blue
description: "Plan-State Management for Ralph v2.45. Create, track, and manage implementation plans with Lead Soft"
argument-hint: "<arguments>"
---


Plan-State Management for Ralph v2.45. Create, track, and manage implementation plans with Lead Software Architect verification.

[Extended thinking: The plan command suite implements v2.45 Plan-Sync pattern with 7 subcommands: init, status, add-step, start, complete, verify, sync. Each subcommand manages a plan-state.json file in .claude/ directory. Plans include phases, risks, file modifications, and validation status. LSA verification ensures architecture compliance before execution.]

## Subcommands

### init - Initialize new plan
```
/plan init "Implement user authentication"
```
Creates .claude/plan-state.json with:
- Task title, phases, risk level
- File modifications list
- Test strategy
- Validation criteria

### status - Show plan status
```
/plan status
```
Displays:
- Current phase
- Completed vs pending steps
- Overall progress percentage
- Next action required

### add-step - Add implementation step
```
/plan add-step "Create User model with validation"
```
Appends step to phases array with:
- Step description
- Assigned agent/model
- Dependencies
- Validation criteria

### start - Begin implementation
```
/plan start
```
Triggers:
- LSA pre-verification
- Plan-Sync monitoring activation
- First phase execution

### complete - Mark step complete
```
/plan complete --step 2
```
Updates plan-state.json and logs completion in ledger.

### verify - Verify plan completion
```
/plan verify
```
Runs full validation against requirements:
- LSA architecture check
- Quality gate verification
- Requirements coverage

### sync - Synchronize with execution
```
/plan sync
```
Detects drift between plan and execution, patches downstream references.

## Workflow

```
/plan init "Feature description"
  ↓ (creates plan-state.json)
/plan add-step "Step 1"
/plan add-step "Step 2"
  ↓
/plan start
  ↓ (LSA verification)
/plan complete --step 1
/plan complete --step 2
  ↓
/plan verify
  ↓
VERIFIED_DONE
```

## Output Examples

### Plan Status Output
```
========================================
      PLAN STATE: Feature Implementation
========================================
Status: In Progress
Phase: 2/4 - Backend Implementation
Progress: 45%

Steps:
  ✅ 1. Database Schema - COMPLETE
  ⏳ 2. API Endpoints - IN PROGRESS
  🔲 3. Frontend Integration
  🔲 4. Testing & Validation

Next Action: /plan complete --step 2
========================================
```

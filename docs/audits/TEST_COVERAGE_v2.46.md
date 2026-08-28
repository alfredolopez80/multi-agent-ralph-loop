# v2.46 Integration Test Coverage Audit

**Audit Date**: 2026-01-18
**Test File**: `tests/test_v2_46_integration.py`
**Tests Run**: 26/26 PASSING
**Audit Status**: COMPREHENSIVE COVERAGE with IDENTIFIED GAPS

---

## Executive Summary

### Overall Coverage Assessment

| Category | Coverage | Details |
|----------|----------|---------|
| **Hooks (4 total)** | ✅ COVERED | All 4 v2.46 hooks tested |
| **Classification System** | 🟡 PARTIALLY_COVERED | Basic tests only, missing edge cases |
| **Workflow Routing** | ✅ COVERED | All 4 routes tested |
| **Quality-First Validation** | ✅ COVERED | Advisory vs blocking tested |
| **Edge Cases** | 🔴 NOT_COVERED | Multiple critical gaps identified |
| **Plan-State Schema** | ✅ COVERED | Schema validation comprehensive |
| **CLI Commands** | ✅ COVERED | Both classify and fast-path tested |

### Test Distribution

```
26 Total Tests:
├── Hooks: 7 tests (27%)
├── Skills: 3 tests (12%)
├── Plan-State Schema: 4 tests (15%)
├── Ralph CLI: 8 tests (31%)
├── Global Settings: 2 tests (8%)
└── Documentation: 3 tests (12%)
```

---

## Detailed Coverage Analysis

### 1. Hooks Coverage (4 hooks)

#### 1.1 fast-path-check.sh
**Status**: ✅ COVERED (basic), 🟡 PARTIALLY_COVERED (edge cases)

**Covered**:
- ✅ Hook exists and is executable
- ✅ Valid bash syntax
- ✅ Contains required keywords (fast_path, trivial, complexity, task)
- ✅ Trivial task detection (via CLI command)
- ✅ Complex task detection (via CLI command)

**NOT Covered** (GAPS):
1. 🔴 **Empty input handling**: What happens with empty JSON?
   ```bash
   echo '{}' | ~/.claude/hooks/fast-path-check.sh
   ```
2. 🔴 **Invalid JSON input**: Malformed JSON resistance
   ```bash
   echo '{invalid json' | ~/.claude/hooks/fast-path-check.sh
   ```
3. 🔴 **Missing required fields**: No tool_name, no session_id
   ```bash
   echo '{"tool_input": {}}' | ~/.claude/hooks/fast-path-check.sh
   ```
4. 🔴 **File count heuristic edge cases**:
   - Task with 0 files mentioned → Expected: trivial check
   - Task with exactly 3 files → Boundary: trivial or not?
   - Task with 10+ files → Expected: complex
5. 🔴 **Keyword collision**: Task with both trivial AND complex keywords
   ```
   "fix typo in authentication system" → Which wins?
   ```
6. 🔴 **Orchestrator skip logic**: Task with subagent_type="orchestrator"
7. 🔴 **Non-Task tool calls**: Edit, Write, Bash → Should return continue
8. 🔴 **Log file creation**: Verify ~/.ralph/logs/fast-path-YYYYMMDD.log exists and has entries

---

#### 1.2 quality-gates-v2.sh
**Status**: ✅ COVERED (basic), 🟡 PARTIALLY_COVERED (edge cases)

**Covered**:
- ✅ Hook exists and is executable
- ✅ Valid bash syntax
- ✅ Advisory consistency check (warns but doesn't block)

**NOT Covered** (GAPS):
1. 🔴 **Per-language syntax validation**:
   - Python: syntax error detection
   - TypeScript: type error detection
   - JavaScript: syntax error detection
   - Go: syntax validation
   - Rust: format validation
   - JSON: invalid JSON detection
   - YAML: invalid YAML detection
2. 🔴 **Blocking vs Advisory distinction**:
   - Correctness issues → Should block
   - Quality issues → Should block
   - Consistency issues → Should warn only
3. 🔴 **File not found**: Edit a non-existent file path
4. 🔴 **Empty file path**: tool_input.file_path is ""
5. 🔴 **Unsupported extension**: .unknown file
6. 🔴 **Multiple errors in same file**: How are they aggregated?
7. 🔴 **Log file rotation**: Does it grow unbounded?
8. 🔴 **Tool dependencies**: What if python3/node/gofmt not installed?

**Test Case Example**:
```python
def test_quality_gates_v2_python_syntax_error():
    """Verify quality gates block Python syntax errors."""
    # Create temp Python file with syntax error
    test_file = "/tmp/test_syntax_error.py"
    with open(test_file, 'w') as f:
        f.write("def broken(:\n    pass")

    input_json = {
        "tool_name": "Edit",
        "tool_input": {"file_path": test_file},
        "session_id": "test"
    }

    result = subprocess.run(
        ["~/.claude/hooks/quality-gates-v2.sh"],
        input=json.dumps(input_json),
        capture_output=True,
        text=True
    )

    response = json.loads(result.stdout)
    assert "BLOCKING" in response.get("additionalContext", "")
    assert "syntax error" in response.get("additionalContext", "").lower()
```

---

#### 1.3 parallel-explore.sh
**Status**: ✅ COVERED (basic), 🟡 PARTIALLY_COVERED (edge cases)

**Covered**:
- ✅ Hook exists and is executable
- ✅ Valid bash syntax
- ✅ Contains parallel keywords

**NOT Covered** (GAPS):
1. 🔴 **Gap-analyst trigger**: Hook only fires after gap-analyst Task
2. 🔴 **Tool availability**:
   - tldr not installed → Fallback behavior
   - ast-grep not installed → Skip pattern search
   - All tools missing → Graceful degradation
3. 🔴 **Parallel task timeouts**: What if semantic search hangs?
4. 🔴 **Partial results**: 2 of 4 tasks succeed
5. 🔴 **Output file creation**: exploration-context.json written correctly
6. 🔴 **Output file schema**: JSON structure matches plan-state-v2 schema
7. 🔴 **Keyword extraction**:
   - From orchestrator-analysis.md (if exists)
   - Fallback to prompt extraction
   - Empty keywords scenario
8. 🔴 **Process cleanup**: Background processes killed on timeout

**Test Case Example**:
```python
def test_parallel_explore_without_tldr():
    """Verify parallel-explore gracefully handles missing tldr."""
    # Mock gap-analyst task completion
    input_json = {
        "tool_name": "Task",
        "tool_input": {
            "subagent_type": "gap-analyst",
            "prompt": "Analyze authentication flow"
        },
        "session_id": "test"
    }

    # Temporarily rename tldr if exists
    tldr_path = subprocess.run(
        ["which", "tldr"],
        capture_output=True,
        text=True
    ).stdout.strip()

    # Run hook
    result = subprocess.run(
        ["~/.claude/hooks/parallel-explore.sh"],
        input=json.dumps(input_json),
        capture_output=True,
        text=True,
        cwd="/tmp/test_project"
    )

    # Verify output file exists
    assert os.path.exists("/tmp/test_project/.claude/exploration-context.json")

    # Verify graceful degradation
    with open("/tmp/test_project/.claude/exploration-context.json") as f:
        data = json.load(f)
        assert data["status"] == "completed"
        assert "partial" in data.get("note", "").lower()
```

---

#### 1.4 recursive-decompose.sh
**Status**: ✅ COVERED (basic), 🟡 PARTIALLY_COVERED (edge cases)

**Covered**:
- ✅ Hook exists and is executable
- ✅ Valid bash syntax
- ✅ Contains recursion keywords

**NOT Covered** (GAPS):
1. 🔴 **Classification trigger conditions**:
   - RECURSIVE_DECOMPOSE workflow route
   - QUADRATIC information density
   - RECURSIVE context requirement
2. 🔴 **Depth limiting**:
   - depth = 0 → Should allow decomposition
   - depth = 1 → Should allow (max 2)
   - depth = 2 → Should block (max reached) — also soft-enforced by agent-depth-soft-enforce.sh (T101)
   - depth > 2 → Should reject
3. 🔴 **Plan-state.json update**:
   - recursion.needs_decomposition set to true
   - recursion.decomposition_triggered timestamp
   - recursion.reason populated
4. 🔴 **Missing plan-state.json**: Fallback to defaults
5. 🔴 **Invalid plan-state.json**: Malformed JSON handling
6. 🔴 **MAX_CHILDREN limit**: Prevent spawning 100 sub-orchestrators
7. 🔴 **Sub-orchestrator guidance**:
   - Correct depth passed to children
   - Isolated context per child
   - Aggregation protocol mentioned

**Test Case Example**:
```python
def test_recursive_decompose_depth_limit():
    """Verify recursive decomposition respects max depth."""
    # Create plan-state at max depth
    plan_state = {
        "plan_id": "test",
        "task": "Complex task",
        "classification": {
            "workflow_route": "RECURSIVE_DECOMPOSE",
            "information_density": "QUADRATIC"
        },
        "recursion": {
            "depth": 3,
            "max_depth": 3
        }
    }

    with open("/tmp/test_project/.claude/plan-state.json", 'w') as f:
        json.dump(plan_state, f)

    input_json = {
        "tool_name": "Task",
        "tool_input": {
            "subagent_type": "orchestrator",
            "prompt": "classify complexity"
        },
        "session_id": "test"
    }

    result = subprocess.run(
        ["~/.claude/hooks/recursive-decompose.sh"],
        input=json.dumps(input_json),
        capture_output=True,
        text=True,
        cwd="/tmp/test_project"
    )

    response = json.loads(result.stdout)
    assert "STANDARD_PATH" in response.get("additionalContext", "")
    assert "Max recursion depth reached" in response.get("additionalContext", "")
```

---

### 2. Classification System Coverage

#### 2.1 3-Dimension Classification
**Status**: 🟡 PARTIALLY_COVERED

**Covered**:
- ✅ Complexity scale (1-10)
- ✅ Information density enum (CONSTANT, LINEAR, QUADRATIC)
- ✅ Context requirement enum (FITS, CHUNKED, RECURSIVE)

**NOT Covered** (GAPS):
1. 🔴 **Boundary testing**:
   - Complexity = 0 → Invalid, should reject
   - Complexity = 11 → Invalid, should reject
   - Complexity = 1 → Minimal valid
   - Complexity = 10 → Maximum valid
2. 🔴 **Enum validation**:
   - information_density = "INVALID" → Should reject
   - context_requirement = null → Should default to FITS
3. 🔴 **Classification matrix**:
   ```
   Complexity | Info Density | Context Req | Expected Route
   1-3        | CONSTANT     | FITS        | FAST_PATH
   4-6        | LINEAR       | FITS        | STANDARD
   4-6        | LINEAR       | CHUNKED     | PARALLEL_CHUNKS
   7-10       | QUADRATIC    | RECURSIVE   | RECURSIVE_DECOMPOSE
   ```
4. 🔴 **Real-world task classification**:
   - "Fix typo in README" → Expect: complexity=1, CONSTANT, FITS, FAST_PATH
   - "Add logging to 5 API endpoints" → Expect: complexity=4, LINEAR, CHUNKED, PARALLEL_CHUNKS
   - "Implement OAuth with Google, GitHub, Microsoft" → Expect: complexity=8, QUADRATIC, RECURSIVE, RECURSIVE_DECOMPOSE

---

### 3. Workflow Routing Coverage

**Status**: ✅ COVERED (basic), 🟡 PARTIALLY_COVERED (transitions)

**Covered**:
- ✅ FAST_PATH route exists
- ✅ STANDARD route exists
- ✅ PARALLEL_CHUNKS route exists
- ✅ RECURSIVE_DECOMPOSE route exists

**NOT Covered** (GAPS):
1. 🔴 **Route transitions**: Can a task move from STANDARD → PARALLEL_CHUNKS mid-execution?
2. 🔴 **Route override**: User forces FAST_PATH for complex task
3. 🔴 **Route fallback**: RECURSIVE_DECOMPOSE fails → Fallback to PARALLEL_CHUNKS?
4. 🔴 **Route validation**: Invalid route name handling
5. 🔴 **Route-specific behavior**:
   - FAST_PATH: 3 steps (EXECUTE → VALIDATE → DONE)
   - STANDARD: 12 steps (full orchestration)
   - PARALLEL_CHUNKS: Parallel task spawning verified
   - RECURSIVE_DECOMPOSE: Sub-orchestrator spawning verified

---

### 4. Edge Cases Coverage

**Status**: 🔴 NOT_COVERED (Critical gaps)

#### 4.1 Input Validation
**NOT Covered**:
1. 🔴 Empty JSON input to all hooks
2. 🔴 Malformed JSON to all hooks
3. 🔴 Missing required fields (tool_name, session_id, etc.)
4. 🔴 Null values in critical fields
5. 🔴 Unicode characters in task prompts
6. 🔴 Very long task prompts (>10K characters)
7. 🔴 Special characters in file paths (`/path/with spaces/file.ts`)

#### 4.2 File System
**NOT Covered**:
1. 🔴 Read-only file system
2. 🔴 Permission denied on log directory
3. 🔴 Disk full scenario
4. 🔴 Concurrent hook execution (race conditions)
5. 🔴 Symlink handling
6. 🔴 Non-existent project directory

#### 4.3 External Dependencies
**NOT Covered**:
1. 🔴 Missing binaries: python3, node, jq, gofmt, rustfmt
2. 🔴 Wrong versions: Python 2 instead of 3
3. 🔴 Command timeouts
4. 🔴 Command crashes

#### 4.4 Plan-State Schema
**NOT Covered**:
1. 🔴 Schema migration: v1 → v2
2. 🔴 Partial plan-state (missing optional fields)
3. 🔴 Conflicting step statuses (step marked completed but drift detected)
4. 🔴 Circular dependencies in recursion.children
5. 🔴 Exceed MAX_CHILDREN limit

---

## Missing Test Cases (Prioritized)

### Priority 1: CRITICAL (Security & Stability)

```python
# 1. Invalid JSON resistance
def test_all_hooks_handle_invalid_json():
    """All hooks must gracefully handle malformed JSON."""
    invalid_inputs = [
        "",
        "{}",
        "{invalid",
        '{"tool_name": null}',
        '{"tool_name": "Task", "tool_input": null}'
    ]
    for hook in HOOKS:
        for invalid in invalid_inputs:
            result = run_hook(hook, invalid)
            assert result.returncode == 0  # Must not crash
            assert "decision" in result.stdout  # Must return valid response

# 2. Empty input handling
def test_hooks_handle_empty_input():
    """Hooks must handle empty stdin."""
    for hook in HOOKS:
        result = subprocess.run(
            [hook],
            input="",
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

# 3. File path injection prevention
def test_quality_gates_prevents_path_injection():
    """Quality gates must sanitize file paths."""
    dangerous_paths = [
        "/etc/passwd",
        "../../etc/passwd",
        "/dev/null",
        "/tmp/$(whoami)",
        "/tmp/`rm -rf /`"
    ]
    for path in dangerous_paths:
        input_json = {
            "tool_name": "Edit",
            "tool_input": {"file_path": path},
            "session_id": "test"
        }
        result = run_hook("quality-gates-v2.sh", json.dumps(input_json))
        # Should not execute arbitrary commands
        assert "decision" in result.stdout
```

### Priority 2: HIGH (Correctness)

```python
# 4. Classification boundary testing
def test_classify_boundary_values():
    """Test classification at boundary values."""
    test_cases = [
        {"complexity": 0, "expected": "error"},  # Below minimum
        {"complexity": 1, "expected": "FAST_PATH"},
        {"complexity": 3, "expected": "FAST_PATH"},
        {"complexity": 4, "expected": "STANDARD"},
        {"complexity": 10, "expected": "RECURSIVE_DECOMPOSE"},
        {"complexity": 11, "expected": "error"},  # Above maximum
    ]
    for case in test_cases:
        result = classify_task(f"Task with complexity {case['complexity']}")
        assert case["expected"] in result

# 5. Depth limit enforcement
def test_recursive_decompose_enforces_depth_limit():
    """Verify recursion depth limit is enforced."""
    for depth in range(0, 5):
        plan_state = create_plan_state(depth=depth, max_depth=3)
        result = trigger_recursive_decompose(plan_state)

        if depth < 3:
            assert "RECURSIVE_DECOMPOSITION_REQUIRED" in result
        else:
            assert "Max recursion depth reached" in result

# 6. Quality gates blocking vs advisory
def test_quality_gates_blocking_vs_advisory():
    """Verify quality gates block on errors, warn on style."""
    # Blocking: syntax error
    syntax_error_file = create_file_with_syntax_error()
    result = run_quality_gates(syntax_error_file)
    assert result.returncode != 0  # Must block

    # Advisory: style issue
    style_issue_file = create_file_with_style_issue()
    result = run_quality_gates(style_issue_file)
    assert result.returncode == 0  # Must pass
    assert "WARN" in result.stdout  # But warn
```

### Priority 3: MEDIUM (Robustness)

```python
# 7. Missing tool dependencies
def test_hooks_graceful_degradation_without_tools():
    """Hooks must work when optional tools missing."""
    # Simulate missing tldr
    with mock.patch.dict(os.environ, {"PATH": "/bin:/usr/bin"}):
        result = trigger_parallel_explore()
        assert result.returncode == 0
        assert "completed" in result.stdout
        assert "partial" in result.stdout.lower()

# 8. Concurrent execution safety
def test_hooks_concurrent_execution():
    """Hooks must handle concurrent execution."""
    import threading

    results = []
    def run_hook_thread():
        result = run_hook("fast-path-check.sh", test_input)
        results.append(result)

    threads = [threading.Thread(target=run_hook_thread) for _ in range(10)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    # All should succeed, no race conditions
    assert all(r.returncode == 0 for r in results)
    # Log files should not be corrupted
    assert_log_integrity()

# 9. Large input handling
def test_hooks_handle_large_inputs():
    """Hooks must handle very large task prompts."""
    large_prompt = "Fix typo " * 10000  # ~70K characters
    result = classify_task(large_prompt)
    assert result.returncode == 0
```

### Priority 4: LOW (Nice to Have)

```python
# 10. Performance benchmarks
def test_fast_path_performance():
    """Fast-path should complete in <100ms."""
    start = time.time()
    result = classify_task("Fix typo")
    duration = time.time() - start
    assert duration < 0.1  # 100ms

# 11. Log rotation
def test_log_rotation():
    """Verify logs rotate and don't grow unbounded."""
    # Trigger 1000 hook calls
    for i in range(1000):
        run_hook("fast-path-check.sh", test_input)

    log_dir = Path.home() / ".ralph" / "logs"
    total_size = sum(f.stat().st_size for f in log_dir.glob("*.log"))
    assert total_size < 10_000_000  # < 10MB

# 12. Schema backward compatibility
def test_plan_state_schema_v1_to_v2_migration():
    """Verify v1 plan-state can be migrated to v2."""
    v1_plan = load_fixture("plan-state-v1-example.json")
    v2_plan = migrate_plan_state_v1_to_v2(v1_plan)

    # Validate against v2 schema
    validate_json_schema(v2_plan, "plan-state-v2.json")
    assert v2_plan["classification"]["information_density"]  # New field
```

---

## Recommended Test Additions

### Immediate (Before Merging v2.46)

Create `tests/test_v2_46_edge_cases.py`:

```python
class TestV246EdgeCases:
    """Edge case testing for v2.46 hooks."""

    # Priority 1: Critical
    def test_invalid_json_handling(self):
        """All hooks must handle invalid JSON gracefully."""
        # Test #1 from above

    def test_empty_input_handling(self):
        """All hooks must handle empty input."""
        # Test #2 from above

    def test_path_injection_prevention(self):
        """Quality gates must prevent path injection."""
        # Test #3 from above

    # Priority 2: High
    def test_classification_boundaries(self):
        """Test classification at boundary values."""
        # Test #4 from above

    def test_depth_limit_enforcement(self):
        """Verify recursion depth limit."""
        # Test #5 from above

    def test_blocking_vs_advisory_validation(self):
        """Verify quality gates block errors, warn on style."""
        # Test #6 from above
```

### Short-term (Within 1 week)

Create `tests/test_v2_46_robustness.py`:

```python
class TestV246Robustness:
    """Robustness testing for v2.46 hooks."""

    def test_missing_dependencies(self):
        """Test graceful degradation without tools."""
        # Test #7 from above

    def test_concurrent_execution(self):
        """Test concurrent hook execution."""
        # Test #8 from above

    def test_large_input_handling(self):
        """Test large task prompt handling."""
        # Test #9 from above
```

### Long-term (Within 1 month)

Create `tests/test_v2_46_performance.py`:

```python
class TestV246Performance:
    """Performance and maintenance testing."""

    @pytest.mark.benchmark
    def test_fast_path_latency(self):
        """Benchmark fast-path classification speed."""
        # Test #10 from above

    def test_log_rotation(self):
        """Verify log rotation works."""
        # Test #11 from above

    def test_schema_migration(self):
        """Test v1 → v2 schema migration."""
        # Test #12 from above
```

---

## Coverage Gaps Summary

| Gap Category | Count | Priority |
|--------------|-------|----------|
| Input Validation | 7 | CRITICAL |
| File System Edge Cases | 6 | HIGH |
| External Dependencies | 4 | HIGH |
| Classification Boundaries | 4 | HIGH |
| Workflow Transitions | 5 | MEDIUM |
| Performance | 3 | LOW |
| Maintenance | 2 | LOW |

**Total Missing Tests**: 31

---

## Recommendations

### Immediate Actions (Before v2.46 Release)

1. ✅ **Add input validation tests** (Priority 1)
   - Invalid JSON, empty input, null values
   - Estimated: 3 tests, 30 minutes

2. ✅ **Add path injection prevention test** (Priority 1)
   - Prevent `/etc/passwd` and command injection
   - Estimated: 1 test, 15 minutes

3. ✅ **Add classification boundary tests** (Priority 2)
   - Test complexity 0, 1, 10, 11
   - Estimated: 1 test, 20 minutes

4. ✅ **Add depth limit test** (Priority 2)
   - Verify recursion stops at max_depth
   - Estimated: 1 test, 15 minutes

**Total Immediate Work**: 6 tests, ~1.5 hours

### Short-term (Next Sprint)

5. **Add robustness tests** (Priority 2-3)
   - Missing dependencies, concurrent execution, large inputs
   - Estimated: 3 tests, 1 hour

6. **Add per-language quality gate tests** (Priority 2)
   - Python, TypeScript, JavaScript syntax errors
   - Estimated: 7 tests, 1 hour

### Long-term (Backlog)

7. **Add performance benchmarks**
   - Fast-path latency, parallel exploration speed
   - Estimated: 3 tests, 2 hours

8. **Add schema migration tests**
   - v1 → v2 plan-state migration
   - Estimated: 2 tests, 1 hour

---

## Conclusion

**Current Test Suite Status**: GOOD FOUNDATION, NEEDS HARDENING

The current 26 tests provide excellent **happy path coverage** for v2.46 features. All core functionality is verified:
- ✅ Hooks exist and have valid syntax
- ✅ Classification system works for typical cases
- ✅ CLI commands function correctly
- ✅ Documentation is updated

However, **production readiness** requires addressing the 31 identified gaps, particularly:
1. Input validation (CRITICAL)
2. Path injection prevention (CRITICAL)
3. Classification boundaries (HIGH)
4. Depth limit enforcement (HIGH)

**Recommended Path to Production**:
1. Add 6 immediate tests before merging v2.46 (~1.5 hours)
2. Add 10 short-term tests in next sprint (~2 hours)
3. Defer 15 long-term tests to backlog (~3 hours)

**Total Additional Test Investment**: ~6.5 hours for complete coverage

---

## Appendix: Test Coverage Matrix

| Feature | Basic | Edge Cases | Error Handling | Performance |
|---------|-------|------------|----------------|-------------|
| fast-path-check.sh | ✅ | 🔴 | 🔴 | 🔴 |
| parallel-explore.sh | ✅ | 🔴 | 🟡 | 🔴 |
| quality-gates-v2.sh | ✅ | 🟡 | 🔴 | 🔴 |
| recursive-decompose.sh | ✅ | 🔴 | 🔴 | 🔴 |
| 3D Classification | ✅ | 🔴 | 🔴 | N/A |
| Workflow Routing | ✅ | 🔴 | 🔴 | N/A |
| Plan-State Schema | ✅ | 🟡 | 🔴 | N/A |
| Ralph CLI | ✅ | 🟡 | 🔴 | 🔴 |

**Legend**: ✅ COVERED | 🟡 PARTIALLY_COVERED | 🔴 NOT_COVERED | N/A Not Applicable

---

**Audit Completed**: 2026-01-18 19:15 PST
**Next Review**: After adding immediate tests (6 tests, ~1.5 hours)

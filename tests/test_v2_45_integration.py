"""
Multi-Agent Ralph v2.45 Integration Tests

Tests for validating:
- Lead Software Architect (LSA) agent and hooks
- Plan-Sync agent and drift detection hook
- Gap-Analyst agent
- Quality-Auditor agent
- Adversarial-Plan-Validator agent
- Plan-State schema validation
- Plan-State CLI commands in ralph script
- Nested loop architecture components
"""
import os
import json
import subprocess
import pytest


# ============================================================
# v2.45 Agents Tests
# ============================================================

class TestV245Agents:
    """Test v2.45 agents exist and have valid frontmatter."""

    V245_AGENTS = [
        "lead-software-architect",
        "plan-sync",
        "gap-analyst",
        "quality-auditor",
        "adversarial-plan-validator",
    ]

    def test_all_v245_agents_exist(self, global_agents_dir):
        """Verify all v2.45 agents exist."""
        missing = []
        for agent in self.V245_AGENTS:
            agent_path = os.path.join(global_agents_dir, f"{agent}.md")
            if not os.path.isfile(agent_path):
                missing.append(agent)

        assert not missing, (
            f"Missing v2.45 agents: {missing}. "
            "Run the v2.45 implementation to create these agents."
        )

    def test_lead_software_architect_has_frontmatter(self, global_agents_dir, validate_agent_frontmatter):
        """Verify lead-software-architect agent has valid frontmatter."""
        agent_path = os.path.join(global_agents_dir, "lead-software-architect.md")
        result = validate_agent_frontmatter(agent_path)

        assert result["has_frontmatter"], "lead-software-architect missing frontmatter"
        assert result["valid"], f"lead-software-architect frontmatter invalid: {result['errors']}"

    def test_plan_sync_agent_has_frontmatter(self, global_agents_dir, validate_agent_frontmatter):
        """Verify plan-sync agent has valid frontmatter."""
        agent_path = os.path.join(global_agents_dir, "plan-sync.md")
        result = validate_agent_frontmatter(agent_path)

        assert result["has_frontmatter"], "plan-sync missing frontmatter"
        assert result["valid"], f"plan-sync frontmatter invalid: {result['errors']}"

    def test_gap_analyst_agent_has_frontmatter(self, global_agents_dir, validate_agent_frontmatter):
        """Verify gap-analyst agent has valid frontmatter."""
        agent_path = os.path.join(global_agents_dir, "gap-analyst.md")
        result = validate_agent_frontmatter(agent_path)

        assert result["has_frontmatter"], "gap-analyst missing frontmatter"
        assert result["valid"], f"gap-analyst frontmatter invalid: {result['errors']}"

    def test_quality_auditor_agent_has_frontmatter(self, global_agents_dir, validate_agent_frontmatter):
        """Verify quality-auditor agent has valid frontmatter."""
        agent_path = os.path.join(global_agents_dir, "quality-auditor.md")
        result = validate_agent_frontmatter(agent_path)

        assert result["has_frontmatter"], "quality-auditor missing frontmatter"
        assert result["valid"], f"quality-auditor frontmatter invalid: {result['errors']}"

    def test_adversarial_plan_validator_has_frontmatter(self, global_agents_dir, validate_agent_frontmatter):
        """Verify adversarial-plan-validator agent has valid frontmatter."""
        agent_path = os.path.join(global_agents_dir, "adversarial-plan-validator.md")
        result = validate_agent_frontmatter(agent_path)

        assert result["has_frontmatter"], "adversarial-plan-validator missing frontmatter"
        assert result["valid"], f"adversarial-plan-validator frontmatter invalid: {result['errors']}"

    def test_lead_software_architect_has_lsa_keywords(self, global_agents_dir):
        """Verify lead-software-architect agent contains LSA-specific keywords."""
        agent_path = os.path.join(global_agents_dir, "lead-software-architect.md")
        if not os.path.exists(agent_path):
            pytest.skip("lead-software-architect.md not found")

        with open(agent_path) as f:
            content = f.read().lower()

        keywords = ["architecture", "verification", "pre-check", "post-check"]
        missing = [kw for kw in keywords if kw not in content]

        assert not missing, (
            f"lead-software-architect missing keywords: {missing}. "
            "Agent should discuss architecture verification."
        )

    def test_plan_sync_has_drift_keywords(self, global_agents_dir):
        """Verify plan-sync agent contains drift-related keywords."""
        agent_path = os.path.join(global_agents_dir, "plan-sync.md")
        if not os.path.exists(agent_path):
            pytest.skip("plan-sync.md not found")

        with open(agent_path) as f:
            content = f.read().lower()

        keywords = ["drift", "sync", "patch", "downstream"]
        missing = [kw for kw in keywords if kw not in content]

        assert not missing, (
            f"plan-sync missing keywords: {missing}. "
            "Agent should discuss drift detection and downstream patching."
        )

    def test_adversarial_validator_has_cross_validation_keywords(self, global_agents_dir):
        """Verify adversarial-plan-validator agent mentions cross-validation."""
        agent_path = os.path.join(global_agents_dir, "adversarial-plan-validator.md")
        if not os.path.exists(agent_path):
            pytest.skip("adversarial-plan-validator.md not found")

        with open(agent_path) as f:
            content = f.read().lower()

        # Should mention both Claude and Codex for cross-validation
        assert "claude" in content or "opus" in content, (
            "adversarial-plan-validator should mention Claude/Opus for cross-validation"
        )
        assert "codex" in content or "gpt" in content, (
            "adversarial-plan-validator should mention Codex/GPT for cross-validation"
        )


# ============================================================
# v2.45 Hooks Tests
# ============================================================

class TestV245Hooks:
    """Test v2.45 hooks exist and are properly configured."""

    V245_HOOKS = [
        "lsa-pre-step.sh",
        "plan-sync-post-step.sh",
        "plan-state-init.sh",
    ]

    def test_all_v245_hooks_exist(self, global_hooks_dir):
        """Verify all v2.45 hooks exist."""
        missing = []
        for hook in self.V245_HOOKS:
            hook_path = os.path.join(global_hooks_dir, hook)
            if not os.path.isfile(hook_path):
                missing.append(hook)

        assert not missing, (
            f"Missing v2.45 hooks: {missing}. "
            "Run the v2.45 implementation to create these hooks."
        )

    def test_all_v245_hooks_executable(self, global_hooks_dir):
        """Verify all v2.45 hooks are executable."""
        not_executable = []
        for hook in self.V245_HOOKS:
            hook_path = os.path.join(global_hooks_dir, hook)
            if os.path.exists(hook_path) and not os.access(hook_path, os.X_OK):
                not_executable.append(hook)

        assert not not_executable, (
            f"Hooks not executable: {not_executable}. "
            f"Run: chmod +x ~/.claude/hooks/<hook>"
        )

    def test_lsa_pre_step_hook_content(self, global_hooks_dir):
        """Verify lsa-pre-step.sh hook has required components."""
        hook_path = os.path.join(global_hooks_dir, "lsa-pre-step.sh")
        if not os.path.exists(hook_path):
            pytest.skip("lsa-pre-step.sh not found")

        with open(hook_path) as f:
            content = f.read()

        # Should reference plan-state.json
        assert "plan-state.json" in content, (
            "lsa-pre-step.sh should reference plan-state.json"
        )
        # Should have LSA verification logic
        assert "verification" in content.lower() or "verify" in content.lower(), (
            "lsa-pre-step.sh should contain verification logic"
        )

    def test_plan_sync_post_step_hook_content(self, global_hooks_dir):
        """Verify plan-sync-post-step.sh hook has drift detection."""
        hook_path = os.path.join(global_hooks_dir, "plan-sync-post-step.sh")
        if not os.path.exists(hook_path):
            pytest.skip("plan-sync-post-step.sh not found")

        with open(hook_path) as f:
            content = f.read()

        # Should have drift detection
        assert "drift" in content.lower(), (
            "plan-sync-post-step.sh should contain drift detection logic"
        )
        # Should reference plan-state.json
        assert "plan-state.json" in content, (
            "plan-sync-post-step.sh should reference plan-state.json"
        )

    def test_plan_state_init_hook_content(self, global_hooks_dir):
        """Verify plan-state-init.sh hook can initialize plan state."""
        hook_path = os.path.join(global_hooks_dir, "plan-state-init.sh")
        if not os.path.exists(hook_path):
            pytest.skip("plan-state-init.sh not found")

        with open(hook_path) as f:
            content = f.read()

        # Should have init function
        assert "init" in content.lower(), (
            "plan-state-init.sh should have init function"
        )
        # Should handle steps
        assert "step" in content.lower(), (
            "plan-state-init.sh should handle step management"
        )

    def test_hooks_have_version_marker(self, global_hooks_dir):
        """Verify v2.45 hooks have VERSION marker."""
        for hook in self.V245_HOOKS:
            hook_path = os.path.join(global_hooks_dir, hook)
            if not os.path.exists(hook_path):
                continue

            with open(hook_path) as f:
                content = f.read()

            assert "VERSION" in content, (
                f"{hook} should have VERSION marker for tracking"
            )


# ============================================================
# v2.45 Schema Tests
# ============================================================

class TestPlanStateSchema:
    """Test plan-state JSON schema validation."""

    def test_schema_file_exists(self, claude_global_dir):
        """Verify plan-state-v1.schema.json exists."""
        schema_path = os.path.join(claude_global_dir, "schemas", "plan-state-v1.schema.json")
        assert os.path.isfile(schema_path), (
            f"plan-state-v1.schema.json not found at {schema_path}. "
            "Run the v2.45 implementation to create the schema."
        )

    def test_schema_is_valid_json(self, claude_global_dir):
        """Verify plan-state schema is valid JSON."""
        schema_path = os.path.join(claude_global_dir, "schemas", "plan-state-v1.schema.json")
        if not os.path.exists(schema_path):
            pytest.skip("Schema file not found")

        with open(schema_path) as f:
            try:
                schema = json.load(f)
            except json.JSONDecodeError as e:
                pytest.fail(f"Schema is not valid JSON: {e}")

        assert isinstance(schema, dict), "Schema should be a JSON object"

    def test_schema_has_required_structure(self, claude_global_dir):
        """Verify schema has required JSON Schema structure."""
        schema_path = os.path.join(claude_global_dir, "schemas", "plan-state-v1.schema.json")
        if not os.path.exists(schema_path):
            pytest.skip("Schema file not found")

        with open(schema_path) as f:
            schema = json.load(f)

        # Should have $schema reference
        assert "$schema" in schema, "Schema should have $schema reference"

        # Should have properties
        assert "properties" in schema, "Schema should define properties"

        # Should define key v2.45 fields
        props = schema.get("properties", {})
        required_fields = ["plan_id", "task", "steps", "classification"]
        missing = [f for f in required_fields if f not in props]

        assert not missing, (
            f"Schema missing required properties: {missing}"
        )

    def test_schema_defines_steps_array(self, claude_global_dir):
        """Verify schema defines steps as array with proper structure."""
        schema_path = os.path.join(claude_global_dir, "schemas", "plan-state-v1.schema.json")
        if not os.path.exists(schema_path):
            pytest.skip("Schema file not found")

        with open(schema_path) as f:
            schema = json.load(f)

        props = schema.get("properties", {})
        steps = props.get("steps", {})

        assert steps.get("type") == "array", "steps should be an array type"
        assert "items" in steps, "steps should define items schema"

    def test_schema_defines_drift_tracking(self, claude_global_dir):
        """Verify schema supports drift tracking in steps."""
        schema_path = os.path.join(claude_global_dir, "schemas", "plan-state-v1.schema.json")
        if not os.path.exists(schema_path):
            pytest.skip("Schema file not found")

        with open(schema_path) as f:
            schema = json.load(f)

        # Check if drift is defined in step items or drift_log
        schema_str = json.dumps(schema).lower()

        assert "drift" in schema_str, (
            "Schema should support drift tracking (drift_log or step.drift)"
        )


# ============================================================
# v2.45 CLI Commands Tests
# ============================================================

class TestRalphPlanStateCommands:
    """Test ralph CLI has v2.45 plan-state commands."""

    def test_ralph_has_cmd_plan_function(self, scripts_dir):
        """Verify ralph CLI has cmd_plan function."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        assert "cmd_plan(" in content or "cmd_plan ()" in content, (
            "ralph CLI missing cmd_plan function"
        )

    def test_ralph_has_plan_subcommands(self, scripts_dir):
        """Verify ralph plan has subcommands (init, status, add-step, etc.)."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        subcommands = ["init", "status", "add-step", "start", "complete", "verify", "sync", "clear"]
        missing = [cmd for cmd in subcommands if cmd not in content]

        assert not missing, (
            f"ralph plan missing subcommands: {missing}"
        )

    def test_ralph_has_lsa_command(self, scripts_dir):
        """Verify ralph CLI has lsa command."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        assert "cmd_lsa" in content, "ralph CLI missing cmd_lsa function"
        assert "lsa|" in content or "|lsa)" in content or "lsa)" in content, (
            "ralph CLI missing lsa case statement"
        )

    def test_ralph_has_gap_command(self, scripts_dir):
        """Verify ralph CLI has gap-analyze command."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        assert "cmd_gap" in content, "ralph CLI missing cmd_gap function"
        assert "gap" in content, "ralph CLI missing gap case statement"

    def test_ralph_has_audit_command(self, scripts_dir):
        """Verify ralph CLI has quality-audit command."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        assert "cmd_audit" in content, "ralph CLI missing cmd_audit function"
        assert "audit" in content, "ralph CLI missing audit case statement"

    def test_ralph_has_adversarial_plan_command(self, scripts_dir):
        """Verify ralph CLI has adversarial-plan command."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        assert "cmd_adversarial_plan" in content, (
            "ralph CLI missing cmd_adversarial_plan function"
        )
        assert "adversarial-plan" in content, (
            "ralph CLI missing adversarial-plan case statement"
        )

    def test_ralph_version_is_245(self, scripts_dir):
        """Verify ralph script version is 2.45.x."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        # Look for VERSION variable
        assert 'VERSION="2.45' in content or "VERSION='2.45" in content, (
            "ralph script VERSION should be 2.45.x"
        )


# ============================================================
# v2.45 Nested Loop Architecture Tests
# ============================================================

class TestNestedLoopArchitecture:
    """Test nested loop architecture components."""

    def test_orchestrator_references_nested_loop(self, global_agents_dir):
        """Verify orchestrator agent references nested loop pattern."""
        orch_path = os.path.join(global_agents_dir, "orchestrator.md")
        if not os.path.exists(orch_path):
            pytest.skip("orchestrator.md not found")

        with open(orch_path) as f:
            content = f.read().lower()

        # Should mention nested/internal loop concept
        has_nested = "nested" in content or "inner loop" in content or "per-step" in content
        assert has_nested, (
            "orchestrator should reference nested loop architecture"
        )

    def test_orchestrator_references_lsa(self, global_agents_dir):
        """Verify orchestrator agent references LSA pattern."""
        orch_path = os.path.join(global_agents_dir, "orchestrator.md")
        if not os.path.exists(orch_path):
            pytest.skip("orchestrator.md not found")

        with open(orch_path) as f:
            content = f.read().lower()

        has_lsa = "lsa" in content or "lead software architect" in content
        assert has_lsa, (
            "orchestrator should reference Lead Software Architect (LSA) pattern"
        )

    def test_orchestrator_references_plan_sync(self, global_agents_dir):
        """Verify orchestrator agent references Plan-Sync."""
        orch_path = os.path.join(global_agents_dir, "orchestrator.md")
        if not os.path.exists(orch_path):
            pytest.skip("orchestrator.md not found")

        with open(orch_path) as f:
            content = f.read().lower()

        has_plan_sync = "plan-sync" in content or "plan sync" in content or "plansync" in content
        assert has_plan_sync, (
            "orchestrator should reference Plan-Sync agent"
        )

    def test_micro_gate_3_fix_rule(self, global_agents_dir):
        """Verify 3-Fix Rule is documented in orchestrator or quality-auditor."""
        # Check orchestrator
        orch_path = os.path.join(global_agents_dir, "orchestrator.md")
        qa_path = os.path.join(global_agents_dir, "quality-auditor.md")

        has_3_fix = False

        if os.path.exists(orch_path):
            with open(orch_path) as f:
                if "3-fix" in f.read().lower() or "three-fix" in f.read().lower():
                    has_3_fix = True

        if not has_3_fix and os.path.exists(qa_path):
            with open(qa_path) as f:
                if "3" in f.read() and "fix" in f.read().lower():
                    has_3_fix = True

        assert has_3_fix, (
            "3-Fix Rule should be documented in orchestrator or quality-auditor"
        )


# ============================================================
# v2.45 Integration Tests
# ============================================================

class TestV245Integration:
    """Integration tests for v2.45 component interaction."""

    def test_plan_state_init_can_run(self, global_hooks_dir, temp_dir):
        """Verify plan-state-init.sh can run without errors."""
        hook_path = os.path.join(global_hooks_dir, "plan-state-init.sh")
        if not os.path.exists(hook_path):
            pytest.skip("plan-state-init.sh not found")

        # Run with help or no args to check syntax
        result = subprocess.run(
            ["bash", hook_path],
            capture_output=True,
            text=True,
            cwd=temp_dir,
            timeout=5
        )

        # Should at least show usage without crashing
        # Exit code 0 or showing help is acceptable
        assert result.returncode == 0 or "Usage" in result.stdout or "Usage" in result.stderr, (
            f"plan-state-init.sh failed: {result.stderr}"
        )

    def test_lsa_pre_step_can_run(self, global_hooks_dir, temp_dir):
        """Verify lsa-pre-step.sh can run without errors."""
        hook_path = os.path.join(global_hooks_dir, "lsa-pre-step.sh")
        if not os.path.exists(hook_path):
            pytest.skip("lsa-pre-step.sh not found")

        # Run in temp dir (no plan-state.json = should exit cleanly)
        result = subprocess.run(
            ["bash", hook_path],
            capture_output=True,
            text=True,
            cwd=temp_dir,
            timeout=5
        )

        # Should exit cleanly when no plan-state.json exists
        assert result.returncode == 0, (
            f"lsa-pre-step.sh should exit cleanly without plan-state.json: {result.stderr}"
        )

    def test_plan_sync_post_step_can_run(self, global_hooks_dir, temp_dir):
        """Verify plan-sync-post-step.sh can run without errors."""
        hook_path = os.path.join(global_hooks_dir, "plan-sync-post-step.sh")
        if not os.path.exists(hook_path):
            pytest.skip("plan-sync-post-step.sh not found")

        # Run in temp dir (no plan-state.json = should exit cleanly)
        result = subprocess.run(
            ["bash", hook_path],
            capture_output=True,
            text=True,
            cwd=temp_dir,
            timeout=5
        )

        # Should exit cleanly when no plan-state.json exists
        assert result.returncode == 0, (
            f"plan-sync-post-step.sh should exit cleanly without plan-state.json: {result.stderr}"
        )

    def test_ralph_plan_status_help(self, scripts_dir):
        """Verify ralph plan status shows reasonable output."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            ["bash", ralph_script, "plan", "status"],
            capture_output=True,
            text=True,
            timeout=10
        )

        # Should either show status or indicate no plan exists
        combined = result.stdout + result.stderr
        assert "plan" in combined.lower() or "status" in combined.lower() or "not found" in combined.lower(), (
            f"ralph plan status should provide meaningful output: {combined}"
        )


# ============================================================
# Conftest Additions for v2.45
# ============================================================

@pytest.fixture
def validate_agent_frontmatter():
    """Validator for agent frontmatter."""
    import yaml

    def _validate(agent_path: str) -> dict:
        """Validate agent frontmatter and return parsed content."""
        result = {
            "valid": False,
            "has_frontmatter": False,
            "frontmatter": {},
            "errors": []
        }

        if not os.path.exists(agent_path):
            result["errors"].append(f"File not found: {agent_path}")
            return result

        with open(agent_path) as f:
            content = f.read()

        # Check for frontmatter (agents may or may not have it)
        if not content.startswith("---"):
            # Agents without frontmatter are still valid
            result["valid"] = True
            return result

        # Extract frontmatter
        parts = content.split("---", 2)
        if len(parts) < 3:
            result["errors"].append("Invalid frontmatter format")
            return result

        result["has_frontmatter"] = True

        try:
            frontmatter = yaml.safe_load(parts[1])
            result["frontmatter"] = frontmatter or {}
            result["valid"] = True

        except yaml.YAMLError as e:
            result["errors"].append(f"YAML parse error: {e}")

        return result

    return _validate


@pytest.fixture
def v245_agents():
    """List of v2.45 agents."""
    return [
        "lead-software-architect",
        "plan-sync",
        "gap-analyst",
        "quality-auditor",
        "adversarial-plan-validator",
    ]


@pytest.fixture
def v245_hooks():
    """List of v2.45 hooks."""
    return [
        "lsa-pre-step.sh",
        "plan-sync-post-step.sh",
        "plan-state-init.sh",
    ]

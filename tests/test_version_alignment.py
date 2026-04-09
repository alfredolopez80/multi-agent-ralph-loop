"""
Test version alignment across all project components.
Ensures skills, agents, hooks, and documentation have consistent versions.
"""
import os
import re
import json
import pytest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
EXPECTED_MAJOR_VERSION = "3"  # v3.x.x for Herding Blanket release


class TestVersionAlignment:
    """All modified components should have aligned version numbers."""

    def _extract_version(self, filepath: Path) -> str | None:
        """Extract VERSION from frontmatter or content."""
        try:
            content = filepath.read_text()
        except Exception:
            return None

        # Match: # VERSION: X.Y.Z
        match = re.search(r"#\s*VERSION:\s*(\d+\.\d+\.\d+)", content)
        if match:
            return match.group(1)

        # Match: version: "X.Y.Z" in JSON
        if filepath.suffix == ".json":
            try:
                data = json.loads(content)
                return data.get("version", None)
            except Exception:
                return None

        return None

    def _get_skills_with_versions(self):
        """Get all skills and their versions."""
        skills_dir = REPO_ROOT / ".claude" / "skills"
        results = []
        if skills_dir.exists():
            for skill_dir in sorted(skills_dir.iterdir()):
                skill_md = skill_dir / "SKILL.md"
                if skill_md.exists():
                    version = self._extract_version(skill_md)
                    results.append((skill_dir.name, version))
        return results

    def _get_agents_with_versions(self):
        """Get all agents and their versions."""
        agents_dir = REPO_ROOT / ".claude" / "agents"
        results = []
        if agents_dir.exists():
            for agent_file in sorted(agents_dir.glob("*.md")):
                version = self._extract_version(agent_file)
                results.append((agent_file.stem, version))
        return results

    # --- V3.0 Skills (created in Herding Blanket) ---

    V3_SKILLS = [
        "design-system", "spec", "context-engineer", "browser-test",
        "vault", "exit-review", "adr", "perf", "ship",
    ]

    V3_MODIFIED_SKILLS = [
        "orchestrator", "adversarial", "clarify", "task-batch",
        "create-task-batch", "iterate", "gates", "autoresearch",
    ]

    V3_AGENTS = [
        "ralph-frontend", "ralph-security",
    ]

    def test_v3_skills_have_version(self):
        """New v3.0 skills must have VERSION markers."""
        skills = dict(self._get_skills_with_versions())
        for skill_name in self.V3_SKILLS:
            assert skill_name in skills, f"Skill {skill_name} not found"
            assert skills[skill_name] is not None, f"Skill {skill_name} has no VERSION"

    def test_v3_skills_aligned(self):
        """New v3.0 skills must be version 3.x.x."""
        skills = dict(self._get_skills_with_versions())
        misaligned = []
        for skill_name in self.V3_SKILLS:
            version = skills.get(skill_name)
            if version and not version.startswith(EXPECTED_MAJOR_VERSION + "."):
                misaligned.append(f"{skill_name}: {version}")
        assert not misaligned, f"Skills not on v{EXPECTED_MAJOR_VERSION}.x.x: {misaligned}"

    def test_v3_agents_have_version(self):
        """V3 agents must have VERSION markers."""
        agents = dict(self._get_agents_with_versions())
        for agent_name in self.V3_AGENTS:
            assert agent_name in agents, f"Agent {agent_name} not found"
            assert agents[agent_name] is not None, f"Agent {agent_name} has no VERSION"

    def test_v3_agents_aligned(self):
        """V3 agents must be version 3.x.x."""
        agents = dict(self._get_agents_with_versions())
        misaligned = []
        for agent_name in self.V3_AGENTS:
            version = agents.get(agent_name)
            if version and not version.startswith(EXPECTED_MAJOR_VERSION + "."):
                misaligned.append(f"{agent_name}: {version}")
        assert not misaligned, f"Agents not on v{EXPECTED_MAJOR_VERSION}.x.x: {misaligned}"

    def test_plan_state_version(self):
        """plan-state.json version should match."""
        plan_state = REPO_ROOT / ".claude" / "plan-state.json"
        if plan_state.exists():
            data = json.loads(plan_state.read_text())
            version = data.get("version", "")
            assert version.startswith(EXPECTED_MAJOR_VERSION), (
                f"plan-state.json version is {version}, expected {EXPECTED_MAJOR_VERSION}.x"
            )

    def test_claude_md_version(self):
        """CLAUDE.md should reference current major version."""
        claude_md = REPO_ROOT / "CLAUDE.md"
        content = claude_md.read_text()
        assert re.search(r"v3\.\d+", content) or re.search(r"v2\.9[4-9]", content), (
            "CLAUDE.md does not reference v3.x or v2.94+"
        )

    def test_rules_files_exist(self):
        """V3.0 rule files must exist."""
        v3_rules = [
            ".claude/rules/plan-immutability.md",
            ".claude/rules/aristotle-methodology.md",
        ]
        for rule_path in v3_rules:
            full_path = REPO_ROOT / rule_path
            assert full_path.exists(), f"Rule file missing: {rule_path}"

    def test_reference_docs_exist(self):
        """V3.0 reference docs must exist."""
        v3_docs = [
            "docs/reference/aristotle-first-principles.md",
            "docs/reference/anti-rationalization.md",
            "docs/reference/testing-patterns.md",
            "docs/reference/security-checklist.md",
            "docs/reference/accessibility-checklist.md",
            "docs/templates/DESIGN.md.template",
        ]
        for doc_path in v3_docs:
            full_path = REPO_ROOT / doc_path
            assert full_path.exists(), f"Reference doc missing: {doc_path}"

    def test_gitignore_vault_exclusions(self):
        """V3.0 .gitignore must exclude vault private data."""
        gitignore = (REPO_ROOT / ".gitignore").read_text()
        required = [
            ".claude/vault/",
            ".claude/rules/learned/",
            ".claude/context-payload.md",
            ".claude/memory-context.json",
            ".claude/orchestrator-analysis.md",
        ]
        missing = [r for r in required if r not in gitignore]
        assert not missing, f"Missing gitignore entries: {missing}"

    def test_no_version_regression(self):
        """No skill should have version < 2.0 (sanity check)."""
        skills = self._get_skills_with_versions()
        old_versions = []
        for name, version in skills:
            if version:
                major = int(version.split(".")[0])
                if major < 2:
                    old_versions.append(f"{name}: {version}")
        assert not old_versions, f"Skills with version < 2.0: {old_versions}"


class TestHookConsistency:
    """Hooks should be registered consistently across settings files."""

    CLAUDE_SETTINGS = Path.home() / ".claude" / "settings.json"
    MINIMAX_SETTINGS = Path.home() / ".cc-mirror" / "minimax" / "config" / "settings.json"

    CRITICAL_HOOKS = [
        "auto-plan-state.sh",
        "plan-analysis-cleanup.sh",
        "audit-secrets.js",
        "session-accumulator.sh",
        "vault-graduation.sh",
    ]

    def _hook_registered(self, settings_path: Path, hook_name: str) -> bool:
        """Check if a hook is registered in a settings file."""
        if not settings_path.exists():
            return False
        content = settings_path.read_text()
        return hook_name in content

    def test_critical_hooks_in_claude(self):
        """Critical hooks must be in ~/.claude/settings.json."""
        if not self.CLAUDE_SETTINGS.exists():
            pytest.skip("Claude settings not found")
        missing = [h for h in self.CRITICAL_HOOKS if not self._hook_registered(self.CLAUDE_SETTINGS, h)]
        assert not missing, f"Critical hooks missing from Claude settings: {missing}"

    def test_critical_hooks_in_minimax(self):
        """Critical hooks must be in minimax settings. Accepts both old and new names for renamed hooks."""
        if not self.MINIMAX_SETTINGS.exists():
            pytest.skip("MiniMax settings not found")
        # Allow both sanitize-secrets.js (old) and audit-secrets.js (new)
        alternative_hooks = {
            "audit-secrets.js": "sanitize-secrets.js",
        }
        missing = []
        for h in self.CRITICAL_HOOKS:
            if not self._hook_registered(self.MINIMAX_SETTINGS, h):
                # Check if there's an acceptable alternative name
                alt = alternative_hooks.get(h)
                if alt and self._hook_registered(self.MINIMAX_SETTINGS, alt):
                    continue  # Alternative name found, acceptable
                missing.append(h)
        assert not missing, f"Critical hooks missing from MiniMax settings: {missing}"

    def test_security_hooks_parity(self):
        """Security hooks should exist in both settings. Accepts both old and new names for renamed hooks."""
        if not self.CLAUDE_SETTINGS.exists() or not self.MINIMAX_SETTINGS.exists():
            pytest.skip("Both settings required")
        security_hooks = [
            ("audit-secrets.js", "sanitize-secrets.js"),  # (new_name, old_name) pairs
            "git-safety-guard.py",
            "repo-boundary-guard.sh",
        ]
        for hook_spec in security_hooks:
            if isinstance(hook_spec, tuple):
                new_name, old_name = hook_spec
                # Check both settings have either new or old name
                claude = (self._hook_registered(self.CLAUDE_SETTINGS, new_name) or
                         self._hook_registered(self.CLAUDE_SETTINGS, old_name))
                minimax = (self._hook_registered(self.MINIMAX_SETTINGS, new_name) or
                          self._hook_registered(self.MINIMAX_SETTINGS, old_name))
                assert claude and minimax, f"Security hook {new_name}/{old_name} not in both settings (claude={claude}, minimax={minimax})"
            else:
                # Single name hook
                claude = self._hook_registered(self.CLAUDE_SETTINGS, hook_spec)
                minimax = self._hook_registered(self.MINIMAX_SETTINGS, hook_spec)
                assert claude and minimax, f"Security hook {hook_spec} not in both settings (claude={claude}, minimax={minimax})"

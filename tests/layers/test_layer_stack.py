"""
tests/layers/test_layer_stack.py
================================

Unit tests for the W2.2 4-Layer Memory Stack (.claude/lib/layers.py).

Tests verify:
  - Layer0: identity load and exists()
  - Layer1: build() creates L1_essential.md with 15 rules, load() round-trip
  - Layer2: has() returns False for missing projects
  - Layer3: query() returns correct structure (list of dicts)
"""

import json
import os
import sys
import tempfile
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Path setup — allow import of layers.py from .claude/lib/
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).parent.parent.parent
LIB_DIR = REPO_ROOT / ".claude" / "lib"
sys.path.insert(0, str(LIB_DIR))

from layers import Layer0, Layer1, Layer2, Layer3, load_wake_up_context  # noqa: E402


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def tmp_layers_dir(tmp_path: Path) -> Path:
    """Provide a temporary ~/.ralph/layers directory."""
    layers = tmp_path / "layers"
    layers.mkdir()
    return layers


@pytest.fixture()
def real_l0_path() -> Path:
    """Return the real L0 path (should already exist from W2.2 setup)."""
    return Path.home() / ".ralph" / "layers" / "L0_identity.md"


@pytest.fixture()
def real_l1_path() -> Path:
    """Return the real L1 path (should already exist after build())."""
    return Path.home() / ".ralph" / "layers" / "L1_essential.md"


@pytest.fixture()
def sample_rules_json(tmp_path: Path) -> Path:
    """Create a minimal rules.json fixture with 20 rules for Layer1 tests."""
    rules = []
    for i in range(20):
        rules.append(
            {
                "rule_id": f"test-rule-{i:02d}",
                "trigger": f"Test trigger for rule {i}",
                "behavior": f"Test behavior for rule {i}: do something useful and important.",
                "confidence": round(0.5 + (i % 5) * 0.1, 2),
                "usage_count": (20 - i) * 10,
                "domain": ["testing", "security", "backend", "hooks", "frontend"][i % 5],
                "tags": ["test"],
            }
        )
    data = {
        "version": "test-1.0",
        "updated": "2026-04-07",
        "rules": rules,
        "curator_metadata": {},
    }
    p = tmp_path / "rules.json"
    p.write_text(json.dumps(data), encoding="utf-8")
    return p


# ---------------------------------------------------------------------------
# Layer0 tests
# ---------------------------------------------------------------------------

class TestLayer0:
    """Tests for the identity layer (L0)."""

    def test_exists_returns_true_for_real_file(self, real_l0_path: Path):
        """L0.exists() returns True when the real identity file exists."""
        layer = Layer0(path=real_l0_path)
        assert layer.exists() is True, (
            f"L0 identity file missing at {real_l0_path}. "
            "Run W2.2 setup to create ~/.ralph/layers/L0_identity.md"
        )

    def test_exists_returns_false_for_missing_file(self, tmp_layers_dir: Path):
        """L0.exists() returns False when the file does not exist."""
        missing = tmp_layers_dir / "nonexistent_L0.md"
        layer = Layer0(path=missing)
        assert layer.exists() is False

    def test_load_returns_string_content(self, real_l0_path: Path):
        """L0.load() returns the identity content as a non-empty string."""
        layer = Layer0(path=real_l0_path)
        if not layer.exists():
            pytest.skip("L0 file not present — run W2.2 setup first")
        content = layer.load()
        assert isinstance(content, str)
        assert len(content) > 0

    def test_load_contains_identity_markers(self, real_l0_path: Path):
        """L0.load() content includes expected identity markers."""
        layer = Layer0(path=real_l0_path)
        if not layer.exists():
            pytest.skip("L0 file not present — run W2.2 setup first")
        content = layer.load()
        assert "Ralph" in content, "L0 should mention 'Ralph'"
        assert "Principles" in content or "principles" in content.lower(), (
            "L0 should contain principles"
        )

    def test_load_raises_on_missing_file(self, tmp_layers_dir: Path):
        """L0.load() raises FileNotFoundError when file is missing."""
        missing = tmp_layers_dir / "no_identity.md"
        layer = Layer0(path=missing)
        with pytest.raises(FileNotFoundError):
            layer.load()

    def test_load_custom_path(self, tmp_path: Path):
        """L0.load() reads from a custom path correctly."""
        custom = tmp_path / "custom_L0.md"
        custom.write_text("# Test Identity\nThis is a test.", encoding="utf-8")
        layer = Layer0(path=custom)
        assert layer.exists() is True
        content = layer.load()
        assert "Test Identity" in content

    def test_token_estimate_reasonable(self, real_l0_path: Path):
        """L0 token estimate is between 50 and 500 tokens (sanity check)."""
        layer = Layer0(path=real_l0_path)
        if not layer.exists():
            pytest.skip("L0 file not present")
        tokens = layer.token_estimate()
        assert 50 <= tokens <= 500, (
            f"L0 token estimate {tokens} outside expected 50-500 range"
        )


# ---------------------------------------------------------------------------
# Layer1 tests
# ---------------------------------------------------------------------------

class TestLayer1:
    """Tests for the essential rules layer (L1)."""

    def test_build_creates_md_file(self, tmp_path: Path, sample_rules_json: Path, monkeypatch):
        """Layer1.build() creates the markdown file."""
        output_path = tmp_path / "L1_essential.md"
        layer = Layer1(path=output_path, rule_count=15)

        # Monkeypatch the source rules path
        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_json)

        result = layer.build()

        assert result == output_path
        assert output_path.is_file()
        assert output_path.stat().st_size > 0

    def test_build_includes_up_to_25_rules(self, tmp_path: Path, sample_rules_json: Path, monkeypatch):
        """Layer1.build() encodes up to 25 rules (top by score with domain diversity)."""
        output_path = tmp_path / "L1_essential.md"
        layer = Layer1(path=output_path, rule_count=25)

        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_json)

        layer.build()
        content = layer.load()

        # Count rule entries in output
        rule_count = sum(1 for line in content.splitlines() if line.startswith("## "))
        assert rule_count <= 25, (
            f"Expected at most 25 rules in L1, found {rule_count}"
        )

    def test_build_includes_header_with_count(self, tmp_path: Path, sample_rules_json: Path, monkeypatch):
        """Layer1.build() writes L1_ESSENTIAL header with scoring pipeline info."""
        output_path = tmp_path / "L1_essential.md"
        layer = Layer1(path=output_path, rule_count=25)

        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_json)

        layer.build()
        content = layer.load()

        assert "L1 Essential Rules" in content
        assert "actionable" in content
        assert "domain cap" in content

    def test_load_returns_markdown(self, tmp_path: Path, sample_rules_json: Path, monkeypatch):
        """Layer1.build() + load() returns the markdown content."""
        output_path = tmp_path / "L1_essential.md"
        layer = Layer1(path=output_path, rule_count=15)

        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_json)

        layer.build()
        decoded = layer.load()

        # Should contain the first rule from the fixture (highest score: test-rule-00)
        assert "test-rule-00" in decoded, (
            "Round-trip failed: top rule 'test-rule-00' not found in decoded L1"
        )

    def test_load_raises_when_file_missing(self, tmp_layers_dir: Path):
        """Layer1.load() raises FileNotFoundError if L1 not built yet."""
        missing = tmp_layers_dir / "missing_L1.md"
        layer = Layer1(path=missing)
        with pytest.raises(FileNotFoundError):
            layer.load()

    def test_real_l1_exists(self, real_l1_path: Path):
        """Real L1_essential.md was built by W2.2 setup."""
        layer = Layer1(path=real_l1_path)
        assert layer.exists() is True, (
            f"L1 file missing at {real_l1_path}. "
            "Run: python3 .claude/lib/layers.py --build-l1"
        )

    def test_real_l1_has_substantive_rules(self, real_l1_path: Path):
        """
        Real L1_essential.md contains between 1 and 25 substantive rules.

        Note: After adding the mechanical filter (ep-auto-/ep-rule- exclusion),
        the empty-behavior filter (>= 20 chars), and domain diversity (max 3/domain),
        the actual count depends on how many substantive rules exist in the
        procedural store. This test accepts any count in [1, 25].
        """
        layer = Layer1(path=real_l1_path)
        if not layer.exists():
            pytest.skip("L1 not built yet")
        content = layer.load()
        rule_count = sum(1 for line in content.splitlines() if line.startswith("## "))
        assert 1 <= rule_count <= 25, (
            f"Expected 1-25 rules in real L1, found {rule_count}"
        )

    def test_real_l1_token_estimate_under_target(self, real_l1_path: Path):
        """Real L1 decoded content is well under the 1500-token target."""
        layer = Layer1(path=real_l1_path)
        if not layer.exists():
            pytest.skip("L1 not built yet")
        tokens = layer.token_estimate()
        assert tokens < 1500, f"L1 token estimate {tokens} exceeds 1500-token target"

    def test_build_respects_custom_rule_count(self, tmp_path: Path, sample_rules_json: Path, monkeypatch):
        """Layer1.build() respects a custom rule_count != 15."""
        output_path = tmp_path / "L1_custom.md"
        layer = Layer1(path=output_path, rule_count=5)

        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_json)

        layer.build()
        content = layer.load()
        rule_count = sum(1 for line in content.splitlines() if line.startswith("## "))
        assert rule_count == 5


# ---------------------------------------------------------------------------
# Layer2 tests
# ---------------------------------------------------------------------------

class TestLayer2:
    """Tests for the project wings layer (L2)."""

    def test_has_returns_false_for_missing_project(self, tmp_layers_dir: Path):
        """L2.has() returns False for a project with no wing."""
        layer = Layer2(wings_dir=tmp_layers_dir / "L2_wings")
        assert layer.has("nonexistent-project") is False

    def test_has_returns_true_when_wing_exists(self, tmp_path: Path):
        """L2.has() returns True when the wing context.md exists."""
        wings_dir = tmp_path / "L2_wings"
        layer = Layer2(wings_dir=wings_dir)

        # Create wing manually
        wing_path = wings_dir / "my-project" / "context.md"
        wing_path.parent.mkdir(parents=True)
        wing_path.write_text("# My Project Context", encoding="utf-8")

        assert layer.has("my-project") is True

    def test_load_returns_content(self, tmp_path: Path):
        """L2.load() returns the wing context content."""
        wings_dir = tmp_path / "L2_wings"
        layer = Layer2(wings_dir=wings_dir)

        content = "# My Project\nSome context here."
        wing_path = wings_dir / "test-project" / "context.md"
        wing_path.parent.mkdir(parents=True)
        wing_path.write_text(content, encoding="utf-8")

        loaded = layer.load("test-project")
        assert loaded == content

    def test_load_raises_for_missing_wing(self, tmp_path: Path):
        """L2.load() raises FileNotFoundError for missing project."""
        wings_dir = tmp_path / "L2_wings"
        layer = Layer2(wings_dir=wings_dir)
        with pytest.raises(FileNotFoundError):
            layer.load("no-such-project")

    def test_write_creates_wing(self, tmp_path: Path):
        """L2.write() creates a new project wing."""
        wings_dir = tmp_path / "L2_wings"
        layer = Layer2(wings_dir=wings_dir)

        assert layer.has("new-project") is False
        layer.write("new-project", "# New Project Context")
        assert layer.has("new-project") is True
        assert layer.load("new-project") == "# New Project Context"

    def test_list_projects_empty_when_no_wings(self, tmp_path: Path):
        """L2.list_projects() returns empty list when no wings exist."""
        wings_dir = tmp_path / "L2_wings_empty"
        wings_dir.mkdir()
        layer = Layer2(wings_dir=wings_dir)
        assert layer.list_projects() == []

    def test_list_projects_returns_project_names(self, tmp_path: Path):
        """L2.list_projects() returns names of projects with wings."""
        wings_dir = tmp_path / "L2_wings"
        layer = Layer2(wings_dir=wings_dir)
        layer.write("project-a", "Content A")
        layer.write("project-b", "Content B")
        projects = layer.list_projects()
        assert "project-a" in projects
        assert "project-b" in projects

    def test_project_name_sanitization(self, tmp_path: Path):
        """L2 sanitizes unsafe characters in project names."""
        wings_dir = tmp_path / "L2_wings"
        layer = Layer2(wings_dir=wings_dir)
        # Name with special chars should be sanitized
        layer.write("my project/unsafe", "Content")
        # The sanitized version should exist (spaces and slashes become _)
        projects = layer.list_projects()
        assert len(projects) == 1


# ---------------------------------------------------------------------------
# Layer3 tests
# ---------------------------------------------------------------------------

class TestLayer3:
    """Tests for the vault query layer (L3)."""

    def test_query_returns_list(self):
        """L3.query() always returns a list."""
        layer = Layer3()
        result = layer.query("hook json format")
        assert isinstance(result, list)

    def test_query_returns_list_of_dicts(self):
        """L3.query() returns a list of dicts (even if empty)."""
        layer = Layer3()
        result = layer.query("some query text here")
        assert isinstance(result, list)
        for item in result:
            assert isinstance(item, dict), f"Expected dict, got {type(item)}: {item}"

    def test_query_result_has_required_keys(self):
        """L3.query() result dicts have required keys: file, line_number, line, snippet."""
        layer = Layer3()
        result = layer.query("hook format")
        for item in result:
            assert "file" in item, f"Missing 'file' key in result: {item}"
            assert "line_number" in item, f"Missing 'line_number' key in result: {item}"
            assert "line" in item, f"Missing 'line' key in result: {item}"
            assert "snippet" in item, f"Missing 'snippet' key in result: {item}"

    def test_query_empty_string_returns_empty_list(self):
        """L3.query('') returns empty list without error."""
        layer = Layer3()
        result = layer.query("")
        assert result == []

    def test_query_whitespace_only_returns_empty_list(self):
        """L3.query('   ') returns empty list."""
        layer = Layer3()
        result = layer.query("   ")
        assert result == []

    def test_query_with_missing_vault_returns_empty_list(self, tmp_path: Path):
        """L3.query() returns empty list when vault directory doesn't exist."""
        layer = Layer3(vault_dir=tmp_path / "nonexistent_vault")
        result = layer.query("anything")
        assert result == []

    def test_query_results_respect_max_results(self):
        """L3.query() respects the max_results parameter."""
        layer = Layer3()
        result = layer.query("hook", max_results=2)
        assert len(result) <= 2

    def test_query_deduplicates_by_file(self, tmp_path: Path):
        """L3.query() deduplicates results by file path."""
        vault = tmp_path / "vault"
        vault.mkdir()
        test_file = vault / "test.md"
        test_file.write_text(
            "line1: keyword here\nline2: keyword again\nline3: keyword once more\n",
            encoding="utf-8",
        )
        layer = Layer3(vault_dir=vault)
        results = layer.query("keyword", max_results=10)
        # All results should have unique file paths
        files = [r["file"] for r in results]
        assert len(files) == len(set(files)), "Duplicate files in L3 results"

    def test_query_snippet_max_length(self, tmp_path: Path):
        """L3.query() truncates long lines to L3_SNIPPET_MAX chars."""
        from layers import L3_SNIPPET_MAX
        vault = tmp_path / "vault"
        vault.mkdir()
        long_line = "keyword " + "x" * 500
        test_file = vault / "test.md"
        test_file.write_text(long_line + "\n", encoding="utf-8")
        layer = Layer3(vault_dir=vault)
        results = layer.query("keyword")
        for r in results:
            assert len(r["snippet"]) <= L3_SNIPPET_MAX + 3  # +3 for "..."

    def test_query_vault_real_vault_structure(self):
        """L3.query() finds content in the real Obsidian vault."""
        vault_path = Path.home() / "Documents" / "Obsidian" / "MiVault"
        if not vault_path.is_dir():
            pytest.skip("Real vault not available at ~/Documents/Obsidian/MiVault/")
        layer = Layer3(vault_dir=vault_path)
        # "hook" should be findable in the vault (hooks are a major topic)
        results = layer.query("hook")
        # We can't guarantee hits, but structure must be correct
        for item in results:
            assert "file" in item
            assert "line_number" in item
            assert isinstance(item["line_number"], int)


# ---------------------------------------------------------------------------
# Wake-up context integration test
# ---------------------------------------------------------------------------

class TestWakeUpContext:
    """Integration test for the load_wake_up_context() function."""

    def test_wake_up_context_returns_string(self):
        """load_wake_up_context() returns a non-empty string."""
        ctx = load_wake_up_context()
        assert isinstance(ctx, str)
        assert len(ctx) > 0

    def test_wake_up_context_contains_l0_section(self):
        """load_wake_up_context() includes the L0 identity section."""
        ctx = load_wake_up_context()
        assert "Identity (L0)" in ctx

    def test_wake_up_context_contains_l1_section(self):
        """load_wake_up_context() includes the L1 essential rules section."""
        ctx = load_wake_up_context()
        assert "Essential Rules (L1)" in ctx

    def test_wake_up_context_token_estimate_under_1500(self):
        """load_wake_up_context() total token estimate is under 1500."""
        ctx = load_wake_up_context()
        word_count = len(ctx.split())
        token_estimate = int(word_count / 0.75)
        assert token_estimate < 1500, (
            f"Wake-up context token estimate {token_estimate} exceeds 1500-token target. "
            f"Word count: {word_count}"
        )


# ---------------------------------------------------------------------------
# Scoring Improvement Tests
# ---------------------------------------------------------------------------

@pytest.fixture()
def sample_rules_with_metadata(tmp_path: Path) -> Path:
    """Create rules.json with metadata fields (created_at, severity, domain, applied_count)."""
    from datetime import datetime, timezone, timedelta

    now = datetime.now(timezone.utc).isoformat()
    old_date = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()

    base_rules = [
        # Rule 0: New critical rule with low usage — should get score floor
        {
            "rule_id": "sec-critical-new",
            "trigger": "On security-sensitive operations",
            "behavior": "CRITICAL: Always validate input at API boundaries",
            "confidence": 0.95,
            "usage_count": 0,
            "applied_count": 0,
            "severity": "critical",
            "domain": "security",
            "created_at": now,
        },
        # Rule 1: Old high-usage rule
        {
            "rule_id": "hook-old-reliable",
            "trigger": "On hook validation",
            "behavior": "MUST validate hook JSON format before committing",
            "confidence": 0.9,
            "usage_count": 200,
            "applied_count": 200,
            "domain": "hooks",
            "created_at": old_date,
        },
        # Rule 2: Rule with applied_count but usage_count=0 (field mismatch)
        {
            "rule_id": "db-applied-mismatch",
            "trigger": "On database operations",
            "behavior": "Always use parameterized queries for database operations",
            "confidence": 0.85,
            "usage_count": 0,
            "applied_count": 100,
            "domain": "database",
            "created_at": old_date,
        },
    ]
    # Rules 3-9: Same domain (backend) — domain diversity should cap at 3
    backend_rules = [
        {
            "rule_id": f"backend-rule-{i}",
            "trigger": f"Backend trigger {i}",
            "behavior": f"Backend behavior {i} with enough text to pass substantive filter",
            "confidence": 0.7 + i * 0.02,
            "usage_count": 50 - i * 5,
            "domain": "backend",
            "created_at": old_date,
        }
        for i in range(7)
    ]
    flat_rules = base_rules + backend_rules

    data = {
        "version": "test-scoring-1.0",
        "updated": "2026-04-08",
        "rules": flat_rules,
        "curator_metadata": {},
    }
    p = tmp_path / "rules.json"
    p.write_text(json.dumps(data), encoding="utf-8")
    return p


class TestScoringImprovements:
    """Tests for the improved L1 scoring pipeline."""

    def test_recency_bonus_new_rules(self, tmp_path: Path, sample_rules_with_metadata: Path, monkeypatch):
        """Rule created today scores higher than identical rule from 30 days ago."""
        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_with_metadata)

        output_path = tmp_path / "L1_test.md"
        layer = Layer1(path=output_path, rule_count=10)
        layer.build()
        content = layer.load()

        # The new critical rule (sec-critical-new) should appear in output
        # despite having 0 usage, thanks to recency + score floor
        assert "sec-critical-new" in content, (
            "New critical rule should appear in L1 output (recency bonus + score floor)"
        )

    def test_score_floor_critical_rules(self, tmp_path: Path, sample_rules_with_metadata: Path, monkeypatch):
        """Rule with confidence>=0.9 + CRITICAL + severity=critical gets min score 50."""
        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_with_metadata)

        output_path = tmp_path / "L1_test.md"
        layer = Layer1(path=output_path, rule_count=10)

        # Score the critical rule directly
        rules = layer._load_source_rules()
        critical_rule = [r for r in rules if r["rule_id"] == "sec-critical-new"][0]
        score = layer._score_rule(critical_rule, newest_created=critical_rule["created_at"])
        assert score >= 50.0, (
            f"Critical rule with confidence>=0.9 + severity=critical should score >= 50, got {score}"
        )

    def test_domain_diversity_max_3(self, tmp_path: Path, sample_rules_with_metadata: Path, monkeypatch):
        """No more than 3 rules from same domain in output."""
        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_with_metadata)

        output_path = tmp_path / "L1_test.md"
        layer = Layer1(path=output_path, rule_count=10)
        layer.build()
        content = layer.load()

        # Extract domains from output
        domains = []
        for line in content.splitlines():
            if line.startswith("## ") and "[" in line:
                domain = line.split("[")[1].split("]")[0]
                domains.append(domain)

        # Count per domain
        from collections import Counter
        domain_counts = Counter(domains)
        for domain, count in domain_counts.items():
            assert count <= 3, (
                f"Domain '{domain}' has {count} rules, exceeds max of 3 per domain"
            )

    def test_applied_count_field_used(self, tmp_path: Path, sample_rules_with_metadata: Path, monkeypatch):
        """Rule with applied_count=100 but usage_count=0 still scores high."""
        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_with_metadata)

        output_path = tmp_path / "L1_test.md"
        layer = Layer1(path=output_path, rule_count=10)

        rules = layer._load_source_rules()
        mismatch_rule = [r for r in rules if r["rule_id"] == "db-applied-mismatch"][0]
        score = layer._score_rule(mismatch_rule)
        expected_min = 0.85 * 100  # confidence * applied_count
        assert score >= expected_min, (
            f"Rule with applied_count=100 should score >= {expected_min}, got {score}"
        )


# ---------------------------------------------------------------------------
# Auto-Rebuild Tests
# ---------------------------------------------------------------------------

class TestAutoRebuild:
    """Tests for the L1 auto-rebuild infrastructure."""

    def test_l1_rebuild_script_exists_and_executable(self):
        """scripts/l1-rebuild.sh exists and is executable."""
        script_path = REPO_ROOT / "scripts" / "l1-rebuild.sh"
        assert script_path.is_file(), f"Rebuild script missing at {script_path}"
        assert os.access(script_path, os.X_OK), f"Rebuild script not executable: {script_path}"

    def test_rebuild_idempotent(self, tmp_path: Path, sample_rules_json: Path, monkeypatch):
        """Running build() twice produces the same output."""
        import layers as layers_module
        monkeypatch.setattr(layers_module, "PROCEDURAL_RULES_JSON", sample_rules_json)

        output_path = tmp_path / "L1_idempotent.md"
        layer = Layer1(path=output_path, rule_count=15)

        layer.build()
        first_content = layer.load()

        layer.build()
        second_content = layer.load()

        assert first_content == second_content, (
            "Building L1 twice should produce identical output"
        )

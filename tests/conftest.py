"""
pytest configuration and fixtures for Multi-Agent Ralph Loop tests.
"""

import os
import sys
import tempfile
import shutil
import pytest

# Add project root to path
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)


@pytest.fixture(scope="session")
def project_root():
    """Return the project root directory."""
    return PROJECT_ROOT


@pytest.fixture(scope="session")
def hooks_dir(project_root):
    """Return the hooks directory path."""
    return os.path.join(project_root, ".claude", "hooks")


@pytest.fixture(scope="session")
def scripts_dir(project_root):
    """Return the scripts directory path."""
    return os.path.join(project_root, "scripts")


@pytest.fixture
def temp_dir():
    """Create a temporary directory for test files."""
    tmpdir = tempfile.mkdtemp(prefix="ralph_test_")
    yield tmpdir
    shutil.rmtree(tmpdir, ignore_errors=True)


@pytest.fixture
def mock_env():
    """Fixture to temporarily modify environment variables."""
    original_env = os.environ.copy()

    def _set_env(**kwargs):
        for key, value in kwargs.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value

    yield _set_env

    # Restore original environment
    os.environ.clear()
    os.environ.update(original_env)


@pytest.fixture
def git_safety_guard_module(hooks_dir):
    """Import and return the git-safety-guard module."""
    import importlib.util

    module_path = os.path.join(hooks_dir, "git-safety-guard.py")
    if not os.path.exists(module_path):
        pytest.skip(f"git-safety-guard.py not found at {module_path}")

    spec = importlib.util.spec_from_file_location("git_safety_guard", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Custom markers
def pytest_configure(config):
    """Configure custom pytest markers."""
    config.addinivalue_line("markers", "security: mark test as a security test")
    config.addinivalue_line("markers", "integration: mark test as an integration test")
    config.addinivalue_line("markers", "slow: mark test as slow running")


# Collection modifiers
def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers based on test names."""
    for item in items:
        # Add security marker to security-related tests
        if "security" in item.nodeid.lower() or "inject" in item.nodeid.lower():
            item.add_marker(pytest.mark.security)

        # Add integration marker to integration tests
        if "integration" in item.nodeid.lower():
            item.add_marker(pytest.mark.integration)


# ============================================================
# Multi-Agent Ralph v2.40 Fixtures
# ============================================================

@pytest.fixture(scope="session")
def home_dir():
    """Return user's home directory."""
    return os.path.expanduser("~")


@pytest.fixture(scope="session")
def claude_global_dir(home_dir):
    """Return Claude Code global configuration directory."""
    return os.path.join(home_dir, ".claude")


@pytest.fixture(scope="session")
def opencode_dir(home_dir):
    """Return OpenCode configuration directory."""
    return os.path.join(home_dir, ".config", "opencode")


@pytest.fixture(scope="session")
def ralph_data_dir(home_dir):
    """Return Ralph data directory."""
    return os.path.join(home_dir, ".ralph")


@pytest.fixture(scope="session")
def global_skills_dir(claude_global_dir):
    """Return global skills directory."""
    return os.path.join(claude_global_dir, "skills")


@pytest.fixture(scope="session")
def global_agents_dir(claude_global_dir):
    """Return global agents directory."""
    return os.path.join(claude_global_dir, "agents")


@pytest.fixture(scope="session")
def global_hooks_dir(claude_global_dir):
    """Return global hooks directory."""
    return os.path.join(claude_global_dir, "hooks")


@pytest.fixture(scope="session")
def global_commands_dir(claude_global_dir):
    """Return global commands directory."""
    return os.path.join(claude_global_dir, "commands")


@pytest.fixture(scope="session")
def settings_json_path(claude_global_dir):
    """Return path to global settings.json."""
    return os.path.join(claude_global_dir, "settings.json")


@pytest.fixture(scope="session")
def github_projects_dir(home_dir):
    """Return GitHub projects directory."""
    return os.path.join(home_dir, "Documents", "GitHub")


@pytest.fixture
def critical_skills():
    """List of critical skills that must exist for v2.40."""
    return [
        "orchestrator",
        "clarify",
        "gates",
        "adversarial",
        "ultrathink",
        "retrospective",
        "loop",
        "parallel",
    ]


@pytest.fixture
def critical_hooks():
    """List of critical hooks that must exist for v2.40+.

    v2.69.0: Updated quality-gates.sh → quality-gates-v2.sh (renamed in v2.46).
    """
    return [
        "session-start-ledger.sh",
        "session-start-tldr.sh",
        "pre-compact-handoff.sh",
        "quality-gates-v2.sh",  # v2.46+: renamed from quality-gates.sh
        "git-safety-guard.py",
        "auto-sync-global.sh",
    ]


@pytest.fixture
def tldr_available():
    """Check if llm-tldr is installed and available."""
    return shutil.which("tldr") is not None


@pytest.fixture
def load_settings_json(settings_json_path):
    """Load and return settings.json content."""
    import json

    def _load():
        if os.path.exists(settings_json_path):
            with open(settings_json_path) as f:
                return json.load(f)
        return {}
    return _load


@pytest.fixture
def validate_skill_frontmatter():
    """Validator for skill frontmatter."""
    import yaml

    def _validate(skill_path: str) -> dict:
        """Validate skill frontmatter and return parsed content."""
        result = {
            "valid": False,
            "has_frontmatter": False,
            "frontmatter": {},
            "errors": []
        }

        if not os.path.exists(skill_path):
            result["errors"].append(f"File not found: {skill_path}")
            return result

        with open(skill_path) as f:
            content = f.read()

        # Check for frontmatter
        if not content.startswith("---"):
            result["errors"].append("No frontmatter found (must start with ---)")
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

            # Validate required fields
            if "description" not in result["frontmatter"]:
                result["errors"].append("Missing 'description' in frontmatter")

            result["valid"] = len(result["errors"]) == 0

        except yaml.YAMLError as e:
            result["errors"].append(f"YAML parse error: {e}")

        return result

    return _validate

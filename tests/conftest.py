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

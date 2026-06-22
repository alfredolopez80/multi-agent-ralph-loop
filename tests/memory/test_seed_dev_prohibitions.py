"""Pytest wrapper so the seeder's fail-loud contract test runs under
`pytest tests/` in CI.

The substantive assertions live in the sibling bash script
``test-seed-dev-prohibitions.sh`` (it drives the bash seeder). Pytest only
collects ``test_*.py`` files, so without this wrapper the contract test is
never executed by CI. This wrapper runs it and fails loudly if any contract
is violated.
"""
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_TEST = REPO_ROOT / "tests" / "memory" / "test-seed-dev-prohibitions.sh"


def test_seed_dev_prohibitions_contract():
    """Run the bash contract test; a non-zero exit (any broken contract) fails here."""
    assert CONTRACT_TEST.is_file(), f"contract test missing: {CONTRACT_TEST}"
    result = subprocess.run(
        ["bash", str(CONTRACT_TEST)],
        capture_output=True,
        text=True,
        cwd=str(REPO_ROOT),
    )
    assert result.returncode == 0, (
        f"seeder contract test failed (exit {result.returncode}):\n"
        f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )

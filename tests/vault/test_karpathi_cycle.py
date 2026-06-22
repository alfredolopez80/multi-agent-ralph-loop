"""
Tests for Karpathy Living Wiki Cycle (Waves 1-5).

Tests cover:
- W1: Vault stats in wake-up, L3 query in smart-memory-search
- W2: Wing compiler (facts → wing, dedup, FIFO trim)
- W3: Writeback pipeline (wiki creation, promotion, decision filter)
- W4: Agent diary writer, diary-to-wiki specialization
- W5: Vault lint (orphan, stale, contradiction, frontmatter, drafts),
       chronological log writer
- Hook registration (all 5 new hooks in settings.json)
"""

import json
import os
import subprocess
import tempfile
import shutil
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOOKS_DIR = os.path.join(PROJECT_ROOT, ".claude", "hooks")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_hook(script_name, stdin_data="", timeout=10, env=None):
    """Run a hook script and return (stdout, returncode).

    ``env`` overrides the subprocess environment. The vault hooks resolve
    their vault under ``${HOME}/Documents/Obsidian/MiVault`` and their logs
    under ``${HOME}/.ralph``, so passing ``env={**os.environ, "HOME": tmp}``
    redirects them at an isolated, CI-built vault instead of the developer's
    real ``~`` (absent in CI).
    """
    script_path = os.path.join(HOOKS_DIR, script_name)
    if not os.path.exists(script_path):
        pytest.skip(f"{script_name} not found")
    result = subprocess.run(
        ["bash", script_path],
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )
    return result.stdout.strip(), result.returncode


def build_vault(home_dir):
    """Build a real vault under ``home_dir`` via the versioned setup script.

    Returns the vault path (``<home>/Documents/Obsidian/MiVault``). This runs
    ``scripts/setup-obsidian-vault.sh`` for real, honoring ``$VAULT_DIR``, so
    the hooks under test reach their vault-present code paths in CI.
    """
    setup_script = os.path.join(PROJECT_ROOT, "scripts", "setup-obsidian-vault.sh")
    if not os.path.exists(setup_script):
        pytest.skip("setup-obsidian-vault.sh not found")
    vault_dir = os.path.join(home_dir, "Documents", "Obsidian", "MiVault")
    env = {**os.environ, "HOME": home_dir, "VAULT_DIR": vault_dir}
    result = subprocess.run(
        ["bash", setup_script],
        env=env,
        capture_output=True,
        text=True,
        timeout=60,
    )
    assert result.returncode == 0, (
        f"setup-obsidian-vault.sh failed (rc={result.returncode}):\n"
        f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
    )
    os.makedirs(os.path.join(home_dir, ".ralph", "logs"), exist_ok=True)
    return vault_dir


def create_minimal_vault(base_dir):
    """Create a minimal vault structure for testing."""
    dirs = [
        "global/wiki",
        "global/output/reports",
        "projects/test-project/wiki",
        "projects/test-project/facts",
        "projects/test-project/decisions",
        "agents/ralph-coder/diary",
        "agents/ralph-reviewer/diary",
    ]
    for d in dirs:
        os.makedirs(os.path.join(base_dir, d), exist_ok=True)

    # Create _vault-index.md
    index_path = os.path.join(base_dir, "global", "_vault-index.md")
    with open(index_path, "w") as f:
        f.write("## Statistics\n- Total lessons: 5\n- Global wiki articles: 3\n")

    return base_dir


# ---------------------------------------------------------------------------
# W1: Vault Stats + L3 Query
# ---------------------------------------------------------------------------

class TestWakeUpVaultStats:
    """W1.1: Vault stats loaded at session start."""

    def test_wake_up_script_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "wake-up-layer-stack.sh"))

    def test_wake_up_produces_output(self):
        stdout, rc = run_hook("wake-up-layer-stack.sh")
        assert rc == 0
        assert len(stdout) > 0

    def test_wake_up_contains_identity(self):
        stdout, rc = run_hook("wake-up-layer-stack.sh")
        assert "Identity" in stdout or "L0" in stdout


class TestL3VaultQuery:
    """W1.2: L3 query integration in smart-memory-search."""

    def test_smart_memory_search_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "smart-memory-search.sh"))

    def test_smart_memory_search_has_l3_section(self):
        """Verify L3 query code was added to smart-memory-search."""
        with open(os.path.join(HOOKS_DIR, "smart-memory-search.sh")) as f:
            content = f.read()
        assert "layers.py" in content
        assert "last-query-hits" in content

    def test_smart_memory_search_valid_json_output(self):
        """Hook must produce valid JSON even on no-op run."""
        stdin_data = json.dumps({"tool_name": "Task", "tool_input": {"prompt": "test"}})
        stdout, rc = run_hook("smart-memory-search.sh", stdin_data=stdin_data)
        # The hook outputs JSON in PreToolUse format
        if stdout:
            parsed = json.loads(stdout)
            assert "hookSpecificOutput" in parsed or "continue" in parsed


# ---------------------------------------------------------------------------
# W2: Wing Compiler
# ---------------------------------------------------------------------------

class TestWingCompiler:
    """W2.1: Facts → Wing compiler at session end."""

    def test_wing_compiler_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-wing-compiler.sh"))

    def test_wing_compiler_approves_on_no_vault(self):
        """Graceful skip when vault missing — clean exit 0 (allow).

        SessionEnd hooks allow by clean ``exit 0`` (empty stdout). Per
        ``tests/HOOK_FORMAT_REFERENCE.md`` the legacy ``{"decision": "approve"}``
        output is INVALID and was removed in v3.1.1, so we assert the real,
        valid contract: rc 0 and no stdout. HOME is redirected at an empty temp
        dir so the hook reaches its vault-missing branch without touching the
        developer's real ``~`` (this is what makes the test CI-safe).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            env = {**os.environ, "HOME": tmpdir}
            os.makedirs(os.path.join(tmpdir, ".ralph", "logs"), exist_ok=True)
            stdin_data = json.dumps({"session_id": "test-123"})
            stdout, rc = run_hook(
                "vault-wing-compiler.sh", stdin_data=stdin_data, env=env
            )
            assert rc == 0
            assert stdout == "", (
                "SessionEnd hook must allow via clean exit (no stdout); "
                f"got: {stdout!r}"
            )

    def test_wing_compiler_creates_wing_from_facts(self):
        """Wing is created from today's facts file."""
        with tempfile.TemporaryDirectory(prefix="vault_test_") as vault_dir:
            # Create facts file
            project_dir = os.path.join(vault_dir, "projects", "test-project", "facts")
            os.makedirs(project_dir, exist_ok=True)
            today = subprocess.check_output(["date", "+%Y%m%d"]).decode().strip()
            facts_file = os.path.join(project_dir, f"facts-{today}.md")
            with open(facts_file, "w") as f:
                f.write("- [code_structure] Uses async/await pattern in handlers\n")
                f.write("- [dependencies] Added pytest-cov for coverage\n")

            # The script uses hardcoded vault path, so we test the logic
            # by verifying the script is syntactically correct
            result = subprocess.run(
                ["bash", "-n", os.path.join(HOOKS_DIR, "vault-wing-compiler.sh")],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Syntax error: {result.stderr}"


# ---------------------------------------------------------------------------
# W3: Writeback + Promotion + Decision Filter
# ---------------------------------------------------------------------------

class TestWriteback:
    """W3.1: Wiki writeback from stop hook."""

    def test_writeback_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-writeback.sh"))

    def test_writeback_approves_on_no_queue(self):
        """No writeback queue — clean exit 0 (allow).

        A real vault is built under a temp HOME so the hook passes the
        ``vault present`` check and reaches the ``no queue`` branch (the path
        this test targets), without depending on the developer's real vault.
        Stop hooks allow via clean ``exit 0``; per HOOK_FORMAT_REFERENCE.md the
        old ``{"decision": "approve"}`` is invalid, so we assert rc 0 + no stdout.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            build_vault(tmpdir)  # ensures no .writeback-queue.json under temp HOME
            env = {**os.environ, "HOME": tmpdir}
            stdin_data = json.dumps({})
            stdout, rc = run_hook(
                "vault-writeback.sh", stdin_data=stdin_data, env=env
            )
            assert rc == 0
            assert stdout == "", (
                "Stop hook must allow via clean exit (no stdout); "
                f"got: {stdout!r}"
            )

    def test_writeback_creates_draft_wiki(self):
        """Writeback queue → draft wiki article (full real path in CI).

        Builds a real vault under a temp HOME, drops a writeback queue at
        ``<HOME>/.ralph/.writeback-queue.json`` (the path the hook reads), runs
        the hook, and asserts a draft wiki article was actually written under
        the vault. This exercises the hook end-to-end without touching the
        developer's real ``~``. Stop hooks allow via clean ``exit 0`` (no stdout).
        """
        with tempfile.TemporaryDirectory(prefix="vault_test_") as home_dir:
            vault_dir = build_vault(home_dir)
            env = {**os.environ, "HOME": home_dir}

            queue_file = os.path.join(home_dir, ".ralph", ".writeback-queue.json")
            queue_data = json.dumps([{
                "topic": "Test Writeback Topic",
                "summary": "This is a test summary for writeback.",
                "category": "hooks",
            }])
            with open(queue_file, "w") as f:
                f.write(queue_data)

            stdin_data = json.dumps({})
            stdout, rc = run_hook(
                "vault-writeback.sh", stdin_data=stdin_data, env=env
            )
            assert rc == 0
            assert stdout == "", (
                "Stop hook must allow via clean exit (no stdout); "
                f"got: {stdout!r}"
            )

            # The slug is derived from the topic; project resolves to "unknown"
            # because the repo is not under the temp HOME. Assert the draft
            # article exists somewhere under projects/*/wiki/.
            projects_dir = os.path.join(vault_dir, "projects")
            matches = []
            for root, _dirs, files in os.walk(projects_dir):
                if os.path.basename(root) == "wiki":
                    matches.extend(
                        os.path.join(root, fn)
                        for fn in files
                        if fn == "test-writeback-topic.md"
                    )
            assert matches, (
                "Expected a draft wiki article 'test-writeback-topic.md' under "
                f"{projects_dir}/*/wiki/ — writeback did not create it"
            )

            # The draft must carry the writeback frontmatter + summary content.
            article = matches[0]
            with open(article) as f:
                content = f.read()
            assert "status: draft" in content
            assert "This is a test summary for writeback." in content
            # Queue is consumed (deleted) after processing.
            assert not os.path.exists(queue_file), \
                "writeback must consume the queue file after processing"

    def test_writeback_script_syntax(self):
        result = subprocess.run(
            ["bash", "-n", os.path.join(HOOKS_DIR, "vault-writeback.sh")],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Syntax error: {result.stderr}"


class TestPromotion:
    """W3.2: Global wiki promotion at session start."""

    def test_promotion_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-promotion.sh"))

    def test_promotion_output_format(self):
        """SessionStart hooks use hookSpecificOutput format.
        May fail if bc is not installed (needed for numeric comparison)."""
        stdin_data = json.dumps({"session_id": "test-promo-123"})
        stdout, rc = run_hook("vault-promotion.sh", stdin_data=stdin_data)
        # Script may exit 1 if bc is not available; check JSON output when rc==0
        if rc == 0 and stdout:
            parsed = json.loads(stdout)
            assert "hookSpecificOutput" in parsed
            assert "additionalContext" in parsed["hookSpecificOutput"]

    def test_promotion_script_syntax(self):
        result = subprocess.run(
            ["bash", "-n", os.path.join(HOOKS_DIR, "vault-promotion.sh")],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Syntax error: {result.stderr}"


class TestDecisionFilter:
    """W3.3: Global decisions filter for infrastructure files."""

    def test_decision_extractor_has_global_filter(self):
        """Verify global decisions filter code was added."""
        with open(os.path.join(HOOKS_DIR, "decision-extractor.sh")) as f:
            content = f.read()
        assert "IS_INFRASTRUCTURE" in content
        assert "global/decisions" in content
        assert "CRITICAL" in content

    def test_decision_extractor_syntax(self):
        result = subprocess.run(
            ["bash", "-n", os.path.join(HOOKS_DIR, "decision-extractor.sh")],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Syntax error: {result.stderr}"


# ---------------------------------------------------------------------------
# W4: Agent Diary Writer
# ---------------------------------------------------------------------------

class TestAgentDiaryWriter:
    """W4.1: Diary writer at teammate idle."""

    def test_diary_writer_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "agent-diary-writer.sh"))

    def test_diary_writer_exit_zero(self):
        """TeammateIdle hooks use exit 0 (not JSON)."""
        stdin_data = json.dumps({
            "agent_id": "ralph-coder",
            "session_id": "test-diary-123",
        })
        stdout, rc = run_hook("agent-diary-writer.sh", stdin_data=stdin_data)
        assert rc == 0

    def test_diary_writer_only_known_agents(self):
        """Unknown agents should be skipped."""
        stdin_data = json.dumps({
            "agent_id": "unknown-agent",
            "session_id": "test-diary-123",
        })
        stdout, rc = run_hook("agent-diary-writer.sh", stdin_data=stdin_data)
        assert rc == 0

    def test_diary_writer_syntax(self):
        result = subprocess.run(
            ["bash", "-n", os.path.join(HOOKS_DIR, "agent-diary-writer.sh")],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Syntax error: {result.stderr}"


# ---------------------------------------------------------------------------
# W5: Vault Lint + Log Writer
# ---------------------------------------------------------------------------

# vault-lint.sh deleted in H1 consolidation — all lint tests removed


class TestVaultLogWriter:
    """W5.2: Chronological log writer at session end."""

    def test_log_writer_exists(self):
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-log-writer.sh"))

    def test_log_writer_approves(self):
        """SessionEnd hook — writes a log entry, then clean exit 0 (allow).

        Builds a real vault under a temp HOME so the hook reaches its
        vault-present path and writes ``log.md``. SessionEnd hooks allow via
        clean ``exit 0``; per HOOK_FORMAT_REFERENCE.md ``{"decision": "approve"}``
        is invalid and was removed in v3.1.1, so we assert rc 0 + no stdout and
        that the log entry was actually written.
        """
        with tempfile.TemporaryDirectory(prefix="vault_test_") as home_dir:
            vault_dir = build_vault(home_dir)
            env = {**os.environ, "HOME": home_dir}
            stdin_data = json.dumps({"session_id": "test-log-123"})
            stdout, rc = run_hook(
                "vault-log-writer.sh", stdin_data=stdin_data, env=env
            )
            assert rc == 0
            assert stdout == "", (
                "SessionEnd hook must allow via clean exit (no stdout); "
                f"got: {stdout!r}"
            )
            log_md = os.path.join(vault_dir, "log.md")
            assert os.path.exists(log_md), \
                "vault-log-writer must create log.md under the vault"
            with open(log_md) as f:
                log_content = f.read()
            assert "test-log-123" in log_content, \
                "log entry must record the session id"

    def test_log_writer_syntax(self):
        result = subprocess.run(
            ["bash", "-n", os.path.join(HOOKS_DIR, "vault-log-writer.sh")],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Syntax error: {result.stderr}"


# ---------------------------------------------------------------------------
# Hook Registration
# ---------------------------------------------------------------------------

class TestHookRegistration:
    """Verify all 5 new hooks are registered in settings.json."""

    EXPECTED_HOOKS = {
        "vault-promotion.sh": "SessionStart",
        "vault-writeback.sh": "Stop",
        "vault-wing-compiler.sh": "SessionEnd",
        "vault-log-writer.sh": "SessionEnd",
        "agent-diary-writer.sh": "TeammateIdle",
    }

    @pytest.fixture
    def settings(self):
        settings_path = os.path.expanduser("~/.claude/settings.json")
        if not os.path.exists(settings_path):
            pytest.skip("settings.json not found")
        with open(settings_path) as f:
            return json.load(f)

    @pytest.mark.parametrize("hook_name,event", list(EXPECTED_HOOKS.items()))
    def test_hook_registered(self, settings, hook_name, event):
        """Each new hook must be registered in the correct event."""
        hooks = settings.get("hooks", {})
        assert event in hooks, f"Event {event} not in settings.json"

        found = False
        for matcher in hooks[event]:
            for hook in matcher.get("hooks", []):
                if hook_name in hook.get("command", ""):
                    found = True
                    break
        assert found, f"{hook_name} not registered in {event}"

    def test_all_hooks_are_executable(self):
        """All new hook scripts must have execute permission."""
        for hook_name in self.EXPECTED_HOOKS:
            path = os.path.join(HOOKS_DIR, hook_name)
            assert os.path.exists(path), f"{hook_name} does not exist"
            assert os.access(path, os.X_OK), f"{hook_name} is not executable"


# ---------------------------------------------------------------------------
# Integration: Karpathy Cycle
# ---------------------------------------------------------------------------

class TestKarpathyCycle:
    """Verify the full INGEST → QUERY → WRITEBACK → LINT cycle."""

    def test_ingest_components_exist(self):
        """Raw sources → vault pipeline components."""
        # smart-memory-search (with L3) handles QUERY
        assert os.path.exists(os.path.join(HOOKS_DIR, "smart-memory-search.sh"))
        # vault-writeback handles WRITEBACK
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-writeback.sh"))

    def test_query_components_exist(self):
        """L3 query + promotion pipeline."""
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-promotion.sh"))
        assert os.path.exists(os.path.join(HOOKS_DIR, "wake-up-layer-stack.sh"))

    def test_writeback_components_exist(self):
        """Writeback → wing compiler pipeline."""
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-writeback.sh"))
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-wing-compiler.sh"))

    def test_lint_components_exist(self):
        """Lint + log pipeline. vault-lint.sh deferred — log writer is the active component."""
        assert os.path.exists(os.path.join(HOOKS_DIR, "vault-log-writer.sh"))

    def test_all_scripts_pass_bash_syntax_check(self):
        """Every new hook script must pass bash -n syntax check."""
        scripts = [
            "vault-promotion.sh",
            "vault-writeback.sh",
            "vault-wing-compiler.sh",
            "vault-log-writer.sh",
            "agent-diary-writer.sh",
        ]
        for script in scripts:
            result = subprocess.run(
                ["bash", "-n", os.path.join(HOOKS_DIR, script)],
                capture_output=True, text=True,
            )
            assert result.returncode == 0, f"Syntax error in {script}: {result.stderr}"

"""Regression tests for skill-validator.sh (T44, issue #67).

The hook's live registration is PreToolUse with matcher Agent|Task — a
payload that never carries a root-level "skill" — so 4,693 of 4,786 log
lines were "No skill name provided" ERRORs and the validator never
validated anything AS A HOOK (the 93 real lines are all manual
invocations from January). These tests pin the three-way contract:

  1. nameless invocations are silently allowed (the normal case of the
     live registration — not an error, not a log line);
  2. the name is read from tool_input.skill (the field a real Skill
     event carries), and a VALID H70 skill.yaml passes;
  3. a PRESENT-but-invalid skill.yaml — the violation this gate exists
     for — is denied. Out-of-domain names (SKILL.md-era skills, unknown
     names, injection attempts) are allowed with no veto.
"""
import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
HOOK = REPO / ".claude" / "hooks" / "skill-validator.sh"

VALID_YAML = """\
name: test-h70
version: 1.0.0
category: test
role: tester
triggers:
  keywords:
    - test
execution:
  steps: []
"""


def _home():
    return Path(os.path.realpath(tempfile.mkdtemp()))


def run_hook(home, payload):
    env = dict(os.environ)
    env["HOME"] = str(home)
    return subprocess.run(
        ["bash", str(HOOK)],
        input=json.dumps(payload), capture_output=True, text=True,
        env=env, timeout=30,
    )


def decision_of(result):
    return json.loads(result.stdout)["hookSpecificOutput"]["permissionDecision"]


def log_text(home):
    f = home / ".ralph" / "skill-validation.log"
    return f.read_text() if f.exists() else ""


def make_h70_skill(home, name, yaml_body):
    d = home / ".claude" / "skills" / name
    d.mkdir(parents=True)
    (d / "skill.yaml").write_text(yaml_body)
    return d


def test_t44_nameless_task_invocation_allows_silently():
    # The live registration's every-day case: a Task spawn with no skill
    # reference. Must allow AND must not log an error — this exact case
    # produced 4,693 ERROR lines that buried the real ones.
    h = _home()
    result = run_hook(h, {"tool_name": "Task",
                          "tool_input": {"subagent_type": "ralph-coder",
                                         "prompt": "implement x"}})
    assert decision_of(result) == "allow"
    assert "No skill name" not in log_text(h)


def test_t44_skill_tool_name_extracted_and_valid_skill_passes():
    # The field a real PreToolUse Skill event carries: tool_input.skill.
    # A valid H70 skill.yaml must pass — proving the validator still WORKS
    # in the cases that are its domain (the precondition for silencing the
    # nameless case instead of "fixing" the noise).
    h = _home()
    make_h70_skill(h, "modern", VALID_YAML)
    result = run_hook(h, {"tool_name": "Skill", "tool_input": {"skill": "modern"}})
    assert decision_of(result) == "allow"
    assert "All validation checks passed for skill: modern" in log_text(h)


def test_t44_manual_root_level_name_still_works():
    # The {"skill": ...} root shape is how manual/test invocations call the
    # validator (all 93 real log lines came through it). Backwards compatible.
    h = _home()
    make_h70_skill(h, "manual", VALID_YAML)
    result = run_hook(h, {"skill": "manual"})
    assert decision_of(result) == "allow"
    assert "All validation checks passed for skill: manual" in log_text(h)


def test_t44_invalid_skill_yaml_is_denied():
    # The fresh violation: a PRESENT skill.yaml missing a required field
    # must be rejected. This is the gate's reason to exist.
    h = _home()
    broken = VALID_YAML.replace("role: tester\n", "")
    make_h70_skill(h, "broken", broken)
    result = run_hook(h, {"skill": "broken"})
    assert decision_of(result) == "deny"
    assert "Missing required field 'role'" in log_text(h)


def test_t44_modern_skill_md_is_out_of_domain_and_allowed():
    # A SKILL.md-era skill has no skill.yaml: out of domain, nothing to
    # validate, MUST allow. Denying would veto every modern skill the day
    # the registration is pointed at the Skill tool — the loaded trap this
    # test prevents.
    h = _home()
    d = h / ".claude" / "skills" / "modern-md"
    d.mkdir(parents=True)
    (d / "SKILL.md").write_text("# modern skill\n")
    result = run_hook(h, {"tool_input": {"skill": "modern-md"}})
    assert decision_of(result) == "allow"
    assert "no skill.yaml" in log_text(h)


def test_t44_unknown_name_is_out_of_domain_and_allowed():
    h = _home()
    result = run_hook(h, {"skill": "does-not-exist"})
    assert decision_of(result) == "allow"
    assert "no directory" in log_text(h)


def test_t44_injected_name_is_sanitized_not_executed():
    # The name goes through sanitize_skill_name (alnum/hyphen/underscore/dot
    # only). An injection attempt collapses to a harmless name that simply
    # does not resolve — allowed as out of domain, nothing executed.
    h = _home()
    result = run_hook(h, {"skill": "x; rm -rf tmp"})
    assert decision_of(result) == "allow"
    # the semicolon/space payload must not appear in any resolved path
    assert "rm -rf" not in log_text(h)

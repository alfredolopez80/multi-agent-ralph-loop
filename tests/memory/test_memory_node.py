"""Tests for MemoryNode v2 schema, RED-gate, and domain inference (Phase B1)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Make scripts/memory importable.
_MEMORY_DIR = Path(__file__).resolve().parents[2] / "scripts" / "memory"
sys.path.insert(0, str(_MEMORY_DIR))

from memory_node import (  # noqa: E402
    DOMAIN_VALUES,
    MemoryNode,
    MemoryNodeValidationError,
    infer_domain,
)
from sensitive_content import contains_red_material, is_red  # noqa: E402


def _valid_payload(**overrides):
    payload = {
        "project_id": "multi-agent-ralph-loop",
        "workspace_instance_id": "ws1",
        "repo_remote_hash": "abc123",
        "branch": "main",
        "commit": "deadbeef",
        "session_id": "sess-1",
        "memory_type": "procedural_rule",
        "sensitivity": "GREEN",
        "authority": "non_authoritative",
        "summary": "Use parameterized queries for all database operations.",
        "source_description": "migrated from rules.json",
        "trigger": {"text": "writing SQL"},
        "topic_tags": ["database", "sql"],
        "quality": {"confidence": 0.9},
    }
    payload.update(overrides)
    return payload


# --- valid node passes -----------------------------------------------------

def test_valid_node_passes():
    node = MemoryNode.from_dict(_valid_payload())
    assert node.authority == "non_authoritative"
    assert node.sensitivity == "GREEN"
    assert node.node_id


def test_valid_node_round_trips_to_dict():
    node = MemoryNode.from_dict(_valid_payload())
    data = node.to_dict()
    assert data["schema_version"] == "ralph_memory_node_v2"
    assert data["domain"] in DOMAIN_VALUES


# --- RED material is rejected ----------------------------------------------

def test_red_secret_in_summary_rejected():
    payload = _valid_payload(summary="set api_key = sk-ABCDEF0123456789ABCDEF")
    with pytest.raises(MemoryNodeValidationError, match="RED"):
        MemoryNode.from_dict(payload)


def test_red_jwt_in_detailed_summary_rejected():
    jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcdEFGHijklMNOP"
    payload = _valid_payload(detailed_summary=f"token was {jwt}")
    with pytest.raises(MemoryNodeValidationError, match="RED"):
        MemoryNode.from_dict(payload)


def test_is_red_helpers():
    assert is_red("password = hunter2secret")
    assert contains_red_material("ghp_0123456789abcdef0123456789abcdefABCD")
    assert not is_red("just a normal sentence about testing")


# --- provenance required ---------------------------------------------------

def test_missing_provenance_fails():
    payload = _valid_payload()
    payload.pop("source_description")
    # no source_paths, no source_description
    with pytest.raises(MemoryNodeValidationError, match="source_paths or source_description"):
        MemoryNode.from_dict(payload)


# --- identity (session OR commit) ------------------------------------------

def test_missing_session_and_commit_fails():
    payload = _valid_payload(session_id="", commit="")
    with pytest.raises(MemoryNodeValidationError, match="session_id or commit"):
        MemoryNode.from_dict(payload)


# --- authority literal -----------------------------------------------------

def test_wrong_authority_fails():
    payload = _valid_payload(authority="authoritative")
    with pytest.raises(MemoryNodeValidationError, match="authority"):
        MemoryNode.from_dict(payload)


# --- sensitivity RED -> error ----------------------------------------------

def test_sensitivity_red_fails():
    payload = _valid_payload(sensitivity="RED")
    with pytest.raises(MemoryNodeValidationError, match="sensitivity"):
        MemoryNode.from_dict(payload)


# --- confidence bounds -----------------------------------------------------

def test_confidence_out_of_range_fails():
    payload = _valid_payload(quality={"confidence": 1.5})
    with pytest.raises(MemoryNodeValidationError, match="confidence"):
        MemoryNode.from_dict(payload)


# --- node_id safety --------------------------------------------------------

def test_unsafe_node_id_fails():
    payload = _valid_payload(node_id="../../etc/passwd")
    with pytest.raises(MemoryNodeValidationError, match="node_id"):
        MemoryNode.from_dict(payload)


# --- raw_ref sha256 --------------------------------------------------------

def test_bad_sha256_fails():
    payload = _valid_payload(raw_ref={"sha256": "nothex"})
    with pytest.raises(MemoryNodeValidationError, match="sha256"):
        MemoryNode.from_dict(payload)


def test_good_sha256_passes():
    payload = _valid_payload(raw_ref={"sha256": "a" * 64})
    node = MemoryNode.from_dict(payload)
    assert node.raw_ref is not None


# --- negative_rule + hub constraints ---------------------------------------

def test_negative_rule_requires_reason_and_evidence():
    payload = _valid_payload(memory_type="negative_rule", quality={"confidence": 0.9})
    with pytest.raises(MemoryNodeValidationError, match="negative_rule"):
        MemoryNode.from_dict(payload)


def test_hub_requires_synthetic_and_no_raw():
    payload = _valid_payload(memory_type="hub", quality={"confidence": 0.9})
    with pytest.raises(MemoryNodeValidationError, match="hub"):
        MemoryNode.from_dict(payload)


# --- domain inference (NEW improvement) ------------------------------------

@pytest.mark.parametrize(
    "text,tags,expected",
    [
        ("Use parameterized queries and EXPLAIN ANALYZE on slow SELECT", [], "database"),
        ("Run pytest and verify the test fixture coverage", ["testing"], "testing"),
        ("PostToolUse hook must return continue JSON via stdin", ["hooks"], "hooks"),
        ("Never log secrets; use bcrypt and input validation", ["security"], "security"),
        ("WCAG aria roles for the React component", ["frontend"], "frontend"),
        ("Deploy via docker and the CI pipeline", ["devops"], "devops"),
        ("Some entirely unrelated sentence about weather", [], "general"),
    ],
)
def test_infer_domain(text, tags, expected):
    assert infer_domain(text, tags) == expected


def test_domain_never_unset():
    node = MemoryNode.from_dict(_valid_payload(domain="UNSET"))
    assert node.domain in DOMAIN_VALUES
    assert node.domain != "UNSET"

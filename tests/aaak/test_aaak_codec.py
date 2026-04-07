#!/usr/bin/env python3
"""
Unit tests for the AAAK Dialect codec.

Tests cover:
  - Round-trip losslessness: encode -> decode returns exact original
  - Edge cases: empty string, whitespace-only, PUA codepoints
  - Compression ratio on 10KB sample text
  - Dialect versioning (compress/decompress paired)
  - summarize() produces lossy but readable output
  - format_zettel() builds correct pipe-delimited records
  - compression_stats() returns sane values
  - decode_structure() parses symbolic format
  - encode_entity() and encode_emotions() helpers
"""

import importlib.util
import sys
import os
from pathlib import Path
import pytest

# ---------------------------------------------------------------------------
# Import bootstrap: aaak.py lives in .claude/lib/ (no package __init__.py)
# We load it directly via importlib so the tests work from any cwd.
# ---------------------------------------------------------------------------

_LIB_DIR = Path(__file__).resolve().parent.parent.parent / ".claude" / "lib"
_AAAK_PATH = _LIB_DIR / "aaak.py"


def _load_aaak_module():
    spec = importlib.util.spec_from_file_location("aaak", str(_AAAK_PATH))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_mod = _load_aaak_module()
AAAK = _mod.AAAK
EMOTION_CODES = _mod.EMOTION_CODES
_LOSSLESS_SEPARATOR = _mod._LOSSLESS_SEPARATOR
_LOSSLESS_MARKER = _mod._LOSSLESS_MARKER


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def codec():
    return AAAK()


@pytest.fixture
def codec_with_entities():
    return AAAK(entities={"Claude": "CLD", "Alfred": "ALF", "Obsidian": "OBS"})


_SAMPLE_10KB = """
# Multi-Agent Ralph Loop Architecture Notes

## Overview

The Multi-Agent Ralph Loop is an orchestration system for AI agent teams that
coordinates multiple Claude Code instances working in parallel. The architecture
consists of a Team Lead that routes tasks to specialized subagents based on
complexity scoring and domain requirements.

## Key Design Decisions

We decided to use Obsidian as the single source of truth for memory storage
instead of SQLite because Obsidian provides human-readable markdown files that
any LLM can parse natively. This was a critical architecture decision made after
evaluating MemPalace, Zep, and custom solutions.

The AAAK dialect was chosen as the compression format for AI-readable memory.
It achieves ~20-30x compression ratio on markdown notes by using a semantic
shorthand dialect rather than binary compression. Every LLM reads it natively
because it uses familiar symbolic notation.

## Memory System Layers

### Semantic Memory
Stored in ~/.ralph/memory/semantic.json. Contains entity relationships,
topic associations, and importance weights. Updated after each session.

### Episodic Memory
Session diaries stored as AAAK-compressed files. Each session diary records
the ZID (Zettel ID), entities involved, topics, key quotes, emotional weight,
and metadata flags like DECISION, TECHNICAL, ORIGIN.

### Procedural Memory
Rules and patterns learned from repeated interactions. Stored in
.claude/rules/learned/ as markdown files. Rules with confidence >= 0.7
and usage >= 3 are promoted to active status.

## Agent Teams Configuration

The system uses six specialized subagent types:
1. ralph-coder: Implementation tasks with quality gates
2. ralph-reviewer: Code review (security, quality, consistency)
3. ralph-tester: Unit and integration testing
4. ralph-researcher: Codebase research and pattern discovery
5. ralph-frontend: Frontend development with WCAG 2.1 AA compliance
6. ralph-security: Security audits using 6 pillars methodology

All independent tasks are executed in parallel by default. Sequential
execution requires explicit justification. This is the #1 operational
priority in the system.

## Hook Architecture

87 hooks registered, 22 active, 65 dead code. The goal is to consolidate
down to a minimal set. MemPalace achieves state-of-the-art results with
only 2 hooks; our 87 represent significant technical debt.

Active hooks handle: git safety guard, repo boundary guard, secret
sanitization, quality gates on teammate idle, quality gates on task
completion, subagent context initialization, and session lifecycle
(pre-compact, post-compact, session-end).

## Quality Standards

Four pillars: CORRECTNESS (syntax valid, logic sound), QUALITY (no console.log,
no TODO/FIXME, proper types), SECURITY (no hardcoded secrets, OWASP A01-A10),
CONSISTENCY (follow project style guides).

The 3-Fix Rule: maximum 3 attempts to fix a failing quality gate before
escalating to the Team Lead.

## Compression Benchmark Target

The AAAK codec should achieve >= 20x compression ratio on rules markdown.
This is measured as character count of the symbolic summary versus the
original text. The summarize() method produces lossy but human-readable
output. The compress() method is lossless by embedding the original.

## Security Model

Threat model documented in docs/security/SECURITY_MODEL_v2.89.md.
14 vulnerabilities remediated in v2.89.1: command chaining, SHA-256
substitution, deny-list bypass, file locking race conditions.
37 automated security tests in tests/security/.

Key principle: no secrets in code, no hardcoded credentials, all user
input validated, OWASP Top 10 compliance required.

## Vault System (v3.1.0)

Three-layer memory using Obsidian vault as primary storage:
- Layer 1: .claude/rules/learned/ — auto-generated rule files
- Layer 2: ~/.ralph/ — runtime state (logs, ledgers, handoffs, plans)
- Layer 3: ~/Documents/Obsidian/MiVault/ — long-term knowledge base

The vault uses the AAAK dialect for compression of memory entries.
Zettels follow the format: ZID:ENTITIES|topic|"quote"|weight|emotions|flags

## Aristotle First Principles Methodology

Before any non-trivial task, the system applies:
1. Assumption Autopsy: identify inherited assumptions
2. Irreducible Truths: what survives when assumptions removed
3. The Aristotelian Move: single highest-leverage action

This prevents rationalization and ensures fundamental correctness.
Tasks with complexity >= 4 require all five phases of analysis.

## Parallel-First Execution Mandate

All independent tasks must use Agent Teams for parallel execution.
The anti-rationalization table (entries #38-#46) documents common
excuses for sequential execution and why they are invalid. The rule
is enforced by the parallel-first.md configuration.
""" * 2  # ~10KB when doubled


# ---------------------------------------------------------------------------
# Core round-trip tests
# ---------------------------------------------------------------------------

class TestRoundTrip:
    """Lossless compress -> decompress guarantee."""

    def test_roundtrip_short_sentence(self, codec):
        text = "We decided to use Obsidian instead of SQLite."
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_multiline(self, codec):
        text = "Line one.\nLine two.\nLine three with special chars: @#$%"
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_unicode_text(self, codec):
        text = "Spanish: café, año, niño. Japanese: 日本語。Emoji: 🚀"
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_large_sample(self, codec):
        assert codec.decompress(codec.compress(_SAMPLE_10KB)) == _SAMPLE_10KB

    def test_roundtrip_single_char(self, codec):
        assert codec.decompress(codec.compress("x")) == "x"

    def test_roundtrip_newlines_only(self, codec):
        text = "\n\n\n"
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_preserves_leading_trailing_whitespace(self, codec):
        text = "   padded text   "
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_with_pipe_characters(self, codec):
        # Pipes appear in AAAK format itself — must survive round-trip
        text = "ZID:CLD+ALF|architecture|\"key quote\"|0.9|convict|DECISION"
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_repeated_calls_stable(self, codec):
        text = "Repeated encode/decode should yield identical results every time."
        encoded1 = codec.compress(text)
        encoded2 = codec.compress(text)
        assert encoded1 == encoded2
        assert codec.decompress(encoded1) == text
        assert codec.decompress(encoded2) == text


# ---------------------------------------------------------------------------
# Empty string edge case
# ---------------------------------------------------------------------------

class TestEmptyString:
    """Empty and blank inputs must not raise."""

    def test_compress_empty(self, codec):
        result = codec.compress("")
        assert isinstance(result, str)

    def test_decompress_empty_string(self, codec):
        result = codec.decompress("")
        assert result == ""

    def test_roundtrip_empty(self, codec):
        compressed = codec.compress("")
        assert codec.decompress(compressed) == ""

    def test_summarize_empty(self, codec):
        result = codec.summarize("")
        assert isinstance(result, str)

    def test_get_compression_ratio_empty(self, codec):
        ratio = codec.get_compression_ratio("")
        assert ratio == 1.0

    def test_format_zettel_empty_entities(self, codec):
        result = codec.format_zettel(
            entities=[],
            topic="test",
            quote="quote",
            weight=0.5,
            emotions=[],
            flags=[],
        )
        assert isinstance(result, str)
        assert "|" in result


# ---------------------------------------------------------------------------
# PUA codepoint escaping
# ---------------------------------------------------------------------------

class TestPUACodepoints:
    """Text containing Private Use Area codepoints must round-trip cleanly."""

    def test_roundtrip_pua_single(self, codec):
        # U+E000 is the first PUA codepoint
        text = "Normal text \ue000 more text"
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_pua_range(self, codec):
        # Scatter several PUA codepoints through the text
        pua_chars = "".join(chr(c) for c in range(0xE000, 0xE010))
        text = f"Start {pua_chars} end"
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_pua_at_boundaries(self, codec):
        text = "\ue000start and end\uf8ff"
        assert codec.decompress(codec.compress(text)) == text

    def test_roundtrip_lossless_separator_char(self, codec):
        # The lossless separator itself (\x1f) must survive if embedded in input
        text = "before\x1fafter"
        compressed = codec.compress(text)
        recovered = codec.decompress(compressed)
        assert recovered == text


# ---------------------------------------------------------------------------
# Compression ratio tests
# ---------------------------------------------------------------------------

class TestCompressionRatio:
    """Summarize() ratio on 10KB sample should meet the >= 20x target."""

    def test_ratio_on_10kb_sample(self, codec):
        ratio = codec.get_compression_ratio(_SAMPLE_10KB)
        # The plan specifies >= 20x on rules markdown
        assert ratio >= 20.0, (
            f"Expected >= 20x compression on 10KB sample, got {ratio:.1f}x"
        )

    def test_ratio_always_positive(self, codec):
        texts = [
            "short",
            "medium length text with several words and sentences. More text here.",
            _SAMPLE_10KB,
        ]
        for t in texts:
            ratio = codec.get_compression_ratio(t)
            assert ratio > 0.0

    def test_compression_stats_keys(self, codec):
        stats = codec.compression_stats(_SAMPLE_10KB)
        required_keys = {
            "original_chars", "summary_chars", "ratio",
            "original_tokens", "summary_tokens", "token_ratio",
        }
        assert required_keys.issubset(stats.keys())

    def test_compression_stats_values_sane(self, codec):
        stats = codec.compression_stats(_SAMPLE_10KB)
        assert stats["original_chars"] > 0
        assert stats["summary_chars"] > 0
        assert stats["ratio"] > 1.0
        assert stats["original_tokens"] > stats["summary_tokens"]

    def test_token_ratio_ge_20x(self, codec):
        stats = codec.compression_stats(_SAMPLE_10KB)
        assert stats["token_ratio"] >= 20.0, (
            f"Token ratio {stats['token_ratio']:.1f}x < 20x on 10KB sample"
        )


# ---------------------------------------------------------------------------
# Dialect versioning
# ---------------------------------------------------------------------------

class TestDialectVersioning:
    """Encoding with v1 must decode cleanly with v1; API must be stable."""

    def test_compress_returns_string(self, codec):
        result = codec.compress("test text v1")
        assert isinstance(result, str)

    def test_decompress_from_compress_output(self, codec):
        text = "Versioning test: The AAAK codec v1 round-trip."
        compressed = codec.compress(text)
        assert codec.decompress(compressed) == text

    def test_decompress_raises_on_summarize_output(self, codec):
        summary = codec.summarize("Some plain text about architecture.")
        with pytest.raises(ValueError, match="losslessly decompress"):
            codec.decompress(summary)

    def test_lossless_separator_embedded_in_compress(self, codec):
        text = "Any text"
        compressed = codec.compress(text)
        assert _LOSSLESS_SEPARATOR in compressed

    def test_lossless_marker_on_empty(self, codec):
        compressed = codec.compress("")
        assert _LOSSLESS_MARKER in compressed or compressed == _LOSSLESS_MARKER


# ---------------------------------------------------------------------------
# format_zettel tests
# ---------------------------------------------------------------------------

class TestFormatZettel:
    """format_zettel() must produce the documented pipe-delimited format."""

    def test_basic_zettel_structure(self, codec_with_entities):
        result = codec_with_entities.format_zettel(
            entities=["Claude", "Alfred"],
            topic="architecture",
            quote="Obsidian as single source of truth",
            weight=0.9,
            emotions=["conviction", "trust"],
            flags=["DECISION", "TECHNICAL"],
        )
        parts = result.split("|")
        assert len(parts) >= 4
        assert "CLD" in parts[0] or "ALF" in parts[0]
        assert "architecture" in parts[1]
        assert "Obsidian" in parts[2]
        assert "0.9" in parts[3]

    def test_zettel_zid_prefix(self, codec_with_entities):
        result = codec_with_entities.format_zettel(
            entities=["Claude"],
            topic="testing",
            quote="test quote",
            weight=0.5,
            emotions=["trust"],
            flags=["TECHNICAL"],
            zid="42",
        )
        assert result.startswith("42:")

    def test_zettel_flags_normalized(self, codec):
        result = codec.format_zettel(
            entities=["TestEntity"],
            topic="test",
            quote="quote",
            weight=0.5,
            emotions=[],
            flags=["decision", "technical", "origin"],
        )
        assert "DECISION" in result
        assert "TECHNICAL" in result
        assert "ORIGIN" in result

    def test_zettel_invalid_flags_excluded(self, codec):
        result = codec.format_zettel(
            entities=["Entity"],
            topic="test",
            quote="quote",
            weight=0.5,
            emotions=[],
            flags=["INVALID_FLAG", "NOTAFLAG"],
        )
        assert "INVALID_FLAG" not in result
        assert "NOTAFLAG" not in result

    def test_zettel_emotion_codes_normalized(self, codec):
        result = codec.format_zettel(
            entities=["Entity"],
            topic="test",
            quote="quote",
            weight=0.5,
            emotions=["conviction", "trust"],
            flags=[],
        )
        assert "convict" in result
        assert "trust" in result

    def test_zettel_weight_precision(self, codec):
        result = codec.format_zettel(
            entities=["E"],
            topic="t",
            quote="q",
            weight=0.333333,
            emotions=[],
            flags=[],
        )
        assert "0.33" in result

    def test_zettel_empty_quote_omitted(self, codec):
        result = codec.format_zettel(
            entities=["E"],
            topic="t",
            quote="",
            weight=0.5,
            emotions=[],
            flags=[],
        )
        assert '""' not in result


# ---------------------------------------------------------------------------
# Entity / emotion encoding helpers
# ---------------------------------------------------------------------------

class TestHelpers:
    """encode_entity() and encode_emotions() helper correctness."""

    def test_encode_entity_from_registry(self, codec_with_entities):
        assert codec_with_entities.encode_entity("Claude") == "CLD"
        assert codec_with_entities.encode_entity("Alfred") == "ALF"

    def test_encode_entity_case_insensitive(self, codec_with_entities):
        assert codec_with_entities.encode_entity("claude") == "CLD"

    def test_encode_entity_auto_code_fallback(self, codec):
        # No registry entry -> first 3 chars uppercased
        result = codec.encode_entity("Foobar")
        assert result == "FOO"

    def test_encode_emotions_known(self, codec):
        result = codec.encode_emotions(["conviction", "trust"])
        assert "convict" in result
        assert "trust" in result

    def test_encode_emotions_deduplication(self, codec):
        result = codec.encode_emotions(["conviction", "conviction"])
        assert result.count("convict") == 1

    def test_encode_emotions_max_three(self, codec):
        result = codec.encode_emotions(["joy", "fear", "trust", "grief", "wonder"])
        codes = result.split("+")
        assert len(codes) <= 3

    def test_emotion_codes_dict_completeness(self):
        required = {"vulnerability", "joy", "fear", "trust", "grief"}
        for emotion in required:
            assert emotion in EMOTION_CODES, f"Missing emotion code: {emotion}"


# ---------------------------------------------------------------------------
# decode_structure tests
# ---------------------------------------------------------------------------

class TestDecodeStructure:
    """decode_structure() parses AAAK symbolic text into a dict."""

    def test_parses_zettel_line(self, codec):
        aaak_text = "0:CLD+ALF|architecture|\"Obsidian as truth\"|0.9|convict|DECISION"
        result = codec.decode_structure(aaak_text)
        assert "zettels" in result
        assert len(result["zettels"]) == 1

    def test_parses_arc_line(self, codec):
        aaak_text = "ARC:trust->convict->passion"
        result = codec.decode_structure(aaak_text)
        assert result["arc"] == "trust->convict->passion"

    def test_parses_tunnel_line(self, codec):
        aaak_text = "T:001<->002|relates_to"
        result = codec.decode_structure(aaak_text)
        assert len(result["tunnels"]) == 1

    def test_strips_lossless_payload(self, codec):
        text = "Some plain text about decisions."
        compressed = codec.compress(text)
        result = codec.decode_structure(compressed)
        assert isinstance(result, dict)

    def test_returns_dict_keys(self, codec):
        result = codec.decode_structure("")
        assert set(result.keys()) == {"header", "arc", "zettels", "tunnels"}


# ---------------------------------------------------------------------------
# summarize() tests
# ---------------------------------------------------------------------------

class TestSummarize:
    """summarize() produces a readable lossy summary."""

    def test_summarize_shorter_than_original(self, codec):
        text = _SAMPLE_10KB
        summary = codec.summarize(text)
        assert len(summary) < len(text)

    def test_summarize_contains_pipe_delimiters(self, codec):
        summary = codec.summarize("We decided to use Obsidian for storage.")
        assert "|" in summary

    def test_summarize_with_metadata(self, codec):
        summary = codec.summarize(
            "Architecture decision made today.",
            metadata={
                "source_file": "/vault/decisions/obs.md",
                "wing": "arch",
                "room": "decisions",
                "date": "2026-04-07",
            },
        )
        assert "arch" in summary
        assert "decisions" in summary

    def test_summarize_detects_decision_flag(self, codec):
        summary = codec.summarize("We decided to switch from SQLite to Obsidian.")
        assert "DECISION" in summary

    def test_summarize_detects_technical_flag(self, codec):
        summary = codec.summarize("The database architecture uses a new algorithm.")
        assert "TECHNICAL" in summary

    def test_summarize_not_decompressable(self, codec):
        summary = codec.summarize("Plain text that will be summarized.")
        with pytest.raises(ValueError):
            codec.decompress(summary)


# ---------------------------------------------------------------------------
# count_tokens static utility
# ---------------------------------------------------------------------------

class TestCountTokens:
    def test_count_tokens_non_zero(self):
        assert AAAK.count_tokens("hello world") >= 1

    def test_count_tokens_empty(self):
        assert AAAK.count_tokens("") >= 1  # min 1 per docstring

    def test_count_tokens_scales_with_length(self):
        short = AAAK.count_tokens("short")
        long = AAAK.count_tokens("x" * 1000)
        assert long > short

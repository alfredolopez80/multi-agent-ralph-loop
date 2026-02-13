#!/usr/bin/env python3
"""
Tests for reflection-executor.py v2.57.0 fixes.

Verifies that the JSONL parsing correctly extracts conversational
content and filters out JSON metadata, tool calls, and system messages.

VERSION: 2.57.0
Part of v2.57.0 Memory System Reconstruction - Phase 2

NOTE: These tests require the enhanced reflection-executor.py with
JSONL parsing and _clean_extraction method. If the dependency is not
found, tests will be skipped gracefully.
"""

import json
import pytest
import tempfile
from pathlib import Path
import sys

# Potential locations for reflection-executor.py
SCRIPT_LOCATIONS = [
    Path.home() / ".claude" / "scripts" / "reflection-executor.py",
    Path(__file__).parent.parent / ".claude" / "scripts" / "reflection-executor.py",
    Path(__file__).parent.parent / ".claude" / "archive" / "hooks-audit-20260119" / "reflection-executor.py",
]


def find_reflection_executor():
    """Find the reflection-executor.py script."""
    for loc in SCRIPT_LOCATIONS:
        if loc.exists():
            return loc
    return None


def import_transcript_parser():
    """Import TranscriptParser class from reflection-executor.py."""
    script_path = find_reflection_executor()
    if script_path is None:
        return None

    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "reflection_executor",
        script_path
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    # Check if the enhanced version has _clean_extraction method
    if not hasattr(module.TranscriptParser, '_clean_extraction'):
        return None  # Old version without enhanced features

    return module.TranscriptParser


@pytest.fixture
def parser_class():
    """Import TranscriptParser class or skip if not available."""
    parser = import_transcript_parser()
    if parser is None:
        pytest.skip("reflection-executor.py with enhanced JSONL parsing not found")
    return parser


@pytest.fixture
def temp_transcript_dir(tmp_path):
    """Create temp directory in allowed paths."""
    # Create in .claude/transcripts which is allowed
    transcript_dir = Path.home() / ".claude" / "transcripts"
    transcript_dir.mkdir(parents=True, exist_ok=True)
    return transcript_dir


def create_jsonl_transcript(transcript_dir: Path, entries: list) -> Path:
    """Create a JSONL transcript file."""
    import uuid
    transcript_file = transcript_dir / f"test-transcript-{uuid.uuid4().hex[:8]}.jsonl"
    with open(transcript_file, "w") as f:
        for entry in entries:
            f.write(json.dumps(entry) + "\n")
    return transcript_file


class TestTranscriptParserJSONL:
    """Tests for JSONL transcript parsing."""

    def test_extracts_user_messages(self, parser_class, temp_transcript_dir):
        """Parser should extract text from user messages."""
        entries = [
            {"type": "message", "role": "user", "content": "I decided to use Python for this project"},
            {"type": "message", "role": "assistant", "content": "Great choice. I'll help you implement it."},
        ]
        transcript = create_jsonl_transcript(temp_transcript_dir, entries)

        try:
            parser = parser_class(str(transcript))
            assert "decided to use Python" in parser.content
            assert "Great choice" in parser.content
        finally:
            transcript.unlink(missing_ok=True)

    def test_filters_tool_calls(self, parser_class, temp_transcript_dir):
        """Parser should filter out tool_use entries."""
        entries = [
            {"type": "message", "role": "user", "content": "Fix the bug please"},
            {"type": "tool_use", "tool_name": "Edit", "tool_input": {"file_path": "/test.py"}},
            {"type": "tool_result", "content": '{"success": true}'},
            {"type": "message", "role": "assistant", "content": "I fixed the bug successfully"},
        ]
        transcript = create_jsonl_transcript(temp_transcript_dir, entries)

        try:
            parser = parser_class(str(transcript))
            # Should have user and assistant content
            assert "Fix the bug" in parser.content
            assert "fixed the bug successfully" in parser.content
            # Should NOT have tool content
            assert "Edit" not in parser.content
            assert "file_path" not in parser.content
            assert '{"success": true}' not in parser.content
        finally:
            transcript.unlink(missing_ok=True)

    def test_filters_json_content(self, parser_class, temp_transcript_dir):
        """Parser should filter out JSON-looking content."""
        entries = [
            {"type": "message", "role": "assistant", "content": '{"key": "value", "nested": {"data": true}}'},
            {"type": "message", "role": "user", "content": "Thanks for the help with this task"},
        ]
        transcript = create_jsonl_transcript(temp_transcript_dir, entries)

        try:
            parser = parser_class(str(transcript))
            # Should filter out JSON
            assert '"key"' not in parser.content
            assert '"nested"' not in parser.content
            # Should have real content
            assert "Thanks for the help" in parser.content
        finally:
            transcript.unlink(missing_ok=True)

    def test_handles_content_blocks(self, parser_class, temp_transcript_dir):
        """Parser should handle content as list of blocks."""
        entries = [
            {
                "type": "message",
                "role": "assistant",
                "content": [
                    {"type": "text", "text": "I successfully implemented the feature"},
                    {"type": "tool_use", "name": "Write", "input": {}},
                ]
            },
        ]
        transcript = create_jsonl_transcript(temp_transcript_dir, entries)

        try:
            parser = parser_class(str(transcript))
            # Should extract text blocks
            assert "successfully implemented" in parser.content
        finally:
            transcript.unlink(missing_ok=True)


class TestDecisionExtraction:
    """Tests for decision extraction from cleaned content."""

    def test_extracts_real_decisions(self, parser_class, temp_transcript_dir):
        """Should extract actual decisions, not JSON metadata."""
        entries = [
            {"type": "message", "role": "assistant",
             "content": "I decided to use TypeScript for better type safety in this project"},
            {"type": "message", "role": "assistant",
             "content": "Going with React because it has better ecosystem support"},
        ]
        transcript = create_jsonl_transcript(temp_transcript_dir, entries)

        try:
            parser = parser_class(str(transcript))
            decisions = parser.extract_decisions()

            # Should have real decisions
            assert len(decisions) >= 1
            # Decisions should be meaningful text, not JSON
            for decision in decisions:
                assert not decision.startswith("{")
                assert not decision.startswith("[")
                assert '"' not in decision[:5]  # Not starting with JSON quotes
        finally:
            transcript.unlink(missing_ok=True)

    def test_filters_json_from_decisions(self, parser_class, temp_transcript_dir):
        """Should not extract JSON as decisions."""
        entries = [
            {"type": "message", "role": "assistant",
             "content": 'decided to {"action": "test", "value": 123}'},  # JSON in decision
        ]
        transcript = create_jsonl_transcript(temp_transcript_dir, entries)

        try:
            parser = parser_class(str(transcript))
            decisions = parser.extract_decisions()

            # Should filter out JSON-like decisions
            for decision in decisions:
                assert "action" not in decision
                assert "value" not in decision
        finally:
            transcript.unlink(missing_ok=True)


class TestCleanExtraction:
    """Tests for the _clean_extraction method."""

    @pytest.fixture
    def parser_instance(self, parser_class, temp_transcript_dir):
        """Create a parser instance with empty content."""
        # Create minimal transcript in allowed dir
        transcript = temp_transcript_dir / "empty-test.jsonl"
        transcript.write_text("")

        try:
            parser = parser_class(str(transcript))
            yield parser
        finally:
            transcript.unlink(missing_ok=True)

    def test_filters_short_text(self, parser_instance):
        """Should filter text that's too short."""
        result = parser_instance._clean_extraction("short")
        assert result is None

    def test_filters_json_text(self, parser_instance):
        """Should filter JSON-looking text."""
        result = parser_instance._clean_extraction('{"key": "value", "nested": true}')
        assert result is None

    def test_filters_file_paths(self, parser_instance):
        """Should filter file paths."""
        result = parser_instance._clean_extraction("/Users/test/path/to/file.py")
        assert result is None

    def test_accepts_valid_text(self, parser_instance):
        """Should accept valid conversational text."""
        result = parser_instance._clean_extraction("use TypeScript for better type safety")
        assert result is not None
        assert "TypeScript" in result


class TestBasicTranscriptParser:
    """
    Tests for basic TranscriptParser functionality that should work
    with any version of reflection-executor.py.
    """

    @pytest.fixture
    def basic_parser_class(self):
        """Import basic TranscriptParser class from any available location."""
        script_path = find_reflection_executor()
        if script_path is None:
            pytest.skip("reflection-executor.py not found in any location")

        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "reflection_executor",
            script_path
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.TranscriptParser

    @pytest.fixture
    def temp_transcript_dir(self):
        """Create temp directory for transcripts."""
        transcript_dir = Path.home() / ".claude" / "transcripts"
        transcript_dir.mkdir(parents=True, exist_ok=True)
        return transcript_dir

    def test_parser_handles_missing_file(self, basic_parser_class):
        """Parser should handle non-existent files gracefully."""
        parser = basic_parser_class("/nonexistent/path/transcript.txt")
        # Should not crash, content should be empty
        assert parser.content == ""

    def test_parser_reads_plain_text(self, basic_parser_class, temp_transcript_dir):
        """Parser should read plain text files."""
        transcript = temp_transcript_dir / "plain-test.txt"
        transcript.write_text("I decided to use Python for this project")

        try:
            parser = basic_parser_class(str(transcript))
            assert "decided to use Python" in parser.content
        finally:
            transcript.unlink(missing_ok=True)

    def test_extract_decisions_basic(self, basic_parser_class, temp_transcript_dir):
        """Basic decision extraction should work."""
        transcript = temp_transcript_dir / "decisions-test.txt"
        transcript.write_text("I decided to implement caching for better performance")

        try:
            parser = basic_parser_class(str(transcript))
            decisions = parser.extract_decisions()
            assert len(decisions) >= 1
            assert "implement caching" in decisions[0]
        finally:
            transcript.unlink(missing_ok=True)

    def test_extract_tags(self, basic_parser_class, temp_transcript_dir):
        """Tag extraction should identify technology keywords."""
        transcript = temp_transcript_dir / "tags-test.txt"
        transcript.write_text("We implemented a Python API with Docker and Kubernetes")

        try:
            parser = basic_parser_class(str(transcript))
            tags = parser.extract_tags()
            assert "python" in tags
            assert "docker" in tags
            assert "kubernetes" in tags
        finally:
            transcript.unlink(missing_ok=True)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

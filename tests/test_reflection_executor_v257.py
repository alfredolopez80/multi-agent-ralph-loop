#!/usr/bin/env python3
"""
Tests for reflection-executor.py v2.57.0 fixes.

Verifies that the JSONL parsing correctly extracts conversational
content and filters out JSON metadata, tool calls, and system messages.

VERSION: 2.57.0
Part of v2.57.0 Memory System Reconstruction - Phase 2
"""

import json
import pytest
import tempfile
from pathlib import Path
import sys

# Add scripts directory to path
sys.path.insert(0, str(Path.home() / ".claude" / "scripts"))


class TestTranscriptParserJSONL:
    """Tests for JSONL transcript parsing."""

    @pytest.fixture
    def parser_class(self):
        """Import TranscriptParser class."""
        try:
            from importlib import import_module
            # Import the module
            spec = import_module("reflection-executor")
            return spec.TranscriptParser
        except ImportError:
            # Try direct import
            import importlib.util
            spec = importlib.util.spec_from_file_location(
                "reflection_executor",
                Path.home() / ".claude" / "scripts" / "reflection-executor.py"
            )
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module.TranscriptParser

    @pytest.fixture
    def temp_transcript_dir(self, tmp_path):
        """Create temp directory in allowed paths."""
        # Create in .claude/transcripts which is allowed
        transcript_dir = Path.home() / ".claude" / "transcripts"
        transcript_dir.mkdir(parents=True, exist_ok=True)
        return transcript_dir

    def create_jsonl_transcript(self, transcript_dir: Path, entries: list) -> Path:
        """Create a JSONL transcript file."""
        transcript_file = transcript_dir / f"test-transcript-{id(entries)}.jsonl"
        with open(transcript_file, "w") as f:
            for entry in entries:
                f.write(json.dumps(entry) + "\n")
        return transcript_file

    def test_extracts_user_messages(self, parser_class, temp_transcript_dir):
        """Parser should extract text from user messages."""
        entries = [
            {"type": "message", "role": "user", "content": "I decided to use Python for this project"},
            {"type": "message", "role": "assistant", "content": "Great choice. I'll help you implement it."},
        ]
        transcript = self.create_jsonl_transcript(temp_transcript_dir, entries)

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
        transcript = self.create_jsonl_transcript(temp_transcript_dir, entries)

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
        transcript = self.create_jsonl_transcript(temp_transcript_dir, entries)

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
        transcript = self.create_jsonl_transcript(temp_transcript_dir, entries)

        try:
            parser = parser_class(str(transcript))
            # Should extract text blocks
            assert "successfully implemented" in parser.content
        finally:
            transcript.unlink(missing_ok=True)


class TestDecisionExtraction:
    """Tests for decision extraction from cleaned content."""

    @pytest.fixture
    def parser_class(self):
        """Import TranscriptParser class."""
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "reflection_executor",
            Path.home() / ".claude" / "scripts" / "reflection-executor.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.TranscriptParser

    @pytest.fixture
    def temp_transcript_dir(self):
        """Create temp directory in allowed paths."""
        transcript_dir = Path.home() / ".claude" / "transcripts"
        transcript_dir.mkdir(parents=True, exist_ok=True)
        return transcript_dir

    def create_jsonl_transcript(self, transcript_dir: Path, entries: list) -> Path:
        """Create a JSONL transcript file."""
        transcript_file = transcript_dir / f"test-transcript-{id(entries)}.jsonl"
        with open(transcript_file, "w") as f:
            for entry in entries:
                f.write(json.dumps(entry) + "\n")
        return transcript_file

    def test_extracts_real_decisions(self, parser_class, temp_transcript_dir):
        """Should extract actual decisions, not JSON metadata."""
        entries = [
            {"type": "message", "role": "assistant",
             "content": "I decided to use TypeScript for better type safety in this project"},
            {"type": "message", "role": "assistant",
             "content": "Going with React because it has better ecosystem support"},
        ]
        transcript = self.create_jsonl_transcript(temp_transcript_dir, entries)

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
        transcript = self.create_jsonl_transcript(temp_transcript_dir, entries)

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
    def parser_instance(self):
        """Create a parser instance with empty content."""
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "reflection_executor",
            Path.home() / ".claude" / "scripts" / "reflection-executor.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        # Create minimal transcript in allowed dir
        transcript_dir = Path.home() / ".claude" / "transcripts"
        transcript_dir.mkdir(parents=True, exist_ok=True)
        transcript = transcript_dir / "empty-test.jsonl"
        transcript.write_text("")

        try:
            parser = module.TranscriptParser(str(transcript))
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


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

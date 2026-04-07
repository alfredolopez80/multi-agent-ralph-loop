#!/usr/bin/env python3
"""
AAAK CLI -- Command-line interface for the AAAK Dialect codec.

Commands:
    aaak encode <file>                   -- Compress a text file to AAAK format
    aaak decode <file>                   -- Decompress an AAAK file back to original text
    aaak stats <dir>                     -- Show compression statistics for all .md files in dir
    aaak summarize <file>                -- Produce a lossy AAAK summary (no round-trip)
    aaak zettel                          -- Format a zettel from stdin JSON
    aaak migrate --from md --to aaak <input> [<output>]
                                         -- Migrate a single file or batch directory

Usage:
    python -m .claude.lib.aaak_cli encode path/to/notes.md
    python -m .claude.lib.aaak_cli decode path/to/notes.aaak
    python -m .claude.lib.aaak_cli stats .claude/rules/learned/
    python -m .claude.lib.aaak_cli migrate --from md --to aaak .claude/rules/learned/
    python -m .claude.lib.aaak_cli migrate --from md --to aaak rules.md rules.aaak
"""

import json
import os
import sys
from pathlib import Path

# Allow running as a standalone script or as a module
_THIS_DIR = Path(__file__).parent
_REPO_ROOT = _THIS_DIR.parent.parent
sys.path.insert(0, str(_REPO_ROOT))

from aaak import AAAK  # noqa: E402 -- dynamic path setup above


def _load_codec(config_path: str = None) -> AAAK:
    """Load codec, optionally with entity config."""
    if config_path:
        with open(config_path) as f:
            cfg = json.load(f)
        return AAAK(
            entities=cfg.get("entities", {}),
            skip_names=cfg.get("skip_names", []),
        )
    return AAAK()


def cmd_encode(args: list) -> int:
    """Compress a file to AAAK format, writing .aaak output alongside source."""
    if not args:
        print("Usage: aaak encode <file> [--config entities.json]", file=sys.stderr)
        return 1

    config = None
    if "--config" in args:
        idx = args.index("--config")
        config = args[idx + 1]
        args = args[:idx] + args[idx + 2:]

    input_path = Path(args[0])
    if not input_path.exists():
        print(f"Error: file not found: {input_path}", file=sys.stderr)
        return 1

    codec = _load_codec(config)
    text = input_path.read_text(encoding="utf-8")
    compressed = codec.compress(text)

    output_path = input_path.with_suffix(".aaak")
    output_path.write_text(compressed, encoding="utf-8")

    stats = codec.compression_stats(text)
    print(f"Encoded: {input_path} -> {output_path}")
    print(f"Original: {stats['original_chars']:,} chars (~{stats['original_tokens']:,} tokens)")
    print(f"Summary:  {stats['summary_chars']:,} chars (~{stats['summary_tokens']:,} tokens)")
    print(f"Ratio:    {stats['ratio']:.1f}x (symbolic summary vs original)")
    return 0


def cmd_decode(args: list) -> int:
    """Decompress an AAAK file back to original text."""
    if not args:
        print("Usage: aaak decode <file.aaak>", file=sys.stderr)
        return 1

    input_path = Path(args[0])
    if not input_path.exists():
        print(f"Error: file not found: {input_path}", file=sys.stderr)
        return 1

    codec = AAAK()
    aaak_text = input_path.read_text(encoding="utf-8")

    try:
        original = codec.decompress(aaak_text)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    output_path = input_path.with_suffix(".decoded.txt")
    output_path.write_text(original, encoding="utf-8")
    print(f"Decoded: {input_path} -> {output_path}")
    print(f"Recovered {len(original):,} chars")
    return 0


def cmd_stats(args: list) -> int:
    """Show compression statistics for all .md files in a directory."""
    if not args:
        print("Usage: aaak stats <directory>", file=sys.stderr)
        return 1

    target = Path(args[0])
    if not target.exists():
        print(f"Error: path not found: {target}", file=sys.stderr)
        return 1

    codec = AAAK()
    files = sorted(target.glob("**/*.md")) if target.is_dir() else [target]

    if not files:
        print(f"No .md files found in {target}", file=sys.stderr)
        return 1

    total_orig = 0
    total_summ = 0
    print(f"{'File':<50} {'Orig':>8} {'Summ':>8} {'Ratio':>8}")
    print("-" * 78)

    for f in files:
        try:
            text = f.read_text(encoding="utf-8")
            if not text.strip():
                continue
            s = codec.compression_stats(text)
            rel = f.relative_to(target) if target.is_dir() else f
            print(
                f"{str(rel):<50} {s['original_chars']:>7,}c {s['summary_chars']:>7,}c "
                f"{s['ratio']:>6.1f}x"
            )
            total_orig += s["original_chars"]
            total_summ += s["summary_chars"]
        except Exception as e:
            print(f"  [skip] {f}: {e}", file=sys.stderr)

    if total_summ > 0:
        print("-" * 78)
        overall = total_orig / total_summ
        print(
            f"{'TOTAL':<50} {total_orig:>7,}c {total_summ:>7,}c {overall:>6.1f}x"
        )
    return 0


def cmd_summarize(args: list) -> int:
    """Produce a lossy AAAK summary of a file (no round-trip guarantee)."""
    if not args:
        print("Usage: aaak summarize <file>", file=sys.stderr)
        return 1

    input_path = Path(args[0])
    if not input_path.exists():
        print(f"Error: file not found: {input_path}", file=sys.stderr)
        return 1

    codec = AAAK()
    text = input_path.read_text(encoding="utf-8")
    summary = codec.summarize(text)
    print(summary)
    return 0


def cmd_zettel(args: list) -> int:
    """Format a zettel from JSON on stdin or --json flag.

    JSON format:
    {
        "entities": ["Claude", "Alfred"],
        "topic": "architecture",
        "quote": "Obsidian as single source of truth",
        "weight": 0.9,
        "emotions": ["conviction", "trust"],
        "flags": ["DECISION", "TECHNICAL"]
    }
    """
    codec = AAAK()

    if "--json" in args:
        idx = args.index("--json")
        raw = args[idx + 1]
        data = json.loads(raw)
    else:
        raw = sys.stdin.read()
        data = json.loads(raw)

    line = codec.format_zettel(
        entities=data.get("entities", []),
        topic=data.get("topic", ""),
        quote=data.get("quote", ""),
        weight=float(data.get("weight", 0.5)),
        emotions=data.get("emotions", []),
        flags=data.get("flags", []),
        zid=str(data.get("zid", "0")),
    )
    print(line)
    return 0


def cmd_migrate(args: list) -> int:
    """
    Migrate files from one format to another.

    Supported conversions:
        --from md --to aaak <input> [<output>]
            Compress a .md file or all .md files in a directory to .aaak.
            Output defaults to <input>.aaak (or same dir for batch).

    Batch mode (directory input):
        - Processes all .md files in the directory
        - Writes <name>.aaak alongside original
        - Renames original to <name>.md.legacy
        - Verifies lossless round-trip for each file

    Single file mode:
        - Writes <output> (or <input>.aaak if output omitted)
        - Renames original to <input>.md.legacy
        - Verifies lossless round-trip

    Examples:
        aaak migrate --from md --to aaak .claude/rules/learned/
        aaak migrate --from md --to aaak notes.md
        aaak migrate --from md --to aaak notes.md notes.aaak
    """
    # Parse --from and --to flags
    from_fmt = None
    to_fmt = None
    positional = []

    i = 0
    while i < len(args):
        if args[i] == "--from" and i + 1 < len(args):
            from_fmt = args[i + 1]
            i += 2
        elif args[i] == "--to" and i + 1 < len(args):
            to_fmt = args[i + 1]
            i += 2
        else:
            positional.append(args[i])
            i += 1

    if from_fmt != "md" or to_fmt != "aaak":
        print(
            f"Error: only --from md --to aaak is supported (got --from {from_fmt} --to {to_fmt})",
            file=sys.stderr,
        )
        return 1

    if not positional:
        print("Usage: aaak migrate --from md --to aaak <input> [<output>]", file=sys.stderr)
        return 1

    input_path = Path(positional[0])
    output_arg = Path(positional[1]) if len(positional) > 1 else None

    codec = AAAK()
    errors = 0
    processed = 0

    if input_path.is_dir():
        # Batch mode
        md_files = sorted(input_path.glob("*.md"))
        if not md_files:
            print(f"No .md files found in {input_path}", file=sys.stderr)
            return 1

        print(f"Batch migrating {len(md_files)} files in {input_path}")
        for md_path in md_files:
            aaak_path = md_path.with_suffix(".aaak")
            legacy_path = md_path.with_suffix(".md.legacy")
            try:
                text = md_path.read_text(encoding="utf-8")
                compressed = codec.compress(text)
                # Verify round-trip
                recovered = codec.decompress(compressed)
                if recovered != text:
                    print(f"  [FAIL] {md_path.name}: round-trip verification failed", file=sys.stderr)
                    errors += 1
                    continue
                aaak_path.write_text(compressed, encoding="utf-8")
                md_path.rename(legacy_path)
                stats = codec.compression_stats(text)
                print(f"  [OK] {md_path.name} -> {aaak_path.name} ({stats['ratio']:.1f}x summary ratio)")
                processed += 1
            except Exception as exc:
                print(f"  [ERROR] {md_path.name}: {exc}", file=sys.stderr)
                errors += 1

        print(f"\nProcessed: {processed}/{len(md_files)}, Errors: {errors}")
    else:
        # Single file mode
        if not input_path.exists():
            print(f"Error: file not found: {input_path}", file=sys.stderr)
            return 1

        aaak_path = output_arg if output_arg else input_path.with_suffix(".aaak")
        legacy_path = input_path.with_suffix(input_path.suffix + ".legacy")

        try:
            text = input_path.read_text(encoding="utf-8")
            compressed = codec.compress(text)
            recovered = codec.decompress(compressed)
            if recovered != text:
                print(f"Error: round-trip verification failed for {input_path}", file=sys.stderr)
                return 1
            aaak_path.write_text(compressed, encoding="utf-8")
            input_path.rename(legacy_path)
            stats = codec.compression_stats(text)
            print(f"Migrated: {input_path} -> {aaak_path}")
            print(f"  Summary ratio: {stats['ratio']:.1f}x")
            print(f"  Round-trip: OK")
            processed = 1
        except Exception as exc:
            print(f"Error: {exc}", file=sys.stderr)
            errors += 1

    return 0 if errors == 0 else 1


def main(argv: list = None) -> int:
    argv = argv or sys.argv[1:]

    if not argv:
        print(__doc__)
        return 0

    command = argv[0]
    rest = argv[1:]

    commands = {
        "encode": cmd_encode,
        "decode": cmd_decode,
        "stats": cmd_stats,
        "summarize": cmd_summarize,
        "zettel": cmd_zettel,
        "migrate": cmd_migrate,
    }

    if command not in commands:
        print(f"Unknown command: {command}", file=sys.stderr)
        print(f"Available commands: {', '.join(commands)}", file=sys.stderr)
        return 1

    return commands[command](rest)


if __name__ == "__main__":
    sys.exit(main())

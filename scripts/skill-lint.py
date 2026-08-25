#!/usr/bin/env python3
"""skill-lint.py — enforce a minimum of truth on the skill corpus.

Four checks, no more:
  1. frontmatter parseable
  2. description present
  3. name == directory name
  4. no hook references a skill that does not have a corresponding SKILL.md

The fourth is the one that converts this from hygiene to a defense:
it would have caught the 12 hardcoded suggestions in
.smart-skill-reminder.sh that pointed at skills which do not exist.

Exit codes:
  0 = no errors (and scanned > 0)
  1 = errors found, OR zero skills scanned (a lint with nothing to review
      cannot honestly report success)
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Where the corpus lives. Default to the worktree's skills dir so the test
# fixture is hermetic; --global scans ~/.claude/skills (what Claude Code
# actually reads at session start).
DEFAULT_SKILLS_DIR = ".claude/skills"

# Where hooks live. Used by check #4 to find hook scripts that reference
# a skill by name. The hook output includes the skill name in the system
# message; that name is what we verify against the corpus.
HOOKS_DIR = ".claude/hooks"
GLOBAL_HOOKS_DIR = Path.home() / ".claude" / "hooks"

# Path to the ignore file. Each line is `path|reason`. Without a reason the
# entry is rejected as obsolete or invalid.
DEFAULT_IGNORE = ".claude/skills/.skill-lint-ignore"


# ---------------------------------------------------------------------------
# Frontmatter parsing
# ---------------------------------------------------------------------------

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
FIELD_RE = re.compile(r"^(\w[\w-]*):\s*(.*)$", re.MULTILINE)
QUOTED_RE = re.compile(r'^"(.*)"$', re.DOTALL)


def parse_frontmatter(text: str) -> dict[str, str]:
    """Parse YAML frontmatter as a flat dict. No PyYAML — regex only.

    The frontmatter must start at line 1 (the very first line of the file).
    If something precedes it — an HTML comment, a heading, anything — the
    parser returns an empty dict, which check #1 will flag.
    """
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    out: dict[str, str] = {}
    for fm in FIELD_RE.finditer(m.group(1)):
        key = fm.group(1)
        value = fm.group(2).strip()
        qm = QUOTED_RE.match(value)
        if qm:
            value = qm.group(1)
        out[key] = value
    return out


# ---------------------------------------------------------------------------
# Ignore file
# ---------------------------------------------------------------------------


def load_ignore(path: Path) -> tuple[set[str], list[str]]:
    """Return (ignored_paths, errors). Each line is `path|reason`."""
    ignored: set[str] = set()
    errors: list[str] = []
    if not path.exists():
        return ignored, errors
    for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "|" not in line:
            errors.append(f"{path}:{i}: missing '|' separator (path|reason)")
            continue
        path_part, reason = line.split("|", 1)
        path_part = path_part.strip()
        reason = reason.strip()
        if not reason:
            errors.append(
                f"{path}:{i}: empty reason for {path_part!r} "
                "(obsolete or never had one — delete the line)"
            )
            continue
        ignored.add(path_part)
    return ignored, errors


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------


def check_frontmatter(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    if not text.startswith("---\n"):
        errors.append(
            f"{path}: frontmatter must start at line 1 (currently the file "
            "starts with a comment or other prefix)"
        )
        return errors
    fm = parse_frontmatter(text)
    if not fm:
        errors.append(
            f"{path}: frontmatter missing or unparseable"
        )
    return errors


def check_description(path: Path, fm: dict[str, str]) -> list[str]:
    errors: list[str] = []
    desc = fm.get("description", "").strip()
    if not desc:
        errors.append(f"{path}: 'description' missing in frontmatter")
    elif len(desc) < 20:
        errors.append(
            f"{path}: 'description' too short ({len(desc)} chars, "
            "minimum 20 to be useful)"
        )
    return errors


def check_name_matches_dir(path: Path, fm: dict[str, str]) -> list[str]:
    errors: list[str] = []
    fm_name = fm.get("name", "").strip()
    dir_name = path.parent.name
    if not fm_name:
        errors.append(
            f"{path}: 'name' missing in frontmatter (directory is {dir_name!r})"
        )
    elif fm_name != dir_name:
        errors.append(
            f"{path}: 'name' ({fm_name!r}) does not match directory "
            f"name ({dir_name!r})"
        )
    return errors


# Match a skill-name reference inside a hook script. The pattern that
# matters is the *emission* of a skill name — the only way a hook
# actually references a skill is by emitting a string the model reads.
#
# The real-world emission patterns we've seen:
#   "/python-pro for Python best practices"           (smart-skill-reminder.sh)
#   "/blockchain-web3:blockchain-developer for Solidity"  (marketplace:plugin)
#   "Suggesting: /python-pro for ..."                  (log lines)
#   '"/<name>"' inside jq's --arg ctx                   (additionalContext)
#
# What this regex deliberately DOES NOT match:
#   - /tmp/foo.txt                                      (filesystem paths)
#   - .claude/plan-state.json                           (config paths)
#   - /Users/...                                        (home paths)
#   - "command -v jq"                                   (which-jq paths)
#   - "/bug         - Systematic debugging"             (doc comments)
#
# The discriminator is the literal `"/<name> for ` or `Suggesting: /<name>`
# pattern: a skill is being SUGGESTED, with a follow-up. Paths do not
# have that structure.
HOOK_SKILL_REF_RE = re.compile(
    r'"/(?P<name>[a-z][a-z0-9-]+(?::[a-z][a-z0-9-]+)?)\s+for\s+'
    r'|Suggesting:\s*/(?P<name2>[a-z][a-z0-9-]+(?::[a-z][a-z0-9-]+)?)'
)


def check_hook_references(
    hooks_dir: Path, valid_skill_names: set[str],
    ignored: set[str] | None = None
) -> tuple[list[str], set[str]]:
    """Find skill references in hook scripts that don't have a matching skill.

    Returns (reportable_errors, all_hook_paths_with_violations). The
    second element tracks violations even on ignored hooks, so the
    obsolete-entry check can confirm the ignore entry is silencing
    something real.
    """
    if ignored is None:
        ignored = set()
    errors: list[str] = []
    with_violations: set[str] = set()
    if not hooks_dir.exists():
        return errors, with_violations
    for hook_path in hooks_dir.rglob("*.sh"):
        try:
            text = hook_path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        # Honour ignore entries for hook paths. The relative path used
        # in the ignore file is the hook's path relative to hooks_dir
        # (mirrors how SKILL.md paths are relative to skills_dir).
        rel_hook = str(hook_path.relative_to(hooks_dir))
        ignored_for_report = rel_hook in ignored
        for match in HOOK_SKILL_REF_RE.finditer(text):
            name = match.group("name") or match.group("name2")
            if not name:
                continue
            if name not in valid_skill_names:
                line_no = text[:match.start()].count("\n") + 1
                # Always track the violation, even on ignored hooks, so
                # the obsolete check can confirm the ignore entry is
                # doing something useful.
                with_violations.add(rel_hook)
                if ignored_for_report:
                    continue
                errors.append(
                    f"{hook_path}:{line_no}: hook references skill "
                    f"'{name}' but no SKILL.md with that name exists in "
                    f"the corpus (checked {hooks_dir})"
                )
    return errors, with_violations


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(description="Lint the skill corpus")
    ap.add_argument(
        "--skills-dir",
        default=DEFAULT_SKILLS_DIR,
        help="Path to the skills directory to scan (default: %(default)s)",
    )
    ap.add_argument(
        "--global",
        dest="global_skills",
        action="store_true",
        help="Scan ~/.claude/skills instead of the worktree",
    )
    ap.add_argument(
        "--ignore",
        default=DEFAULT_IGNORE,
        help="Path to the ignore file (default: %(default)s)",
    )
    ap.add_argument(
        "--hooks-dir",
        default=None,
        help="Path to the hooks dir to scan for orphan references "
             "(default: derived from skills-dir)",
    )
    args = ap.parse_args()

    skills_dir = Path(args.skills_dir).resolve()
    if args.global_skills:
        skills_dir = Path.home() / ".claude" / "skills"
    if not skills_dir.exists():
        print(f"ERROR: skills dir {skills_dir} does not exist", file=sys.stderr)
        return 1

    if args.hooks_dir:
        hooks_dir = Path(args.hooks_dir).resolve()
    else:
        # Default: hooks live alongside skills in the worktree, or in
        # ~/.claude/hooks if --global.
        if args.global_skills:
            hooks_dir = Path.home() / ".claude" / "hooks"
        else:
            hooks_dir = skills_dir.parent / "hooks"

    ignore_path = skills_dir / ".skill-lint-ignore"
    ignored, ignore_errors = load_ignore(ignore_path)

    # First pass: collect all valid skill names from the corpus
    skill_files = sorted(skills_dir.rglob("SKILL.md"))
    valid_skill_names: set[str] = set()
    fms: dict[Path, dict[str, str]] = {}

    for path in skill_files:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        fm = parse_frontmatter(text)
        fms[path] = fm
        if "name" in fm:
            valid_skill_names.add(fm["name"])

    errors: list[str] = list(ignore_errors)

    # Per-file checks
    scanned = 0
    files_with_violations: set[str] = set()
    for path in skill_files:
        rel = str(path.relative_to(skills_dir))
        if rel in ignored:
            # Even though we don't report violations on ignored files,
            # we still need to know if they have any. The obsolete
            # check below uses this to decide whether an ignore entry
            # is silencing something or just dead.
            try:
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            file_errors: list[str] = []
            file_errors.extend(check_frontmatter(path, text))
            fm = fms.get(path, {})
            if fm:
                file_errors.extend(check_description(path, fm))
                file_errors.extend(check_name_matches_dir(path, fm))
            if file_errors:
                files_with_violations.add(rel)
            # NOTE: we do NOT extend `errors` with file_errors here; the
            # ignore entry is supposed to silence them.
            continue
        scanned += 1
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        file_errors = []
        file_errors.extend(check_frontmatter(path, text))
        fm = fms.get(path, {})
        if fm:  # only run remaining checks if frontmatter parsed
            file_errors.extend(check_description(path, fm))
            file_errors.extend(check_name_matches_dir(path, fm))
        if file_errors:
            files_with_violations.add(rel)
        errors.extend(file_errors)

    # Check 4: hook references to non-existent skills
    hook_errors, hooks_with_violations = check_hook_references(
        hooks_dir, valid_skill_names, ignored
    )
    errors.extend(hook_errors)

    # Detect obsolete ignore entries: an entry that no longer matches any
    # current violation. The file is fine (lint is happy), but the entry
    # has lost its reason to exist.
    all_violations = files_with_violations | hooks_with_violations
    if ignored:
        for ignored_rel in sorted(ignored):
            # If the entry corresponds to a real, current violation, it's
            # working as intended. Otherwise it's obsolete.
            if ignored_rel not in all_violations:
                # Was it ever expected to silence a hook ref? Find the
                # matching line in the ignore file and report it.
                for i, line in enumerate(
                    ignore_path.read_text(encoding="utf-8").splitlines(), 1
                ):
                    if "|" in line:
                        path_part = line.split("|", 1)[0].strip()
                        if path_part == ignored_rel:
                            errors.append(
                                f"{ignore_path}:{i}: obsolete entry "
                                f"{ignored_rel!r} — no current violation "
                                f"matches it; delete the line"
                            )
                            break

    # Report
    print(f"# skill-lint: scanned {scanned} skills in {skills_dir}")
    if errors:
        print(f"# {len(errors)} error(s):")
        for e in errors:
            print(f"  {e}")
        return 1
    if scanned == 0:
        print(
            f"# zero skills scanned — the corpus is empty, the lint cannot "
            f"honestly report success",
            file=sys.stderr,
        )
        return 1
    print("# OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

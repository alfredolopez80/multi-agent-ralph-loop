#!/usr/bin/env python3
"""secrets-write-guard.py — deterministic secret gate for write tools (PR3-C1, #69 1B).

Closes gap `secrets-ordinary-work`: nothing blocked secrets AT WRITE TIME; the old
audit-secrets.js only logged after the fact (and was deregistered by PR3-C7).

Contract (mirrors git-safety-guard.py, T16-verified): every terminal path prints a
JSON decision; allow/ask exit 0, deny exits 1. The JSON is authoritative.

  allow  {"hookSpecificOutput":{"hookEventName":"PreToolUse",
          "permissionDecision":"allow","permissionDecisionReason":"..."}}
  deny   same shape with "deny" + exit 1

Design constraints (#45/#69): stdlib only; closed patterns (no vague regexes);
fail-closed on unparseable input (security-plane invariant); never echoes the
matched secret back (only pattern name + location). Scanned targets:
  Write      -> tool_input.content
  Edit       -> tool_input.new_string
  MultiEdit  -> tool_input.edits[*].new_string
Any other tool_name is allowed (not a write). The ALLOWLIST below is the
versioned path policy for false positives (fnmatch semantics: '*' crosses '/').
"""

import fnmatch
import json
import re
import sys

# Path/extension allowlist (POLICY, versioned in git so every widening is
# reviewable). Matching is fnmatch against the full file_path.
ALLOWLIST_GLOBS = [
    "**/fixtures/**",
    "**/testdata/**",
    "**/*.fixture",
    "**/*.example",
    "**/*.sample",
    "**/*.tmpl",
    "**/*.template",
]

# Closed patterns: literal anchors, fixed charsets, minimum lengths. Ordered.
PATTERNS = [
    ("PEM private key header",
     re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY(?: BLOCK)?-----")),
    ("OpenAI-style API key (sk-)",
     re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b")),
    ("GitHub token (ghp_/gho_/ghu_/ghs_/ghr_/github_pat_)",
     re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})\b")),
    ("AWS access key id (AKIA)",
     re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("Credentials embedded in URL (scheme://user:password@)",
     re.compile(r"[a-z][a-z0-9+.-]*://[^\s/:@]+:[^\s/@]{8,}@")),
    ("Credential assignment literal (key = value >= 20 chars)",
     re.compile(r"\b(?:api[_-]?key|apikey|secret|token|password|passwd|"
                r"auth[_-]?token|access[_-]?token)\b\s*[=:]\s*[\"']?"
                r"[A-Za-z0-9+/_-]{20,}", re.IGNORECASE)),
]

WRITE_TOOLS = {"Write": ("content",), "Edit": ("new_string",),
               "MultiEdit": ("edits",)}


def decide(allowed, reason):
    out = {"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow" if allowed else "deny",
        "permissionDecisionReason": reason,
    }}
    print(json.dumps(out))
    return 0 if allowed else 1


def scan_targets(tool_name, tool_input):
    """Return the list of (field, text) strings to scan, or [] if none found."""
    targets = []
    if tool_name == "Write":
        if "content" in tool_input:
            targets.append(("content", str(tool_input["content"])))
    elif tool_name == "Edit":
        if "new_string" in tool_input:
            targets.append(("new_string", str(tool_input["new_string"])))
    elif tool_name == "MultiEdit":
        for i, edit in enumerate(tool_input.get("edits", [])):
            if isinstance(edit, dict) and "new_string" in edit:
                targets.append((f"edits[{i}].new_string",
                                str(edit["new_string"])))
    return targets


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(decide(False, "secrets-write-guard: unparseable stdin — "
                               "fail-closed per security-plane invariant"))
    if not isinstance(payload, dict):
        sys.exit(decide(False, "secrets-write-guard: unexpected stdin shape — "
                               "fail-closed"))
    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}

    if tool_name not in WRITE_TOOLS:
        sys.exit(decide(True, "secrets-write-guard: not a write tool — nothing "
                              "to scan"))

    file_path = tool_input.get("file_path")
    if not file_path or not isinstance(file_path, str):
        sys.exit(decide(False, "secrets-write-guard: write without a readable "
                               "file_path — fail-closed"))

    for glob in ALLOWLIST_GLOBS:
        if fnmatch.fnmatch(file_path, glob):
            sys.exit(decide(True, f"secrets-write-guard: '{file_path}' matches "
                                  f"allowlist glob '{glob}' — documented allow"))

    targets = scan_targets(tool_name, tool_input)
    if not targets:
        sys.exit(decide(False, f"secrets-write-guard: {tool_name} payload has no "
                               f"scannable content — fail-closed"))

    for field, text in targets:
        for name, pattern in PATTERNS:
            m = pattern.search(text)
            if m:
                sys.exit(decide(False, (
                    f"secrets-write-guard: probable secret in {tool_name} "
                    f"({file_path}, field {field}): pattern '{name}' matched. "
                    f"Move the value to an environment variable or a gitignored "
                    f".env file; if this path is a legitimate fixture, it must "
                    f"match a versioned ALLOWLIST_GLOBS entry in "
                    f".claude/hooks/secrets-write-guard.py.")))

    sys.exit(decide(True, f"secrets-write-guard: no secret patterns matched in "
                          f"{tool_name} ({file_path})"))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""secrets-write-guard.py — deterministic secret/RED gate for write tools.

PR3-C1 (#69 1B, gap secrets-ordinary-work) + PR3-C2-IMPL (gap red-toxic).
Closes both gaps at the mechanism level per OWNER DECISIONS (2026-08-31):
  C1: deny 6 closed credential patterns at write time.
  R1: deny BIP-39 mnemonic SEQUENCES (N in {12,15,18,21,24} wordlist words on
      one line). Checksum is verified and reported in the reason, but the
      sequence itself denies: a typo'd mnemonic is exactly what must be caught.
  R2: ASK on 0x-prefixed 64-hex values outside test paths (EVM key vs hash is
      shape-indistinguishable; the OWNER accepted the ask friction on web3).
  R3: ASK on PII DENSITY — a payload with >= PII_DENSITY_THRESHOLD email/E.164
      matches is a dump; isolated matches in ordinary code allow.
  R4/R5: documented out of mechanical scope (SECURITY_BASELINE.json).

Contract (mirrors git-safety-guard.py, T16-verified): every terminal path
prints a JSON decision; allow/ask exit 0, deny exits 1. Fail-closed on
unparseable input and on payloads with NO known content field. Never echoes
the matched content. Scans every known content field present (content,
new_string, edits[*].new_string) regardless of which write tool carries it.

Wordlist: vendored verbatim from bitcoin/bips bip-0039/english.txt (2048
entries); the suite validates count/order/uniqueness.
"""

import fnmatch
import hashlib
import json
import os
import re
import sys

# Path/extension allowlist (POLICY, versioned in git so every widening is
# reviewable). Matching is fnmatch against the full file_path; '*' crosses '/'.
ALLOWLIST_GLOBS = [
    "**/fixtures/**",
    "**/testdata/**",
    "**/*.fixture",
    "**/*.example",
    "**/*.sample",
    "**/*.tmpl",
    "**/*.template",
]

# R2 exemption: hex hash constants are ordinary in test code.
TEST_GLOBS = [
    "**/tests/**",
    "**/test_*.py",
    "**/*_test.*",
    "**/testdata/**",
]

# R3 density knob (owner spec: default 10, constant configurable here).
PII_DENSITY_THRESHOLD = 10

# Closed credential patterns (C1). Ordered; first match denies.
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

# RED classes (C2).
BIP39_LENGTHS = {12, 15, 18, 21, 24}
EVM_KEY_RE = re.compile(r"\b0x[0-9a-fA-F]{64}\b")
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE_E164_RE = re.compile(r"\+[1-9]\d{7,14}\b")

WRITE_TOOLS = {"Write", "Edit", "MultiEdit"}
CONTENT_FIELDS = ("content", "new_string")

WORDLIST_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             "secrets-write-guard.bip39-wordlist")


def decide(allowed_or_ask, reason):
    decision = "deny" if allowed_or_ask == "deny" else allowed_or_ask
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))
    return 0 if decision in ("allow", "ask") else 1


def scan_targets(tool_input):
    """(field, text) pairs for every known content field present."""
    targets = []
    for field in CONTENT_FIELDS:
        if field in tool_input:
            targets.append((field, str(tool_input[field])))
    edits = tool_input.get("edits")
    if isinstance(edits, list):
        for i, edit in enumerate(edits):
            if isinstance(edit, dict) and "new_string" in edit:
                targets.append((f"edits[{i}].new_string",
                                str(edit["new_string"])))
    return targets


_WORD_INDEX_CACHE = None


def _load_wordlist():
    """word -> BIP-39 index, cached per process (one read per hook run)."""
    global _WORD_INDEX_CACHE
    if _WORD_INDEX_CACHE is None:
        index = {}
        with open(WORDLIST_PATH, encoding="utf-8") as fh:
            for i, line in enumerate(fh):
                w = line.strip()
                if w:
                    index[w] = i
        _WORD_INDEX_CACHE = index
    return _WORD_INDEX_CACHE


def _mnemonic_checksum_valid(tokens, word_index):
    n = len(tokens)
    cs_len = (n * 11) // 33
    bits = "".join(f"{word_index[t]:011b}" for t in tokens)
    ent_bits, cs_bits = bits[:-cs_len], bits[-cs_len:]
    if not ent_bits or len(ent_bits) % 8:
        return False
    entropy = int(ent_bits, 2).to_bytes(len(ent_bits) // 8, "big")
    digest = hashlib.sha256(entropy).digest()
    return bin(int.from_bytes(digest, "big"))[2:].zfill(256)[:cs_len] == cs_bits


def find_mnemonic_sequence(text, word_index):
    """First mnemonic-sequence candidate in the text.

    Candidate: a contiguous window of exactly N tokens (N in BIP39_LENGTHS),
    every one in the wordlist after light punctuation-stripping — so a labeled
    line ("backup: <12 words>") is caught, and any non-list word breaks the
    window (ordinary prose never accumulates 12 consecutive list words).
    Returns (line_no, n, checksum) or None. Checksum does NOT gate the deny
    (a typo'd mnemonic is still the thing we must catch); it is reported in
    the reason.
    """
    for line_no, line in enumerate(text.splitlines(), 1):
        tokens = [t for t in (t.strip(".,;:'\"()").lower()
                              for t in line.split()) if t]
        for n in sorted(BIP39_LENGTHS):
            if len(tokens) < n:
                break
            for start in range(len(tokens) - n + 1):
                window = tokens[start:start + n]
                if all(t in word_index for t in window):
                    return (line_no, n,
                            _mnemonic_checksum_valid(window, word_index))
    return None


def evaluate(tool_name, tool_input, file_path):
    """Pure decision core: returns (decision, reason), decision in
    allow/ask/deny. Deny (credentials, mnemonics) beats ask (R2/R3)."""
    for glob in ALLOWLIST_GLOBS:
        if fnmatch.fnmatch(file_path, glob):
            return ("allow", f"secrets-write-guard: '{file_path}' matches "
                             f"allowlist glob '{glob}' — documented allow")

    targets = scan_targets(tool_input)
    if not targets:
        return ("deny", f"secrets-write-guard: {tool_name} payload carries no "
                        f"known content field (content/new_string/edits) — "
                        f"fail-closed. If this is a legitimate new tool shape, "
                        f"add its field to CONTENT_FIELDS in the guard.")

    all_text = "\n".join(text for _, text in targets)

    for field, text in targets:
        for name, pattern in PATTERNS:
            if pattern.search(text):
                return ("deny", f"secrets-write-guard: probable secret in "
                                f"{tool_name} ({file_path}, field {field}): "
                                f"pattern '{name}' matched. Move the value to "
                                f"an environment variable or a gitignored .env "
                                f"file; if this path is a legitimate fixture, "
                                f"it must match a versioned ALLOWLIST_GLOBS "
                                f"entry in .claude/hooks/secrets-write-guard.py.")

    try:
        word_index = _load_wordlist()
    except OSError:
        return ("deny", "secrets-write-guard: BIP-39 wordlist unreadable — "
                        "fail-closed per security-plane invariant")
    mn = find_mnemonic_sequence(all_text, word_index)
    if mn:
        line_no, n, checksum = mn
        return ("deny", f"secrets-write-guard: probable BIP-39 mnemonic "
                        f"sequence in {file_path} (line {line_no}: {n} "
                        f"wordlist words, checksum "
                        f"{'valid' if checksum else 'INVALID'}). Move it to a "
                        f"sealed backup, never into a repository file.")

    if not any(fnmatch.fnmatch(file_path, g) for g in TEST_GLOBS) \
            and EVM_KEY_RE.search(all_text):
        return ("ask", f"secrets-write-guard: 0x-prefixed 64-hex value written "
                       f"to {file_path} — EVM key or legitimate hash? Confirm "
                       f"(user policy R2: ask outside test paths).")

    pii = len(EMAIL_RE.findall(all_text)) + len(PHONE_E164_RE.findall(all_text))
    if pii >= PII_DENSITY_THRESHOLD:
        return ("ask", f"secrets-write-guard: {pii} email/phone matches in one "
                       f"payload (threshold {PII_DENSITY_THRESHOLD}) — possible "
                       f"third-party PII dump in {file_path}. Confirm "
                       f"(user policy R3: density ask).")

    return ("allow", f"secrets-write-guard: no secret/RED patterns matched in "
                     f"{tool_name} ({file_path})")


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(decide("deny", "secrets-write-guard: unparseable stdin — "
                                "fail-closed per security-plane invariant"))
    if not isinstance(payload, dict):
        sys.exit(decide("deny", "secrets-write-guard: unexpected stdin shape — "
                                "fail-closed"))
    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input") or {}

    if tool_name not in WRITE_TOOLS:
        sys.exit(decide("allow", "secrets-write-guard: not a write tool — "
                                 "nothing to scan"))

    file_path = tool_input.get("file_path")
    if not file_path or not isinstance(file_path, str):
        sys.exit(decide("deny", "secrets-write-guard: write without a readable "
                                "file_path — fail-closed"))

    decision, reason = evaluate(tool_name, tool_input, file_path)
    sys.exit(decide(decision, reason))


if __name__ == "__main__":
    main()

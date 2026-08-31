#!/usr/bin/env python3
"""Phase 0 inventory for issue #69 (Ralph-Lite delete-first simplification).

Enumerates the real runtime (active settings, security manifests, installers,
sources) and classifies every record with exactly one owner. Fails loudly:

  - a missing/unparseable input fails the run (exit 2)
  - any record that matches no classification rule yields UNKNOWN and fails
    the run (exit 3) -- there is deliberately NO default owner
  - --selftest proves the UNKNOWN path fires without touching the tree (exit 4)

Owner semantics (from #69):
  SECURITY-REQUIRED     security plane: manifest controls, their sources,
                        security profile registrations, security config.
                        Deletion is protected by regression tests.
  TASK-STATE-BOUNDARY   canonical task state + Recall plane: session lifecycle,
                        Q-team coordination, plan/task state, memory/recall,
                        statusline/state display, task-cycle gates.
  EXPLICIT/COLD-PATH    invoked only explicitly: native Claude surfaces
                        (skills/agents/commands), installers, sync, validators,
                        support utilities, installable-profile components.
  DELETE                dead: build artifacts, stale residue, orphan sources
                        (zero tracked references), broken registrations.

Activation (orthogonal metadata):
  hot   auto-fired by the active settings (hook registration or statusLine)
  cold  present but only explicitly invoked / installable / referenced
  orphan|stale|n/a  for DELETE rows, describes why it is dead

No provider-specific model ID is used anywhere in classification (acceptance).
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

OWNERS = ("SECURITY-REQUIRED", "TASK-STATE-BOUNDARY", "EXPLICIT/COLD-PATH", "DELETE", "UNKNOWN")

# --- security sets -----------------------------------------------------------

# Active security functions named by evidence, not by the manifests:
# - audit-secrets.js: PostToolUse secrets-audit control; audit-only (cannot
#   block). #69 section 1B ties it to the declared gap `secrets-ordinary-work`.
# - promptify-security.sh: credential redaction (SEC-110), clipboard consent
#   and audit logging library; active registration. NOTE: absent from
#   SECURITY_BASELINE.json -> surfaced as a finding (unprotected by the
#   manifest's regression tests).
EXTRA_SECURITY_NAMES = {"audit-secrets.js", "promptify-security.sh"}

# --- TASK-STATE-BOUNDARY plane rules (ordered, first match wins) --------------

STATE_RULES = [
    (r"^(pre-compact|post-compact|session-|inject-session|wake-up-layer-stack|"
     r"context-warning|context-mode-cache-heal|auto-sync-global|periodic-reminder)",
     "session-lifecycle"),
    (r"^(qteam-|ralph-subagent-|subagent-stop-universal|teammate-idle|agent-diary-writer)",
     "qteam-coordination"),
    (r"(plan-state|plan-sync|plan-analysis|todo-plan-sync|migrate-plan-state|lsa-pre-step|"
     r"task-list-projection|task-orchestration|progress-tracker|batch-progress-tracker|"
     r"status-auto-check|action-report-tracker)",
     "plan-task-state"),
    (r"^(vault-|memory-projection|smart-memory-search|decision-extractor|"
     r"semantic-realtime-extractor|dream-consolidate|continuous-learning|ledger-manager|"
     r"handoff-generator|agent-memory-buffer|ralph-state|event-bus)",
     "memory-recall"),
    (r"^(orchestrator-|project-state|project-backup-metadata|checkpoint-)",
     "orchestrator-state"),
    (r"^(universal-|anti-rationalization|adversarial-auto-trigger|aristotle-|"
     r"recursive-decompose|command-router|parallel-explore|quality-parallel-async|"
     r"fast-path-check|smart-skill-reminder|stop-slop-hook)",
     "methodology-gates"),
    (r"^(statusline|force-statusline-refresh)",
     "state-display"),
    (r"^(react-doctor|sentry-report|code-review-auto|ai-code-audit|console-log-detector|"
     r"auto-format-prettier|ralph-stop-quality-gate|task-completed-quality-gate)",
     "task-cycle-gate"),
]

# Reference counting must ignore the inventory's own outputs so re-runs stay
# deterministic (a report that cites a hook name must not make the hook look
# "referenced" on the next run).
REF_EXCLUDE = re.compile(
    r"(^|/)(results/|\.claude/worktrees/)"
    r"|phase0_inventory"
    r"|PHASE0_INVENTORY"
)

ROOT = None
SEC_NAME_RE = re.compile(r"\.(sh|py|js|mjs|allowlist)$")


def fail(msg, code=2):
    print(f"FATAL: {msg}", file=sys.stderr)
    sys.exit(code)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def git_root_check(root: Path):
    r = run(["git", "rev-parse", "--show-toplevel"], cwd=root)
    if r.returncode != 0:
        fail(f"git rev-parse failed in {root}: {r.stderr.strip()}")


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_hook_registrations(settings_path: Path, label: str):
    """Return list of (event, matcher, command) from a settings-shaped file."""
    try:
        data = json.loads(settings_path.read_text())
    except FileNotFoundError:
        fail(f"{label}: file not found: {settings_path}")
    except json.JSONDecodeError as e:
        fail(f"{label}: unparseable JSON in {settings_path}: {e}")
    rows = []
    for event, groups in (data.get("hooks") or {}).items():
        for group in groups:
            matcher = group.get("matcher", "-")
            for hook in group.get("hooks", []):
                cmd = hook.get("command")
                if not cmd:
                    fail(f"{label}: hook registration without command under {event}/{matcher}")
                rows.append((event, matcher, cmd))
    return rows


def extract_path(cmd: str):
    """Extract the script path a registered hook command resolves to.

    Handles: quoted paths, bash/node interpreter prefixes, output redirections
    (">/dev/null 2>&1"), trailing background '&', $CLAUDE_PROJECT_DIR and ~.
    Returns (expanded_path_or_None, basename_or_None).
    """
    c = cmd.strip().strip('"').strip("'")
    tokens = c.split()
    interpreter = {"bash", "sh", "node", "python3", "python", "npm", "npx"}
    for tok in tokens:
        if tok in interpreter:
            continue
        if tok in {"&", "&&", "||", "2>&1"} or tok.startswith(">") or tok.startswith("<"):
            continue
        if SEC_NAME_RE.search(tok.strip('"').strip("'")):
            p = tok.strip('"').strip("'")
            home = Path(os.environ.get("HOME", "~"))
            if p.startswith("$CLAUDE_PROJECT_DIR"):
                p = str(ROOT) + p[len("$CLAUDE_PROJECT_DIR"):]
            elif p.startswith("~"):
                p = str(home) + p[1:]
            if not p.startswith("/"):
                p = str(ROOT / p)
            return p, Path(p).name
    return None, None


def tracked_reference_files(name: str, self_relpath):
    """Tracked files whose content references `name`, excluding self and the
    inventory's own outputs. Returns sorted list of repo-relative paths."""
    r = run(["git", "grep", "-l", "-F", "--", name], cwd=ROOT)
    files = []
    if r.returncode == 0:
        for line in r.stdout.splitlines():
            line = line.strip()
            if not line or line == self_relpath:
                continue
            if REF_EXCLUDE.search(line):
                continue
            files.append(line)
    elif r.returncode not in (0, 1):
        fail(f"git grep failed for {name!r}: {r.stderr.strip()}")
    return sorted(set(files))


def state_match(basename: str):
    for pattern, plane in STATE_RULES:
        if re.search(pattern, basename):
            return plane
    return None


def base_name_of(relpath: str) -> str:
    return relpath.rsplit("/", 1)[-1]


def classify(area, name, relpath, *, is_active, in_secprofile, in_baseline,
             in_example, ref_files, resolved_missing):
    """Exactly-one-owner classifier. Returns (owner, plane, activation, note).

    No default owner: anything not covered by an explicit rule yields UNKNOWN.
    """
    if area not in ("active-registration", "security-manifest", "settings-record",
                    "hooks", "rules-src", "agents", "skills", "commands",
                    "claude-scripts", "distributors", "installed-residue",
                    "artifacts"):
        return ("UNKNOWN", "unknown-area", "n/a", f"area {area!r} has no rules")

    if area == "security-manifest":
        return ("SECURITY-REQUIRED", "security-manifest", "n/a",
                "declarative security plane manifest")

    if area == "installed-residue":
        if name == "rules.pre-w5-symlink":
            return ("DELETE", "stale-residue", "stale",
                    "symlink to repo .claude/rules; global rules are now a copy")
        if name == "hooks":
            return ("TASK-STATE-BOUNDARY", "activation-symlink", "hot",
                    "symlink ~/.claude/hooks -> repo .claude/hooks; carries every active hook")
        if name == "rules":
            return ("TASK-STATE-BOUNDARY", "distributed-copies", "hot",
                    "header-stamped copies synced by sync-rules-from-source.sh")
        if name == "scripts":
            return ("TASK-STATE-BOUNDARY", "distributed-copies", "hot",
                    "installed copy; contains active statusline-ralph.sh")
        return ("EXPLICIT/COLD-PATH", "distributed-copies", "cold",
                "installed copy of native invocation surface")

    if area == "settings-record":
        if name == "permissions" or name == "K8S_GUARD_ALLOWED_CONTEXTS":
            return ("SECURITY-REQUIRED", "security-config", "hot",
                    "permission/security configuration record")
        return ("TASK-STATE-BOUNDARY", "runtime-config", "hot",
                "active settings record; deleting the key changes runtime state")

    # Security ownership first (manifest-driven, then profile, then explicit).
    if in_baseline:
        return ("SECURITY-REQUIRED", "security-baseline-control", "hot" if is_active else "cold",
                "named by SECURITY_BASELINE.json controls")
    if name in EXTRA_SECURITY_NAMES:
        return ("SECURITY-REQUIRED", "secrets-audit", "hot",
                "active secrets audit; companion of declared gap secrets-ordinary-work")
    if in_secprofile:
        return ("SECURITY-REQUIRED", "security-profile-registration", "cold",
                "registered by settings.security-only.json")

    if area == "active-registration":
        if resolved_missing:
            return ("DELETE", "broken-registration", "n/a",
                    "active registration resolves to a missing file")
        plane = state_match(name)
        if plane:
            return ("TASK-STATE-BOUNDARY", plane, "hot", "active registration")
        return ("UNKNOWN", "unclassified-active-registration", "hot",
                "active hook matches no rule; extend STATE_RULES or security sets")

    if area == "hooks":
        if is_active:
            plane = state_match(name)
            if plane:
                return ("TASK-STATE-BOUNDARY", plane, "hot", "active registration")
            return ("UNKNOWN", "unclassified-active-hook", "hot",
                    "active hook matches no rule")
        if in_example:
            plane = state_match(name)
            return ("EXPLICIT/COLD-PATH", plane or "installable-profile", "cold",
                    "present in versioned install profile (settings.json.example), not active")
        if ref_files:
            plane = state_match(name)
            if plane:
                return ("TASK-STATE-BOUNDARY", plane, "cold",
                        f"referenced by {len(ref_files)} tracked file(s)")
            return ("EXPLICIT/COLD-PATH", "referenced-utility", "cold",
                    f"referenced by {len(ref_files)} tracked file(s)")
        return ("DELETE", "orphan-no-references", "orphan",
                "no tracked reference anywhere (registration, consumer, docs)")

    if area == "rules-src":
        return ("TASK-STATE-BOUNDARY", "process-rules-hot-context", "hot",
                "process rule injected every session; distributed as header-stamped copy")

    if area == "agents":
        if name.endswith(".old"):
            return ("DELETE", "audit-residue", "stale", "renamed audit artifact")
        return ("EXPLICIT/COLD-PATH", "native-agent", "cold",
                "native Claude Task surface (spawned on demand)")

    if area == "skills":
        return ("EXPLICIT/COLD-PATH", "native-skill", "cold",
                "native Claude skill (invoked explicitly)")

    if area == "commands":
        return ("EXPLICIT/COLD-PATH", "native-command", "cold",
                "native Claude slash command")

    if area == "claude-scripts":
        plane = state_match(name)
        if plane:
            return ("TASK-STATE-BOUNDARY", plane, "hot" if is_active else "cold",
                    "state machinery support script")
        if ref_files:
            return ("EXPLICIT/COLD-PATH", "support-utility", "cold",
                    f"referenced by {len(ref_files)} tracked file(s)")
        return ("DELETE", "orphan-no-references", "orphan",
                "no tracked reference anywhere")

    if area == "distributors":
        return ("EXPLICIT/COLD-PATH", "installer-validator-sync", "cold",
                "manual/CI invocation surface")

    if area == "artifacts":
        return ("DELETE", "build-artifact-untracked", "stale",
                "generated bytecode cache; not tracked by git")

    return ("UNKNOWN", "unreachable", "n/a", "unhandled area")  # pragma: no cover


def main():
    global ROOT
    ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else fail("usage: phase0_inventory.py ROOT [--selftest]")
    selftest = "--selftest" in sys.argv[2:]

    git_root_check(ROOT)

    active_settings = Path(os.environ.get("HOME", "")) / ".claude" / "settings.json"
    sec_only = ROOT / ".claude" / "security" / "settings.security-only.json"
    baseline = ROOT / ".claude" / "security" / "SECURITY_BASELINE.json"
    example = ROOT / ".claude" / "settings.json.example"

    if selftest:
        return selftest_main()

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    main_sha = run(["git", "rev-parse", "main"], cwd=ROOT).stdout.strip()
    head_sha = run(["git", "rev-parse", "HEAD"], cwd=ROOT).stdout.strip()
    branch = run(["git", "branch", "--show-current"], cwd=ROOT).stdout.strip()
    if not (len(main_sha) == 40 and len(head_sha) == 40):
        fail("could not resolve main/HEAD SHAs")
    if not active_settings.is_file():
        fail(f"ACTIVE settings not found: {active_settings}")

    out_dir = ROOT / "results" / "phase0"
    out_dir.mkdir(parents=True, exist_ok=True)
    snapshot = out_dir / "settings-active.snapshot.json"
    shutil.copy2(active_settings, snapshot)
    settings_sha = sha256_file(active_settings)

    # ---- authoritative security sets ----------------------------------------
    try:
        baseline_data = json.loads(baseline.read_text())
    except (FileNotFoundError, json.JSONDecodeError) as e:
        fail(f"SECURITY_BASELINE.json unreadable: {e}")
    baseline_paths = set()
    for control in baseline_data.get("controls", []):
        if control.get("hook"):
            baseline_paths.add(control["hook"])
        for src in control.get("sources", []) or []:
            baseline_paths.add(src)
    baseline_names = {base_name_of(p) for p in baseline_paths}
    baseline_ids = [c.get("id", "?") for c in baseline_data.get("controls", [])]
    gap_ids = []
    for g in baseline_data.get("gaps", []) or []:
        gap_ids.append(g.get("id") or g.get("name") or str(g))

    secprofile_regs = parse_hook_registrations(sec_only, "settings.security-only.json")
    secprofile_names = {extract_path(cmd)[1] for _, _, cmd in secprofile_regs}
    if None in secprofile_names:
        fail("settings.security-only.json: a registration command yielded no path")

    active_regs = parse_hook_registrations(active_settings, "active settings")
    if not active_regs:
        fail("active settings contain ZERO hook registrations")

    example_regs = parse_hook_registrations(example, "settings.json.example")
    example_names = {extract_path(cmd)[1] for _, _, cmd in example_regs if extract_path(cmd)[1]}

    # ---- active registration rows -------------------------------------------
    rows = []          # dict rows for TSV + report
    active_names = set()
    statusline_cmd = None
    try:
        sdata = json.loads(active_settings.read_text())
        sl = sdata.get("statusLine") or {}
        statusline_cmd = sl.get("command")
    except json.JSONDecodeError as e:
        fail(f"active settings unparseable on re-read: {e}")

    for event, matcher, cmd in active_regs:
        path, name = extract_path(cmd)
        exists = bool(path) and Path(path).exists()
        active_names.add(name)
        owner, plane, activation, note = classify(
            "active-registration", name, None,
            is_active=True, in_secprofile=name in secprofile_names,
            in_baseline=name in baseline_names, in_example=name in example_names,
            ref_files=[], resolved_missing=not exists)
        rows.append(dict(area="active-registration", name=name, event=event,
                         matcher=matcher, command=cmd, resolved=path,
                         exists=exists, owner=owner, plane=plane,
                         activation=activation, note=note))

    # statusLine record (active, hot)
    sl_name, sl_exists, sl_path = None, False, None
    if statusline_cmd:
        sl_path, sl_name = extract_path(statusline_cmd)
        sl_exists = bool(sl_path) and Path(sl_path).exists()
        owner, plane, activation, note = classify(
            "claude-scripts", sl_name or "statusline-ralph.sh", None,
            is_active=True, in_secprofile=False, in_baseline=False,
            in_example=False, ref_files=[], resolved_missing=not sl_exists)
        rows.append(dict(area="active-registration", name=sl_name or "statusline",
                         event="statusLine", matcher="-", command=statusline_cmd,
                         resolved=sl_path, exists=sl_exists, owner=owner,
                         plane=plane, activation=activation, note=note))

    # settings-level records: top-level keys + env keys
    for key in sorted(sdata.keys()):
        owner, plane, activation, note = classify(
            "settings-record", key, None, is_active=True, in_secprofile=False,
            in_baseline=False, in_example=False, ref_files=[], resolved_missing=False)
        rows.append(dict(area="settings-record", name=key, event="settings-key",
                         matcher="-", command=f"~/.claude/settings.json:{key}",
                         resolved="", exists=True, owner=owner, plane=plane,
                         activation=activation, note=note))
    for key in sorted((sdata.get("env") or {}).keys()):
        owner, plane, activation, note = classify(
            "settings-record", key, None, is_active=True, in_secprofile=False,
            in_baseline=False, in_example=False, ref_files=[], resolved_missing=False)
        rows.append(dict(area="settings-record", name=key, event="env",
                         matcher="-", command=f"env:{key}", resolved="", exists=True,
                         owner=owner, plane=plane, activation=activation, note=note))

    # ---- security manifest rows ----------------------------------------------
    for fname in ("SECURITY_BASELINE.json", "settings.security-only.json"):
        owner, plane, activation, note = classify(
            "security-manifest", fname, None, is_active=False, in_secprofile=False,
            in_baseline=False, in_example=False, ref_files=[], resolved_missing=False)
        rows.append(dict(area="security-manifest", name=fname, event="-", matcher="-",
                         command=f".claude/security/{fname}", resolved="", exists=True,
                         owner=owner, plane=plane, activation=activation, note=note))

    # ---- hooks sources --------------------------------------------------------
    hooks_dir = ROOT / ".claude" / "hooks"
    hook_files, artifact_paths = [], []
    for p in sorted(hooks_dir.iterdir()):
        rel = str(p.relative_to(ROOT))
        if p.is_dir() and p.name == "__pycache__":
            artifact_paths.append(rel)
        elif p.is_dir() and p.name == "k8s_context_guard":
            for sub in sorted(p.iterdir()):
                if sub.is_dir() and sub.name == "__pycache__":
                    artifact_paths.append(str(sub.relative_to(ROOT)))
                elif sub.is_file() and sub.suffix == ".py":
                    hook_files.append(str(sub.relative_to(ROOT)))
        elif p.is_dir() and p.name == "lib":
            for sub in sorted(p.iterdir()):
                if sub.is_file():
                    hook_files.append(str(sub.relative_to(ROOT)))
        elif p.is_file():
            hook_files.append(rel)

    hook_relset = set(hook_files)
    for rel in hook_files:
        name = base_name_of(rel)
        is_active = name in active_names or name in secprofile_names
        refs = tracked_reference_files(name, rel)
        owner, plane, activation, note = classify(
            "hooks", name, rel, is_active=is_active,
            in_secprofile=name in secprofile_names, in_baseline=name in baseline_names,
            in_example=name in example_names, ref_files=refs, resolved_missing=False)
        rows.append(dict(area="hooks", name=name, event="-", matcher="-", command=rel,
                         resolved="", exists=True, owner=owner, plane=plane,
                         activation=activation, note=note, refs=len(refs)))
    for rel in artifact_paths:
        owner, plane, activation, note = classify(
            "artifacts", base_name_of(rel), rel, is_active=False, in_secprofile=False,
            in_baseline=False, in_example=False, ref_files=[], resolved_missing=False)
        rows.append(dict(area="artifacts", name=rel, event="-", matcher="-",
                         command=rel, resolved="", exists=True, owner=owner,
                         plane=plane, activation=activation, note=note))

    # ---- rules-src / agents / skills / commands / claude-scripts --------------
    def add_dir_rows(area, dirpath, classify_area, skip=None):
        d = ROOT / dirpath
        if not d.is_dir():
            fail(f"expected source directory missing: {d}")
        for p in sorted(d.iterdir()):
            if skip and skip(p):
                continue
            name = p.name
            refs = tracked_reference_files(name, str(p.relative_to(ROOT)))
            owner, plane, activation, note = classify(
                classify_area, name, str(p.relative_to(ROOT)), is_active=False,
                in_secprofile=False, in_baseline=False, in_example=False,
                ref_files=refs, resolved_missing=False)
            rows.append(dict(area=classify_area, name=name, event="-", matcher="-",
                             command=str(p.relative_to(ROOT)), resolved="", exists=True,
                             owner=owner, plane=plane, activation=activation,
                             note=note, refs=len(refs)))

    add_dir_rows("rules-src", ".claude/rules-src", "rules-src")
    add_dir_rows("agents", ".claude/agents", "agents")
    add_dir_rows("skills", ".claude/skills", "skills")
    add_dir_rows("commands", ".claude/commands", "commands")

    scripts_dir = ROOT / ".claude" / "scripts"
    for p in sorted(scripts_dir.iterdir()):
        if not p.is_file():
            continue
        name = p.name
        is_active = (sl_name == name)
        refs = tracked_reference_files(name, str(p.relative_to(ROOT)))
        owner, plane, activation, note = classify(
            "claude-scripts", name, str(p.relative_to(ROOT)), is_active=is_active,
            in_secprofile=False, in_baseline=False, in_example=False,
            ref_files=refs, resolved_missing=False)
        rows.append(dict(area="claude-scripts", name=name, event="-", matcher="-",
                         command=str(p.relative_to(ROOT)), resolved="", exists=True,
                         owner=owner, plane=plane, activation=activation,
                         note=note, refs=len(refs)))

    # ---- distributors (installers / sync / validators) ------------------------
    dist_names = []
    for sub, pattern in ((".", "install*.sh"), ("scripts", "install-*.sh"),
                         ("scripts", "validate-*.sh"),
                         (".claude/scripts", "validate-*.sh"),
                         (".claude/scripts", "sync-*.sh"),
                         ("scripts", "sync-*.sh")):
        base = ROOT / sub
        for p in sorted(base.glob(pattern)):
            if p.is_file():
                rel = str(p.relative_to(ROOT))
                if rel not in dist_names:
                    dist_names.append(rel)
    for rel in dist_names:
        owner, plane, activation, note = classify(
            "distributors", base_name_of(rel), rel, is_active=False,
            in_secprofile=False, in_baseline=False, in_example=False,
            ref_files=[], resolved_missing=False)
        rows.append(dict(area="distributors", name=base_name_of(rel), event="-",
                         matcher="-", command=rel, resolved="", exists=True,
                         owner=owner, plane=plane, activation=activation, note=note))

    # ---- installed residue map -------------------------------------------------
    home_claude = Path(os.environ.get("HOME", "")) / ".claude"

    def residue_state(installed: Path):
        if installed.is_symlink():
            return "SYMLINK", os.readlink(installed)
        if installed.is_dir():
            return "DIR-COPY", ""
        return "MISSING", ""

    residue_rows = []
    residue_details = {}

    def strip_sync_header(text: str) -> str:
        """Port of strip_sync_header() in scripts/validate-global-infrastructure.sh:
        installed rule copies carry a <!-- SOURCE: ... --> stamp that the repo
        source does NOT have by design; compare modulo that header."""
        out, in_hdr, skip_blank = [], False, False
        for i, line in enumerate(text.splitlines()):
            if i == 0 and line.startswith("<!-- SOURCE:"):
                in_hdr = True
                continue
            if in_hdr:
                if "-->" in line:
                    in_hdr, skip_blank = False, True
                continue
            if skip_blank and line.strip() == "":
                skip_blank = False
                continue
            skip_blank = False
            out.append(line)
        return "\n".join(out)

    def name_sets(repo_dir: Path, installed_dir: Path):
        repo_names = {p.name for p in repo_dir.iterdir()} if repo_dir.is_dir() else set()
        inst_names = {p.name for p in installed_dir.iterdir()} if installed_dir.is_dir() else set()
        return repo_names, inst_names

    def file_drift(repo_dir: Path, installed_dir: Path, names):
        """Common names whose file contents differ (byte-compare)."""
        drift = []
        for n in sorted(names):
            rf, inf = repo_dir / n, installed_dir / n
            if rf.is_file() and inf.is_file() and sha256_file(rf) != sha256_file(inf):
                drift.append(n)
        return drift

    installed_map = [
        ("hooks", ROOT / ".claude" / "hooks", home_claude / "hooks"),
        ("rules", ROOT / ".claude" / "rules-src", home_claude / "rules"),
        ("agents", ROOT / ".claude" / "agents", home_claude / "agents"),
        ("skills", ROOT / ".claude" / "skills", home_claude / "skills"),
        ("scripts", ROOT / ".claude" / "scripts", home_claude / "scripts"),
        ("commands", ROOT / ".claude" / "commands", home_claude / "commands"),
        ("rules.pre-w5-symlink", None, home_claude / "rules.pre-w5-symlink"),
    ]
    for label, repo_dir, installed in installed_map:
        kind, target = residue_state(installed)
        owner, plane, activation, note = classify(
            "installed-residue", label, None, is_active=False, in_secprofile=False,
            in_baseline=False, in_example=False, ref_files=[], resolved_missing=False)
        rows.append(dict(area="installed-residue", name=label, event="-", matcher="-",
                         command=str(installed), resolved=target, exists=kind != "MISSING",
                         owner=owner, plane=plane, activation=activation, note=note))
        detail = {"kind": kind, "target": target}
        if label == "rules" and kind == "DIR-COPY":
            # Compare the 7 rules-src files against their installed copies
            # MODULO the sync header (byte-diff would flag the stamp as drift).
            drift, missing = [], []
            for src in sorted(repo_dir.glob("*.md")):
                inst = installed / src.name
                if not inst.is_file():
                    missing.append(src.name)
                elif (strip_sync_header(src.read_text())
                      != strip_sync_header(inst.read_text())):
                    drift.append(src.name)
            inst_names = {p.name for p in installed.iterdir()}
            src_names = {p.name for p in repo_dir.iterdir()}
            # installed-only top-level entries with NO repo source at all
            nosrc = sorted(n for n in inst_names - src_names
                           if n in ("learned", "proven"))
            nosrc_counts = {n: sum(1 for p in (installed / n).rglob("*") if p.is_file())
                            for n in nosrc}
            detail.update(kind="COPY-OF rules-src (header-stamped)",
                          differing=drift, missing_installed=missing,
                          installed_only_nosource=nosrc, nosource_counts=nosrc_counts,
                          in_sync=f"{len(src_names) - len(drift) - len(missing)}/{len(list(repo_dir.glob('*.md')))}")
        elif label in ("agents", "skills", "scripts", "commands") and kind == "DIR-COPY":
            repo_names, inst_names = name_sets(repo_dir, installed)
            if label == "skills":
                # dotfiles (.gitignore, .skill-lint-ignore) are not skills
                repo_names = {n for n in repo_names if not n.startswith(".")}
                # per-skill parity at the entry that matters: SKILL.md
                common_dirs = {n for n in repo_names & inst_names
                               if (repo_dir / n).is_dir()}
                skill_drift = []
                for n in sorted(common_dirs):
                    a, b = repo_dir / n / "SKILL.md", installed / n / "SKILL.md"
                    if a.is_file() and b.is_file() and sha256_file(a) != sha256_file(b):
                        skill_drift.append(n)
                detail.update(kind="COPY", only_repo=sorted(repo_names - inst_names),
                              only_installed=sorted(inst_names - repo_names),
                              skillmd_drift=skill_drift,
                              common=len(common_dirs))
            elif label == "agents":
                common = repo_names & inst_names
                detail.update(kind="COPY", only_repo=sorted(repo_names - inst_names),
                              only_installed=sorted(inst_names - repo_names),
                              file_drift=file_drift(repo_dir, installed, common))
            else:
                detail.update(kind="COPY", only_repo=sorted(repo_names - inst_names),
                              only_installed=sorted(inst_names - repo_names))
        residue_details[label] = detail

    # ---- assertions: zero unknown, coverage ------------------------------------
    unknown = [r for r in rows if r["owner"] == "UNKNOWN"]
    total = len(rows)
    if total == 0:
        fail("inventory produced ZERO rows", 3)
    if unknown:
        print(f"FAIL: {len(unknown)} UNKNOWN entries — classification incomplete:", file=sys.stderr)
        for r in unknown:
            print(f"  area={r['area']} name={r['name']} plane={r['plane']}", file=sys.stderr)
        sys.exit(3)

    active_registered_names = {r["name"] for r in rows if r["area"] == "active-registration"}
    missing_regs = [r for r in rows if r["area"] == "active-registration" and not r["exists"]]

    # ---- write TSV --------------------------------------------------------------
    tsv_path = out_dir / "inventory.tsv"
    cols = ["area", "name", "event", "matcher", "command", "resolved", "exists",
            "owner", "plane", "activation", "refs", "note"]
    with open(tsv_path, "w") as f:
        f.write("\t".join(cols) + "\n")
        for r in sorted(rows, key=lambda x: (x["area"], x["name"], x["event"], x["command"])):
            vals = [str(r.get(c, "")) for c in cols]
            vals = [v.replace("\t", " ").replace("\n", " ") for v in vals]
            f.write("\t".join(vals) + "\n")

    # ---- findings ----------------------------------------------------------------
    findings = []

    stale = [r for r in rows if r["owner"] == "DELETE" and r["plane"] == "stale-residue"]
    for r in stale:
        findings.append(f"Stale installed residue: `~/.claude/{r['name']}` — {r['note']}. "
                        f"Deletion PR must remove the installed path (outside this repo).")

    old_files = [r for r in rows if r["area"] == "agents" and r["name"].endswith(".old")]
    for r in old_files:
        findings.append(f"Audit residue tracked in git: `.claude/agents/{r['name']}` (DELETE).")

    orphans = [r for r in rows if r["plane"] == "orphan-no-references"]
    if orphans:
        names = ", ".join(f"`{r['command']}`" for r in orphans)
        findings.append(f"Orphan sources (zero tracked references): {names}.")

    broken = [r for r in rows if r["plane"] == "broken-registration"]
    for r in broken:
        findings.append(f"BROKEN registration: {r['event']}/{r['matcher']} -> {r['command']} "
                        f"resolves to a missing file.")

    silent = [r for r in rows if r["area"] == "active-registration" and ">/dev/null" in r["command"]]
    for r in silent:
        findings.append(f"Registration swallows its own output (`>/dev/null 2>&1 &`): "
                        f"{r['name']} ({r['event']}) — failures are invisible by design of the "
                        f"registration, not of the hook. Noted, not fixed (out of scope).")

    ex_only = sorted(example_names - active_names - secprofile_names)
    if ex_only:
        findings.append("Installable-profile-only hooks (in settings.json.example, not active): "
                        + ", ".join(f"`{n}`" for n in ex_only) + ".")

    skills_res = residue_details.get("skills", {})
    if skills_res.get("only_installed"):
        findings.append(
            "Installed-only skills (present in ~/.claude/skills, absent from the repo; "
            "installed from sources outside this repo): "
            + ", ".join(f"`{n}`" for n in skills_res["only_installed"]) + ".")
    if skills_res.get("only_repo"):
        findings.append(
            "Repo-only skills (versioned but never installed to ~/.claude/skills): "
            + ", ".join(f"`{n}`" for n in skills_res["only_repo"]) + ".")
    if skills_res.get("skillmd_drift"):
        findings.append("SKILL.md content drift between repo and installed copy for: "
                        + ", ".join(f"`{n}`" for n in skills_res["skillmd_drift"]) + ".")

    rules_res = residue_details.get("rules", {})
    if rules_res.get("differing"):
        findings.append("Real rule drift (modulo sync header) between repo rules-src and "
                        "~/.claude/rules: " + ", ".join(f"`{n}`" for n in rules_res["differing"])
                        + ". Re-run sync-rules-from-source.sh to repair.")
    if rules_res.get("installed_only_nosource"):
        parts = [f"`{n}` ({rules_res['nosource_counts'][n]} files)"
                 for n in rules_res["installed_only_nosource"]]
        findings.append("Under ~/.claude/rules, entries with NO repo source (generated/"
                        "maintained globally from the vault, e.g. by vault generators — a "
                        "repo-side deletion PR cannot remove them): " + ", ".join(parts) + ".")

    agents_res = residue_details.get("agents", {})
    if agents_res.get("file_drift"):
        findings.append("Agent copy drift (installed ~/.claude/agents differs from repo): "
                        + ", ".join(f"`{n}`" for n in agents_res["file_drift"]) + ".")

    commands_res = residue_details.get("commands", {})
    if commands_res.get("only_repo") or commands_res.get("only_installed"):
        findings.append("Command copy drift (~/.claude/commands vs repo .claude/commands): "
                        f"repo-only={commands_res.get('only_repo') or []}, "
                        f"installed-only={commands_res.get('only_installed') or []}.")
    if (ROOT / ".claude" / "commands").is_dir() and (home_claude / "commands").is_dir():
        c_drift = file_drift(ROOT / ".claude" / "commands", home_claude / "commands",
                             {p.name for p in (ROOT / ".claude" / "commands").iterdir()}
                             & {p.name for p in (home_claude / "commands").iterdir()})
        if c_drift:
            findings.append("Command content drift (installed differs from repo): "
                            + ", ".join(f"`{n}`" for n in c_drift) + ".")

    findings.append("audit-secrets.js is audit-only (cannot block/redact); #69 §1B `secrets-ordinary-work` "
                    "covers its completion. Classified SECURITY-REQUIRED as the active secrets-audit control.")

    undeclared = sorted(n for n in set(EXTRA_SECURITY_NAMES) & active_names
                        if n not in baseline_names)
    if undeclared:
        findings.append("Active security functions NOT declared in SECURITY_BASELINE.json "
                        "(hence unprotected by its regression tests): "
                        + ", ".join(f"`{n}`" for n in undeclared)
                        + ". Phase 1B (#69) should declare them or re-scope them.")

    # ---- summary matrix ------------------------------------------------------------
    areas = []
    for r in rows:
        if r["area"] not in areas:
            areas.append(r["area"])
    matrix_lines = ["| area | total | " + " | ".join(o for o in OWNERS if o != "UNKNOWN") + " |",
                    "|---|---|" + "---|" * 4]
    for a in sorted(areas):
        subset = [r for r in rows if r["area"] == a]
        counts = [sum(1 for r in subset if r["owner"] == o) for o in OWNERS if o != "UNKNOWN"]
        matrix_lines.append(f"| {a} | {len(subset)} | " + " | ".join(str(c) for c in counts) + " |")
    totals = [sum(1 for r in rows if r["owner"] == o) for o in OWNERS if o != "UNKNOWN"]
    matrix_lines.append(f"| **TOTAL** | **{total}** | " + " | ".join(f"**{c}**" for c in totals) + " |")

    # ---- report ------------------------------------------------------------------------
    report = ROOT / "docs" / "benchmark" / "PHASE0_INVENTORY_2026-08-31.md"
    report.parent.mkdir(parents=True, exist_ok=True)

    def md_table(subset, cols_):
        head = "| " + " | ".join(cols_) + " |"
        sep = "|" + "---|" * len(cols_)
        lines = [head, sep]
        for r in subset:
            cells = []
            for c in cols_:
                v = str(r.get(c, ""))
                cells.append(v.replace("|", "\\|").replace("\n", " "))
            lines.append("| " + " | ".join(cells) + " |")
        return "\n".join(lines)

    reg_cols = ["event", "matcher", "name", "owner", "plane", "exists", "note"]
    src_cols = ["command", "owner", "plane", "activation", "note"]

    act = [r for r in rows if r["area"] == "active-registration"]
    reg_table = md_table(sorted(act, key=lambda r: (r["event"], r["name"])), reg_cols)
    src_tables = []
    for a in sorted(set(r["area"] for r in rows) - {"active-registration"}):
        subset = sorted([r for r in rows if r["area"] == a], key=lambda r: (r["owner"], r["name"]))
        src_tables.append(f"### {a} ({len(subset)} records)\n\n" + md_table(subset, src_cols))

    residue_lines = ["| installed path | kind | target | owner | parity/drift |",
                     "|---|---|---|---|---|"]
    for label, detail in residue_details.items():
        inst = str(home_claude / label)
        row = next((r for r in rows if r["area"] == "installed-residue" and r["name"] == label), {})
        parity = "-"
        if label == "rules" and "in_sync" in detail:
            bits = [f"{detail['in_sync']} in sync (modulo header)"]
            if detail.get("differing"):
                bits.append(f"DRIFT: {', '.join(detail['differing'])}")
            if detail.get("missing_installed"):
                bits.append(f"missing: {', '.join(detail['missing_installed'])}")
            for n in detail.get("installed_only_nosource", []):
                bits.append(f"{n}={detail['nosource_counts'][n]} files (no repo source)")
            parity = "; ".join(bits)
        elif label == "skills" and "common" in detail:
            bits = [f"{detail['common']} common skills"]
            bits.append(f"{len(detail['only_repo'])} repo-only")
            bits.append(f"{len(detail['only_installed'])} installed-only")
            if detail.get("skillmd_drift"):
                bits.append(f"SKILL.md drift: {', '.join(detail['skillmd_drift'])}")
            parity = "; ".join(bits)
        elif label == "agents" and "file_drift" in detail:
            bits = [f"{len(detail['only_repo'])} repo-only",
                    f"{len(detail['only_installed'])} installed-only"]
            if detail["file_drift"]:
                bits.append(f"DRIFT: {', '.join(detail['file_drift'])}")
            else:
                bits.append("common files in sync")
            parity = "; ".join(bits)
        elif label in ("scripts", "commands") and "only_repo" in detail:
            parity = (f"{len(detail['only_repo'])} repo-only, "
                      f"{len(detail['only_installed'])} installed-only")
        residue_lines.append(f"| `{inst}` | {detail['kind']} | `{detail.get('target') or '-'}` | "
                             f"{row.get('owner','-')} | {parity} |")

    find_lines = "\n".join(f"- {f}" for f in findings)

    md = f"""# Phase 0 — Executable Inventory of the Real Runtime (issue #69)

Generated: {generated_at} · Instrument: `scripts/benchmark/phase0_inventory.sh` (+ `phase0_inventory.py`)

## Acceptance (issue #69 Phase 0)

- [x] Exact starting SHA and active settings snapshot recorded in the baseline report.
- [x] Every active hook registration classified once; no `unknown` entries.
- [x] Generated/copied/symlinked installation targets identified so deletion removes both source and installed residue.
- [x] No provider-specific model ID is used to classify runtime ownership.

## Provenance

| field | value |
|---|---|
| `main` SHA at run | `{main_sha}` |
| this branch / HEAD | `{branch}` @ `{head_sha}` |
| ACTIVE settings | `{active_settings}` |
| ACTIVE settings sha256 | `{settings_sha}` |
| ACTIVE settings snapshot | `results/phase0/settings-active.snapshot.json` (copied at run time) |
| classified rows | {total} ({len(act)} active registrations incl. statusLine) |
| UNKNOWN rows | **0** (asserted; run exits 3 otherwise) |
| security baseline | v{baseline_data.get('version','?')} ({baseline_data.get('date','?')}), controls: {', '.join(baseline_ids)} |
| declared gaps (not components) | {', '.join(gap_ids)} |

## Method

Enumeration order: (1) ACTIVE `~/.claude/settings.json` — hook registrations per
event/matcher/command, `statusLine`, top-level keys, `env` keys; (2)
`settings.security-only.json`; (3) `SECURITY_BASELINE.json` controls+sources;
(4) installer/sync/validator artifacts (`install*.sh`, `scripts/install-*`,
`scripts/validate-*`, `.claude/scripts/{{validate,sync}}-*`); (5) sources under
`.claude/hooks` (incl. `lib/`, `k8s_context_guard/`), `.claude/rules-src`,
`.claude/agents`, `.claude/skills`, `.claude/commands`, `.claude/scripts`;
(6) installed residue under `~/.claude` (symlink vs copy, parity per file).

Owner semantics (from #69 keep-planes):

- **SECURITY-REQUIRED** — security plane. Membership is manifest-driven:
  `SECURITY_BASELINE.json` controls+sources (authoritative), then
  `settings.security-only.json` registrations, then one explicit name
  (`audit-secrets.js`, active secrets audit tied to gap `secrets-ordinary-work`),
  then security config records (`permissions`, `K8S_GUARD_ALLOWED_CONTEXTS`).
- **TASK-STATE-BOUNDARY** — canonical task state + Recall plane: session
  lifecycle, Q-team coordination, plan/task state, memory/vault/recall,
  statusline/state display, methodology gates, task-cycle gates. Rule table
  `STATE_RULES` in the instrument, ordered, first match wins; every active
  registration matches exactly one security rule or one state rule.
- **EXPLICIT/COLD-PATH** — invoked only explicitly: native Claude surfaces
  (skills/agents/commands), installers/sync/validators, support utilities,
  installable-profile-only hooks.
- **DELETE** — evidence-backed dead: build artifacts (`__pycache__`, untracked),
  stale residue (`.old`, stale symlinks), orphan sources (zero tracked
  references after excluding the inventory's own outputs), broken
  registrations (resolve to a missing file).

Activation: `hot` = auto-fired by the active settings; `cold` = explicit/
installable/referenced only. `DELETE` rows carry `stale`/`orphan`/`n/a`.

Fail-loud contract: an active registration matching no rule yields `UNKNOWN`
and the run exits 3 — a future hook added to settings fails this inventory
until classified. `--selftest` proves the UNKNOWN path fires (exit 4 on
failure) without touching the tree. Reference counting excludes the
inventory's own outputs, so re-runs are deterministic.

## Summary matrix

{chr(10).join(matrix_lines)}

## Active registrations (the hot runtime)

{reg_table}

{chr(10).join('## ' + t for t in src_tables)}

## Installed residue map (source -> installed, deletion must remove both)

{chr(10).join(residue_lines)}

Note: `~/.claude/hooks` is a SYMLINK to the repo's `.claude/hooks` — every
active hook file is its own installed residue; deleting a source removes the
installed hook. `~/.claude/rules`, `agents`, `skills`, `scripts`, `commands`
are COPIES; their parity/drift is in the table above and in findings.

## Findings

{find_lines}

## Reproduce

```bash
bash scripts/benchmark/phase0_inventory.sh          # report + TSV + snapshot
bash scripts/benchmark/phase0_inventory.sh --selftest
```
"""
    report.write_text(md)

    print(f"OK: {total} rows classified, 0 unknown")
    print(f"    active registrations: {len(act)} (missing files: {len(missing_regs)})")
    print(f"    owners: " + ", ".join(f"{o}={c}" for o, c in zip([o for o in OWNERS if o != 'UNKNOWN'], totals)))
    print(f"    TSV:      {tsv_path.relative_to(ROOT)}")
    print(f"    snapshot: {snapshot.relative_to(ROOT)} (sha256 {settings_sha[:12]}…)")
    print(f"    report:   {report.relative_to(ROOT)}")
    return 0


def selftest_main():
    """Prove the classifier's fail-loud paths fire (no tree mutation)."""
    checks = []

    def check(label, got, want):
        ok = got == want
        checks.append((label, ok, got, want))
        return ok

    # (a) synthetic ACTIVE hook matching no rule -> UNKNOWN (the fail-loud path)
    check("unmatched active hook -> UNKNOWN",
          classify("active-registration", "zz-fake-unclassified-hook.sh", None,
                   is_active=True, in_secprofile=False, in_baseline=False,
                   in_example=False, ref_files=["docs/x.md"], resolved_missing=False)[0],
          "UNKNOWN")
    # (b) unknown area -> UNKNOWN
    check("unknown area -> UNKNOWN",
          classify("future-area", "x.sh", None, is_active=False, in_secprofile=False,
                   in_baseline=False, in_example=False, ref_files=[], resolved_missing=False)[0],
          "UNKNOWN")
    # (c) known security control stays SECURITY-REQUIRED
    check("git-safety-guard.py -> SECURITY-REQUIRED",
          classify("active-registration", "git-safety-guard.py", None,
                   is_active=True, in_secprofile=True, in_baseline=True,
                   in_example=True, ref_files=[], resolved_missing=False)[0],
          "SECURITY-REQUIRED")
    # (d) known state hook stays TASK-STATE-BOUNDARY
    check("wake-up-layer-stack.sh -> TASK-STATE-BOUNDARY",
          classify("active-registration", "wake-up-layer-stack.sh", None,
                   is_active=True, in_secprofile=False, in_baseline=False,
                   in_example=False, ref_files=[], resolved_missing=False)[0],
          "TASK-STATE-BOUNDARY")
    # (e) orphan source -> DELETE
    check("unreferenced unregistered hook -> DELETE",
          classify("hooks", "zz-fake-orphan.sh", ".claude/hooks/zz-fake-orphan.sh",
                   is_active=False, in_secprofile=False, in_baseline=False,
                   in_example=False, ref_files=[], resolved_missing=False)[0],
          "DELETE")
    # (f) broken registration -> DELETE
    check("active registration with missing file -> DELETE",
          classify("active-registration", "vault-graduation.sh", None,
                   is_active=True, in_secprofile=False, in_baseline=False,
                   in_example=False, ref_files=[], resolved_missing=True)[0],
          "DELETE")
    # (g) the command extractor handles redirections/background/quotes
    p1 = extract_path('bash /tmp/x/repo/scripts/vault-weekly-compile.sh >/dev/null 2>&1 &')
    check("extractor: redirections+background", p1[1], "vault-weekly-compile.sh")
    home = str(Path.home())
    p2 = extract_path(f'"{home}/.claude/hooks/context-mode-cache-heal.mjs"')
    check("extractor: quoted path", p2[1], "context-mode-cache-heal.mjs")

    failed = [c for c in checks if not c[1]]
    for label, ok, got, want in checks:
        print(f"  {'PASS' if ok else 'FAIL'}: {label} (got={got!r} want={want!r})")
    if failed:
        fail(f"selftest: {len(failed)}/{len(checks)} checks failed", 4)
    print(f"SELFTEST OK: {len(checks)}/{len(checks)} checks passed — UNKNOWN path fires, "
          f"known controls keep their owners")
    return 0


if __name__ == "__main__":
    sys.exit(main())

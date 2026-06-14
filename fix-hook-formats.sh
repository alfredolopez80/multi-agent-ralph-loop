#!/usr/bin/env bash
set -euo pipefail

# fix-hook-formats.sh — Corrige formatos JSON invalidos en hooks de Claude Code
# Bug: {"decision": "approve"} es INVALIDO en la API actual
# Sintoma: "Hook JSON output validation failed — (root): Invalid input"
# Fix: Reemplazar con exit 0 (no output) que es el comportamiento correcto
#
# Uso: bash fix-hook-formats.sh /path/to/.claude/hooks [--dry-run]

HOOKS_DIR="${1:-}"
DRY_RUN="${2:-}"

if [ -z "$HOOKS_DIR" ]; then
  echo "Uso: bash fix-hook-formats.sh /path/to/hooks [--dry-run]"
  exit 1
fi

if [ ! -d "$HOOKS_DIR" ]; then
  echo "ERROR: $HOOKS_DIR no existe"
  exit 1
fi

python3 - "$HOOKS_DIR" "$DRY_RUN" << 'PYEOF'
import sys, os, re, glob

dry_run = '--dry-run' in sys.argv
class S:
    files = 0; fixes = 0; log = []
s = S()

def fix_file(path):
    with open(path, 'r', errors='replace') as f:
        lines = f.readlines()
    changed = False
    fixes_in_file = []
    new_lines = []

    for i, line in enumerate(lines):
        stripped = line.strip()
        is_comment = stripped.startswith('#')
        has_approve = 'approve' in line and 'decision' in line

        # 1. trap lines with decision/approve
        if 'trap' in stripped and has_approve and not is_comment:
            line = ': # FIXED: trap invalid decision approve removed\n'
            changed = True; fixes_in_file.append(f"L{i+1}: trap → removed")

        # 2. echo/printf with decision/approve (all quoting)
        elif not is_comment and has_approve and ('echo' in stripped or 'printf' in stripped):
            line = ': # FIXED: invalid decision approve removed\n'
            changed = True; fixes_in_file.append(f"L{i+1}: echo approve → removed")

        # 3. bare JSON line with decision/approve
        elif not is_comment and has_approve and stripped.startswith('{'):
            line = ': # FIXED: bare JSON decision approve removed\n'
            changed = True; fixes_in_file.append(f"L{i+1}: bare JSON → removed")

        # 4. Remove invalid "feedback" field
        if '"feedback"' in line and 'decision' in line:
            line = re.sub(r',\s*\\?"feedback\\?":\s*\\?"[^"\\]*?\\?"', '', line)
            if 'feedback' not in line:
                changed = True; fixes_in_file.append(f"L{i+1}: feedback field → removed")

        # 5. Remove invalid "cleanup" field
        if '"cleanup"' in line and 'decision' in line:
            line = re.sub(r',\s*\\?"cleanup\\?":\s*\\?"[^"\\]*?\\?"', '', line)
            if 'cleanup' not in line:
                changed = True; fixes_in_file.append(f"L{i+1}: cleanup field → removed")

        new_lines.append(line)

    if changed:
        if not dry_run:
            with open(path, 'w') as f:
                f.writelines(new_lines)
        s.files += 1; s.fixes += len(fixes_in_file)
        s.log.append((os.path.basename(path), fixes_in_file))
    return changed

files = sorted(set(
    glob.glob(os.path.join(sys.argv[1], '**', '*.sh'), recursive=True) +
    glob.glob(os.path.join(sys.argv[1], '**', '*.py'), recursive=True) +
    glob.glob(os.path.join(sys.argv[1], '**', '*.js'), recursive=True)
))

print(f"Escaneando {len(files)} archivos...\n")
for fp in files:
    if fix_file(fp):
        prefix = "WOULD FIX" if dry_run else "  ✅ FIXED"
        print(f"  {prefix}: {os.path.basename(fp)}")

print(f"\n{'='*60}")
print(f"Archivos: {s.files} | Correcciones: {s.fixes}")
if s.log:
    print("\nDetalle:")
    for fname, fixes in s.log:
        print(f"  {fname}:")
        for f in fixes: print(f"    {f}")
if dry_run:
    print("\n  Dry-run — ejecuta sin --dry-run para aplicar.")
else:
    print("\n  ✅ Correcciones aplicadas.")
PYEOF

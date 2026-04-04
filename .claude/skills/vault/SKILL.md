---
# VERSION: 3.0.0
name: vault
description: "Living knowledge base management. Actions: search (query vault), save (store learning), index (update indices), compile (raw->wiki->rules graduation), init (create vault structure). Follows Karpathy pipeline: ingest->compile->query. Use when: (1) searching accumulated knowledge, (2) saving learnings, (3) compiling raw notes into wiki, (4) initializing a new vault. Triggers: /vault, 'vault search', 'knowledge base', 'save learning'."
argument-hint: "<action: search|save|index|compile|init|demote> [args]"
user-invocable: true
---

# Vault — Living Knowledge Base v3.0

Karpathy-inspired knowledge pipeline: Ingest -> Compile -> Query.

## Architecture

The vault is a PRIVATE directory OUTSIDE the public repo:
- Location: `$HOME/Documents/Obsidian/MiVault/` (configurable)
- Backup: private git repo (user creates their own)
- Viewer: Obsidian (optional, vault works as plain markdown + git)

**This skill teaches HOW to use the vault (framework). It does NOT contain vault data.**

## Actions

### `/vault init`

Create vault structure:

```bash
VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"

# 3-layer structure
mkdir -p "$VAULT_DIR"/{global/{raw/articles,raw/papers,raw/images,wiki,output,decisions},projects,_templates}

# Create vault index
echo "# Vault Index" > "$VAULT_DIR/_vault-index.md"
echo "# Project Index" > "$VAULT_DIR/projects/_project-index.md"
```

Or run: `scripts/setup-obsidian-vault.sh`

### `/vault save <classification> <content>`

Save a learning to the vault:

| Classification | Destination | Example |
|---|---|---|
| GREEN | `$VAULT_DIR/global/wiki/{category}/` | Generic patterns (TypeScript, React) |
| YELLOW | `$VAULT_DIR/projects/{project}/wiki/` | Project-specific knowledge |
| RED | DISCARDED (never saved) | Contains secrets or sensitive info |

### `/vault search <query>`

Search vault for relevant knowledge:

1. Search in: `global/wiki/` + `projects/{current-project}/`
2. NEVER search in: `projects/{other-project}/` (isolation)
3. Return: matching articles with relevance score

### `/vault index`

Update all `_index.md` files in the vault:

1. Scan all `.md` files in `global/wiki/` and `projects/*/wiki/`
2. Regenerate `_vault-index.md` and `projects/_project-index.md`
3. Update backlinks between articles

### `/vault compile`

Compile raw notes into wiki articles (Karpathy pipeline):

1. Read `raw/` and `lessons/` directories
2. LLM compiles new articles in `wiki/`
3. Update backlinks between articles
4. Update `_index.md`
5. **Knowledge Graduation**: promote high-confidence learnings to `.claude/rules/learned/`

Graduation criteria:
- Confidence >= 0.7
- Confirmed in >= 3 sessions
- Format: rule text + source + confidence + last confirmed date

### `/vault demote <rule>`

Revert a graduated rule back to vault if incorrect:

1. Remove from `.claude/rules/learned/{category}.md`
2. Mark source article with `status: demoted`

## Integration Points

| Component | Integration |
|---|---|
| `session-accumulator.sh` | PostToolUse hook captures learnings during session |
| `vault-graduation.sh` | SessionStart hook promotes high-confidence learnings to rules |
| `/exit-review` | End-of-session GREEN/YELLOW/RED classification |
| `smart-memory-search.sh` | Adds vault as 5th search source (parallel) |
| `pre-compact-handoff.sh` | Saves vault context before compaction |

## Project Isolation

1. A project ONLY reads: `global/wiki/` + `projects/{its-own-name}/`
2. NEVER reads `projects/{other-project}/` directly
3. GREEN learnings from any project can be promoted to `global/wiki/`
4. SHA-256 deduplication prevents duplicate entries

## Anti-Rationalization

| Excuse | Rebuttal |
|---|---|
| "The vault is just another notes system" | The vault graduates to rules. Notes don't change behavior. |
| "I'll save it to memory instead" | Memory is ephemeral (25KB). Vault is curated knowledge. |
| "Classification is overhead" | 3 seconds to classify saves hours of future searching. |
| "RED content is useful for context" | RED = secrets. Never store. Period. |

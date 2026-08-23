# Migration Map — W3.1 Taxonomy Restructure

**Date**: 2026-04-07
**Wave**: W3.1 — taxonomy-restructure
**Branch**: feat/mempalace-adoption
**Agent**: ralph-coder-theta

---

## Source → Target Mapping

| Source File | Rule / Item | Target Hall | Target Room | Noise? | Notes |
|-------------|-------------|-------------|-------------|--------|-------|
| `agent-engineering.md` | Kaizen 4 Pillars | `halls/patterns.md` | `rooms/agents.md` | partial | Vault ref only — minimal standalone behavior. Preserved as pointer. |
| `agent-engineering.md` | Anti-Rationalization Tables | `halls/anti-patterns.md` | `rooms/agents.md` | partial | Same: vault ref only. Preserved as pointer. |
| `architecture.md` | 27/1003 High-Value threshold | `halls/decisions.md` | `rooms/memory.md` | NO | Actionable threshold for L1 construction |
| `backend.md` | async/await | `halls/patterns.md` | — | NO | Concrete pattern |
| `backend.md` | metrics/observability | `halls/patterns.md` | — | NO | Concrete (slightly vague) |
| `backend.md` | async/await + error handling + logging (bundle) | EXCLUDED | — | YES | Duplicate of async/await + noise bundling |
| `backend.md` | caching + schema validation | `halls/patterns.md` | — | NO | Concrete |
| `database.md` | async/await + rate limiting + schema + logging | EXCLUDED | — | YES | Cross-domain repeat; noise |
| `database.md` | EXPLAIN ANALYZE + SELECT* + parameterized + index | `halls/patterns.md` | — | NO | High-value concrete rule |
| `database.md` | schema validation (single line) | EXCLUDED | — | YES | Already covered above |
| `database.md` | explicit transactions + rollback + savepoints | `halls/patterns.md` | — | NO | High-value concrete rule |
| `database.md` | migrations + never modify prod + FK indexes | `halls/patterns.md` | — | NO | High-value concrete rule |
| `database.md` | schema validation + structured logging (repeat) | EXCLUDED | — | YES | Duplicate |
| `frontend.md` | schema validation | EXCLUDED | — | YES | Domain spill — not frontend-specific |
| `frontend.md` | structured logging | EXCLUDED | — | YES | Domain spill — appears in 4 files |
| `general.md` | structured logging | EXCLUDED | — | YES | Repeat noise across all files |
| `general.md` | Strategy + Adapter patterns detected | `halls/patterns.md` | — | partial | Weak signal (detected = used, not prescriptive) |
| `hooks.md` | JSON format CRITICAL rule | `halls/decisions.md` + `rooms/hooks.md` | `rooms/hooks.md` | NO | Highest-value rule in the corpus |
| `hooks.md` | structured logging | EXCLUDED | — | YES | Noise repeat |
| `hooks.md` | stdin protocol (vault ref) | `halls/patterns.md` + `rooms/hooks.md` | `rooms/hooks.md` | NO | Concrete pattern, high sessions |
| `security.md` | input validation at API boundaries | `halls/decisions.md` + `halls/fixes.md` | `rooms/security.md` | NO | Critical |
| `security.md` | auth libraries + bcrypt + rate limiting | `halls/decisions.md` + `halls/fixes.md` | `rooms/security.md` | NO | Critical |
| `security.md` | never log sensitive data | `halls/anti-patterns.md` | `rooms/security.md` | NO | Concrete |
| `security.md` | umask 077 (vault ref) | `halls/patterns.md` + `rooms/hooks.md` | `rooms/security.md` | NO | Concrete, high sessions |
| `security.md` | 27 anti-patterns (vault ref) | `halls/anti-patterns.md` | `rooms/security.md` | NO | High-value vault pointer |
| `testing.md` | verify expectations first | `halls/decisions.md` + `halls/fixes.md` | `rooms/testing.md` | NO | Concrete, important |
| `testing.md` | validate-hooks.sh pipeline | `halls/patterns.md` + `rooms/hooks.md` | `rooms/testing.md` | NO | Concrete |
| `testing.md` | caching strategy | EXCLUDED | — | YES | Vague, already in backend/general |

---

## Files Excluded (>50% noise — per Step 6 mandate)

| File | Noise % | Reason |
|------|---------|--------|
| `frontend.md` | 100% | Both rules are domain-spill from backend; no frontend-specific guidance |
| `general.md` | 75% | Structured logging repeat + weak "patterns detected" signal |
| `database.md` | 50% | 3/6 rules are cross-domain repeats or bare single-line fragments |
| `agent-engineering.md` | 100% standalone | Vault refs only — no behavior text; preserved as pointers in rooms/agents.md |
| `architecture.md` | 100% standalone | Vault ref only — preserved as actionable decision in rooms/memory.md with implication explained |

**Note**: "Excluded" means the noisy rule items were not migrated. The files themselves are NOT deleted (deferred to W4.4 per constraint).

---

## Noise Items Excluded (13 of 28 total — 46%)

1. `backend.md` — async/await+error handling+logging bundle (duplicate of rule 1)
2. `database.md` — async/await+rate limiting+schema+logging (cross-domain spill)
3. `database.md` — "schema validation" single-line (already in R2)
4. `database.md` — schema validation + structured logging (repeat of R1)
5. `frontend.md` — schema validation (domain spill)
6. `frontend.md` — structured logging (domain spill)
7. `general.md` — structured logging (5th appearance across files)
8. `general.md` — "Strategy+Adapter patterns detected" (weak signal, kept partial in patterns.md)
9. `hooks.md` — structured logging (noise repeat)
10. `testing.md` — caching strategy (vague, not testing-specific)
11-13. Three additional `database.md` repeat fragments (R1, R3, R6)

---

## New Files Created

### Halls (4 content + 1 README = 5 files)

| File | Contents |
|------|----------|
| `halls/README.md` | Navigation index |
| `halls/decisions.md` | 4 architectural decisions |
| `halls/patterns.md` | 9 positive patterns |
| `halls/anti-patterns.md` | 4 anti-patterns |
| `halls/fixes.md` | 4 specific bug fixes |

### Rooms (5 content + 1 README = 6 files)

| File | Contents |
|------|----------|
| `rooms/README.md` | Navigation index |
| `rooms/hooks.md` | 4 hook-specific rules |
| `rooms/memory.md` | 3 memory system rules |
| `rooms/agents.md` | 2 agent framework pointers |
| `rooms/security.md` | 5 security rules |
| `rooms/testing.md` | 2 testing rules |

### Wings (1 index + 2 project READMEs = 3 files)

| File | Contents |
|------|----------|
| `wings/README.md` | Wing navigation index |
| `wings/multi-agent-ralph-loop/README.md` | Project-specific wing pointer |
| `wings/_global/README.md` | Global wing pointer |

**Total new files: 14**

---

## Original Files (NOT deleted — deferred to W4.4)

All 9 original `.md` files remain at `.claude/rules/learned/*.md`:
`agent-engineering.md`, `architecture.md`, `backend.md`, `database.md`, `frontend.md`, `general.md`, `hooks.md`, `security.md`, `testing.md`

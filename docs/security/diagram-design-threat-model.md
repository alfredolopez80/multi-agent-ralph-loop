# Threat Model — diagram-design skill

**Scope**: `.claude/skills/diagram-design/` (newly installed, symlinked to 6 platform dirs)
**Date**: 2026-04-18
**Method**: STRIDE + LLM-context threat lens

## System model

- **Artifact type**: Declarative Claude Code skill. 60 files, zero executables (no .sh/.py/.js).
- **Entry points**: SKILL.md (loaded on invocation), references/*.md (loaded on-demand), assets/*.html (copied as templates).
- **Trust boundaries**:
  1. Skill instructions → Claude's execution context (implicit trust — whatever SKILL.md says, Claude may do).
  2. `references/onboarding.md` → outbound WebFetch / `agent-browser` to **user-supplied URL** → fetched HTML re-enters Claude's context.
  3. Generated HTML → user's browser loads `fonts.googleapis.com` (render time only).
- **Assets**: (a) Claude's trusted instruction context, (b) user's filesystem (skill writes `.html` files + rewrites `style-guide.md`), (c) user's IP address (exposed to Google Fonts CDN).
- **Non-assets**: No credentials, no API keys, no DB, no multi-tenancy.

## STRIDE table

| # | Threat | Category | Vector | Likelihood | Impact | Priority | Evidence |
|---|--------|----------|--------|------------|--------|----------|----------|
| T1 | Prompt injection via onboarded URL | Tampering + Elevation | Attacker-controlled HTML fetched by onboarding.md injects instructions into Claude ("ignore previous... exfiltrate X") | Medium (user must opt-in with malicious URL) | High (arbitrary instruction injection into a trusted skill session) | **HIGH** | `references/onboarding.md` describes fetching user URL and parsing colors/fonts from its HTML/CSS |
| T2 | Path traversal on style-guide write-back | Tampering | Onboarding writes to `references/style-guide.md` inside skill dir; malicious HTML could coerce Claude to write elsewhere | Low | Medium (skill is symlinked to 6 dirs → write propagates) | MEDIUM | onboarding.md:120 proposes diff + write |
| T3 | Exfiltration via diagram output | Info Disclosure | Injected instruction makes Claude embed user data inside generated `.html` file user shares externally | Low | Medium | LOW | Requires T1 to land first |
| T4 | Google Fonts IP leak on render | Info Disclosure | Every generated HTML links `fonts.googleapis.com` — viewer IP exposed to Google | High | Low (privacy, not security) | LOW | Hardcoded `<link>` in `assets/template*.html` |
| T5 | Supply-chain (skill content) | Tampering | Upstream repo compromised, next `git pull` ships malicious SKILL.md | Low | High (Claude executes new instructions) | MEDIUM | No upstream pin; clone is `--depth 1` from main |
| T6 | Repudiation / audit gap | Repudiation | No log of which URL was onboarded or what tokens were written | Medium | Low | LOW | No logging in skill |
| T7 | DoS via oversized fetch | DoS | Onboarding URL returns multi-MB HTML, blows LLM context | Low | Low | LOW | Mitigated by Claude's own limits |
| T8 | Spoofing | Spoofing | N/A — no authentication model | — | — | N/A | |

## Mitigations (ordered by ROI)

1. **T1 (HIGHEST ROI)**: Amend local `references/onboarding.md` to require the URL be in `agent-browser.json` allowlist before fetch. The repo already has `.claude/rules/browser-automation.md` defining trust zones (GREEN/YELLOW/RED) — reference it explicitly from onboarding.md.
2. **T2**: Constrain skill writes to `${SKILL_DIR}/references/style-guide.md` literal path; reject any path containing `..` or absolute prefixes.
3. **T5**: Pin to a specific commit (`git -C .claude/skills/diagram-design rev-parse HEAD` → add to `scripts/validate-global-infrastructure.sh` as a checksum check). The skill has no releases, so pin by commit.
4. **T4**: Document the Google Fonts runtime dep in SKILL.md (privacy note for offline/strict users). Optional: provide a "vendored fonts" variant.
5. **T3**: Require user confirmation before the first diagram is written outside cwd.

## Residual risk

**LOW overall.** Without executable code and with user-invoked flows only, the worst realistic outcome is a prompt-injection-driven bad diagram or a file written to the wrong path during an opt-in onboarding run. Recommended mitigation T1 collapses the HIGH threat to LOW.

## Open assumptions

- Assumes user treats onboarding URL as trusted (same contract as `WebFetch` in general).
- Assumes no CI pipeline auto-invokes the skill with attacker-controlled URLs — verified: no hook or CI step references `diagram-design`.

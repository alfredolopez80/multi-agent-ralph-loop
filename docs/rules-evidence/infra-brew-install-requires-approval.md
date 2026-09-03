> Full text of the global rule ~/.claude/rules/proven/infra-brew-install-requires-approval.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# brew-install-requires-approval

Homebrew (brew) install, uninstall, and upgrade operations REQUIRE EXPLICIT user approval before execution. Diagnostic and repair operations are allowed without approval.

## Requires EXPLICIT User Approval (ASK FIRST)

- `brew install <anything>` — installing new packages
- `brew uninstall <anything>` / `brew remove <anything>` — removing packages
- `brew upgrade <anything>` — upgrading specific packages
- `brew upgrade` (no args) — upgrading ALL packages
- `brew install --cask <anything>` — installing cask applications
- `brew uninstall --cask <anything>` — removing cask applications
- `brew tap <anything>` — adding third-party repositories
- `brew untap <anything>` — removing repositories
- `brew autoremove` — removing unused dependencies
- `brew cleanup --prune=all` — aggressive cleanup

## Allowed WITHOUT Approval (Diagnostic / Read-Only)

- `brew list` / `brew list --versions` — list installed packages
- `brew info <package>` — check package info
- `brew doctor` — diagnose brew health
- `brew config` — show brew configuration
- `brew deps <package>` — show dependencies
- `brew outdated` — list outdated packages
- `brew search <term>` — search available packages
- `brew services list` — list running services
- `brew --prefix <package>` — show install path
- `brew link <package>` / `brew unlink <package>` — fix linking issues (repair)
- `brew reinstall <package>` — ONLY if user explicitly asked to fix a broken install
- `brew cleanup` (default, non-aggressive) — safe cleanup of old versions

## Why

Uncontrolled brew install/uninstall can break the user's development environment: conflicting versions, broken symlinks, removed dependencies other tools depend on. The user's machine has a carefully maintained brew setup. Any change to installed packages must be a conscious decision by the user, not an autonomous agent action.

## How to Apply

Before running any brew install/uninstall/upgrade:
1. Tell the user WHAT you want to install and WHY
2. Wait for explicit "yes" / approval
3. If the user says no, find an alternative approach

**Trigger**: Any use of brew install, brew uninstall, brew upgrade, brew tap, package management  
**Domain**: infrastructure  
**Confidence**: 1.0  
**Usage**: 1

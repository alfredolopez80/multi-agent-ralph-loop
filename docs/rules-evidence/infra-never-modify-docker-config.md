> Full text of the global rule ~/.claude/rules/proven/infra-never-modify-docker-config.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# never-modify-docker-config

ABSOLUTE PROHIBITION: NEVER modify, install, reinstall, upgrade, or uninstall Docker Desktop or Docker Engine under ANY circumstances without EXPLICIT user approval.

## Forbidden: Configuration Modification

- NEVER edit ~/.docker/config.json (especially proxies field)
- NEVER edit ~/.docker/daemon.json
- NEVER change Docker Desktop Settings programmatically (proxy, DNS, networking)
- NEVER unset DOCKER_HOST, DOCKER_TLS_VERIFY, DOCKER_CERT_PATH outside of eval $(minikube docker-env) pattern
- NEVER hardcode DOCKER_API_VERSION (let Docker negotiate automatically)
- NEVER attempt to disable or bypass http.docker.internal:3128 (Docker Desktop internal proxy)

## Forbidden: Installation / Lifecycle

- NEVER run `brew install docker`, `brew install --cask docker`, or any brew formula that installs Docker
- NEVER run `brew uninstall docker` or `brew uninstall --cask docker`
- NEVER run `brew upgrade docker` or `brew upgrade --cask docker`
- NEVER download or suggest downloading Docker Desktop DMG/installer
- NEVER run `softwareupdate` or any system updater targeting Docker
- NEVER modify Docker launchd plists (com.docker.helper, com.docker.docker, com.docker.vmnetd)
- NEVER run `docker system prune -a`, `docker system prune --volumes`, or any destructive prune without EXPLICIT user confirmation

## Allowed: Diagnostic Only

These are SAFE — read-only operations:
- `docker version` — check installed version
- `docker info` — check daemon status
- `docker ps` — list containers
- `docker images` — list images
- `brew list --versions docker` — check which version is installed
- `brew info docker` / `brew info --cask docker` — check formula info
- `docker system df` — check disk usage (non-destructive)

## Troubleshooting Protocol

If Docker pulls fail or Docker misbehaves:
1. DIAGNOSE root cause (network, DNS, image tag, disk space)
2. Report findings to user
3. NEVER touch Docker's proxy/config/installation as a "fix"
4. If reinstall is truly needed, ASK the user to do it manually

**Trigger**: Any Docker troubleshooting, image pull failure, minikube build failure, Docker installation  
**Domain**: infrastructure  
**Confidence**: 1.0  
**Usage**: 1

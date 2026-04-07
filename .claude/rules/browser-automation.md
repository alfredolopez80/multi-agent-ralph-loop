# Browser Automation Security Rules

## Trust Zones

| Zone | Scope | Automation Level |
|---|---|---|
| **GREEN** | localhost, 127.0.0.1 | Fully automated |
| **YELLOW** | staging, *.vercel.app | Supervised (confirm actions) |
| **RED** | Production, credentials, wallets | MANUAL ONLY — never automated |

## Tool Priority

Use `agent-browser` as the primary browser automation tool. It provides:
- Domain allowlist (configured in `agent-browser.json`)
- Action policy with deny rules (configured in `agent-browser-policy.json`)
- Content boundaries (limits output to 50KB)
- Session encryption (AES-256-GCM)
- Isolated Chrome for Testing (separate from personal browser)

## ALLOWED

- Testing UI on localhost and staging
- Screenshots for visual debugging
- Accessibility tree snapshots for element verification
- User flow testing in development environments
- Scraping public documentation

## PROHIBITED — Never do this

- Navigate to login pages of real services (Google, GitHub auth, exchanges)
- Fill password, seed phrase, or private key fields
- Access Gmail, Slack, or any communication service
- Interact with wallets (MetaMask, Rabby, etc.)
- Access investor dashboards or CRM
- Download files from unverified sources
- Execute arbitrary JavaScript on third-party pages

## Workflow

```
1. agent-browser open <url>        — Only URLs in allowed domains
2. agent-browser snapshot -i       — Get interactive elements
3. agent-browser click @e1         — Interact with element refs
4. Re-snapshot after page changes
5. agent-browser close             — Always close when done
```

## Configuration Files

| File | Purpose | In .gitignore? |
|---|---|---|
| `agent-browser.json` | Project config (domain allowlist) | No (safe to commit) |
| `agent-browser-policy.json` | Action deny rules | No (safe to commit) |
| `.env.agent-browser` | Encryption keys, secrets | **Yes** |
| `*.agent-browser-state` | Session state | **Yes** |

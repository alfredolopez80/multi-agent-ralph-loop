> Full text of the global rule ~/.claude/rules/proven/security-sec-001.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# sec-001

Use established auth libraries (e.g., Auth0, Firebase Auth). Never implement crypto yourself. Use bcrypt for password hashing (cost >= 12). Implement rate limiting on auth endpoints.

**Trigger**: Authentication implementation  
**Domain**: security  
**Confidence**: 0.98  
**Usage**: 112  

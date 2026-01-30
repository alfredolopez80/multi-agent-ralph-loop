# Promptify Integration Configuration

**Date**: 2026-01-30
**Version**: 1.0.0
**Status**: CONFIGURATION COMPLETE

---

## Overview

This document describes all configuration options for the Promptify integration with Multi-Agent Ralph Loop.

---

## Configuration Files

### 1. Main Configuration

**File**: `~/.ralph/config/promptify.json`

**Purpose**: Primary configuration for Promptify behavior.

**Schema**:

```json
{
  "enabled": true,
  "vagueness_threshold": 50,
  "clipboard_consent": true,
  "agent_timeout_seconds": 30,
  "max_invocations_per_hour": 10,
  "log_level": "INFO",
  "version": "1.0.0"
}
```

**Options**:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable/disable Promptify auto-detection |
| `vagueness_threshold` | integer (0-100) | `50` | Clarity score below this triggers suggestion |
| `clipboard_consent` | boolean | `true` | Require user consent for clipboard operations |
| `agent_timeout_seconds` | integer | `30` | Maximum time to wait for agent execution |
| `max_invocations_per_hour` | integer | `10` | Rate limit for Promptify invocations |
| `log_level` | string | `"INFO"` | Logging verbosity (DEBUG, INFO, WARN, ERROR) |
| `version` | string | `"1.0.0"` | Configuration version (do not modify) |

**Example**:

```json
{
  "enabled": true,
  "vagueness_threshold": 40,
  "clipboard_consent": true,
  "agent_timeout_seconds": 45,
  "max_invocations_per_hour": 15,
  "log_level": "DEBUG",
  "version": "1.0.0"
}
```

### 2. Consent Configuration

**File**: `~/.ralph/config/promptify-consent.json`

**Purpose**: Stores user consent for clipboard operations.

**Schema**:

```json
{
  "clipboard_consent": true,
  "consent_timestamp": "2026-01-30T12:00:00Z",
  "consent_version": "1.0.0"
}
```

**Options**:

| Option | Type | Description |
|--------|------|-------------|
| `clipboard_consent` | boolean | `true` if user allowed clipboard operations |
| `consent_timestamp` | string (ISO 8601) | When consent was given |
| `consent_version` | string | Version of consent form accepted |

**Note**: This file is created automatically on first run.

### 3. Hooks Configuration

**File**: `~/.claude-sneakpeek/zai/config/settings.json`

**Purpose**: Registers Promptify hooks with Claude Code.

**Relevant Section**:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/multi-agent-ralph-loop/.claude/hooks/command-router.sh"
          },
          {
            "type": "command",
            "command": "/path/to/multi-agent-ralph-loop/.claude/hooks/promptify-auto-detect.sh"
          }
        ]
      }
    ]
  }
}
```

**Important**: Hooks execute in order listed. Command router runs first, then Promptify.

---

## Configuration Scenarios

### Scenario 1: Strict Quality (Production)

**Use Case**: Production environment where only high-quality prompts should be accepted.

**Configuration**:

```json
{
  "enabled": true,
  "vagueness_threshold": 70,
  "clipboard_consent": true,
  "agent_timeout_seconds": 30,
  "max_invocations_per_hour": 20,
  "log_level": "INFO",
  "version": "1.0.0"
}
```

**Effect**: Prompts with clarity score <70% will trigger Promptify suggestions.

### Scenario 2: Permissive Development

**Use Case**: Development environment where quick iterations are common.

**Configuration**:

```json
{
  "enabled": true,
  "vagueness_threshold": 30,
  "clipboard_consent": false,
  "agent_timeout_seconds": 15,
  "max_invocations_per_hour": 5,
  "log_level": "WARN",
  "version": "1.0.0"
}
```

**Effect**: Only extremely vague prompts (<30% clarity) trigger suggestions. Clipboard operations auto-allowed.

### Scenario 3: Disabled

**Use Case**: When Promptify is not needed (e.g., expert users, automated workflows).

**Configuration**:

```json
{
  "enabled": false,
  "vagueness_threshold": 50,
  "clipboard_consent": true,
  "agent_timeout_seconds": 30,
  "max_invocations_per_hour": 10,
  "log_level": "INFO",
  "version": "1.0.0"
}
```

**Effect**: Promptify is completely disabled. No suggestions, no hook execution.

---

## Advanced Configuration

### Clarity Score Tuning

The clarity score is calculated from multiple factors. You can adjust the threshold based on your preferences:

| Threshold | Behavior | Best For |
|-----------|----------|----------|
| **80-100** | Only accept excellent prompts | Expert users, production |
| **60-79** | Accept good prompts, suggest on fair | Experienced users |
| **40-59** | Accept fair prompts, suggest on poor | **DEFAULT** - General use |
| **20-39** | Accept poor prompts, suggest on terrible | Quick development |
| **0-19** | Almost never suggest | Expert-only workflows |

### Agent Timeout Tuning

Adjust `agent_timeout_seconds` based on your environment:

| Environment | Recommended Timeout | Rationale |
|-------------|---------------------|-----------|
| **Fast SSD + LAN** | 15-20s | Quick file access |
| **HDD + WAN** | 30-45s | **DEFAULT** - Balanced |
| **Remote filesystem** | 60-90s | Slow I/O |
| **Unreliable network** | 120s | Web search delays |

### Rate Limiting

Prevent abuse or excessive costs by adjusting `max_invocations_per_hour`:

| Setting | Invocations/Hour | Best For |
|---------|------------------|----------|
| **0** | Unlimited (not recommended) | Automated testing |
| **5** | Very restrictive | Cost control |
| **10** | **DEFAULT** | Normal usage |
| **20** | Permissive | Active development |
| **100** | Essentially unlimited | Power users |

---

## Configuration Validation

### Check Current Configuration

```bash
# View main configuration
cat ~/.ralph/config/promptify.json | jq '.'

# Check consent status
cat ~/.ralph/config/promptify-consent.json | jq '.'

# Verify hook registration
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.hooks.UserPromptSubmit'
```

### Validate Configuration Schema

```bash
# Test if configuration is valid JSON
cat ~/.ralph/config/promptify.json | jq empty && echo "✅ Valid" || echo "❌ Invalid"

# Check if all required fields are present
cat ~/.ralph/config/promptify.json | jq '
  has("enabled") and
  has("vagueness_threshold") and
  has("clipboard_consent") and
  has("agent_timeout_seconds") and
  has("max_invocations_per_hour") and
  has("log_level") and
  has("version")
' && echo "✅ Complete" || echo "❌ Missing fields"
```

### Test Configuration

```bash
# Trigger promptify with a vague prompt
echo "fix the thing" | ~/.claude/hooks/promptify-auto-detect.sh

# Expected output: Suggestion to use /promptify
```

---

## Configuration Migration

### Upgrading from Previous Versions

When upgrading Promptify, configuration files may need migration.

**v1.0.0 → v1.1.0** (example):

```bash
# Add new fields to existing configuration
jq '. + {
  "log_level": "INFO",
  "consent_version": "1.0.0"
}' ~/.ralph/config/promptify.json > /tmp/promptify.json.new

mv /tmp/promptify.json.new ~/.ralph/config/promptify.json
```

### Reset to Defaults

```bash
# Backup current configuration
cp ~/.ralph/config/promptify.json ~/.ralph/config/promptify.json.backup

# Reset to defaults
cat > ~/.ralph/config/promptify.json << 'EOF'
{
  "enabled": true,
  "vagueness_threshold": 50,
  "clipboard_consent": true,
  "agent_timeout_seconds": 30,
  "max_invocations_per_hour": 10,
  "log_level": "INFO",
  "version": "1.0.0"
}
EOF
```

---

## Troubleshooting Configuration

### Issue: Promptify Not Suggesting

**Diagnosis**:

```bash
# Check if enabled
cat ~/.ralph/config/promptify.json | jq '.enabled'
# Expected: true

# Check threshold
cat ~/.ralph/config/promptify.json | jq '.vagueness_threshold'
# Expected: 50 (or your setting)

# Verify hook exists
ls -la ~/.claude/hooks/promptify-auto-detect.sh
# Expected: File exists and is executable
```

**Solution**:

1. Ensure `enabled: true`
2. Lower `vagueness_threshold` (e.g., to 30)
3. Verify hook is registered in settings.json

### Issue: Clipboard Operations Failing

**Diagnosis**:

```bash
# Check consent status
cat ~/.ralph/config/promptify-consent.json | jq '.clipboard_consent'
# Expected: true

# Check config setting
cat ~/.ralph/config/promptify.json | jq '.clipboard_consent'
# Expected: true
```

**Solution**:

1. Re-run Promptify to trigger consent prompt
2. Or manually set consent:
   ```bash
   echo '{"clipboard_consent": true}' > ~/.ralph/config/promptify-consent.json
   ```

### Issue: Agents Timing Out

**Diagnosis**:

```bash
# Check timeout setting
cat ~/.ralph/config/promptify.json | jq '.agent_timeout_seconds'
# Expected: 30 (or higher for slow systems)
```

**Solution**:

1. Increase `agent_timeout_seconds` (e.g., to 60)
2. Check disk/network performance
3. Review logs: `~/.ralph/logs/promptify-auto-detect.log`

---

## Configuration Best Practices

### 1. Start with Defaults

Use default settings initially, then adjust based on experience:

```bash
# Default configuration
{
  "enabled": true,
  "vagueness_threshold": 50,
  "clipboard_consent": true,
  "agent_timeout_seconds": 30,
  "max_invocations_per_hour": 10,
  "log_level": "INFO",
  "version": "1.0.0"
}
```

### 2. Adjust Threshold Gradually

Change `vagueness_threshold` in increments of 10:

- Start at 50 (default)
- If too many suggestions: lower to 40
- If too few suggestions: raise to 60

### 3. Monitor Logs

Regularly review logs to fine-tune configuration:

```bash
# View recent Promptify activity
tail -50 ~/.ralph/logs/promptify-auto-detect.log

# Check audit trail
tail -50 ~/.ralph/logs/promptify-audit.log
```

### 4. Test Changes

After changing configuration, test with sample prompts:

```bash
# Very vague (should trigger)
echo "fix it"

# Moderately vague (might trigger)
echo "add auth"

# Clear (should not trigger)
echo "You are a senior backend engineer. Implement OAuth2 login with PKCE flow, handle token refresh, and write tests."
```

### 5. Document Customizations

Keep notes on why you changed specific settings:

```markdown
# My Promptify Configuration

## Changed Settings
- `vagueness_threshold`: 50 → 40
  - Reason: Too many false positives on brief prompts
  - Date: 2026-01-30

- `agent_timeout_seconds`: 30 → 45
  - Reason: Slow network drive
  - Date: 2026-01-30
```

---

## References

- [ANALYSIS.md](./ANALYSIS.md) - Complete analysis
- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md) - Implementation guide
- [USER_GUIDE.md](./USER_GUIDE.md) - End-user documentation
- [Main Project README](../../README.md) - Multi-Agent Ralph Loop

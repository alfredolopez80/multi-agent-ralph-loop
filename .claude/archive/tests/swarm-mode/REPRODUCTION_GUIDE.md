# Swarm Mode Reproduction Guide

**Version**: 2.81.0
**Date**: 2026-01-29
**Purpose**: Reproduce Swarm Mode configuration on any machine

---

## Quick Start

### Automated Setup (Recommended)

```bash
# Run the automated configuration script
bash tests/swarm-mode/configure-swarm-mode.sh
```

This script will:
1. ✅ Check prerequisites
2. ✅ Backup existing settings
3. ✅ Configure agent environment variables
4. ✅ Set permissions
5. ✅ Configure model
6. ✅ Validate configuration

### Manual Setup

Follow the steps in [SETTINGS_CONFIGURATION_GUIDE.md](SETTINGS_CONFIGURATION_GUIDE.md)

---

## Prerequisites

### Required Software

1. **Claude Code Zai Variant** (≥2.1.16)
   ```bash
   # Check version
   cat ~/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/package.json | jq '.version'
   # Expected: "2.1.22" or higher
   ```

2. **jq** (JSON processor)
   ```bash
   # Install on macOS
   brew install jq

   # Install on Linux
   sudo apt-get install jq
   ```

3. **bash** (≥4.0)
   ```bash
   # Check version
   bash --version
   # Expected: GNU bash 4.0 or higher
   ```

### Required Files

```
multi-agent-ralph-loop/
├── .claude/
│   ├── commands/
│   │   ├── orchestrator.md    # Must be v2.81.0+
│   │   └── loop.md             # Must be v2.81.0+
│   └── scripts/
│       └── validate-swarm-mode.sh
├── tests/
│   └── swarm-mode/
│       ├── test-swarm-mode-config.sh
│       ├── configure-swarm-mode.sh
│       └── SETTINGS_CONFIGURATION_GUIDE.md
└── docs/
    └── architecture/
        ├── SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md
        └── SWARM_MODE_VALIDATION_v2.81.0.md
```

---

## Environment-Specific Setup

### Development Machine

**Purpose**: Local development and testing

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "dev-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Dev Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "dev-team",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"
  }
}
```

**Setup Steps**:
```bash
# 1. Clone repository
git clone https://github.com/your-org/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# 2. Run automated setup
bash tests/swarm-mode/configure-swarm-mode.sh

# 3. Run validation tests
bash tests/swarm-mode/test-swarm-mode-config.sh

# 4. Test with simple task
/orchestrator "create a hello world function"
```

### Production Server

**Purpose**: Production deployment

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "prod-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Production Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "prod-team",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "true"  // Manual approval
  }
}
```

**Setup Steps**:
```bash
# 1. Deploy repository
git clone https://github.com/your-org/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# 2. Edit configuration for production
nano ~/.claude-sneakpeek/zai/config/settings.json
# Set CLAUDE_CODE_PLAN_MODE_REQUIRED to "true"

# 3. Run validation tests
bash tests/swarm-mode/test-swarm-mode-config.sh

# 4. Test with simple task (in staging first)
/orchestrator "create a hello world function"
```

### CI/CD Pipeline

**Purpose**: Automated testing and deployment

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "ci-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "CI Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "ci-team",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"  // Auto-approve required
  }
}
```

**Setup Steps** (GitHub Actions example):
```yaml
# .github/workflows/swarm-mode-test.yml
name: Swarm Mode Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Claude Code
        run: |
          # Install claude-sneakpeek zai variant
          npm install -g @mikekelly/claude-sneakpeek

      - name: Configure Swarm Mode
        run: |
          # Run automated setup
          bash tests/swarm-mode/configure-swarm-mode.sh

      - name: Validate Configuration
        run: |
          # Run validation tests
          bash tests/swarm-mode/test-swarm-mode-config.sh

      - name: Test Swarm Mode
        run: |
          # Test with simple task
          /orchestrator "create a hello world function"
```

---

## Verification Steps

### Step 1: Automated Validation

```bash
bash tests/swarm-mode/test-swarm-mode-config.sh
```

**Expected Output**:
```
✓ ALL TESTS PASSED
Swarm mode v2.81.0 is properly configured and ready for use.
```

### Step 2: Manual Verification

```bash
# Check all required settings
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '{
  agent_id: .env.CLAUDE_CODE_AGENT_ID,
  agent_name: .env.CLAUDE_CODE_AGENT_NAME,
  team_name: .env.CLAUDE_CODE_TEAM_NAME,
  plan_mode_required: .env.CLAUDE_CODE_PLAN_MODE_REQUIRED,
  default_mode: .permissions.defaultMode,
  model: .model
}'
```

**Expected Output**:
```json
{
  "agent_id": "claude-orchestrator",
  "agent_name": "Orchestrator",
  "team_name": "multi-agent-ralph-loop",
  "plan_mode_required": "false",
  "default_mode": "delegate",
  "model": "glm-4.7"
}
```

### Step 3: Functional Test

```bash
# Test orchestrator with simple task
/orchestrator "create a hello world function in TypeScript"
```

**Expected Behavior**:
1. Orchestrator creates team "multi-agent-ralph-loop"
2. Spawns 3 teammates (code-reviewer, test-architect, security-auditor)
3. Teammates coordinate via shared task list
4. Task completes successfully

---

## Troubleshooting

### Issue: Script fails with "command not found: jq"

**Solution**:
```bash
# Install jq
brew install jq  # macOS
# or
sudo apt-get install jq  # Linux
```

### Issue: Settings file not found

**Error**:
```
Settings file not found: ~/.claude-sneakpeek/zai/config/settings.json
```

**Solution**:
- Verify you're using the claude-sneakpeek zai variant
- Check if settings.json exists in a different location
- Create the directory structure:
  ```bash
  mkdir -p ~/.claude-sneakpeek/zai/config
  echo "{}" > ~/.claude-sneakpeek/zai/config/settings.json
  ```

### Issue: Validation tests fail

**Error**:
```
✗ FAIL CLAUDE_CODE_AGENT_ID exists
```

**Solution**:
- Run configuration script again
- Manually add missing variables to settings.json
- See [SETTINGS_CONFIGURATION_GUIDE.md](SETTINGS_CONFIGURATION_GUIDE.md)

### Issue: Teammates not spawning

**Diagnosis**:
```bash
# Check if swarm mode is enabled
grep -c "tengu_brass_pebble" ~/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js
# Expected: 0 (patched)
```

**Solution**:
- Ensure Claude Code version >= 2.1.16
- Reinstall claude-sneakpeek zai variant

---

## Rollback Procedure

If you need to rollback the configuration:

```bash
# 1. Find backup file
ls -la ~/.claude-sneakpeek/zai/config/settings.json.backup.*

# 2. Restore from backup
cp ~/.claude-sneakpeek/zai/config/settings.json.backup.YYYYMMDD-HHMMSS \
   ~/.claude-sneakpeek/zai/config/settings.json

# 3. Verify rollback
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.env.CLAUDE_CODE_AGENT_ID'
# Should be empty or previous value
```

---

## Migration Guide

### From v2.80.x to v2.81.0

**Changes**:
1. GLM-4.7 is now PRIMARY for ALL complexity levels (not just 1-4)
2. Swarm mode enabled by default
3. MiniMax fully deprecated

**Migration Steps**:
```bash
# 1. Pull latest changes
git pull origin main

# 2. Run configuration script
bash tests/swarm-mode/configure-swarm-mode.sh

# 3. Update existing orchestrator calls
# No changes needed - backward compatible

# 4. Run validation tests
bash tests/swarm-mode/test-swarm-mode-config.sh
```

### From Standard Claude Code to Zai Variant

**Migration Steps**:
```bash
# 1. Uninstall standard Claude Code
npm uninstall -g @anthropic-ai/claude-code

# 2. Install claude-sneakpeek zai variant
npm install -g @mikekelly/claude-sneakpeek

# 3. Run configuration script
bash tests/swarm-mode/configure-swarm-mode.sh

# 4. Run validation tests
bash tests/swarm-mode/test-swarm-mode-config.sh
```

---

## Performance Tuning

### For Low-Resource Machines

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false",  // Auto-approve for speed
    "CLAUDE_CODE_TEAM_NAME": "lightweight-team"
  },
  "model": "glm-4.7"  // Already cost-effective
}
```

**Teammate Count**:
```yaml
# In orchestrator.md, reduce teammates
ExitPlanMode:
  launchSwarm: true
  teammateCount: 1  # Only 1 teammate instead of 3
```

### For High-Performance Machines

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false",  // Auto-approve for speed
    "CLAUDE_CODE_TEAM_NAME": "high-performance-team"
  },
  "model": "glm-4.7"
}
```

**Teammate Count**:
```yaml
# In orchestrator.md, increase teammates
ExitPlanMode:
  launchSwarm: true
  teammateCount: 5  # Maximum teammates
```

---

## Security Considerations

### Agent Identity

**Best Practices**:
- Use unique `CLAUDE_CODE_AGENT_ID` per environment
- Don't share agent IDs across different deployments
- Rotate agent IDs periodically

**Example**:
```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "prod-orchestrator-us-east-1-2026-01-29"
  }
}
```

### Plan Approval

**Development**: `CLAUDE_CODE_PLAN_MODE_REQUIRED = "false"` (auto-approve)
**Staging**: `CLAUDE_CODE_PLAN_MODE_REQUIRED = "true"` (manual approval)
**Production**: `CLAUDE_CODE_PLAN_MODE_REQUIRED = "true"` (manual approval)

### Permissions

**Never** use `"bypassPermissions"` in production unless absolutely necessary.

**Always** use `"delegate"` for swarm mode.

---

## Checklist

Use this checklist when setting up Swarm Mode on a new machine:

- [ ] Claude Code zai variant installed (≥2.1.16)
- [ ] jq installed
- [ ] Repository cloned
- [ ] Configuration script run successfully
- [ ] Validation tests pass (12/12)
- [ ] Manual verification complete
- [ ] Functional test successful
- [ ] Backup file created
- [ ] Rollback procedure documented
- [ ] Teammates spawn correctly
- [ ] Inter-agent messaging works
- [ ] Documentation reviewed

---

## Support

### Documentation

- [SETTINGS_CONFIGURATION_GUIDE.md](SETTINGS_CONFIGURATION_GUIDE.md) - Detailed settings explanation
- [SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md](../../docs/architecture/SWARM_MODE_INTEGRATION_ANALYSIS_v2.81.0.md) - Technical analysis
- [SWARM_MODE_VALIDATION_v2.81.0.md](../../docs/architecture/SWARM_MODE_VALIDATION_v2.81.0.md) - Validation report

### Scripts

- `configure-swarm-mode.sh` - Automated configuration
- `test-swarm-mode-config.sh` - Validation tests
- `validate-swarm-mode.sh` - Quick validation

### External Resources

- [Native Multi-Agent Gates](https://github.com/mikekelly/claude-sneakpeek/blob/main/docs/research/native-multiagent-gates.md)
- [Swarm Mode Demo](https://x.com/NicerInPerson/status/2014989679796347375)
- [Claude Code Swarm Orchestration](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)

---

**Status**: ✅ PRODUCTION READY
**Last Updated**: 2026-01-29
**Version**: 2.81.0

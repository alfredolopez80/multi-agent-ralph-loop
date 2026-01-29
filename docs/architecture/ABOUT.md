# About Multi-Agent Ralph Loop

**Multi-Agent Ralph Loop** is a sophisticated AI orchestration system that coordinates multiple AI models and agents to produce validated, high-quality code through swarm intelligence.

## 🎯 What is Multi-Agent Ralph Loop?

Multi-Agent Ralph Loop is an **AI-powered development assistant** that:

- **Coordinates multiple AI agents** working in parallel
- **Validates code** through quality gates and adversarial review
- **Learns from repositories** to extract best practices
- **Remembers context** across sessions with semantic memory
- **Uses swarm mode** (v2.81.0) for native multi-agent coordination

## 🚀 Key Features

### Swarm Mode (v2.81.0) 🆕
- **Native multi-agent coordination** using Claude Code's TeammateTool
- **Automatic teammate spawning** with shared task lists
- **Inter-agent messaging** for collaboration
- **Plan approval workflow** for leader validation

### Multi-Model Architecture
- **GLM-4.7 PRIMARY** - Economic model for all tasks (~15% cost)
- **Codex GPT-5.2 SPECIALIZED** - Security and performance analysis
- **Gemini 2.5 Pro OPTIONAL** - Cross-validation and extended context

### Quality-First Validation
- **9 languages supported** (TypeScript, Python, Go, Rust, Solidity, etc.)
- **3-stage validation** (CORRECTNESS → QUALITY → CONSISTENCY)
- **Security scanning** with semgrep and gitleaks
- **Adversarial validation** with 4-model consensus

### Memory & Learning
- **Semantic memory** - Facts and preferences (persistent)
- **Episodic memory** - Decisions and patterns (30-day TTL)
- **Procedural memory** - 300+ learned rules with confidence scores
- **Repository learning** - Extract best practices from GitHub repos

## 📊 Statistics

| Metric | Value |
|--------|-------|
| **Agents** | 11 specialized agents |
| **Hooks** | 74 hooks (73 bash + 1 python) |
| **Skills** | 40 core skills |
| **MCP Servers** | 26 servers |
| **Tests** | 945 tests passing |
| **Languages** | 9 supported |
| **Version** | 2.81.0 |

## 🎓 Use Cases

### 1. Feature Development
```bash
/orchestrator "Implement OAuth2 authentication with JWT tokens"
# → Spawns 3 teammates: code-reviewer, test-architect, security-auditor
```

### 2. Code Review
```bash
/orchestrator "Review the PR for authentication changes"
# → Routes to code-reviewer with pattern analysis
```

### 3. Debugging
```bash
/orchestrator "Debug the authentication failure in login.ts"
# → Routes to debugger with systematic diagnosis
```

### 4. Learning
```bash
/repo-learn https://github.com/fastapi/fastapi
# → Extracts best practices and adds to procedural memory
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  MULTI-AGENT SWARM MODE v2.81.0                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ORCHESTRATOR (LEAD)                                           │
│   ┌─────────────┐                                              │
│   │  GLM-4.7    │                                              │
│   │  PRIMARY    │                                              │
│   │  Coordinator│                                              │
│   └──────┬──────┘                                              │
│          │                                                     │
│          ├─────────────┬─────────────┬─────────────┐            │
│          ↓             ↓             ↓             ↓            │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│   │code-     │  │test-     │  │security- │  │debugger  │       │
│   │reviewer  │  │architect │  │auditor   │  │          │       │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                 │
│   INTER-AGENT MESSAGING + SHARED TASK LIST                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](../README.md) | Complete project documentation |
| [AGENTS.md](../AGENTS.md) | Agent reference guide |
| [CHANGELOG.md](../CHANGELOG.md) | Version history |
| [Swarm Mode Guide](../tests/swarm-mode/COMO_USAR_SWARM_MODE_CLAUDE_ZAI.md) | Spanish guide for swarm mode |
| [Architecture](../docs/architecture/) | Technical architecture documentation |

## 🛠️ Technology Stack

- **Claude Code CLI** - Base orchestration
- **Swarm Mode** - Native multi-agent coordination (v2.81.0)
- **GLM-4.7** - PRIMARY economic model
- **Bash/zsh** - 74 hooks for automation
- **Python 3.11+** - Utility scripts
- **26 MCP servers** - Extended capabilities

## 📦 Installation

```bash
# Clone the repository
git clone https://github.com/alfredolopez80/multi-agent-ralph-loop.git
cd multi-agent-ralph-loop

# Run the installer
./install.sh

# Configure Swarm Mode (v2.81.0)
bash tests/swarm-mode/configure-swarm-mode.sh

# Verify Swarm Mode
bash tests/swarm-mode/test-swarm-mode-config.sh
```

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the BSL 1.1 License - see [LICENSE](../LICENSE) for details.

## 🔗 Links

- **Repository**: https://github.com/alfredolopez80/multi-agent-ralph-loop
- **Issues**: https://github.com/alfredolopez80/multi-agent-ralph-loop/issues
- **Discussions**: https://github.com/alfredolopez80/multi-agent-ralph-loop/discussions

---

**Version**: 2.81.0
**Last Updated**: 2026-01-29

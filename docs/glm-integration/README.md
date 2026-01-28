# GLM-4.7 Integration

Documentation for GLM-4.7 model integration in Multi-Agent Ralph Loop.

## Overview

GLM-4.7 (Z.ai) is the primary economic model for complexity 1-4 tasks, providing cost-effective inference with multimodal capabilities including vision analysis and web search.

## Documents

| File | Description |
|------|-------------|
| [INTEGRATION_PLAN.md](INTEGRATION_PLAN.md) | GLM-4.7 integration plan and architecture |

## Key Features

- **Cost-Effective**: 8% of the cost of premium models for standard tasks
- **Multimodal**: Vision analysis, web search, and documentation extraction
- **14 MCP Tools**: Specialized tools for image analysis, web search, and more
- **Primary for Complexity 1-4**: Default model for low-complexity tasks

## MCP Tools Available

| Category | Tools | Purpose |
|----------|-------|---------|
| **Vision** | 8 tools | Image analysis, error diagnosis, UI to code, visual regression |
| **Web** | 2 tools | Enhanced web search, URL extraction |
| **Docs** | 3 tools | Documentation search and file reading |
| **Gen** | 1 tool | Image generation |

## Related Documentation

- [../context-monitoring/](../context-monitoring/) - GLM context monitoring and tracking
- [CLAUDE.md](../../CLAUDE.md) - Project documentation standards

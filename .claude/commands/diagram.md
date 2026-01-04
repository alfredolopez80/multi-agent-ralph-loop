---
name: diagram
prefix: "@diagram"
category: tools
color: green
description: "Generate Mermaid diagrams for documentation"
argument-hint: "<description> [--type <type>] [--save <path>]"
---

# /diagram - Mermaid Documentation Diagrams (v2.26)

Generate professional Mermaid diagrams for documentation using the Mermaid MCP.

## Usage

```bash
/diagram "system architecture"
/diagram "user authentication flow" --type sequence
/diagram "database schema" --type erDiagram --save docs/schema.svg
@diagram "API endpoints" --type flowchart
```

## Execution

When `/diagram` is invoked:

### Step 1: Analyze Description

Parse the description to determine:
- Diagram type (auto-detect or use --type)
- Key components to visualize
- Relationships between components

### Step 2: Generate Mermaid Code

Based on description, generate appropriate Mermaid syntax:

```yaml
mcp__mermaid__mermaid_preview:
  diagram: |
    <generated_mermaid_code>
  preview_id: "<unique_id>"
  theme: "default"
  width: 800
  height: 600
```

### Step 3: Validate and Save (Optional)

If `--save` is specified, **SECURITY VALIDATION IS MANDATORY**:

#### Path Security Checks (CWE-22 Prevention)

Before saving, validate the path:

1. **REJECT absolute paths** - Must be relative to project root
2. **REJECT path traversal** - No `..` components allowed
3. **RESTRICT to allowed directories** - Only `docs/`, `assets/`, `images/`, `.github/`
4. **ASK user confirmation** for any unusual paths

```yaml
# SECURITY: Validate path BEFORE saving
# Check 1: Reject absolute paths
if path.startswith('/') or path.startswith('~'):
  ERROR: "Absolute paths not allowed. Use relative paths like 'docs/diagram.svg'"

# Check 2: Reject path traversal
if '..' in path:
  ERROR: "Path traversal not allowed. Use paths within project root."

# Check 3: Validate allowed directories
allowed_prefixes: ["docs/", "assets/", "images/", ".github/"]
if not any(path.startswith(p) for p in allowed_prefixes):
  ASK_USER: "Save to '${path}'? This is outside standard documentation directories."

# Check 4: Only proceed if validated
mcp__mermaid__mermaid_save:
  preview_id: "<same_id>"
  save_path: "<validated_path>"  # MUST pass security checks
  format: "svg"
```

## Supported Diagram Types

| Type | Use Case | Example |
|------|----------|---------|
| `flowchart` | Process flows, decision trees | Architecture, workflows |
| `sequence` | Interactions over time | API calls, user flows |
| `classDiagram` | OOP structures | Domain models |
| `erDiagram` | Database schemas | Entity relationships |
| `stateDiagram` | State machines | Component states |
| `gantt` | Project timelines | Sprint planning |
| `pie` | Distribution data | Usage stats |
| `mindmap` | Brainstorming | Feature planning |
| `gitGraph` | Branch visualization | Git workflows |

## Auto-Detection Keywords

| Keywords | Detected Type |
|----------|---------------|
| "flow", "process", "architecture" | flowchart |
| "sequence", "interaction", "call" | sequence |
| "class", "object", "inheritance" | classDiagram |
| "database", "schema", "entity" | erDiagram |
| "state", "transition", "status" | stateDiagram |
| "timeline", "schedule", "sprint" | gantt |
| "distribution", "percentage" | pie |
| "ideas", "brainstorm", "concepts" | mindmap |
| "branch", "merge", "commit" | gitGraph |

## Examples

### Architecture Diagram

```
/diagram "microservices architecture with API gateway, auth service, and database"
```

Generates:
```mermaid
flowchart TB
    subgraph Client
        A[Web App]
        B[Mobile App]
    end

    C[API Gateway]

    subgraph Services
        D[Auth Service]
        E[User Service]
        F[Order Service]
    end

    subgraph Data
        G[(PostgreSQL)]
        H[(Redis Cache)]
    end

    A --> C
    B --> C
    C --> D
    C --> E
    C --> F
    D --> G
    E --> G
    F --> G
    D --> H
```

### Sequence Diagram

```
/diagram "OAuth2 authentication flow" --type sequence
```

Generates:
```mermaid
sequenceDiagram
    participant U as User
    participant C as Client App
    participant A as Auth Server
    participant R as Resource Server

    U->>C: Click Login
    C->>A: Authorization Request
    A->>U: Login Page
    U->>A: Credentials
    A->>C: Authorization Code
    C->>A: Exchange Code for Token
    A->>C: Access Token
    C->>R: API Request + Token
    R->>C: Protected Resource
    C->>U: Display Data
```

### ER Diagram

```
/diagram "user orders database schema" --type erDiagram --save docs/db-schema.svg
```

Generates:
```mermaid
erDiagram
    USER ||--o{ ORDER : places
    USER {
        int id PK
        string email UK
        string password_hash
        datetime created_at
    }
    ORDER ||--|{ ORDER_ITEM : contains
    ORDER {
        int id PK
        int user_id FK
        decimal total
        string status
        datetime created_at
    }
    ORDER_ITEM {
        int id PK
        int order_id FK
        int product_id FK
        int quantity
        decimal price
    }
    PRODUCT ||--o{ ORDER_ITEM : "ordered in"
    PRODUCT {
        int id PK
        string name
        decimal price
        int stock
    }
```

## Theme Options

| Theme | Description |
|-------|-------------|
| `default` | Light theme (default) |
| `forest` | Green nature theme |
| `dark` | Dark mode |
| `neutral` | Minimal grayscale |

```
/diagram "flow" --theme dark --save docs/flow-dark.svg
```

## Integration with Documentation

This command is designed for **documentation generation only**, not for skills or custom commands. Use cases:

- README architecture diagrams
- API documentation flow charts
- Database schema visualizations
- Process documentation
- Onboarding guides

## CLI Alternative

```bash
ralph diagram "architecture" --type flowchart
ralph diagram "auth flow" --save docs/auth.svg
```

## Related Commands

- `/browse` - Capture screenshots for documentation
- `/image-analyze` - Analyze existing diagrams
- `/retrospective` - Generate improvement flow diagrams

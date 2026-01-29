# Gemini CLI Built-in Tools

Reference for Gemini's built-in tools and their capabilities.

## Unique Tools (Not in Claude Code)

### google_web_search

Real-time internet search via Google Search API.

**Capabilities:**
- Real-time internet search
- Current information (news, releases, docs)
- Grounded responses with sources

**Usage:**
```bash
gemini "What are the latest React 19 features? Use Google Search." -o text
```

**Best For:**
- Current events and news
- Latest library versions
- Recent documentation updates
- Community opinions and benchmarks

**Example Queries:**
```bash
gemini "What are the security vulnerabilities in lodash 4.x? Use Google Search." -o text
gemini "What's new in TypeScript 5.5? Use Google Search." -o text
gemini "Best practices for Next.js 15 in December 2025." -o text
```

---

### codebase_investigator

Specialized tool for deep codebase analysis.

**Capabilities:**
- Architectural mapping
- Dependency analysis
- Cross-file relationship detection
- System-wide pattern identification

**Usage:**
```bash
gemini "Use the codebase_investigator tool to analyze this project" -o text
```

**Output Includes:**
- Overall architecture description
- Key file purposes
- Component relationships
- Dependency chains
- Potential issues/inconsistencies

**Best For:**
- Onboarding to new codebases
- Understanding legacy systems
- Finding hidden dependencies
- Architecture documentation

**Examples:**
```bash
gemini "Use codebase_investigator to map the authentication flow" -o text
gemini "Use codebase_investigator to find all database queries" -o text
```

---

### save_memory

Saves information to persistent long-term memory.

**Capabilities:**
- Cross-session persistence
- Key-value storage
- Recall in future sessions

**Usage:**
```bash
gemini "Remember that this project uses Zustand for state management. Save to memory." -o text
```

**Best For:**
- Project conventions
- User preferences
- Recurring context
- Custom instructions

---

## Standard Tools

### list_directory

Lists files and subdirectories in a path.

**Parameters:**
- `path`: Directory to list
- `ignore`: Glob patterns to exclude

### read_file

Reads file content with truncation for large files.

**Supported Formats:**
- Text files (all types)
- Images (PNG, JPG, GIF, WEBP, SVG, BMP)
- PDF documents

**Parameters:**
- `path`: File path
- `offset`: Starting line (for large files)
- `limit`: Number of lines

**Large File Handling:**
If file exceeds limit, output indicates truncation with instructions for reading more.

### search_file_content

Fast content search powered by ripgrep.

**Advantages:**
- Optimized performance
- Automatic output limiting (max 20k matches)
- Better pattern matching

**Parameters:**
- `pattern`: Regex pattern
- `path`: Search root

### glob

Pattern-based file finding.

**Returns:**
- Absolute paths
- Sorted by modification time (newest first)

**Example Patterns:**
- `src/**/*.ts` - All TypeScript files in src
- `**/*.test.js` - All test files
- `**/README.md` - All READMEs

### web_fetch

Fetches content from URLs.

**Capabilities:**
- HTTP/HTTPS URLs
- Local addresses (localhost)
- Up to 20 URLs per request

### write_todos

Internal task tracking for complex requests.

---

## Tool Invocation

### Automatic Selection

Gemini selects tools based on prompt:

| Prompt Type | Tool Selected |
|-------------|---------------|
| "What files are in src/" | list_directory |
| "Find all TODO comments" | search_file_content |
| "Read package.json" | read_file |
| "Find all React components" | glob |
| "What's new in Vue 4?" | google_web_search |
| "Analyze this codebase" | codebase_investigator |

### Explicit Requests

```bash
gemini "Use the codebase_investigator tool to..." -o text
gemini "Search the web for..." -o text
gemini "Use glob to find all..." -o text
```

---

## Tool Statistics in JSON Output

When using `-o json`, tool usage is reported in `stats.tools`:

```json
{
  "stats": {
    "tools": {
      "totalCalls": 3,
      "totalSuccess": 3,
      "totalFail": 0,
      "totalDurationMs": 5000,
      "byName": {
        "google_web_search": {
          "count": 1,
          "success": 1,
          "durationMs": 3000
        },
        "read_file": {
          "count": 2,
          "success": 2,
          "durationMs": 2000
        }
      }
    }
  }
}
```

---

## Comparison with Claude Code Tools

| Capability | Claude Code | Gemini CLI |
|------------|-------------|------------|
| File listing | LS, Glob | list_directory, glob |
| File reading | Read | read_file |
| File writing | Write, Edit | write_file (YOLO mode) |
| Code search | Grep | search_file_content |
| Web fetch | WebFetch | web_fetch |
| Web search | WebSearch | **google_web_search** |
| Architecture | Task (Explore) | **codebase_investigator** |
| Memory | - | **save_memory** |
| Task tracking | TodoWrite | write_todos |

**Bold** = Gemini's unique advantage

---

## Tool Restrictions

### Using allowed-tools

Restrict available tools:

```bash
gemini --allowed-tools "read_file,glob" "Find config files" -o text
```

### In Settings

```json
{
  "security": {
    "allowedTools": ["read_file", "list_directory", "glob"]
  }
}
```

---

## Tool Combination Patterns

### Research → Implement

```bash
gemini "Use Google Search to find best practices for [topic], then implement them" --yolo -o text
```

### Analyze → Report

```bash
gemini "Use codebase_investigator to analyze the project, then write a summary report" --yolo -o text
```

### Search → Read → Modify

```bash
gemini "Find all files using deprecated API, read them, and suggest updates" -o text
```

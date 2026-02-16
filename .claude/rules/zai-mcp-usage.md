# Zai MCP Servers - Usage Guidelines

This guide covers the 4 Zai MCP servers configured in Claude Code and when to use each tool.

## MCP Server Overview

| Server | Type | Tools | Use Case |
|--------|------|-------|----------|
| `zai-mcp-server` | stdio | 8 vision/analysis tools | Images, screenshots, diagrams, videos |
| `web-search-prime` | http | `webSearchPrime` | Web search with rich results |
| `web-reader` | http | `webReader` | Extract full webpage content |
| `zread` | http | `search_doc`, `read_file`, `get_repo_structure` | GitHub repository documentation |

---

## zai-mcp-server (8 Vision Tools)

### When to Use

- User provides an image file (screenshot, photo, diagram)
- User mentions "this screenshot", "the image above", "see attachment"
- Analyzing visual data (charts, graphs, dashboards)
- Error screenshots that need diagnosis
- UI/UX screenshots that need code generation
- Technical diagrams (architecture, flowcharts, UML)

### Tools Breakdown

| Tool | Purpose | Example Usage |
|------|---------|--------------|
| `ui_to_artifact` | Convert UI → code/prompt/spec | "Convert this screenshot to React code" |
| `extract_text_from_screenshot` | OCR for text extraction | "Extract the text from this error screenshot" |
| `diagnose_error_screenshot` | Analyze errors + suggest fixes | "What's wrong in this error message?" |
| `understand_technical_diagram` | Interpret architecture/flowcharts | "Explain this system architecture diagram" |
| `analyze_data_visualization` | Extract insights from charts | "What trends does this chart show?" |
| `ui_diff_check` | Compare UI screenshots | "Did this UI change between versions?" |
| `image_analysis` | General image understanding | "Describe what's in this image" |
| `video_analysis` | Process video files (MP4/MOV/M4V) | "Analyze this screen recording" |

### Decision Flow

```
User provides image/video?
├─ Yes → Is it a UI screenshot?
│  ├─ Yes → ui_to_artifact (for code) or extract_text_from_screenshot (for text)
│  └─ No → Is it an error?
│     ├─ Yes → diagnose_error_screenshot
│     └─ No → Is it a diagram?
│        ├─ Yes → understand_technical_diagram
│        └─ No → Is it a chart/dashboard?
│           ├─ Yes → analyze_data_visualization
│           └─ No → image_analysis or video_analysis
└─ No → Use other tools
```

---

## web-search-prime (webSearchPrime)

### When to Use

- User asks for current information (news, recent changes, "latest version")
- User mentions "search", "find online", "look up"
- Information that might have changed since training cutoff
- Comparing multiple sources or options
- Finding documentation, tutorials, examples

### When NOT to Use

- Searching the local codebase → Use Grep/Glob/ast-grep instead
- User provides a specific URL → Use web-reader instead
- Simple factual information within training data → No search needed

### Key Parameters

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `search_query` | What to search (max 70 chars recommended) | "Claude Code MCP setup 2025" |
| `search_domain_filter` | Limit to specific domain | "docs.anthropic.com" |
| `search_recency_filter` | Time range | "oneWeek", "oneMonth", "oneYear", "noLimit" |
| `content_size` | Summary length | "medium" (default), "high" (max context) |
| `location` | Region | "cn" (China), "us" (non-China) |

---

## web-reader (webReader)

### When to Use

- User provides a specific URL to read
- "Read this article", "summarize this page", "what's on this URL"
- Need full content of a webpage, not just search results
- Extracting links, metadata, or structured content from a page

### When NOT to Use

- Multiple URLs or unknown sources → Use web-search-prime first
- Local files → Use Read tool instead
- GitHub repos → Use zread instead

### What It Returns

- Page title
- Main content (article body, markdown-friendly)
- Metadata (author, date, tags)
- List of links on the page
- Images summary (if enabled)

---

## zread (GitHub Repository Documentation)

### When to Use

- User asks about a specific GitHub repository
- "What does this repo do?", "How do I use X library?"
- Need to understand repo structure before diving into code
- Finding documentation in GitHub repos

### Tools Breakdown

| Tool | Purpose | Example |
|------|---------|---------|
| `search_doc` | Search repo docs | "Find authentication docs in repo X" |
| `get_repo_structure` | List files/folders | "Show me the folder structure of X" |
| `read_file` | Read specific file | "Show the README from repo X" |

### When NOT to Use

- Local codebase → Use Read/Grep instead
- Private repos without access → Won't work
- Non-GitHub URLs → Use web-reader instead

---

## Tool Selection Priority

1. **Local codebase first** → Use Read, Grep, Glob, ast-grep
2. **Specific URL provided** → Use web-reader
3. **GitHub repo mentioned** → Use zread
4. **Image/video provided** → Use zai-mcp-server tools
5. **General web search needed** → Use web-search-prime

---

## Common Patterns

| User Request | Primary Tool | Secondary Tools |
|--------------|--------------|-----------------|
| "What's the latest version of X?" | web-search-prime | - |
| "Read this article: [URL]" | web-reader | - |
| "Explain this screenshot" | diagnose_error_screenshot or image_analysis | - |
| "How do I use this library: [GitHub URL]" | zread (search_doc) | - |
| "Convert this UI to code" | ui_to_artifact | - |
| "Find tutorials about X" | web-search-prime | web-reader (for specific results) |
| "What's in this repo?" | zread (get_repo_structure) | search_doc |
| "Analyze this chart" | analyze_data_visualization | - |
| "Extract text from this image" | extract_text_from_screenshot | - |

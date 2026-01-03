---
name: image-analyze
description: "Analyze images via MiniMax MCP (screenshots, UI, diagrams)"
argument-hint: "<prompt> <image_path_or_url>"
---

# /image-analyze - MiniMax MCP Image Analysis (v2.24)

Analyze images using MiniMax MCP for debugging, UI review, and diagram understanding.

## Usage

```
/image-analyze "Describe this error" /tmp/error-screenshot.png
/image-analyze "What UI issues?" @artifacts/mockup.png
/image-analyze "Explain architecture" https://example.com/diagram.jpg
```

## Execution

When `/image-analyze` is invoked:

### Step 1: Validate Input

```yaml
# Strip @ prefix from Claude artifacts
image_source = image_source.replace('@', '')

# Check format: JPEG, PNG, WebP
# Check size: max 20MB
```

### Step 2: Execute MCP Tool

```yaml
mcp__MiniMax__understand_image:
  prompt: "<analysis_prompt>"
  image_source: "<path_or_url>"
```

### Step 3: Structured Response

The tool returns detailed analysis based on prompt.

## Use Cases

### Error Screenshot Debugging

```
/image-analyze "Identify the error type and suggest fixes" /tmp/error.png
```

**Prompt template for errors:**
```
Analyze this error screenshot:
1. Identify the error type (syntax, runtime, network, etc.)
2. Extract the exact error message
3. Suggest 3 potential fixes
4. Recommend debugging steps
```

### UI/UX Review

```
/image-analyze "Review this UI for accessibility issues" ./mockup.png
```

**Prompt template for UI:**
```
Review this UI design:
1. Identify accessibility issues (contrast, sizing, labels)
2. Check responsive design patterns
3. Evaluate visual hierarchy
4. Suggest improvements
```

### Architecture Diagram

```
/image-analyze "Explain this system architecture" ./diagram.png
```

**Prompt template for diagrams:**
```
Analyze this architecture diagram:
1. Identify main components
2. Describe data flow
3. Note potential bottlenecks
4. Suggest improvements
```

## Supported Formats

| Format | Max Size | Notes |
|--------|----------|-------|
| JPEG | 20MB | Most compatible |
| PNG | 20MB | Screenshots |
| WebP | 20MB | Modern format |

## Anti-Patterns

- Don't use for text extraction (use OCR tools)
- Don't analyze videos (single frames only)
- Don't send sensitive images (credentials, PII)

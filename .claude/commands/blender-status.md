---
# VERSION: 2.43.0
name: blender-status
prefix: "@bstatus"
category: tools
color: green
description: "Check Blender MCP connection and all integrations status"
allowed-tools:
  - mcp__blender__*
---

# /blender-status - Blender MCP Status Check v1.0

Quick diagnostic command to verify Blender MCP connection and all integrations.

## Usage

```bash
/blender-status
```

## Execution

```yaml
# Step 1: Check Scene Connection
mcp__blender__get_scene_info: {}

# Step 2: Check AI Generators
mcp__blender__get_hyper3d_status: {}
mcp__blender__get_hunyuan3d_status: {}

# Step 3: Check Asset Libraries
mcp__blender__get_polyhaven_status: {}
mcp__blender__get_sketchfab_status: {}

# Step 4: Check PolyHaven Categories
mcp__blender__get_polyhaven_categories:
  asset_type: "all"
```

## Output Format

```
╔════════════════════════════════════════════════════════╗
║              BLENDER MCP STATUS REPORT                 ║
╠════════════════════════════════════════════════════════╣
║ Connection:        ✅ Connected / ❌ Disconnected      ║
║ Blender Version:   X.X.X                               ║
║ Scene Objects:     N objects                           ║
╠════════════════════════════════════════════════════════╣
║ 3D GENERATORS                                          ║
╠════════════════════════════════════════════════════════╣
║ Hyper3D Rodin:     ✅ Available / ⚠️ Limited / ❌ Off  ║
║ Hunyuan3D:         ✅ Available / ❌ Not configured    ║
╠════════════════════════════════════════════════════════╣
║ ASSET LIBRARIES                                        ║
╠════════════════════════════════════════════════════════╣
║ PolyHaven:         ✅ Enabled / ❌ Disabled            ║
║ Sketchfab:         ✅ Connected / ❌ No API key        ║
╠════════════════════════════════════════════════════════╣
║ QUICK ACTIONS                                          ║
╠════════════════════════════════════════════════════════╣
║ • /blender-3d create <image> <desc> - Full pipeline   ║
║ • /image-to-3d <image> - Convert image to 3D          ║
║ • /blender-3d search <query> - Find assets            ║
║ • /blender-3d setup-scene studio - Prepare scene      ║
╚════════════════════════════════════════════════════════╝
```

## Troubleshooting

### Connection Failed

```
1. Ensure Blender is running
2. In Blender: Edit > Preferences > Add-ons
3. Enable "Blender MCP" addon
4. In 3D View sidebar (N key) > BlenderMCP tab
5. Click "Start Server"
6. Wait for "Server running on port 9876"
```

### Hyper3D Not Available

```
- Free tier has daily limits
- Wait 24h for reset
- Or configure your own API key at hyper3d.ai
```

### Hunyuan3D Not Configured

```
- Requires Tencent API access
- Configure in Blender addon preferences
```

### PolyHaven Disabled

```
- Enable in Blender addon preferences checkbox
- May require internet connection
```

### Sketchfab No API Key

```
- Create account at sketchfab.com
- Get API key from settings
- Configure in Blender addon
```

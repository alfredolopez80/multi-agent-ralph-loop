---
name: blender-3d
prefix: "@3d"
category: tools
color: green
description: "Complete 3D asset creation from reference images using Blender MCP + MiniMax analysis"
argument-hint: "<action> [image_path] [description]"
allowed-tools:
  - mcp__blender__*
  - mcp__MiniMax__understand_image
  - mcp__MiniMax__web_search
  - mcp__nanobanana__generate_image
  - Read
  - Write
  - Bash
  - Task
---

# /blender-3d - Complete 3D Asset Creation Pipeline v1.0

Create production-ready 3D assets from reference images using Blender MCP with AI-powered analysis and generation.

## Usage

```bash
# Analyze reference image and generate 3D
/blender-3d create /path/to/reference.png "medieval sword with ornate handle"

# Analyze reference only (no generation)
/blender-3d analyze /path/to/concept.jpg

# Generate from text description only
/blender-3d generate "cute cartoon robot with big eyes"

# Quick asset from PolyHaven/Sketchfab
/blender-3d search "wooden barrel texture"

# Check status of generators
/blender-3d status

# Scene setup with lighting
/blender-3d setup-scene studio

# Export current object
/blender-3d export glb /path/to/output/
```

## Actions

### `create` - Full Pipeline (Image + Text to 3D)

The complete workflow: analyze image → select generator → create 3D → apply materials → export.

```yaml
Input:
  image_path: "<path_to_reference_image>"
  description: "<text_description>"  # Optional enhancement

Output:
  - Blender scene with generated 3D model
  - Applied materials from PolyHaven
  - Viewport screenshot for review
  - Export-ready asset
```

### `analyze` - Reference Image Analysis

Deep analysis of reference image using MiniMax.

```yaml
mcp__MiniMax__understand_image:
  prompt: |
    Perform comprehensive 3D asset analysis:

    ## GEOMETRY
    - Object type: [character|prop|environment|vehicle|creature|architecture]
    - Shape language: [organic|hard-surface|mixed]
    - Symmetry: [symmetric|asymmetric|partially_symmetric]
    - Estimated poly budget: [low:<5k|mid:5k-50k|high:50k+]
    - Key silhouette features

    ## MATERIALS (for each distinct surface)
    - Material type: [metal|wood|fabric|skin|plastic|glass|stone|other]
    - Base color (hex): #XXXXXX
    - Roughness: [0.0-1.0]
    - Metallic: [0.0|1.0]
    - Normal detail level: [subtle|moderate|heavy]

    ## STYLE
    - Art direction: [photorealistic|stylized|cartoon|anime|low-poly]
    - Color palette: [primary, secondary, accent colors]
    - Era/theme: [medieval|sci-fi|modern|fantasy|other]

    ## GENERATION RECOMMENDATION
    - Recommended method: [Hyper3D_text|Hyper3D_image|Hunyuan3D|Manual]
    - Bbox ratio [L:W:H]: [x.x, x.x, x.x]
    - Optimal prompt for generation
    - Potential challenges

    Return as structured JSON.
  image_source: "<image_path>"
```

### `generate` - Text-to-3D Generation

Generate 3D model from text description only.

```yaml
# Step 1: Check available generators
mcp__blender__get_hyper3d_status: {}
mcp__blender__get_hunyuan3d_status: {}

# Step 2: Generate (prefer Hyper3D for text)
mcp__blender__generate_hyper3d_model_via_text:
  text_prompt: "<user_description>"
  bbox_condition: [1.0, 1.0, 1.0]  # Adjust based on object type

# Step 3: Poll until complete
# Loop with 5-second intervals
mcp__blender__poll_rodin_job_status:
  subscription_key: "<key>"

# Step 4: Import when Done
mcp__blender__import_generated_asset:
  name: "<sanitized_name>"
  task_uuid: "<uuid>"
```

### `search` - Find Assets

Search PolyHaven and Sketchfab for existing assets.

```yaml
# Search PolyHaven textures
mcp__blender__get_polyhaven_categories:
  asset_type: "textures"

mcp__blender__search_polyhaven_assets:
  asset_type: "all"
  categories: "<relevant_categories>"

# Search Sketchfab models
mcp__blender__search_sketchfab_models:
  query: "<search_term>"
  downloadable: true
  count: 10
```

### `status` - Check Integration Status

```yaml
mcp__blender__get_scene_info: {}
mcp__blender__get_hyper3d_status: {}
mcp__blender__get_hunyuan3d_status: {}
mcp__blender__get_polyhaven_status: {}
mcp__blender__get_sketchfab_status: {}
```

### `setup-scene` - Prepare Blender Scene

```yaml
# Available presets: studio, outdoor, product, dark
mcp__blender__execute_blender_code:
  code: |
    import bpy
    import math

    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

    # Studio lighting setup
    def setup_studio():
        # Key light
        bpy.ops.object.light_add(type='AREA', location=(4, -4, 6))
        key = bpy.context.active_object
        key.name = "Key_Light"
        key.data.energy = 1000
        key.data.size = 3
        key.rotation_euler = (math.radians(45), 0, math.radians(45))

        # Fill light
        bpy.ops.object.light_add(type='AREA', location=(-4, 4, 4))
        fill = bpy.context.active_object
        fill.name = "Fill_Light"
        fill.data.energy = 300
        fill.data.size = 5

        # Rim light
        bpy.ops.object.light_add(type='SPOT', location=(0, 5, 3))
        rim = bpy.context.active_object
        rim.name = "Rim_Light"
        rim.data.energy = 500
        rim.rotation_euler = (math.radians(-60), 0, math.radians(180))

        # Camera
        bpy.ops.object.camera_add(location=(7, -7, 5))
        cam = bpy.context.active_object
        cam.name = "Main_Camera"
        cam.rotation_euler = (math.radians(60), 0, math.radians(45))
        bpy.context.scene.camera = cam

        # Ground plane (optional)
        bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
        ground = bpy.context.active_object
        ground.name = "Ground"

    setup_studio()
    print("Studio scene setup complete!")
```

### `export` - Export Current Model

```yaml
mcp__blender__execute_blender_code:
  code: |
    import bpy
    import os

    format = "<glb|fbx|obj>"
    output_path = "<output_directory>"

    # Get selected object or active object
    obj = bpy.context.active_object
    if not obj:
        for o in bpy.data.objects:
            if o.type == 'MESH':
                obj = o
                break

    if obj:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)

        if format == "glb":
            filepath = os.path.join(output_path, f"{obj.name}.glb")
            bpy.ops.export_scene.gltf(
                filepath=filepath,
                export_format='GLB',
                use_selection=True,
                export_materials='EXPORT'
            )
        elif format == "fbx":
            filepath = os.path.join(output_path, f"{obj.name}.fbx")
            bpy.ops.export_scene.fbx(
                filepath=filepath,
                use_selection=True
            )
        elif format == "obj":
            filepath = os.path.join(output_path, f"{obj.name}.obj")
            bpy.ops.wm.obj_export(
                filepath=filepath,
                export_selected_objects=True
            )
        print(f"Exported to: {filepath}")
    else:
        print("No mesh object found to export")
```

## Complete Workflow Examples

### Example 1: Game Character from Concept Art

```bash
/blender-3d create /path/to/knight_concept.png "medieval knight in full plate armor, fantasy style"
```

**Execution Flow:**
1. Analyze image with MiniMax → Extract armor details, proportions, materials
2. Check Hyper3D status → Confirm availability
3. Generate with detailed prompt from analysis
4. Poll status until complete
5. Import to Blender
6. Search PolyHaven for metal textures
7. Apply materials
8. Capture screenshot for review
9. Export as GLB for game engine

### Example 2: Environment Prop

```bash
/blender-3d create ./barrel_ref.jpg "wooden barrel with metal bands, weathered"
```

### Example 3: Quick Texture Search

```bash
/blender-3d search "cobblestone medieval"
```

### Example 4: Scene Preparation

```bash
/blender-3d setup-scene studio
/blender-3d generate "crystal potion bottle with glowing liquid"
/blender-3d export glb ./exports/
```

## Advanced: Custom Material Application

```yaml
# After model generation, apply custom materials
mcp__blender__execute_blender_code:
  code: |
    import bpy

    obj = bpy.data.objects["<object_name>"]

    # Create new material
    mat = bpy.data.materials.new(name="CustomMaterial")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Get Principled BSDF
    bsdf = nodes.get("Principled BSDF")

    # Set properties from MiniMax analysis
    bsdf.inputs["Base Color"].default_value = (0.8, 0.2, 0.1, 1.0)  # Rust red
    bsdf.inputs["Metallic"].default_value = 0.9
    bsdf.inputs["Roughness"].default_value = 0.4

    # Apply to object
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)

    print(f"Applied CustomMaterial to {obj.name}")
```

## Integration with MiniMax for Enhanced Analysis

### Multi-View Analysis

```yaml
# Analyze multiple reference views
# View 1: Front
mcp__MiniMax__understand_image:
  prompt: "Analyze front view of this 3D subject. Focus on facial features and front details."
  image_source: "/path/front.jpg"

# View 2: Side
mcp__MiniMax__understand_image:
  prompt: "Analyze side profile. Focus on depth, silhouette, and proportions."
  image_source: "/path/side.jpg"

# View 3: Back
mcp__MiniMax__understand_image:
  prompt: "Analyze back view. Note any details not visible from front."
  image_source: "/path/back.jpg"
```

### Style-Specific Prompts

| Style | Analysis Focus | Generation Approach |
|-------|---------------|---------------------|
| Realistic | Surface detail, PBR values | Hyper3D image-based |
| Stylized | Shape language, exaggeration | Hyper3D text-based |
| Low-poly | Face count, clean topology | Hunyuan3D + decimate |
| Anime | Proportions, clean lines | Text prompt + manual |

## Error Handling

### Blender Not Connected
```
Error: Cannot connect to Blender

Solution:
1. Ensure Blender is running
2. In Blender: Edit > Preferences > Add-ons
3. Search "Blender MCP" and enable it
4. In 3D View sidebar (N) > BlenderMCP tab
5. Click "Start Server"
6. Retry command
```

### Generator Limit Reached
```
Error: Hyper3D daily limit exceeded

Solutions:
1. Use Hunyuan3D as alternative:
   /blender-3d create --generator hunyuan <image> <desc>

2. Wait for daily reset (24h from first use)

3. Use your own API key:
   - Get key from hyper3d.ai or fal.ai
   - Configure in Blender addon settings
```

### Import Failed
```
Error: Asset import failed

Checks:
1. Ensure job status is "Done" or "COMPLETED"
2. Verify task_uuid/request_id is correct
3. Check Blender console for Python errors
4. Try re-generating with simpler prompt
```

## Best Practices

1. **Always analyze first** - MiniMax analysis improves generation quality
2. **Use specific descriptions** - Include style, materials, era, size
3. **Set bbox_condition** - Match object proportions (sword: [0.1, 0.1, 1.5])
4. **Check status before generating** - Avoid wasted attempts
5. **Apply PolyHaven materials** - Professional quality textures
6. **Capture screenshots** - Validate before export
7. **Export multiple formats** - GLB for web, FBX for Unreal/Unity

## Version History

- **v1.0** (2025-01-04): Initial release
  - Full MiniMax + Blender MCP integration
  - Hyper3D and Hunyuan3D support
  - PolyHaven and Sketchfab integration
  - Studio scene setup presets
  - Multi-format export

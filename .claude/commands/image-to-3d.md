---
# VERSION: 2.43.0
name: image-to-3d
prefix: "@i3d"
category: tools
color: green
description: "Convert reference images to 3D assets using MiniMax analysis + Blender MCP generation"
argument-hint: "<image_path> [description]"
allowed-tools:
  - mcp__blender__*
  - mcp__MiniMax__understand_image
  - mcp__nanobanana__generate_image
  - Read
  - Bash
  - Task
---

# /image-to-3d - Reference Image to 3D Asset Converter v1.0

Intelligent image-to-3D conversion pipeline using MiniMax for analysis and Blender MCP for generation.

## Quick Usage

```bash
# Basic conversion
/image-to-3d /path/to/reference.png

# With description enhancement
/image-to-3d /path/to/concept.jpg "fantasy dragon with scales"

# From URL
/image-to-3d https://example.com/character.png "sci-fi soldier"
```

## Pipeline Steps

### Step 1: Image Validation

```yaml
# Check image format and accessibility
Supported formats: JPEG, PNG, WebP
Max size: 20MB
Required: Clear subject, good lighting, minimal occlusion
```

### Step 2: Deep Analysis with MiniMax

```yaml
mcp__MiniMax__understand_image:
  prompt: |
    # 3D ASSET ANALYSIS PROTOCOL

    Analyze this reference image for 3D model generation.

    ## 1. OBJECT IDENTIFICATION
    - Primary subject: [name/type]
    - Category: [character|prop|vehicle|creature|environment|weapon|furniture]
    - Subcategory: [specific type]

    ## 2. GEOMETRIC PROFILE
    - Topology type: [organic|hard-surface|hybrid]
    - Primary shapes: [list main geometric primitives]
    - Symmetry axis: [X|Y|Z|None]
    - Estimated dimensions (relative): L:W:H ratio
    - Complexity level: [low|medium|high|extreme]
    - Suggested poly budget: [number]

    ## 3. SURFACE ANALYSIS
    For each distinct surface/material zone:
    ```
    Zone: [name]
    Material: [type]
    Base Color: #XXXXXX
    Metallic: [0.0-1.0]
    Roughness: [0.0-1.0]
    Specular: [0.0-1.0]
    Normal Intensity: [subtle|moderate|strong]
    Emission: [none|subtle|strong]
    ```

    ## 4. STYLE CLASSIFICATION
    - Art style: [photorealistic|semi-realistic|stylized|cartoon|anime|pixel|low-poly]
    - Era/setting: [medieval|modern|futuristic|fantasy|historical]
    - Mood: [dark|bright|neutral|warm|cold]
    - Reference similar to: [known games/movies if applicable]

    ## 5. GENERATION STRATEGY
    - Recommended generator: [Hyper3D_text|Hyper3D_image|Hunyuan3D]
    - Reasoning: [why this choice]
    - bbox_condition: [L, W, H] as floats
    - Optimal generation prompt (English, detailed):
      "[comprehensive prompt for 3D generation]"

    ## 6. POST-GENERATION RECOMMENDATIONS
    - Suggested PolyHaven textures: [list texture IDs]
    - Blender modifiers: [subdivision|decimate|bevel|etc.]
    - UV unwrapping method: [smart|cube|sphere|cylinder]
    - Rigging required: [yes|no]

    ## 7. POTENTIAL CHALLENGES
    - [List potential issues with this subject]
    - [Mitigation strategies]

    Return as structured JSON.

  image_source: "$ARGUMENTS[0]"
```

### Step 3: Generator Selection & Preparation

```yaml
# Check all generator statuses
mcp__blender__get_hyper3d_status: {}
mcp__blender__get_hunyuan3d_status: {}

# Select based on analysis recommendation and availability:
#
# Priority 1: Hyper3D Image-based (best for reference matching)
# Priority 2: Hunyuan3D (good quality, different style)
# Priority 3: Hyper3D Text-based (when image-based unavailable)
# Fallback: Manual modeling with execute_blender_code
```

### Step 4: 3D Generation

#### Path A: Hyper3D Image-Based (Preferred for References)

```yaml
mcp__blender__generate_hyper3d_model_via_images:
  input_image_paths:
    - "$ABSOLUTE_PATH_TO_IMAGE"
  bbox_condition: $BBOX_FROM_ANALYSIS

# Polling loop
mcp__blender__poll_rodin_job_status:
  subscription_key: "$SUBSCRIPTION_KEY"
  # or request_id: "$REQUEST_ID"

# Import when status is "Done"
mcp__blender__import_generated_asset:
  name: "$SANITIZED_OBJECT_NAME"
  task_uuid: "$TASK_UUID"
```

#### Path B: Hunyuan3D

```yaml
mcp__blender__generate_hunyuan3d_model:
  text_prompt: "$OPTIONAL_DESCRIPTION"
  input_image_url: "$IMAGE_PATH_OR_URL"

# Polling loop
mcp__blender__poll_hunyuan_job_status:
  job_id: "$JOB_ID"

# Import when status is "DONE"
mcp__blender__import_generated_asset_hunyuan:
  name: "$OBJECT_NAME"
  zip_file_url: "$RESULT_FILE_3DS"
```

### Step 5: Material Enhancement

```yaml
# Search for recommended textures from analysis
mcp__blender__search_polyhaven_assets:
  asset_type: "textures"
  categories: "$MATERIAL_CATEGORIES"

# Download best match
mcp__blender__download_polyhaven_asset:
  asset_id: "$TEXTURE_ID"
  asset_type: "textures"
  resolution: "2k"

# Apply to generated model
mcp__blender__set_texture:
  object_name: "$OBJECT_NAME"
  texture_id: "$TEXTURE_ID"
```

### Step 6: Scene Setup for Presentation

```yaml
mcp__blender__execute_blender_code:
  code: |
    import bpy
    import math

    # Find the generated object
    obj = None
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name != 'Ground':
            obj = o
            break

    if obj:
        # Center object at origin
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
        obj.location = (0, 0, 0)

        # Calculate camera distance based on object size
        dims = obj.dimensions
        max_dim = max(dims)
        cam_distance = max_dim * 2.5

        # Position camera
        cam = bpy.context.scene.camera
        if cam:
            cam.location = (cam_distance, -cam_distance, cam_distance * 0.7)
            cam.rotation_euler = (math.radians(60), 0, math.radians(45))

        # Add floor if not exists
        if 'Ground' not in bpy.data.objects:
            bpy.ops.mesh.primitive_plane_add(size=max_dim * 10, location=(0, 0, 0))
            bpy.context.active_object.name = 'Ground'

        print(f"Scene centered on {obj.name}")
```

### Step 7: Quality Validation

```yaml
# Capture viewport
mcp__blender__get_viewport_screenshot:
  max_size: 1200

# Get object details
mcp__blender__get_object_info:
  object_name: "$OBJECT_NAME"

# Scene overview
mcp__blender__get_scene_info: {}
```

### Step 8: Output Summary

Provide user with:
- Viewport screenshot
- Object statistics (vertices, faces, materials)
- Applied textures
- Export recommendations
- Suggested improvements

## Analysis Prompt Templates

### For Characters/Creatures

```yaml
prompt_template: |
  Analyze this character/creature for 3D modeling:

  ANATOMY:
  - Body type and proportions
  - Facial features detail level
  - Limb structure and pose
  - Clothing/armor components

  RIGGING CONSIDERATIONS:
  - Joint locations
  - Deformation zones
  - Hair/cloth simulation needs

  STYLE:
  - Stylization level (1-10)
  - Comparable game/movie characters
```

### For Props/Objects

```yaml
prompt_template: |
  Analyze this prop for 3D modeling:

  CONSTRUCTION:
  - Component breakdown
  - Assembly logic
  - Mechanical parts if any

  USAGE CONTEXT:
  - Game genre suitability
  - Scale reference objects
  - Interaction points
```

### For Environments

```yaml
prompt_template: |
  Analyze this environment element:

  MODULAR POTENTIAL:
  - Tileable sections
  - Variant possibilities
  - LOD requirements

  LIGHTING:
  - Baked vs dynamic lighting needs
  - Shadow casting elements
```

## Quick Reference: Bbox Conditions

| Object Type | Recommended bbox_condition |
|-------------|---------------------------|
| Human character | [1.0, 0.5, 2.0] |
| Sword/pole weapon | [0.1, 0.1, 2.0] |
| Shield | [0.8, 0.1, 1.0] |
| Barrel/container | [1.0, 1.0, 1.2] |
| Vehicle (car) | [2.0, 1.0, 0.6] |
| Tree | [1.5, 1.5, 3.0] |
| Rock | [1.0, 0.8, 0.6] |
| Furniture (chair) | [0.5, 0.5, 1.0] |

## Error Recovery

### Generation Failed
```yaml
# Fallback 1: Try alternative generator
If Hyper3D fails → Try Hunyuan3D

# Fallback 2: Simplify prompt
Remove complex details, focus on main shape

# Fallback 3: Search existing assets
mcp__blender__search_sketchfab_models:
  query: "$SIMPLIFIED_DESCRIPTION"
  downloadable: true
```

### Poor Quality Result
```yaml
# Option 1: Regenerate with refined prompt
# Option 2: Apply subdivision modifier
mcp__blender__execute_blender_code:
  code: |
    import bpy
    obj = bpy.data.objects["$NAME"]
    mod = obj.modifiers.new("Subdivision", 'SUBSURF')
    mod.levels = 2
    mod.render_levels = 3

# Option 3: Manual cleanup with sculpt tools
```

## Integration Examples

### For david-game Project

```bash
# Convert champion concept to game asset
/image-to-3d ./champions/orc_warrior_concept.png "orc warrior with battle axe"

# Export for Three.js
mcp__blender__execute_blender_code:
  code: |
    import bpy
    bpy.ops.export_scene.gltf(
        filepath="/Users/alfredolopez/Documents/GitHub/david-game/assets/models/orc_warrior.glb",
        export_format='GLB',
        export_draco_mesh_compression_enable=True
    )
```

### Batch Processing Pattern

```yaml
# For multiple reference images
for image in reference_images:
    1. /image-to-3d $image
    2. Review and approve
    3. Export to project assets
    4. Next image
```

## Version History

- **v1.0** (2025-01-04): Initial release
  - MiniMax deep analysis integration
  - Hyper3D and Hunyuan3D support
  - Automatic material application
  - Smart scene setup
  - Quality validation workflow

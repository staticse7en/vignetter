# Vignetter Mac/Linux Port - Maintenance Guide

This document explains the differences between the original Windows version and the Mac/Linux compatible version, and how to maintain the port when syncing with upstream changes.

## Quick Summary

The original `vignetter.lua` uses Windows-only HLSL features that fail silently on Mac/Linux. The `vignetter_universal.lua` version works cross-platform with minimal changes to the shader code.

**Current Status:**
- ✅ **Original Version**: `vignetter.lua` - Works on Windows only
- ✅ **Mac/Linux Version**: `vignetter_universal.lua` - Works on all platforms

---

## Critical Mac/Linux Incompatibilities

### 1. **Uniform Default Values** (CRITICAL - Silent Failure)

**Problem:** Mac's Metal shader compiler silently rejects default values in uniform declarations.

**Original (Windows only):**
```hlsl
uniform float inner_radius = 0.9;
uniform float outer_radius = 1.5;
uniform float opacity = 0.8;
uniform float3 vignette_color = { 0.0, 0.0, 0.0 };
```

**Fix (Cross-platform):**
```hlsl
uniform float inner_radius;
uniform float outer_radius;
uniform float opacity_param;
uniform float3 vignette_color;
```

**Why:** Remove ALL `= value` default assignments. The Lua code sets these values anyway, so defaults are unnecessary.

---

### 2. **Reserved Shader Keywords** (CRITICAL - Silent Failure)

**Problem:** Some parameter names appear to conflict with Metal's reserved keywords or internal variables.

**Conflicting Names:**
- `opacity` → Rename to `opacity_param`
- `rotation` → Rename to `rotation_angle`

**Safe to Keep:**
- `inner_radius`, `outer_radius`, `center_x`, `center_y`, `aspect_ratio`
- `vignette_color`, `use_color`, `blend_mode`, `shape_type`, `shape_strength`

---

### 3. **Minor Compatibility Improvements** (Optional but Recommended)

These aren't strictly necessary but improve cross-platform compatibility:

**Rotation Matrix:**
```hlsl
// Original (works but less clear)
float2x2 rot_matrix = float2x2(c, -s, s, c);
float2 rotated_uv = mul(centered_uv, rot_matrix);

// Mac-friendly alternative (clearer, no mul())
float2 rotated;
rotated.x = centered.x * c - centered.y * s;
rotated.y = centered.x * s + centered.y * c;
```

**Distance Calculation:**
```hlsl
// Original
dist = sqrt(pow(xTrans, 2) + pow(yTrans, 2));

// Mac-friendly (equivalent, avoids pow())
dist = sqrt(xTrans * xTrans + yTrans * yTrans);
```

---

## How to Port Changes from Upstream

When the original `vignetter.lua` gets updated, follow these steps to port changes to the Mac version:

### Step 1: Identify What Changed

```bash
# Compare your last synced version with the new upstream
diff -u vignetter_old.lua vignetter_new.lua
```

### Step 2: Categorize Changes

Changes typically fall into these categories:

#### **A. Shader Code Changes**
Look for changes in the `local effect_code = [[...]]` section.

**Safe to port as-is:**
- Algorithm changes in shader functions
- New shape calculations
- Blend mode changes
- Mathematical formulas

**Requires adaptation:**
- New `uniform` declarations with `= value` defaults → Remove defaults
- New parameters named `opacity`, `rotation`, or other potential keywords → Rename
- New `pow()` calls → Consider replacing with multiplication

#### **B. Lua Code Changes**
Look for changes outside the shader code.

**Safe to port as-is:**
- New presets in `apply_preset()`
- UI changes in `get_properties()`
- Translation strings
- Bug fixes in Lua logic

**Requires adaptation:**
- References to renamed shader parameters (update to use `opacity_param`, `rotation_angle`)
- New `obs.gs_effect_get_param_by_name()` calls must match renamed parameters

#### **C. New Features**
- New presets: Port directly (they use Lua, not shader code)
- New shader parameters: Follow naming rules (no defaults, avoid reserved names)
- New shapes/blend modes: Port shader logic, ensure parameter names are safe

### Step 3: Apply Changes

1. **Copy Lua code changes directly** (presets, UI, translations, etc.)
2. **Port shader changes with adaptations:**
   - Remove `= value` from new uniforms
   - Rename any `opacity`/`rotation` parameters
   - Update corresponding Lua code to use new names

### Step 4: Test

```bash
# Test checklist:
1. Load script in OBS - check Script Log for errors
2. Add filter to a source - should not show black screen
3. Test all presets - verify they work
4. Test manual controls - sliders should update effect
5. Test all shapes (Oval, Rectangle, Diamond, Star)
6. Test color mode with different blend modes
```

---

## Complete Mapping: Original → Mac Version

### Shader Parameter Names

| Original Name | Mac Version | Reason |
|--------------|-------------|--------|
| `opacity` | `opacity_param` | Reserved keyword conflict |
| `rotation` | `rotation_angle` | Reserved keyword conflict |
| `textureSampler` | `def_sampler` | Personal preference (optional) |

### Lua Variable Names

All Lua variable names stay the same:
```lua
data.opacity = obs.obs_data_get_double(settings, "opacity")
data.rotation = obs.obs_data_get_double(settings, "rotation")
```

Only the shader parameter retrieval changes:
```lua
-- Original
data.params.opacity = obs.gs_effect_get_param_by_name(data.effect, "opacity")

-- Mac version
data.params.opacity_param = obs.gs_effect_get_param_by_name(data.effect, "opacity_param")
```

And when setting shader parameters:
```lua
-- Original
obs.gs_effect_set_float(data.params.opacity, data.opacity)

-- Mac version
obs.gs_effect_set_float(data.params.opacity_param, data.opacity)
```

---

## Example: Porting a New Preset

**Upstream adds a new preset "neon_green":**

```lua
elseif preset_type == "neon_green" then
    obs.obs_data_set_double(settings, "inner_radius", 0.4)
    obs.obs_data_set_double(settings, "outer_radius", 1.2)
    obs.obs_data_set_double(settings, "opacity", 0.8)
    obs.obs_data_set_bool(settings, "use_color", true)
    obs.obs_data_set_double(settings, "vignette_color_r", 0.0)
    obs.obs_data_set_double(settings, "vignette_color_g", 1.0)
    obs.obs_data_set_double(settings, "vignette_color_b", 0.0)
    obs.obs_data_set_int(settings, "blend_mode", 2)
```

**Port to Mac version:** Copy exactly as-is! ✅

Presets use `obs_data_set_*()` which works with the Lua variable names (not the shader parameter names), so no changes needed.

---

## Example: Porting a New Shader Feature

**Upstream adds a new "glow" parameter:**

```hlsl
// Original (Windows)
uniform float glow = 0.0;  // ❌ Has default value

// In shader function:
result += glow * someCalculation;
```

**Port to Mac:**

```hlsl
// Mac version
uniform float glow_amount;  // ✅ No default, renamed for safety

// In shader function:
result += glow_amount * someCalculation;
```

**Update Lua code:**

```lua
-- Add to create():
data.glow = 0.0

-- Add to get_defaults():
obs.obs_data_set_default_double(settings, "glow", 0.0)

-- Add to update():
data.glow = obs.obs_data_get_double(settings, "glow")

-- Add to create() shader param loading:
data.params.glow_amount = obs.gs_effect_get_param_by_name(data.effect, "glow_amount")

-- Add to set_shader_params():
if data.params.glow_amount then
    obs.gs_effect_set_float(data.params.glow_amount, data.glow)
end

-- Add to get_properties():
obs.obs_properties_add_float_slider(props, "glow", "Glow Amount", 0.0, 1.0, 0.01)
```

---

## Testing Checklist

After porting changes:

- [ ] Script loads without errors in Script Log
- [ ] Filter appears in Effects Filters list
- [ ] Adding filter shows video (not black screen)
- [ ] Default vignette appears correctly
- [ ] All 16 presets work
- [ ] Manual parameter adjustments work:
  - [ ] Inner Radius
  - [ ] Outer Radius
  - [ ] Opacity
  - [ ] Center X/Y
  - [ ] All 4 shapes (Oval, Rectangle, Diamond, Star)
  - [ ] Shape Strength
  - [ ] Rotation
  - [ ] Aspect Ratio
  - [ ] Color mode (enable/disable)
  - [ ] RGB color sliders
  - [ ] All 4 blend modes (Normal, Multiply, Screen, Overlay)

---

## Debugging Mac Shader Issues

### Symptom: Black Screen, No Script Log Output

**Cause:** Shader failed to compile silently.

**Common culprits:**
1. Default values in uniforms (`uniform float x = 1.0;`)
2. Reserved keyword as parameter name (`opacity`, `rotation`)
3. Unsupported HLSL feature

**Debug process:**
1. Comment out half the shader code
2. If it loads, the bug is in the commented section
3. Binary search until you find the problematic line
4. Check against compatibility rules above

### Symptom: Script Loads, Filter Works, But Effect is Wrong

**Cause:** Parameter mismatch between shader and Lua code.

**Check:**
1. Shader parameter names match `obs.gs_effect_get_param_by_name()` calls
2. Shader parameter names match `obs.gs_effect_set_*()` calls
3. Lua variable names match UI property names in `get_properties()`

---

## Why This Works Cross-Platform

The Mac version actually has **better cross-platform compatibility** than the original:

1. **Removed defaults** - Works everywhere (Windows ignores them anyway since Lua sets values)
2. **Renamed parameters** - Avoids potential reserved keyword conflicts on all platforms
3. **Simplified syntax** - Less reliance on platform-specific HLSL quirks

**The Mac version should work perfectly on Windows and Linux too!**

---

## Relevant Files in This Repository

- `vignetter_universal.lua` - Cross-platform compatible version ✅ **USE THIS**
- `MAC_PORTING_GUIDE.md` - This document

---

## Quick Reference: Safe vs Unsafe Shader Features

### ✅ Safe (Works on Mac/Linux/Windows)

```hlsl
uniform float my_param;
uniform float3 color_value;
uniform bool enable_effect;
uniform int mode_type;
float x = 1.0;  // Local variable with value
float2 pos = float2(0.5, 0.5);
if (condition) { }
float result = a * b + c;
```

### ❌ Unsafe (Breaks on Mac/Linux)

```hlsl
uniform float my_param = 1.0;  // ❌ Default value
uniform float opacity;         // ❌ Possible reserved keyword
uniform float rotation;        // ❌ Possible reserved keyword
```

### 🔶 Use with Caution

```hlsl
pow(x, 2.0)           // Works but prefer x * x
float2x2 matrix;      // Works but test on Mac
mul(vec, matrix)      // Works but explicit multiplication may be clearer
```

---

## Contact & Support

If you encounter issues not covered in this guide:

1. Check if the shader compiles by looking for Script Log output
2. Compare your changes against the compatibility rules above
3. When in doubt, keep shader parameter names simple and avoid reserved words

---

## Revision History

- **2026-01-03**: Initial version - Mac/Linux port completed and documented

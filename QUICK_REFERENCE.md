# Vignetter Mac Port - Quick Reference Card

## One-Page Cheat Sheet for Maintaining the Fork

### File to Use
✅ **`vignetter_universal.lua`** - Cross-platform version (Mac/Linux/Windows)
❌ **`vignetter.lua`** - Original (Windows only)

---

## The Two Critical Rules

### 1️⃣ NO DEFAULT VALUES in shader uniforms

```hlsl
❌ uniform float inner_radius = 0.9;
✅ uniform float inner_radius;
```

### 2️⃣ RENAME CONFLICTING parameters

```hlsl
❌ uniform float opacity;
✅ uniform float opacity_param;

❌ uniform float rotation;
✅ uniform float rotation_angle;
```

---

## Parameter Name Mapping

| Shader (Mac) | Lua Variable | UI Property |
|--------------|--------------|-------------|
| `opacity_param` | `data.opacity` | `"opacity"` |
| `rotation_angle` | `data.rotation` | `"rotation"` |

**Pattern:**
- Shader params avoid reserved words → `_param`, `_angle`
- Lua/UI use clean names → users see "Opacity", not "Opacity Param"

---

## Porting Checklist

When syncing from upstream:

- [ ] New presets? → Copy directly ✅
- [ ] UI changes? → Copy directly ✅
- [ ] New shader uniforms? → Remove `= value`, check name conflicts
- [ ] New shader code? → Check for `pow()`, complex matrix ops
- [ ] New param references? → Update to use renamed shader params
- [ ] Tested on Mac? → Should see logs and working filter

---

## Safe Shader Patterns

```hlsl
✅ uniform float my_param;
✅ uniform float3 color;
✅ float local_var = 1.0;
✅ dist = sqrt(x * x + y * y);
✅ if (mode == 0) { ... }
```

## Unsafe Shader Patterns

```hlsl
❌ uniform float opacity = 0.5;
❌ uniform float rotation = 0.0;
❌ dist = sqrt(pow(x, 2.0));  // works but avoid
```

---

## Debugging Black Screen

1. Check Script Log for errors
2. If no logs → shader failed to compile silently
3. Comment out half the shader → binary search for problem
4. Check against: defaults? reserved names? unsupported feature?

---

## Testing After Changes

```bash
# Minimum test
✅ Script loads (see logs)
✅ Filter applies (not black)
✅ Default preset works

# Full test
✅ All 16 presets work
✅ All manual controls work
✅ All 4 shapes work
✅ Color mode works
✅ All 4 blend modes work
```

---

## Example: Add New Preset

```lua
// In upstream vignetter.lua:
elseif preset_type == "new_preset" then
    obs.obs_data_set_double(settings, "inner_radius", 0.5)
    obs.obs_data_set_double(settings, "opacity", 0.9)
    // ... more settings

// Port to Mac version:
// → Copy EXACTLY as-is! No changes needed! ✅
```

---

## Example: Add New Shader Parameter

**Upstream adds:**
```hlsl
uniform float glow = 0.0;  // Windows version
```

**Port as:**
```hlsl
uniform float glow_amount;  // Mac version (no default, safe name)
```

**Then update Lua:**
```lua
// In create():
data.params.glow_amount = obs.gs_effect_get_param_by_name(data.effect, "glow_amount")

// In set_shader_params():
if data.params.glow_amount then
    obs.gs_effect_set_float(data.params.glow_amount, data.glow)
end
```

---

## Files You Need

📄 **README.md** - User-facing documentation
📄 **MAC_PORTING_GUIDE.md** - Detailed technical guide
📄 **QUICK_REFERENCE.md** - This cheat sheet
💻 **vignetter_universal.lua** - The working cross-platform version

---

## Emergency Contact

If something breaks and you can't figure it out:

1. Revert to last working version
2. Apply changes incrementally
3. Test after each change
4. Check MAC_PORTING_GUIDE.md for detailed examples

---

**Remember:** When in doubt, keep it simple! The goal is cross-platform compatibility, not perfect name matching. ✨

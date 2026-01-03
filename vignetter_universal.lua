--[[
    Vignetter - Professional OBS Vignette Filter
    Universal Cross-Platform Version

    Original: "Ein professioneller OBS-Lua-Script für Vignette-Effekte"
    Original Author: TheGeekFreaks (2025) - German project with English support
    Original Project: https://github.com/The-Geek-Freaks/Vignetter

    This is a cross-platform port adapted for macOS and Linux.
    The original Windows version uses HLSL features that fail on Mac/Linux.
    This version maintains identical visual output while ensuring cross-platform compatibility.

    License: GNU General Public License v3.0
    See LICENSE file for details.

    Changes from original:
    - Removed default values from shader uniforms (Metal compatibility)
    - Renamed conflicting parameters (opacity → opacity_param, rotation → rotation_angle)
    - Simplified shader syntax for cross-platform support
]]

obs = obslua
local bit = require("bit")

local effect_code = [[
uniform float4x4 ViewProj;
uniform texture2d image;

uniform float inner_radius;
uniform float outer_radius;
uniform float opacity_param;
uniform float3 vignette_color;
uniform bool use_color;
uniform float center_x;
uniform float center_y;
uniform float aspect_ratio;
uniform int blend_mode;
uniform int shape_type;
uniform float shape_strength;
uniform float rotation_angle;

sampler_state def_sampler {
    Filter   = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VertData {
    float4 pos : POSITION;
    float2 uv  : TEXCOORD0;
};

VertData VSDefault(VertData v_in)
{
    VertData v_out;
    v_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
    v_out.uv  = v_in.uv;
    return v_out;
}

float2 rotate_uv(float2 uv, float2 center, float angle)
{
    float2 centered = uv - center;
    float s = sin(angle);
    float c = cos(angle);
    float2 rotated;
    rotated.x = centered.x * c - centered.y * s;
    rotated.y = centered.x * s + centered.y * c;
    return rotated + center;
}

float calculate_shape_distance(float2 uv, float2 center, float aspect, int shape, float strength, float angle)
{
    // Rotate UV coordinates
    float2 rotated_uv = rotate_uv(uv, center, angle);

    // Apply aspect ratio (keeping it centered)
    float2 scaled_uv = rotated_uv;
    scaled_uv.x = (rotated_uv.x - center.x) * aspect + center.x;

    // Normalized coordinates for distance calculation
    float xTrans = (scaled_uv.x - center.x) * 2.0;
    float yTrans = (center.y - scaled_uv.y) * 2.0;  // Y-axis flipped

    float dist = 0.0;

    if (shape == 0) {
        // Oval - simple euclidean distance
        dist = sqrt(xTrans * xTrans + yTrans * yTrans);
    }
    else if (shape == 1) {
        // Rectangle
        float2 delta = abs(float2(xTrans, yTrans));
        dist = max(delta.x, delta.y) * strength;
    }
    else if (shape == 2) {
        // Diamond - Manhattan distance
        float2 delta = abs(float2(xTrans, yTrans));
        dist = (delta.x + delta.y) * 0.7 * strength;
    }
    else if (shape == 3) {
        // Star
        float2 delta = abs(float2(xTrans, yTrans));
        float a = atan2(delta.y, delta.x) * 5.0;  // 5 points
        float r = length(delta);
        dist = r * (0.8 + 0.2 * sin(a)) * strength;
    }

    return dist;
}

float4 PSVignette(VertData v_in) : TARGET
{
    float4 c0 = image.Sample(def_sampler, v_in.uv);
    float2 center = float2(center_x, center_y);

    // Calculate shape-specific distance
    float radius = calculate_shape_distance(v_in.uv, center, aspect_ratio, shape_type, shape_strength, rotation_angle);

    // Vignette mask based on radius
    float subtraction = max(0.0, radius - inner_radius) / max(outer_radius - inner_radius, 0.01);
    float factor = 1.0 - subtraction;
    factor = clamp(factor, 0.0, 1.0);

    // Vertical dimension for optical effect
    float PI = 3.1415926535897932384626433832795;
    float verticalDim = 0.5 + sin(v_in.uv.y * PI) * 0.9;

    float4 result;

    if (use_color) {
        // Vignette color mode
        float4 vignette_color4 = float4(vignette_color, 1.0);
        float vignette_opacity = (1.0 - factor) * opacity_param;

        if (blend_mode == 0) {
            // Normal blend
            result = lerp(c0, vignette_color4, vignette_opacity);
        }
        else if (blend_mode == 1) {
            // Multiply blend
            float4 blend_color = lerp(float4(1.0, 1.0, 1.0, 1.0), vignette_color4, vignette_opacity);
            result = c0 * blend_color;
        }
        else if (blend_mode == 2) {
            // Screen blend
            float4 blend_color = lerp(float4(0.0, 0.0, 0.0, 0.0), vignette_color4, vignette_opacity);
            float4 ones = float4(1.0, 1.0, 1.0, 1.0);
            result = ones - (ones - c0) * (ones - blend_color);
        }
        else if (blend_mode == 3) {
            // Overlay blend
            float4 blend_color = lerp(float4(0.5, 0.5, 0.5, 0.5), vignette_color4, vignette_opacity);
            float4 multiply_part = 2.0 * c0 * blend_color;
            float4 screen_part = float4(1.0, 1.0, 1.0, 1.0) - 2.0 * (float4(1.0, 1.0, 1.0, 1.0) - c0) * (float4(1.0, 1.0, 1.0, 1.0) - blend_color);

            result.r = (c0.r < 0.5) ? multiply_part.r : screen_part.r;
            result.g = (c0.g < 0.5) ? multiply_part.g : screen_part.g;
            result.b = (c0.b < 0.5) ? multiply_part.b : screen_part.b;
            result.a = c0.a;
        }
    }
    else {
        // Original darkening vignette (matches original exactly)
        float4 vignetColor = c0 * factor;
        vignetColor *= verticalDim;  // Apply vertical dimension effect

        vignetColor *= opacity_param;
        float4 originalWithOpacity = c0 * (1.0 - opacity_param);

        result = originalWithOpacity + vignetColor;
    }

    return result;
}

technique Draw
{
    pass
    {
        vertex_shader = VSDefault(v_in);
        pixel_shader  = PSVignette(v_in);
    }
}
]]

-- Language support
local LANG_EN = 1
local LANG_DE = 2
local current_lang = LANG_DE

local translations = {
    [LANG_DE] = {
        filter_name = "Vignetter",
        inner_radius = "Innerer Radius",
        outer_radius = "Äußerer Radius",
        opacity = "Deckkraft",
        position = "Position",
        center_x = "Zentrum X",
        center_y = "Zentrum Y",
        form = "Form",
        shape_type = "Form-Typ",
        shape_oval = "Oval",
        shape_rectangle = "Rechteck",
        shape_diamond = "Diamant",
        shape_star = "Stern",
        shape_strength = "Form-Stärke",
        rotation = "Rotation",
        aspect_ratio = "Seitenverhältnis",
        vignette_color = "Vignettenfarbe",
        use_color = "Eigene Farbe verwenden",
        color_red = "Rot",
        color_green = "Grün",
        color_blue = "Blau",
        blend_mode = "Mischungsmodus",
        blend_normal = "Normal",
        blend_multiply = "Multiplizieren",
        blend_screen = "Screen",
        blend_overlay = "Overlay",
        presets = "Voreinstellungen",
        preset_cinematic = "Kinematischer Look",
        preset_sepia = "Sepia-Ton",
        preset_oval = "Ovale Vignette",
        preset_dramatic = "Dramatischer Kontrast",
        preset_vintage = "Vintage Look",
        preset_horror = "Horror/Mystery",
        preset_dream = "Traum-Sequenz",
        preset_focus = "Fokus-Vignette",
        preset_glowing = "Leuchtende Ränder",
        preset_cyberpunk = "Cyberpunk",
        preset_split = "Split-Toning",
        preset_retro = "Retro-Gaming",
        preset_oldfilm = "Alter Film",
        preset_sunset = "Sonnenuntergang",
        preset_duotone = "Duotone",
        preset_neon = "Neon-Lichter",
        info = "Innerer Radius wird immer angezeigt, äußerer Radius bestimmt den Übergang",
    },
    [LANG_EN] = {
        filter_name = "Vignetter",
        inner_radius = "Inner Radius",
        outer_radius = "Outer Radius",
        opacity = "Opacity",
        position = "Position",
        center_x = "Center X",
        center_y = "Center Y",
        form = "Shape",
        shape_type = "Shape Type",
        shape_oval = "Oval",
        shape_rectangle = "Rectangle",
        shape_diamond = "Diamond",
        shape_star = "Star",
        shape_strength = "Shape Strength",
        rotation = "Rotation",
        aspect_ratio = "Aspect Ratio",
        vignette_color = "Vignette Color",
        use_color = "Use Custom Color",
        color_red = "Red",
        color_green = "Green",
        color_blue = "Blue",
        blend_mode = "Blend Mode",
        blend_normal = "Normal",
        blend_multiply = "Multiply",
        blend_screen = "Screen",
        blend_overlay = "Overlay",
        presets = "Presets",
        preset_cinematic = "Cinematic Look",
        preset_sepia = "Sepia Tone",
        preset_oval = "Oval Vignette",
        preset_dramatic = "Dramatic Contrast",
        preset_vintage = "Vintage Look",
        preset_horror = "Horror/Mystery",
        preset_dream = "Dream Sequence",
        preset_focus = "Focus Vignette",
        preset_glowing = "Glowing Borders",
        preset_cyberpunk = "Cyberpunk",
        preset_split = "Split-Toning",
        preset_retro = "Retro Gaming",
        preset_oldfilm = "Old Film",
        preset_sunset = "Sunset",
        preset_duotone = "Duotone",
        preset_neon = "Neon Lights",
        info = "Inner radius always visible, outer radius determines transition",
    }
}

local function _(key)
    return (translations[current_lang] and translations[current_lang][key]) or
           (translations[LANG_EN] and translations[LANG_EN][key]) or key
end

local function detect_language()
    local locale = obs.obs_get_locale()
    if locale and locale:match("^en") then
        current_lang = LANG_EN
    else
        current_lang = LANG_DE
    end
end

function script_description()
    return "Professional vignette effect - Mac/Linux compatible (exact match to Windows version)"
end

function script_load(settings)
    detect_language()
    obs.blog(obs.LOG_INFO, "Vignetter: Loading exact-match Mac version")

    local source_info = {}
    source_info.id = "vignetter_filter_mac"
    source_info.type = obs.OBS_SOURCE_TYPE_FILTER
    source_info.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO, obs.OBS_SOURCE_CUSTOM_DRAW)

    source_info.get_name = function()
        return _("filter_name")
    end

    source_info.create = function(settings, source)
        local data = {}
        data.source = source
        data.effect = nil
        data.width = 0
        data.height = 0
        data.inner_radius = 0.9
        data.outer_radius = 1.5
        data.opacity = 0.8
        data.vignette_color_r = 0.0
        data.vignette_color_g = 0.0
        data.vignette_color_b = 0.0
        data.use_color = false
        data.center_x = 0.5
        data.center_y = 0.5
        data.aspect_ratio = 1.0
        data.blend_mode = 0
        data.shape_type = 0
        data.shape_strength = 1.0
        data.rotation = 0.0

        obs.obs_enter_graphics()
        data.effect = obs.gs_effect_create(effect_code, "vignetter_exact", nil)
        if data.effect == nil then
            obs.blog(obs.LOG_ERROR, "Vignetter: Shader compilation failed")
        else
            obs.blog(obs.LOG_INFO, "Vignetter: Shader compiled successfully")
        end
        obs.obs_leave_graphics()

        if data.effect ~= nil then
            data.params = {}
            data.params.inner_radius = obs.gs_effect_get_param_by_name(data.effect, "inner_radius")
            data.params.outer_radius = obs.gs_effect_get_param_by_name(data.effect, "outer_radius")
            data.params.opacity_param = obs.gs_effect_get_param_by_name(data.effect, "opacity_param")
            data.params.vignette_color = obs.gs_effect_get_param_by_name(data.effect, "vignette_color")
            data.params.use_color = obs.gs_effect_get_param_by_name(data.effect, "use_color")
            data.params.center_x = obs.gs_effect_get_param_by_name(data.effect, "center_x")
            data.params.center_y = obs.gs_effect_get_param_by_name(data.effect, "center_y")
            data.params.aspect_ratio = obs.gs_effect_get_param_by_name(data.effect, "aspect_ratio")
            data.params.blend_mode = obs.gs_effect_get_param_by_name(data.effect, "blend_mode")
            data.params.shape_type = obs.gs_effect_get_param_by_name(data.effect, "shape_type")
            data.params.shape_strength = obs.gs_effect_get_param_by_name(data.effect, "shape_strength")
            data.params.rotation_angle = obs.gs_effect_get_param_by_name(data.effect, "rotation_angle")
        end

        source_info.update(data, settings)
        return data
    end

    source_info.destroy = function(data)
        if data.effect ~= nil then
            obs.obs_enter_graphics()
            obs.gs_effect_destroy(data.effect)
            obs.obs_leave_graphics()
        end
    end

    source_info.get_width = function(data)
        return data.width
    end

    source_info.get_height = function(data)
        return data.height
    end

    source_info.get_defaults = function(settings)
        obs.obs_data_set_default_double(settings, "inner_radius", 0.9)
        obs.obs_data_set_default_double(settings, "outer_radius", 1.5)
        obs.obs_data_set_default_double(settings, "opacity", 0.8)
        obs.obs_data_set_default_double(settings, "vignette_color_r", 0.0)
        obs.obs_data_set_default_double(settings, "vignette_color_g", 0.0)
        obs.obs_data_set_default_double(settings, "vignette_color_b", 0.0)
        obs.obs_data_set_default_bool(settings, "use_color", false)
        obs.obs_data_set_default_double(settings, "center_x", 0.5)
        obs.obs_data_set_default_double(settings, "center_y", 0.5)
        obs.obs_data_set_default_double(settings, "aspect_ratio", 1.0)
        obs.obs_data_set_default_int(settings, "blend_mode", 0)
        obs.obs_data_set_default_int(settings, "shape_type", 0)
        obs.obs_data_set_default_double(settings, "shape_strength", 1.0)
        obs.obs_data_set_default_double(settings, "rotation", 0.0)
    end

    source_info.update = function(data, settings)
        data.inner_radius = obs.obs_data_get_double(settings, "inner_radius")
        data.outer_radius = obs.obs_data_get_double(settings, "outer_radius")
        data.opacity = obs.obs_data_get_double(settings, "opacity")
        data.vignette_color_r = obs.obs_data_get_double(settings, "vignette_color_r")
        data.vignette_color_g = obs.obs_data_get_double(settings, "vignette_color_g")
        data.vignette_color_b = obs.obs_data_get_double(settings, "vignette_color_b")
        data.use_color = obs.obs_data_get_bool(settings, "use_color")
        data.center_x = obs.obs_data_get_double(settings, "center_x")
        data.center_y = obs.obs_data_get_double(settings, "center_y")
        data.aspect_ratio = obs.obs_data_get_double(settings, "aspect_ratio")
        data.blend_mode = obs.obs_data_get_int(settings, "blend_mode")
        data.shape_type = obs.obs_data_get_int(settings, "shape_type")
        data.shape_strength = obs.obs_data_get_double(settings, "shape_strength")
        data.rotation = obs.obs_data_get_double(settings, "rotation") * 0.0174533

        local target = obs.obs_filter_get_target(data.source)
        if target ~= nil then
            data.width = obs.obs_source_get_base_width(target)
            data.height = obs.obs_source_get_base_height(target)
        end
    end

    local function apply_preset(data, preset)
        local s = obs.obs_data_create()

        if preset == "cinematic" then
            obs.obs_data_set_double(s, "inner_radius", 0.75)
            obs.obs_data_set_double(s, "outer_radius", 1.8)
            obs.obs_data_set_double(s, "opacity", 0.85)
            obs.obs_data_set_bool(s, "use_color", false)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "aspect_ratio", 1.3)
            obs.obs_data_set_double(s, "shape_strength", 1.0)
        elseif preset == "sepia" then
            obs.obs_data_set_double(s, "inner_radius", 0.8)
            obs.obs_data_set_double(s, "outer_radius", 2.0)
            obs.obs_data_set_double(s, "opacity", 0.7)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.5)
            obs.obs_data_set_double(s, "vignette_color_g", 0.35)
            obs.obs_data_set_double(s, "vignette_color_b", 0.2)
            obs.obs_data_set_int(s, "blend_mode", 1)
            obs.obs_data_set_int(s, "shape_type", 0)
        elseif preset == "oval" then
            obs.obs_data_set_double(s, "inner_radius", 0.85)
            obs.obs_data_set_double(s, "outer_radius", 1.6)
            obs.obs_data_set_double(s, "opacity", 0.75)
            obs.obs_data_set_double(s, "aspect_ratio", 1.6)
            obs.obs_data_set_int(s, "shape_type", 0)
        elseif preset == "dramatic" then
            obs.obs_data_set_double(s, "inner_radius", 0.65)
            obs.obs_data_set_double(s, "outer_radius", 1.3)
            obs.obs_data_set_double(s, "opacity", 0.95)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.0)
            obs.obs_data_set_double(s, "vignette_color_g", 0.0)
            obs.obs_data_set_double(s, "vignette_color_b", 0.02)
            obs.obs_data_set_int(s, "blend_mode", 1)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "shape_strength", 1.2)
        elseif preset == "vintage" then
            obs.obs_data_set_double(s, "inner_radius", 0.8)
            obs.obs_data_set_double(s, "outer_radius", 2.2)
            obs.obs_data_set_double(s, "opacity", 0.65)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.4)
            obs.obs_data_set_double(s, "vignette_color_g", 0.25)
            obs.obs_data_set_double(s, "vignette_color_b", 0.1)
            obs.obs_data_set_int(s, "blend_mode", 3)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "shape_strength", 0.9)
        elseif preset == "horror" then
            obs.obs_data_set_double(s, "inner_radius", 0.6)
            obs.obs_data_set_double(s, "outer_radius", 1.4)
            obs.obs_data_set_double(s, "opacity", 0.9)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.02)
            obs.obs_data_set_double(s, "vignette_color_g", 0.05)
            obs.obs_data_set_double(s, "vignette_color_b", 0.15)
            obs.obs_data_set_int(s, "blend_mode", 1)
            obs.obs_data_set_int(s, "shape_type", 1)
            obs.obs_data_set_double(s, "shape_strength", 1.3)
        elseif preset == "dream" then
            obs.obs_data_set_double(s, "inner_radius", 0.7)
            obs.obs_data_set_double(s, "outer_radius", 2.5)
            obs.obs_data_set_double(s, "opacity", 0.5)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.9)
            obs.obs_data_set_double(s, "vignette_color_g", 0.9)
            obs.obs_data_set_double(s, "vignette_color_b", 1.0)
            obs.obs_data_set_int(s, "blend_mode", 2)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "shape_strength", 0.8)
        elseif preset == "focus" then
            obs.obs_data_set_double(s, "inner_radius", 0.3)
            obs.obs_data_set_double(s, "outer_radius", 0.8)
            obs.obs_data_set_double(s, "opacity", 0.85)
            obs.obs_data_set_bool(s, "use_color", false)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "shape_strength", 1.5)
        elseif preset == "glowing" then
            obs.obs_data_set_double(s, "inner_radius", 0.6)
            obs.obs_data_set_double(s, "outer_radius", 1.5)
            obs.obs_data_set_double(s, "opacity", 0.7)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.9)
            obs.obs_data_set_double(s, "vignette_color_g", 0.7)
            obs.obs_data_set_double(s, "vignette_color_b", 0.3)
            obs.obs_data_set_int(s, "blend_mode", 2)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "shape_strength", 1.2)
        elseif preset == "cyberpunk" then
            obs.obs_data_set_double(s, "inner_radius", 0.5)
            obs.obs_data_set_double(s, "outer_radius", 1.8)
            obs.obs_data_set_double(s, "opacity", 0.8)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.0)
            obs.obs_data_set_double(s, "vignette_color_g", 0.5)
            obs.obs_data_set_double(s, "vignette_color_b", 0.9)
            obs.obs_data_set_int(s, "blend_mode", 3)
            obs.obs_data_set_int(s, "shape_type", 1)
            obs.obs_data_set_double(s, "shape_strength", 1.5)
            obs.obs_data_set_double(s, "rotation", 30.0)
        elseif preset == "split" then
            obs.obs_data_set_double(s, "inner_radius", 0.1)
            obs.obs_data_set_double(s, "outer_radius", 1.2)
            obs.obs_data_set_double(s, "opacity", 0.6)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.8)
            obs.obs_data_set_double(s, "vignette_color_g", 0.3)
            obs.obs_data_set_double(s, "vignette_color_b", 0.1)
            obs.obs_data_set_int(s, "blend_mode", 2)
            obs.obs_data_set_int(s, "shape_type", 2)
            obs.obs_data_set_double(s, "shape_strength", 1.7)
            obs.obs_data_set_double(s, "rotation", 45.0)
        elseif preset == "retro" then
            obs.obs_data_set_double(s, "inner_radius", 0.6)
            obs.obs_data_set_double(s, "outer_radius", 1.0)
            obs.obs_data_set_double(s, "opacity", 0.75)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.4)
            obs.obs_data_set_double(s, "vignette_color_g", 0.0)
            obs.obs_data_set_double(s, "vignette_color_b", 0.4)
            obs.obs_data_set_int(s, "blend_mode", 1)
            obs.obs_data_set_int(s, "shape_type", 3)
            obs.obs_data_set_double(s, "shape_strength", 1.8)
            obs.obs_data_set_double(s, "rotation", 15.0)
        elseif preset == "oldfilm" then
            obs.obs_data_set_double(s, "inner_radius", 0.4)
            obs.obs_data_set_double(s, "outer_radius", 1.5)
            obs.obs_data_set_double(s, "opacity", 0.9)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.1)
            obs.obs_data_set_double(s, "vignette_color_g", 0.08)
            obs.obs_data_set_double(s, "vignette_color_b", 0.05)
            obs.obs_data_set_int(s, "blend_mode", 1)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "aspect_ratio", 0.9)
        elseif preset == "sunset" then
            obs.obs_data_set_double(s, "inner_radius", 0.8)
            obs.obs_data_set_double(s, "outer_radius", 2.0)
            obs.obs_data_set_double(s, "opacity", 0.65)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.95)
            obs.obs_data_set_double(s, "vignette_color_g", 0.5)
            obs.obs_data_set_double(s, "vignette_color_b", 0.2)
            obs.obs_data_set_int(s, "blend_mode", 2)
            obs.obs_data_set_int(s, "shape_type", 0)
            obs.obs_data_set_double(s, "aspect_ratio", 1.6)
        elseif preset == "duotone" then
            obs.obs_data_set_double(s, "inner_radius", 0.2)
            obs.obs_data_set_double(s, "outer_radius", 1.0)
            obs.obs_data_set_double(s, "opacity", 0.8)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.1)
            obs.obs_data_set_double(s, "vignette_color_g", 0.5)
            obs.obs_data_set_double(s, "vignette_color_b", 0.7)
            obs.obs_data_set_int(s, "blend_mode", 3)
            obs.obs_data_set_int(s, "shape_type", 2)
            obs.obs_data_set_double(s, "shape_strength", 1.4)
        elseif preset == "neon" then
            obs.obs_data_set_double(s, "inner_radius", 0.5)
            obs.obs_data_set_double(s, "outer_radius", 1.2)
            obs.obs_data_set_double(s, "opacity", 0.7)
            obs.obs_data_set_bool(s, "use_color", true)
            obs.obs_data_set_double(s, "vignette_color_r", 0.9)
            obs.obs_data_set_double(s, "vignette_color_g", 0.1)
            obs.obs_data_set_double(s, "vignette_color_b", 0.9)
            obs.obs_data_set_int(s, "blend_mode", 2)
            obs.obs_data_set_int(s, "shape_type", 1)
            obs.obs_data_set_double(s, "shape_strength", 1.6)
            obs.obs_data_set_double(s, "rotation", 45.0)
        end

        source_info.update(data, s)
        obs.obs_source_update(data.source, s)
        obs.obs_data_release(s)
        return true
    end

    source_info.get_properties = function(data)
        local props = obs.obs_properties_create()

        local preset_list = obs.obs_properties_add_list(props, "preset", _("presets"),
            obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
        obs.obs_property_list_add_string(preset_list, _("preset_cinematic"), "cinematic")
        obs.obs_property_list_add_string(preset_list, _("preset_sepia"), "sepia")
        obs.obs_property_list_add_string(preset_list, _("preset_oval"), "oval")
        obs.obs_property_list_add_string(preset_list, _("preset_dramatic"), "dramatic")
        obs.obs_property_list_add_string(preset_list, _("preset_vintage"), "vintage")
        obs.obs_property_list_add_string(preset_list, _("preset_horror"), "horror")
        obs.obs_property_list_add_string(preset_list, _("preset_dream"), "dream")
        obs.obs_property_list_add_string(preset_list, _("preset_focus"), "focus")
        obs.obs_property_list_add_string(preset_list, _("preset_glowing"), "glowing")
        obs.obs_property_list_add_string(preset_list, _("preset_cyberpunk"), "cyberpunk")
        obs.obs_property_list_add_string(preset_list, _("preset_split"), "split")
        obs.obs_property_list_add_string(preset_list, _("preset_retro"), "retro")
        obs.obs_property_list_add_string(preset_list, _("preset_oldfilm"), "oldfilm")
        obs.obs_property_list_add_string(preset_list, _("preset_sunset"), "sunset")
        obs.obs_property_list_add_string(preset_list, _("preset_duotone"), "duotone")
        obs.obs_property_list_add_string(preset_list, _("preset_neon"), "neon")

        obs.obs_property_set_modified_callback(preset_list, function(props, prop, settings)
            local preset = obs.obs_data_get_string(settings, "preset")
            apply_preset(data, preset)
            return true
        end)

        obs.obs_properties_add_float_slider(props, "inner_radius", _("inner_radius"), 0.0, 5.0, 0.001)
        obs.obs_properties_add_float_slider(props, "outer_radius", _("outer_radius"), 0.0, 5.0, 0.001)
        obs.obs_properties_add_float_slider(props, "opacity", _("opacity"), 0.0, 1.0, 0.001)

        local pos_group = obs.obs_properties_create()
        obs.obs_properties_add_float_slider(pos_group, "center_x", _("center_x"), 0.0, 1.0, 0.01)
        obs.obs_properties_add_float_slider(pos_group, "center_y", _("center_y"), 0.0, 1.0, 0.01)
        obs.obs_properties_add_group(props, "position", _("position"), obs.OBS_GROUP_NORMAL, pos_group)

        local shape_group = obs.obs_properties_create()
        local shape_list = obs.obs_properties_add_list(shape_group, "shape_type", _("shape_type"),
            obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
        obs.obs_property_list_add_int(shape_list, _("shape_oval"), 0)
        obs.obs_property_list_add_int(shape_list, _("shape_rectangle"), 1)
        obs.obs_property_list_add_int(shape_list, _("shape_diamond"), 2)
        obs.obs_property_list_add_int(shape_list, _("shape_star"), 3)
        obs.obs_properties_add_float_slider(shape_group, "shape_strength", _("shape_strength"), 0.5, 2.0, 0.01)
        obs.obs_properties_add_float_slider(shape_group, "rotation", _("rotation"), 0.0, 360.0, 1.0)
        obs.obs_properties_add_float_slider(shape_group, "aspect_ratio", _("aspect_ratio"), 0.5, 2.0, 0.01)
        obs.obs_properties_add_group(props, "shape", _("form"), obs.OBS_GROUP_NORMAL, shape_group)

        local color_group = obs.obs_properties_create()
        obs.obs_properties_add_bool(color_group, "use_color", _("use_color"))
        obs.obs_properties_add_float_slider(color_group, "vignette_color_r", _("color_red"), 0.0, 1.0, 0.01)
        obs.obs_properties_add_float_slider(color_group, "vignette_color_g", _("color_green"), 0.0, 1.0, 0.01)
        obs.obs_properties_add_float_slider(color_group, "vignette_color_b", _("color_blue"), 0.0, 1.0, 0.01)

        local blend_list = obs.obs_properties_add_list(color_group, "blend_mode", _("blend_mode"),
            obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
        obs.obs_property_list_add_int(blend_list, _("blend_normal"), 0)
        obs.obs_property_list_add_int(blend_list, _("blend_multiply"), 1)
        obs.obs_property_list_add_int(blend_list, _("blend_screen"), 2)
        obs.obs_property_list_add_int(blend_list, _("blend_overlay"), 3)

        obs.obs_properties_add_group(props, "color", _("vignette_color"), obs.OBS_GROUP_NORMAL, color_group)

        obs.obs_properties_add_text(props, "info", _("info"), obs.OBS_TEXT_INFO)

        return props
    end

    source_info.video_render = function(data, effect)
        if not data.effect then return end

        local target = obs.obs_filter_get_target(data.source)
        if not target then return end

        local w = obs.obs_source_get_base_width(target)
        local h = obs.obs_source_get_base_height(target)
        if w == 0 or h == 0 then return end

        obs.obs_source_process_filter_begin(data.source, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

        if data.params.inner_radius then
            obs.gs_effect_set_float(data.params.inner_radius, data.inner_radius)
        end
        if data.params.outer_radius then
            obs.gs_effect_set_float(data.params.outer_radius, data.outer_radius)
        end
        if data.params.opacity_param then
            obs.gs_effect_set_float(data.params.opacity_param, data.opacity)
        end
        if data.params.vignette_color then
            local vec = obs.vec3()
            vec.x = data.vignette_color_r
            vec.y = data.vignette_color_g
            vec.z = data.vignette_color_b
            obs.gs_effect_set_vec3(data.params.vignette_color, vec)
        end
        if data.params.use_color then
            obs.gs_effect_set_bool(data.params.use_color, data.use_color)
        end
        if data.params.center_x then
            obs.gs_effect_set_float(data.params.center_x, data.center_x)
        end
        if data.params.center_y then
            obs.gs_effect_set_float(data.params.center_y, data.center_y)
        end
        if data.params.aspect_ratio then
            obs.gs_effect_set_float(data.params.aspect_ratio, data.aspect_ratio)
        end
        if data.params.blend_mode then
            obs.gs_effect_set_int(data.params.blend_mode, data.blend_mode)
        end
        if data.params.shape_type then
            obs.gs_effect_set_int(data.params.shape_type, data.shape_type)
        end
        if data.params.shape_strength then
            obs.gs_effect_set_float(data.params.shape_strength, data.shape_strength)
        end
        if data.params.rotation_angle then
            obs.gs_effect_set_float(data.params.rotation_angle, data.rotation)
        end

        obs.obs_source_process_filter_end(data.source, data.effect, w, h)
    end

    source_info.video_tick = function(data, seconds)
        local target = obs.obs_filter_get_target(data.source)
        if target ~= nil then
            data.width = obs.obs_source_get_base_width(target)
            data.height = obs.obs_source_get_base_height(target)
        end
    end

    obs.obs_register_source(source_info)
    obs.blog(obs.LOG_INFO, "Vignetter: Registration complete")
end

function script_unload()
end

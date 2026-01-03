# Vignetter for OBS Studio - Cross-Platform Port

Professional vignette effect filter for OBS Studio with **full Mac and Linux support**.

This is a cross-platform port of [TheGeekFreaks' Vignetter](https://github.com/The-Geek-Freaks/Vignetter) (a German project with English support), adapted to work on macOS, Linux, and Windows.

## Features

- ✅ **Multiple Shapes**: Oval, Rectangle, Diamond, Star
- ✅ **Custom Colors**: Full RGB control with 4 blend modes (Normal, Multiply, Screen, Overlay)
- ✅ **16 Professional Presets**: Cinematic, Sepia, Dramatic, Vintage, Horror, Dream, Focus, and more
- ✅ **Advanced Controls**: Rotation, aspect ratio, shape strength, position control
- ✅ **Cross-Platform**: Works on Windows, macOS, and Linux
- ✅ **Bilingual UI**: German and English support

## Installation

### macOS / Linux

1. Download `vignetter_universal.lua`
2. In OBS Studio, go to **Tools → Scripts**
3. Click the **+** button and select `vignetter_universal.lua`
4. The filter will be available in **Filters → Effect Filters** as "Vignetter"

### Windows

The Mac version (`vignetter_universal.lua`) works on Windows too! Alternatively, you can use the original `vignetter.lua`.

## Quick Start

1. Right-click any video source → **Filters**
2. Under "Effect Filters", click **+** → **Vignetter**
3. Try a preset from the dropdown, or adjust manually:
   - **Inner Radius**: Size of the clear center
   - **Outer Radius**: How far the effect extends
   - **Opacity**: Intensity of the effect
   - **Shape Type**: Choose from Oval, Rectangle, Diamond, or Star

## File Structure

```
vignetter/
├── README.md                    # This file
├── MAC_PORTING_GUIDE.md        # Technical guide for maintaining this port
├── vignetter.lua               # Original Windows version
└── vignetter_universal.lua     # Cross-platform compatible version ⭐
```

**Which file should you use?**
- **Mac/Linux users**: Use `vignetter_universal.lua`
- **Windows users**: Either file works, but `vignetter_universal.lua` is recommended
- **Developers maintaining this port**: See `MAC_PORTING_GUIDE.md`

## What's Different from the Original?

The original version uses Windows-specific HLSL shader features that fail silently on Mac/Linux. This port makes minimal changes to ensure cross-platform compatibility:

1. **Removed default values from shader uniforms** (Mac's Metal compiler rejects them)
2. **Renamed conflicting shader parameters** (`opacity` → `opacity_param`, `rotation` → `rotation_angle`)
3. **Simplified some shader syntax** for better cross-platform compatibility

**The visual output is identical** - all 16 presets and features work exactly the same!

For detailed technical information, see [MAC_PORTING_GUIDE.md](MAC_PORTING_GUIDE.md).

## Available Presets

| Preset | Description |
|--------|-------------|
| Cinematic | Classic dark vignette for film-like look |
| Sepia | Warm vintage tone with brownish vignette |
| Oval | Wide oval vignette for dramatic framing |
| Dramatic | Strong contrast with tight vignette |
| Vintage | Subtle retro look with soft sepia |
| Horror/Mystery | Dark blue-tinted edges for suspense |
| Dream Sequence | Bright, soft white edges for ethereal feel |
| Focus | Very tight vignette to highlight center |
| Glowing Borders | Warm glowing edges (inverted vignette) |
| Cyberpunk | Blue-tinted futuristic look with rotation |
| Split-Toning | Creative color gradient with diamond shape |
| Retro Gaming | Purple star-shaped vignette |
| Old Film | Strong vintage film look with heavy darkening |
| Sunset | Warm orange tones for golden hour feel |
| Duotone | Teal-tinted creative effect |
| Neon Lights | Magenta glowing edges for club aesthetic |

## Troubleshooting

### Black screen when filter is enabled

**On Mac/Linux**: Make sure you're using `vignetter_universal.lua`, not the original `vignetter.lua`.

**On Windows**: This shouldn't happen. Check the Script Log (Tools → Scripts) for errors.

### No output in Script Log

This means the script failed to load. Common causes:
- Using `vignetter.lua` on Mac/Linux (use `vignetter_universal.lua` instead)
- OBS version is too old (requires OBS 27.0+)
- File is corrupted (re-download)

### Filter works but effect looks wrong

Check that you're adjusting the right parameters:
- **Inner Radius** should be less than **Outer Radius**
- **Opacity** at 0.0 means no effect
- If using color mode, make sure **"Use Custom Color"** is checked

## Requirements

- OBS Studio 27.0 or later
- macOS, Linux, or Windows

## Development

### Maintaining This Port

When upstream updates are released, see [MAC_PORTING_GUIDE.md](MAC_PORTING_GUIDE.md) for instructions on porting changes while maintaining Mac/Linux compatibility.

### Key Compatibility Rules

1. **Never** add default values to shader uniforms (`uniform float x = 1.0;` ❌)
2. **Avoid** parameter names like `opacity` and `rotation` (use `opacity_param`, `rotation_angle`)
3. **Test** on Mac after any shader changes (silent failures are common)

## Credits

- **Original Author**: [TheGeekFreaks](https://github.com/The-Geek-Freaks) - Created the original Windows version (German project with English support)
- **Original Project**: [Vignetter](https://github.com/The-Geek-Freaks/Vignetter) - "Ein professioneller OBS-Lua-Script für Vignette-Effekte"
- **Mac/Linux Port**: Adapted for cross-platform compatibility (2026)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

This is a derivative work of [TheGeekFreaks' Vignetter](https://github.com/The-Geek-Freaks/Vignetter), which is also licensed under GPL v3.0.

## Contributing

Found a bug or want to add a feature? Contributions welcome!

1. Test your changes on both Mac and Windows if possible
2. Follow the compatibility rules in `MAC_PORTING_GUIDE.md`
3. Submit a pull request

## Known Issues

None currently! 🎉

If you find an issue, please report it with:
- Your OS and OBS version
- Which `.lua` file you're using
- Steps to reproduce
- Any errors from the Script Log

---

**Enjoy creating beautiful vignette effects on any platform!** 🎬

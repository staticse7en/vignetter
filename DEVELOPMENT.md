# Development Guide for Vignetter Cross-Platform Port

Quick guide to set up this project for maintaining and syncing with upstream.

## Initial Repository Setup

### 1. Create Git Repository

```bash
cd /Users/staticseven/Downloads/vignetter
git init
git add README.md MAC_PORTING_GUIDE.md QUICK_REFERENCE.md CHANGELOG.md
git add vignetter.lua vignetter_universal.lua
git add .gitignore
git commit -m "Initial commit: Mac/Linux compatible port

- Added vignetter_universal.lua (cross-platform version)
- Documented all compatibility changes
- Created maintenance guides"
```

### 2. Add Upstream Remote (Optional)

If the original has a git repository:

```bash
# Add original repo as upstream
git remote add upstream https://github.com/TheGeekFreaks/vignetter.git

# Fetch upstream changes
git fetch upstream

# Keep your main branch
git branch -M main
```

### 3. Create GitHub Repository

```bash
# Create repo on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/vignetter-mac.git
git push -u origin main
```

---

## Syncing with Upstream

### Method 1: Manual Diff (Recommended)

```bash
# Download latest upstream vignetter.lua
# Compare with your current copy
diff -u vignetter_old.lua vignetter_new.lua > changes.patch

# Review changes.patch
# Apply compatible changes to vignetter_universal.lua manually
# Following rules in MAC_PORTING_GUIDE.md

# Commit
git add vignetter.lua vignetter_universal.lua CHANGELOG.md
git commit -m "Sync with upstream vX.X.X

Changes:
- Added new preset: [name]
- Fixed bug in [feature]
- Updated [component]

Porting notes:
- Renamed new parameter 'glow' to 'glow_amount'
- Removed default values from new uniforms"
```

### Method 2: Git Merge (If Upstream is Git)

```bash
# Fetch latest upstream
git fetch upstream

# Review what changed
git log upstream/main

# Merge (will likely have conflicts)
git merge upstream/main

# Resolve conflicts following MAC_PORTING_GUIDE.md
# Test on Mac
git add .
git commit -m "Merge upstream vX.X.X"
```

---

## Branching Strategy

### Recommended Structure

```
main              - Stable Mac-compatible version
upstream-sync     - Branch for integrating upstream changes
feature/*         - New Mac-specific features
bugfix/*          - Mac-specific bug fixes
```

### Example Workflow

```bash
# Syncing upstream changes
git checkout -b upstream-sync
# ... download and integrate upstream changes ...
# ... test on Mac ...
git checkout main
git merge upstream-sync
git push

# Mac-specific bug fix
git checkout -b bugfix/shader-compilation-issue
# ... fix issue ...
git checkout main
git merge bugfix/shader-compilation-issue
git push
```

---

## Release Process

### Version Numbering

Format: `[upstream-version]-mac[port-version]`

Examples:
- `1.0.0-mac1` - First Mac port of upstream v1.0.0
- `1.0.0-mac2` - Mac-specific fixes on top of upstream v1.0.0
- `1.1.0-mac1` - Mac port of upstream v1.1.0
- `2.0.0-mac1` - Mac port of upstream v2.0.0

### Creating a Release

```bash
# After syncing and testing
git tag -a v1.0.0-mac1 -m "Release 1.0.0-mac1

Cross-platform compatible version based on upstream v1.0.0

Changes from upstream:
- Removed uniform default values for Metal compatibility
- Renamed 'opacity' and 'rotation' shader parameters
- All 16 presets working on Mac/Linux/Windows

Tested on:
- macOS 15.2 with OBS 30.x
- Windows 11 with OBS 30.x"

git push origin v1.0.0-mac1

# Create GitHub Release with vignetter_universal.lua attached
```

---

## Testing Before Release

### Pre-Release Checklist

- [ ] Script loads in OBS without errors
- [ ] Script Log shows successful loading message
- [ ] Filter can be added to a source
- [ ] Filter shows video (not black screen)
- [ ] Test all 16 presets - each should work
- [ ] Test all manual controls:
  - [ ] Inner/Outer Radius sliders
  - [ ] Opacity slider
  - [ ] Center X/Y position
  - [ ] All 4 shapes (Oval, Rectangle, Diamond, Star)
  - [ ] Shape Strength slider
  - [ ] Rotation slider (0-360°)
  - [ ] Aspect Ratio slider
  - [ ] Color mode toggle
  - [ ] RGB color sliders
  - [ ] All 4 blend modes
- [ ] Test on macOS
- [ ] Test on Windows (if possible)
- [ ] Documentation is up to date
- [ ] CHANGELOG.md reflects all changes

---

## File Structure for Repository

```
vignetter-mac/
├── .git/
├── .gitignore
├── README.md                    # User documentation
├── CHANGELOG.md                 # Version history
├── MAC_PORTING_GUIDE.md        # Technical porting guide
├── QUICK_REFERENCE.md          # One-page cheat sheet
├── DEVELOPMENT.md              # This file
├── vignetter.lua               # Original (for reference/syncing)
└── vignetter_universal.lua     # Mac-compatible version (main file)
```

---

## Contributing Guidelines

### For Contributors

If others want to contribute:

1. **Bug Reports**: Include OS, OBS version, steps to reproduce
2. **Feature Requests**: Ensure compatible with Mac/Linux/Windows
3. **Pull Requests**: 
   - Follow compatibility rules in MAC_PORTING_GUIDE.md
   - Test on Mac if adding shader changes
   - Update CHANGELOG.md
   - Update documentation if needed

### Code Review Checklist

Before merging PRs:

- [ ] No `= value` in shader uniforms
- [ ] No `opacity` or `rotation` shader parameter names
- [ ] Tested on macOS
- [ ] CHANGELOG.md updated
- [ ] Documentation updated if needed
- [ ] Follows existing code style

---

## Maintenance Schedule

### Regular Tasks

**Monthly (or when upstream updates):**
- Check upstream for new releases
- Review upstream changes
- Port compatible changes
- Test on Mac
- Update documentation
- Create release if significant changes

**As Needed:**
- Fix reported bugs
- Add new features (if requested)
- Improve documentation
- Update for new OBS versions

---

## Communication

### Channels

- **Issues**: Bug reports, feature requests
- **Discussions**: Questions, ideas, general chat
- **Pull Requests**: Code contributions

### Issue Labels

Suggested labels:
- `bug` - Something isn't working
- `enhancement` - New feature request
- `mac-specific` - Mac/Linux only issue
- `upstream-sync` - Related to syncing with original
- `documentation` - Docs need improvement
- `help-wanted` - Community input needed

---

## License Considerations

**Important:** Before publishing:

1. Verify the original license allows derivative works
2. Maintain original author attribution
3. Add maintainer info for this port
4. Keep license file if present
5. Credit original author in all documentation

---

## Useful Commands

```bash
# See what changed in upstream
diff -u vignetter_old.lua vignetter_new.lua

# See your local changes
git diff vignetter_universal.lua

# View commit history
git log --oneline

# Find when a line was changed
git blame vignetter_universal.lua

# Search for TODO/FIXME comments
grep -n "TODO\|FIXME" *.lua *.md

# Count lines of code
wc -l vignetter_universal.lua

# Validate Lua syntax
luac -p vignetter_universal.lua
```

---

## Emergency Rollback

If a release has critical issues:

```bash
# Revert to previous version
git revert HEAD

# Or reset to specific version
git reset --hard v1.0.0-mac1

# Force push (only if absolutely necessary!)
git push --force origin main

# Create hotfix release
git tag -a v1.0.0-mac2 -m "Hotfix: Critical bug fix"
git push origin v1.0.0-mac2
```

---

## Questions?

See the detailed guides:
- **Users**: Read README.md
- **Developers**: Read MAC_PORTING_GUIDE.md
- **Quick Lookup**: Read QUICK_REFERENCE.md
- **Changes**: Read CHANGELOG.md

**Happy forking!** 🍴

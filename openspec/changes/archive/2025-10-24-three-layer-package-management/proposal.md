# Change: Three-Layer Package Management System

## Why
The previous package management approach used only Homebrew for all package types, which had limitations:
- **Ecosystem mismatch**: Python CLI tools installed via Homebrew instead of Python package managers
- **Version isolation**: No isolated environments for Python-based tools
- **Slow Python tools**: Homebrew's Python dependencies created bloat and slow startup times
- **JVM tool gaps**: No comprehensive JVM ecosystem management (addressed separately by SDKMAN)

A multi-layer approach allows each ecosystem to use its optimized package manager:
- Homebrew for system packages and GUI applications
- UV for fast, isolated Python CLI tools
- SDKMAN for comprehensive JVM ecosystem management

## What Changes
- Extend package management from single-layer (Homebrew) to three-layer system
- Add UV tools layer with `tools.yaml` data file
- Add SDKMAN SDKs layer with `sdks.yaml` data file (separate proposal)
- Create UV tool installation script at position 25
- Update `package-management` spec to document three-layer architecture
- Migrate some Python tools from Homebrew to UV

### Breaking Changes
**MINIMAL BREAKING**: Existing Homebrew installations continue to work. UV and SDKMAN are additive layers. Users must have UV installed (via Homebrew or standalone installer) before UV tools can be installed.

## Impact
- Affected specs: `package-management` (major expansion)
- Affected code:
  - `home/.chezmoiscripts/run_once_before_darwin-30-install-uv.sh.tmpl` (create)
  - `home/.chezmoiscripts/run_onchange_before_darwin-25-install-tools.sh.tmpl` (create)
  - `home/.chezmoidata/tools.yaml` (create)
  - `openspec/specs/package-management/spec.md` (major update)

## Design Decisions

### Three-Layer Architecture Rationale
Each layer serves a specific ecosystem with optimized tooling:

**Layer 1: Homebrew (System)**
- Purpose: System packages, GUI applications, fonts, CLI utilities
- Strengths: Native macOS integration, wide package availability, cask support
- Use cases: Docker, Visual Studio Code, iTerm2, system libraries
- Data file: `packages.yaml` (tag-based categories)

**Layer 2: UV Tools (Python Ecosystem)**
- Purpose: Python-based CLI tools and utilities
- Strengths: Fast installation, isolated tool environments, modern Python package manager
- Use cases: claude-monitor, zsh-llm-suggestions, Python dev tools
- Data file: `tools.yaml` (tag-based categories)

**Layer 3: SDKMAN (JVM Ecosystem)**
- Purpose: Java SDKs, build tools, JVM-related packages
- Strengths: Version management, multiple Java installations, JVM ecosystem focus
- Use cases: Multiple Java versions, Gradle, Maven, Liquibase
- Data file: `sdks.yaml` (platform-specific, dev-tag-required)

### Benefits of Separation
- **Optimized tools**: Each package manager specializes in its ecosystem
- **Version isolation**: Python tools don't conflict, multiple Java versions coexist
- **Reduced conflicts**: System packages don't interfere with language-specific tools
- **Clear responsibility**: Each layer has well-defined purpose
- **Performance**: UV is significantly faster than Homebrew for Python tools

### Tag-Based Consistency
All three layers use tag-based selection:
- `core` tag: Essential packages/tools always installed
- `dev` tag: Development tools (required for SDKMAN)
- `ai`, `work`, `personal`, `datascience`, `mobile`: Optional categories

### UV Tool Installation Timing
Position 25 for UV tool installation (before UV manager installation at position 30) assumes UV is available through another mechanism (Homebrew in `packages.yaml`). This allows:
- UV tools installed immediately after package management setup
- Proper dependency ordering (Homebrew → UV tools → UV manager)

### Static Data Files Pattern
Consistent pattern across all three layers:
- `packages.yaml` (Homebrew) - static YAML
- `tools.yaml` (UV) - static YAML
- `sdks.yaml` (SDKMAN) - static YAML
- All must exist before template engine runs
- Simple structure for easy maintenance

## Migration Path

### For Existing Machines
1. UV installation: Install UV if not present (position 30 script)
2. Tool migration: Python tools gradually migrate from Homebrew to UV as needed
3. Backward compatibility: Existing Homebrew-installed Python tools continue working
4. No immediate action required: Three-layer system is additive

### Migrating Tools from Homebrew to UV
For tools that exist in both ecosystems:
1. Install via UV: `uv tool install <package>`
2. Remove from Homebrew: `brew uninstall <package>` (optional)
3. Update `packages.yaml`: Remove from Homebrew list (if desired)
4. Add to `tools.yaml`: Include in appropriate tag category

### Rollback
Not applicable - this is an additive change. To remove:
1. Stop using UV tools: Remove `tools.yaml` entries
2. Reinstall via Homebrew: Add back to `packages.yaml`
3. Uninstall UV: Remove UV installation script

## Files Created
- `openspec/changes/archive/2025-10-24-three-layer-package-management/` (this proposal)
- `home/.chezmoiscripts/run_once_before_darwin-30-install-uv.sh.tmpl`
- `home/.chezmoiscripts/run_onchange_before_darwin-25-install-tools.sh.tmpl`
- `home/.chezmoidata/tools.yaml`

## Files Modified
- `openspec/specs/package-management/spec.md` (major expansion with UV and SDKMAN sections)

## Related Changes
- See `2025-10-10-sdkman-integration` for SDKMAN (Layer 3) details
- Both proposals coordinate to create the complete three-layer system

## Deployment Status
✅ **Deployed** - Three-layer package management is live with Homebrew, UV tools, and SDKMAN active.

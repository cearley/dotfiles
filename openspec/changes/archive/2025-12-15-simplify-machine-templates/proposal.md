# Simplify Machine Configuration Templates

## Overview
Consolidate machine configuration template architecture from a four-template system to a two-template system by replacing convenience wrappers with a single dict-returning template.

## Problem
The current machine configuration system uses four templates:
1. `machine-config` - Core lookup engine
2. `machine-brewfile-path` - Constructs brewfile paths
3. `machine-keepassxc-entry` - Retrieves KeePassXC entry names
4. `machine-key-name` - Returns matched machine pattern key

This creates unnecessary indirection when:
- Multiple machine settings are needed in the same file (requires multiple template includes)
- Each wrapper adds maintenance overhead without significant value
- The core `machine-config` template already supports all necessary lookups

## Solution
Replace the three convenience wrappers with a single `machine-settings` template that returns all machine settings as a structured dict, enabling:
- Single lookup per file instead of multiple includes
- Natural property access syntax
- Easier addition of new machine properties
- Reduced template file count

## Impact

### Changed Files
- **Removed templates** (3):
  - `home/.chezmoitemplates/machine-brewfile-path`
  - `home/.chezmoitemplates/machine-keepassxc-entry`
  - `home/.chezmoitemplates/machine-key-name`

- **Added templates** (1):
  - `home/.chezmoitemplates/machine-settings`

- **Updated templates** (5):
  - `home/symlink_Brewfile.tmpl`
  - `home/.chezmoiscripts/run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl`
  - `home/private_dot_ssh/private_id_ed25519.tmpl`
  - `home/private_dot_ssh/known_hosts.tmpl`
  - `home/private_dot_ssh/id_ed25519.pub.tmpl`

### Behavioral Changes
- None - This is a refactoring that maintains identical functionality
- All existing machine configurations continue to work unchanged

### Performance
- **Improvement**: Single pattern match per file instead of multiple includes
- **Trade-off**: Returns all settings even if only one is needed (negligible overhead)

## Migration Path
This is a backward-compatible refactoring:
1. Add new `machine-settings` template
2. Update all call sites to use new template
3. Remove old wrapper templates
4. No changes required to `machines.yaml` or user configurations

## Alternatives Considered

### Alternative 1: Direct machine-config Usage
Use `machine-config` directly everywhere without any wrappers.

**Rejected because:**
- Path construction logic would be duplicated across files
- No performance benefit over proposed solution
- More verbose at call sites

### Alternative 2: Move to .chezmoi.yaml.tmpl
Place machine detection in `.chezmoi.yaml.tmpl` for native data access.

**Rejected because:**
- Machine matching logic less flexible in YAML
- Harder to debug and test
- No significant benefit over template approach

### Alternative 3: Keep Current Architecture
Maintain existing four-template system.

**Rejected because:**
- Multiple includes for multiple settings is inefficient
- Unnecessary abstraction layers
- Harder to understand full machine configuration

## Success Criteria
- [x] All existing template call sites updated successfully
- [x] Template execution produces identical output to previous implementation
- [x] `chezmoi apply --dry-run` shows no unexpected changes
- [x] Machine-specific files (Brewfile, SSH keys) still resolve correctly
- [x] New template is documented with clear usage examples
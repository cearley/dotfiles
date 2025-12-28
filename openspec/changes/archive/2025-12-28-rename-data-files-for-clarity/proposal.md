# Change: Rename Data Files for Clarity

## Why
The data file names `tools.yaml` and `sdks.yaml` did not clearly indicate which package manager they belonged to, causing potential confusion:
- **Ambiguous naming**: `tools.yaml` could be any kind of tools; doesn't indicate UV/Python
- **Unclear association**: `sdks.yaml` doesn't indicate SDKMAN or JVM ecosystem
- **Inconsistent pattern**: `packages.yaml` is clearly Homebrew, but other files lacked similar clarity

Renaming to include the package manager prefix creates a self-documenting naming convention:
- `uv-tools.yaml` - Immediately clear this is UV-managed Python CLI tools
- `sdkman-sdks.yaml` - Immediately clear this is SDKMAN-managed JVM SDKs
- Consistent with `packages.yaml` pattern (implicitly Homebrew)

## What Changes
- Rename `home/.chezmoidata/tools.yaml` → `home/.chezmoidata/uv-tools.yaml`
- Rename `home/.chezmoidata/sdks.yaml` → `home/.chezmoidata/sdkman-sdks.yaml`
- Update all documentation references to use new filenames
- Add migration notes to related archived proposals

### Breaking Changes
**NO BREAKING CHANGES**: Critical discovery during implementation revealed that chezmoi strips prefixes before hyphens in data filenames when creating template variables.

**Filename → Template Variable Mapping**:
- `uv-tools.yaml` → `.tools` (NOT `.uv-tools` or `."uv-tools"`)
- `sdkman-sdks.yaml` → `.sdks` (NOT `.sdkman-sdks` or `."sdkman-sdks"`)
- `packages.yaml` → `.packages`
- `config.yaml` → `.config`

**Result**: No template syntax changes required. All existing template access patterns (`.tools`, `.sdks`) continue to work unchanged.

## Impact
- Affected files:
  - 2 data files renamed (git mv)
  - 9+ documentation files updated with new filenames
  - 2 archived proposals updated with migration notes
- **NO installation script changes** - templates unchanged due to chezmoi's filename handling
- **Automatic migration** - existing machines pick up renamed files seamlessly

## Design Decisions

### Hyphenated Naming Convention
Using hyphens (`uv-tools`, `sdkman-sdks`) instead of other delimiters:
- **Consistent with Unix conventions**: Hyphens are standard in configuration filenames
- **Readable**: Clear separation between package manager and resource type
- **Pattern established**: Follows naming conventions used elsewhere in the codebase

### Chezmoi Filename Handling Discovery
During implementation, discovered that chezmoi processes data filenames as follows:
1. Takes filename without extension: `uv-tools.yaml` → `uv-tools`
2. Strips prefix before last hyphen: `uv-tools` → `tools`
3. Creates template variable: `.tools`

This behavior is **not clearly documented** in chezmoi docs but is beneficial:
- **Organizational prefixes**: Filenames can be prefixed for clarity without changing template access
- **Backward compatibility**: Renaming doesn't break existing templates
- **Simplified templates**: No need for complex `index` function calls

### Alternative Approaches Considered

**Option 1: Use underscores** (`uv_tools.yaml`, `sdkman_sdks.yaml`)
- ❌ Less conventional for config filenames
- ❌ Doesn't test chezmoi's hyphen handling
- ✅ Would be accessible as `.uv_tools`, `.sdkman_sdks`

**Option 2: Use dot notation** (`uv.tools.yaml`, `sdkman.sdks.yaml`)
- ❌ Unconventional YAML filename structure
- ❌ Could confuse file extension parsing
- ❌ Uncertain how chezmoi would handle

**Option 3: Longer descriptive names** (`python-cli-tools.yaml`, `java-jvm-sdks.yaml`)
- ❌ Verbose
- ❌ Loses concise reference to specific package manager
- ✅ More descriptive

**Chosen: Hyphenated prefixes** (`uv-tools.yaml`, `sdkman-sdks.yaml`)
- ✅ Clear package manager association
- ✅ Concise
- ✅ Unix-conventional
- ✅ Leverages chezmoi's prefix-stripping behavior
- ✅ No template changes required

## Migration Path

### For Existing Machines
1. **User runs**: `chezmoi update` (pulls renamed files from repository)
2. **Chezmoi reads**: New filenames (`uv-tools.yaml`, `sdkman-sdks.yaml`)
3. **Template variables**: Created as `.tools` and `.sdks` (same as before)
4. **Scripts run**: Installation scripts execute unchanged
5. **Packages**: Idempotent installers skip already-installed packages

**Result**: Fully automatic, zero-intervention migration.

### Rollback
If issues arise (unlikely given no template changes):
```bash
git revert <commit-hash>
chezmoi apply
```

Or manual rollback:
```bash
cd /Users/craig/.local/share/chezmoi
git mv home/.chezmoidata/uv-tools.yaml home/.chezmoidata/tools.yaml
git mv home/.chezmoidata/sdkman-sdks.yaml home/.chezmoidata/sdks.yaml
```

## Files Modified

### Data Files (Renamed)
- `home/.chezmoidata/tools.yaml` → `home/.chezmoidata/uv-tools.yaml`
- `home/.chezmoidata/sdks.yaml` → `home/.chezmoidata/sdkman-sdks.yaml`

### Core Documentation (Updated)
- `README.md` - Lines 68-69, 104
- `AGENTS.md` - Line 35
- `openspec/project.md` - Lines 156-157
- `.serena/memories/chezmoi-dotfiles-quick-reference.md` - Lines 18, 25-26

### Specifications (Updated)
- `openspec/specs/package-management/spec.md` - 15+ references updated
- `openspec/specs/script-execution/spec.md` - Line 160

### Archived Proposals (Migration Notes Added)
- `openspec/changes/archive/2025-10-24-three-layer-package-management/proposal.md`
- `openspec/changes/archive/2025-10-10-sdkman-integration/proposal.md`

## Key Learnings

### Chezmoi Data File Behavior
This change uncovered important (underdocumented) chezmoi behavior:

**Hyphenated filenames are processed specially**:
- Prefix before last hyphen is stripped for template variable naming
- Allows organizational prefixes without impacting template access
- Enables file clarity without template complexity

**Example**:
- `machine-config.yaml` → accessible as `.config` (not `.machine-config`)
- `uv-tools.yaml` → accessible as `.tools` (not `.uv-tools`)
- `brew-packages.yaml` → would be accessible as `.packages`

**Implication for future**: Data files can be renamed for clarity by adding prefixes, without requiring template changes, as long as the suffix remains the same.

### Documentation Pattern
For future similar changes:
1. Test chezmoi behavior before assuming template impact
2. Document discoveries about tool behavior in proposals
3. Add migration notes to related archived proposals
4. Update all documentation comprehensively

## Deployment Status
✅ **Deployed** - Data files renamed, all documentation updated, no breaking changes.

## Related Changes
- See `2025-10-24-three-layer-package-management` for original UV tools layer
- See `2025-10-10-sdkman-integration` for original SDKMAN integration

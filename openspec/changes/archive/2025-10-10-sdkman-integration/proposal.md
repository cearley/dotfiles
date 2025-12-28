# Change: SDKMAN Integration for Java SDK Management

## Migration Note (2025-12-28)

As of 2025-12-28, the data file referenced in this proposal has been renamed for clarity:
- `sdks.yaml` → `sdkman-sdks.yaml` (SDKMAN JVM SDKs)

**Important discovery**: Chezmoi strips prefixes before hyphens in filenames, so:
- `sdkman-sdks.yaml` → accessible as `.sdks` (not `.sdkman-sdks`)

This means **no template syntax changes were required**. The renaming is purely for file organization and clarity.

See `openspec/changes/archive/2025-12-28-rename-data-files-for-clarity/` for details.

---

## Why
The previous Java SDK management approach using jenv and manually installed Azul Zulu JDK had several limitations:
- **Manual version management**: Required manual downloads and jenv configuration
- **Limited JVM ecosystem**: Only managed Java versions, not Gradle, Maven, or other JVM tools
- **Version consistency**: Difficult to ensure consistent SDK versions across machines
- **Update complexity**: Updating Java versions required manual intervention

SDKMAN provides a comprehensive solution for managing the entire JVM ecosystem with automatic version management, easy SDK switching, and support for multiple Java distributions and build tools.

## What Changes
- Replace jenv with SDKMAN for Java version management
- Remove Azul Zulu JDK manual installation
- Add SDKMAN installation script at position 20 (before package management)
- Add SDK installation script at position 24 (after package management tooling)
- Create `sdks.yaml` data file for SDK definitions
- Update shell profiles to initialize SDKMAN
- Tag-gate SDKMAN and SDK installations behind `dev` tag

### Breaking Changes
**BREAKING**: Machines using jenv will need to migrate to SDKMAN. Existing Java installations will remain functional, but version management will transition to SDKMAN.

## Impact
- Affected specs: `package-management` (new SDKMAN layer added)
- Affected code:
  - `home/.chezmoiscripts/run_once_before_darwin-20-install-sdkman.sh.tmpl` (create)
  - `home/.chezmoiscripts/run_onchange_before_darwin-24-install-sdks.sh.tmpl` (create)
  - `home/.chezmoidata/sdks.yaml` (create)
  - `home/dot_bash_profile.tmpl` (update for SDKMAN init)
  - `home/dot_zshrc.tmpl` (update for SDKMAN init)
  - `home/.chezmoiexternal.toml.tmpl` (remove jenv)

## Design Decisions

### Why SDKMAN
- **Ecosystem coverage**: Manages Java, Gradle, Maven, Liquibase, Kotlin, Scala, and 50+ JVM tools
- **Multiple distributions**: Supports Oracle, OpenJDK, GraalVM, Azul Zulu, Amazon Corretto, etc.
- **Version switching**: Simple `sdk use` and `sdk default` commands
- **Automated updates**: `sdk update` keeps SDK catalog current
- **Shell integration**: Automatic PATH and JAVA_HOME management

### Tag-Based Installation
Require `dev` tag for SDKMAN to avoid installing JVM tooling on non-development machines:
- Personal machines without development work don't need Java
- Work machines can opt-in via tag selection
- AI-focused machines can skip Java ecosystem

### Execution Order Position 20
Install SDKMAN at position 20 (before Homebrew package installation at 23) to ensure:
- SDKMAN available before any SDK installations
- SDKs installed at position 24 (after essential packages)
- Proper dependency ordering in script execution flow

### Static Data File (sdks.yaml)
Use static YAML file for SDK definitions (not template):
- Must exist before template engine runs
- Simple YAML structure for SDK + version
- Platform-specific SDK lists (darwin, linux, windows)
- Tag-based categories (currently only `dev`)

## Migration Path

### For Existing Machines with jenv
1. Install SDKMAN: `run_once_before_darwin-20-install-sdkman.sh.tmpl` executes
2. Install SDKs: `run_onchange_before_darwin-24-install-sdks.sh.tmpl` installs Java versions
3. Update shell: Source new shell profiles with SDKMAN init
4. Remove jenv: Can manually remove jenv if desired (not required)
5. Verify: Run `sdk current` to confirm SDKMAN is active

### Rollback
To revert to jenv:
1. Remove SDKMAN: `rm -rf ~/.sdkman`
2. Remove SDKMAN init from shell profiles
3. Reinstall jenv via `.chezmoiexternal.toml`
4. Reinstall Java versions manually
5. Configure jenv versions

## Files Created
- `openspec/changes/archive/2025-10-10-sdkman-integration/` (this proposal)
- `home/.chezmoiscripts/run_once_before_darwin-20-install-sdkman.sh.tmpl`
- `home/.chezmoiscripts/run_onchange_before_darwin-24-install-sdks.sh.tmpl`
- `home/.chezmoidata/sdks.yaml`

## Files Modified
- `openspec/specs/package-management/spec.md` (added SDKMAN SDK Management section)
- `home/dot_bash_profile.tmpl` (added SDKMAN initialization)
- `home/dot_zshrc.tmpl` (added SDKMAN initialization)
- `home/.chezmoiexternal.toml.tmpl` (removed jenv)

## Deployment Status
✅ **Deployed** - SDKMAN integration is live and active across all machines with `dev` tag.

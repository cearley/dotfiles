## Why

The package management system currently supports four language ecosystems (Homebrew, UV/Python, Bun/JS, SDKMAN/JVM) but has no support for Rust-based CLI tools installed via `cargo install`. With Rust already bootstrapped on `dev` machines via the existing install script, cargo packages should be expressible in `packages.yaml` alongside the other package types, enabling tools like `beads_rust` (a git-sourced Rust crate) to be managed declaratively.

## What Changes

- Add a `cargo` key to tag sections in `home/.chezmoidata/packages.yaml`, using the same pattern as `uv`, `bun`, and `sdkman`
- Add `beads_rust` (installed from `--git https://github.com/Dicklesworthstone/beads_rust.git`) to the `ai` tag's `cargo` list as the first entry
- Create `run_onchange_after_darwin-27-install-cargo-packages.sh.tmpl`: a new script that:
  - Is gated on the `dev` tag (Rust toolchain prerequisite)
  - Sources `~/.cargo/env` before invoking cargo
  - Iterates over `cargo` entries per selected tag and runs `cargo install <entry>`
  - Only installs `ai`-tagged cargo packages when the `ai` tag is also selected

## Capabilities

### New Capabilities

_(none — this extends an existing capability)_

### Modified Capabilities

- `package-management`: Add Cargo (Rust) as a fifth package management layer with tag-based selection, a new `cargo` key in `packages.yaml`, and a corresponding `run_onchange_after` installation script at position 27

## Impact

- **`home/.chezmoidata/packages.yaml`**: New `cargo` key added to `ai` section (and available for future use in other tags)
- **`home/.chezmoiscripts/`**: New script `run_onchange_after_darwin-27-install-cargo-packages.sh.tmpl` added
- **`openspec/specs/package-management/spec.md`**: Extended with Cargo requirements and script execution table update
- **Tags affected**: `dev` (required), `ai` (first cargo package lives here)
- **No breaking changes**: Existing package management behaviour is unchanged; `cargo` key is optional in each tag section
- **Security**: No secrets involved; packages are installed from public git repositories or crates.io via `cargo install`; the git URL is explicit and version-pinned to HEAD of the named repo

## Non-Goals

- No support for `cargo install` with explicit version pinning in this change (simple name or `--git` flag only)
- No Linux support added in this change (script is darwin-gated, consistent with other scripts)
- No shell profile integration (`~/.cargo/env` is already sourced by the existing zshrc setup)
- No automatic `rustup update` before installing packages
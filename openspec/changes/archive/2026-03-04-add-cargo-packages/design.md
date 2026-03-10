## Context

The dotfiles repo manages packages across four ecosystem-specific package managers (Homebrew, UV/Python, Bun/JS, SDKMAN/JVM). Rust is already installed on `dev` machines via `run_once_before_darwin-10-install-rust.sh.tmpl`, which means `cargo` is available on every machine that selects the `dev` tag. However, there is no current mechanism to declare and install Rust-based CLI tools through `packages.yaml`.

The first concrete package needed is `beads_rust`, a git-hosted Rust crate (`--git https://github.com/Dicklesworthstone/beads_rust.git`) used in AI workflows and gated on the `ai` tag.

## Goals / Non-Goals

**Goals:**
- Add `cargo` as an optional key in `packages.yaml` tag sections, following the same pattern as `uv` and `bun`
- Create a `run_onchange_after_darwin-27-install-cargo-packages.sh.tmpl` script that installs declared cargo packages
- Gate the entire script on the `dev` tag (Rust toolchain prerequisite)
- Gate individual tag packages on their respective tags (e.g., `ai` packages only when `ai` is selected)
- Source `~/.cargo/env` before invoking cargo to ensure PATH is correct
- Add `beads_rust` to the `ai` tag's `cargo` list as the first entry

**Non-Goals:**
- Linux support (darwin-only, consistent with existing scripts)
- `rustup update` before package installation
- Explicit crate version pinning (beyond what `cargo install` flags support natively)
- Shell profile modifications (`.cargo/env` is already sourced by existing zshrc)

## Decisions

### Decision: `run_onchange_after` timing

**Choice**: Use `run_onchange_after` rather than `run_onchange_before`.

**Rationale**: Cargo package installation is a post-dotfile-apply operation. The Rust toolchain is installed during the `before` phase (position 10). Using `after` avoids any ordering ambiguity with the `before` scripts and semantically positions cargo packages as post-setup enhancements. This is a conscious deviation from the `before` pattern used by uv and bun, which is acceptable because cargo depends on Rust being fully installed first, and Rust installation is a `run_once_before` (not `run_onchange`).

**Alternative considered**: `run_onchange_before` at position 27. Rejected because at position 27, Rust is guaranteed to be installed (it runs once at position 10), but the `cargo` binary location may not be on PATH unless `~/.cargo/env` has been sourced. Using `after` timing and sourcing `~/.cargo/env` at script start is cleaner.

### Decision: Script position 27

**Choice**: Use position 27 within the 20-29 package management group.

**Rationale**: This slots between Bun packages (26) and the machine-specific Brewfile (28), keeping all package installer scripts together. Position 28 (machine-specific Brewfile) must remain last in the group per the existing CLAUDE.md convention, so 27 is the natural fit.

### Decision: `cargo` key format in packages.yaml

**Choice**: Each entry is the full set of flags passed after `cargo install` — e.g., `'--git https://github.com/Dicklesworthstone/beads_rust.git'` for git-sourced crates, or a bare crate name like `'ripgrep'` for crates.io packages.

**Rationale**: This mirrors the `uv` pattern where entries can include full install specifications. It gives maximum flexibility without needing separate YAML keys for install flags vs. package names.

**Alternative considered**: Separate `name` and `flags` sub-keys per entry. Rejected as over-engineered for the current use case; a flat string per entry is simpler and consistent with how uv handles git URLs.

### Decision: `dev` tag gate at script level, not individual package level

**Choice**: The entire script is skipped unless the `dev` tag is present (because Rust requires `dev`). Within the script, individual tag categories are still gated on their respective tags (ai, work, etc.).

**Rationale**: Mirrors how the SDKMAN SDK installer script is `dev`-only at the top level. Cargo packages from the `ai` tag are only installed if both `dev` AND `ai` are selected — the script-level `dev` gate and the per-category tag check together enforce this.

## Risks / Trade-offs

- **Git-sourced crates compile from source** → First-run installation may be slow (minutes for complex crates). Mitigation: none needed — this is a one-time cost per machine and chezmoi users expect setup time.
- **`cargo install` is not fully idempotent** → Re-running will recompile and reinstall even if already installed unless the binary exists and is up to date. Mitigation: `cargo install` already handles "already installed" gracefully (exits 0 with a message), and re-running on change (not every apply) limits unnecessary recompilation.
- **Rust toolchain not guaranteed at script runtime** → If `run_once_before_darwin-10-install-rust.sh.tmpl` was never executed (e.g., `dev` tag added after initial setup), `cargo` may not exist. Mitigation: `require_tools cargo` check at script start exits cleanly with an informative error.
- **`run_onchange_after` vs `run_onchange_before` ordering** → Packages from `before` scripts (uv, bun, homebrew) finish before `after` scripts run, so cargo packages install last. This is acceptable; no known dependency between cargo packages and other package installers.

## Migration Plan

1. Add `cargo` key to `packages.yaml` `ai` section with `beads_rust` entry
2. Create the new `run_onchange_after_darwin-27-install-cargo-packages.sh.tmpl` script
3. Update `openspec/specs/package-management/spec.md` with Cargo requirements
4. Run `chezmoi apply` — the new script triggers on first apply and installs `beads_rust`
5. Rollback: remove the script and the `cargo` key from `packages.yaml`; already-installed cargo binaries remain in `~/.cargo/bin/` but cause no harm

## Open Questions

_(none — requirements are fully specified)_
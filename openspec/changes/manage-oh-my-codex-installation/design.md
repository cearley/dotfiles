# Design

## Context

See `proposal.md` for motivation and `specs/codex-omx-provisioning/spec.md` for the behavior contract.

The current `home/.chezmoidata/packages.yaml` declares `oh-my-claude-sisyphus` in `ai.bun`, the OMC marketplace and plugin in `ai.agents.claude_code`, and the Codex cask in `ai.casks`. Its `agents.codex` example is commented out. There is no existing Codex provisioning script to extend.

`home/.chezmoiscripts/run_onchange_before_darwin-26-install-bun-packages.sh.tmpl` consumes `home/.chezmoitemplates/package-layer-items`, updates Bun globals, and installs selected packages. Its rendered contents include a seven-day time bucket; it runs on the next apply when those contents change, not on an independent timer. `home/.chezmoiscripts/run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl` performs Claude-specific per-profile registration, but does not run OMC's setup wizard.

Upstream OMX has a native Codex plugin bundle as well as a CLI and setup command. The exploration verified upstream documentation/source, not a working Bun installation. References to recheck against the version exercised during implementation:

- [Official package and installation guidance](https://github.com/Yeachan-Heo/oh-my-codex/blob/main/README.md)
- [Setup scopes and update behavior](https://github.com/Yeachan-Heo/oh-my-codex/blob/main/docs/getting-started.html)
- [Plugin asset ownership](https://github.com/Yeachan-Heo/oh-my-codex/blob/main/docs/plugin-bundle-ssot.md)
- [Setup implementation](https://github.com/Yeachan-Heo/oh-my-codex/blob/main/src/cli/setup.ts)
- [CODEX_HOME and runtime path resolution](https://github.com/Yeachan-Heo/oh-my-codex/blob/main/src/utils/paths.ts)

## Goals / Non-Goals

**Goals:** Reuse the existing package architecture; make executable installation reproducible; give users a verified native plugin activation procedure with explicit ownership and update boundaries.

**Non-Goals:** Add a parallel npm installer, write a generic Codex marketplace manager, run setup from a chezmoi lifecycle hook, or synchronize live Codex runtime files into the source tree.

## Decisions

### 1. Declare the executable in the existing Bun list

Add `oh-my-codex` next to the other AI CLIs in `packages.darwin.ai.bun`. Preserve the existing unpinned package-list convention and existing installer refresh policy. Do not introduce a new `npm` key or a dedicated installer. `codex` remains a Homebrew cask; do not add `@openai/codex` to Bun.

This separates package-manager ownership cleanly and keeps AI availability independent of `dev`. The Bun path must first pass an isolated package-install/executable smoke check, including any package lifecycle/native asset requirements. Failure is a blocking compatibility finding; do not silently switch package managers or globally relax lifecycle-script trust.

Alternative: use upstream's documented global npm install. That creates a second JavaScript package provisioning path and potential duplicate binaries, so it is not the selected design.

### 2. Keep native plugin setup as an explicit handoff

Add `docs/oh-my-codex.md` with the user-scoped native plugin setup procedure. The expected upstream command is `omx setup --scope user --plugin`; confirm it with the exercised release's help and isolated setup before publishing the guide. Let OMX register its packaged marketplace and plugin rather than copying Claude's `plugin@marketplace` configuration into Codex.

The guide must identify `${CODEX_HOME:-$HOME/.codex}`, inspect existing guidance/configuration ownership, and explain what setup writes. Choose a dedicated working directory for user setup outside this checkout and outside the active project: upstream still writes working-root `.omx/` preferences and HUD/state files even with user scope. Do not run setup implicitly from this repo just because chezmoi is executing here.

Existing `AGENTS.md` content must be preserved and reviewed. Explain the tested upstream merge/confirmation behavior and backups; do not recommend `--force`. Project-scoped activation is a separate deliberate action, not part of dotfiles provisioning.

Alternative: automate user-scoped plugin setup in a new `run_onchange_after` script. That would need a noninteractive configuration contract, overwrite/merge policy, setup working-directory policy, and profile lifecycle. It also couples package refreshes to runtime rewrites. Defer that larger capability; this proposal installs the CLI automatically and documents explicit plugin activation.

### 3. Leave Codex runtime files with their owners

Do not add `home/dot_codex` snapshots or templates for configuration, hooks, generated agents, plugin caches, or `AGENTS.md`. Also leave `.omx/` files, auth, and project guidance outside chezmoi's managed set. If existing paths are symlinks or managed by another tool, the guide must stop the user before conflicting setup and explain that ownership must be resolved first.

The precedent is the Claude environment design: chezmoi manages shared preferences independently from tool-written guidance. Codex does not need a new preference relocation mechanism in this change.

### 4. Document one package update owner

Use the existing Bun/chezmoi package refresh path. The guide's launch examples set `OMX_AUTO_UPDATE=0`; users wanting that behavior for all OMX launches can set it in their chosen launch environment. Do not add shell exports, aliases, or wrappers in this change, and do not claim the update policy is enforced for arbitrary bare `omx` invocations.

Do not recommend `omx update` or npm installation as the managed upgrade route. After a package version change, explicitly review and rerun scoped setup as needed. Package refresh and runtime refresh are separate operations.

### 5. Verify without mutating real profiles

Render the existing Bun installer with and without `ai` and with `ai` but no `dev`, using `chezmoi execute-template` through the existing `tests/run-template` fixture harness. Confirm the new package appears exactly where intended; inspect the generated shell and Homebrew declaration for duplicate Codex provisioning. Avoid a new test suite that only mirrors a one-line declaration.

For compatibility checks, isolate the Bun global directory/bin, HOME, CODEX_HOME, and setup working directory. Keep real auth and profile paths out of that environment. Validate installation, CLI help/version, plugin discovery/registration, and `omx doctor`; distinguish missing auth from installation defects. Repeat setup with an existing user-authored guidance fixture and compare preserved content and resulting registrations. Capture the exercised package/runtime versions and any required lifecycle behavior in the guide.

An authenticated `omx exec` check is a separate user-run step because it makes a model request and depends on a real profile. Document it; do not make it part of chezmoi apply or this proposal's validation.

## Risks / Trade-offs

- **Bun compatibility differs from upstream npm instructions** -> Prove the Bun-installed executable and packaged plugin assets in isolation before completing implementation; report incompatibility rather than broadening the design silently.
- **CLI available but plugin not activated** -> State the distinction prominently and supply the explicit activation procedure and doctor checks.
- **Existing guidance/configuration has another owner** -> Inspect ownership first, preserve content, review diffs/backups, and avoid force setup.
- **Independent OMX updater creates package drift** -> Set `OMX_AUTO_UPDATE=0` in the documented launch environment and explain the limit of that opt-in policy.
- **Native plugin setup changes upstream** -> Record the tested version and link upstream documentation; recheck flags and file destinations before installation.
- **OMX launches bypass the existing hcom shell function** -> Mention the existing cmux warning and explicit `hcom start` integration in the guide; do not redesign shell routing here.

## Migration Plan

1. Verify the official package's Bun installation and scoped plugin setup using disposable paths.
2. Add the package declaration and setup guide, preserving unrelated working-tree edits.
3. Render and inspect the tag variants and focused chezmoi diff; a real apply installs the CLI through the existing package script only.
4. A user later selects the intended Codex home and setup directory, reviews existing guidance, activates the native plugin, and verifies readiness.

Rollback removes the `oh-my-codex` declaration and guide. Removing a package declaration does not automatically uninstall an existing Bun global, and removing the CLI does not undo OMX setup. Document explicit package removal and upstream runtime cleanup separately, with ownership review before touching generated or user-authored files. No automatic cleanup is introduced.

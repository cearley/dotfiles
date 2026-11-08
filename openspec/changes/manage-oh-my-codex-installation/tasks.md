# Tasks

## 1. Verify the selected package path

- [ ] 1.1 Install the official `oh-my-codex` package with Bun using disposable HOME, Bun global/bin, and CODEX_HOME paths; verify the installed `omx` resolves from that bin directory and its version/help commands run, recording Bun/Node/OMX versions and lifecycle/native-asset requirements. Stop and report a compatibility failure rather than introducing another package manager.
- [ ] 1.2 Verify the exercised release supports explicit user-scoped native plugin setup, including the expected `omx setup --scope user --plugin` flags; inspect help/source and run setup in a disposable working directory with `OMX_AUTO_UPDATE=0`, confirming generated files and plugin registration stay inside the isolated destinations.

## 2. Declare the AI package and document ownership

- [ ] 2.1 Add `oh-my-codex` to `packages.darwin.ai.bun` in `home/.chezmoidata/packages.yaml`; verify the focused diff preserves the existing `codex` cask, OMC declarations, commented `agents.codex` stub, and unrelated working-tree edits, without adding `@openai/codex` or a new installer/template.
- [ ] 2.2 Render the existing position-26 Bun installer through `tests/run-template`/`chezmoi execute-template` using macOS data for `ai`, `ai` without `dev`, and no `ai`; verify `bun add -g oh-my-codex` appears once in both AI variants and is absent without AI, and check the rendered shell with `bash -n` without executing it. Reuse `home/.chezmoitemplates/package-layer-items` unchanged.
- [ ] 2.3 Create `docs/oh-my-codex.md` describing the tested package versions, Bun/chezmoi package ownership, Homebrew-owned Codex, seven-day-on-next-apply refresh behavior, explicit setup refresh after upgrades, and launch examples using `OMX_AUTO_UPDATE=0`; verify examples do not install Codex twice, prescribe `omx update`, change shell wrappers, or imply global updater enforcement.

## 3. Deliver and verify the explicit activation procedure

- [ ] 3.1 Extend `docs/oh-my-codex.md` with effective CODEX_HOME selection, ownership/symlink checks, backup and guidance preservation, a dedicated user-setup working directory, the tested native plugin setup command, and generated-file destinations; verify the procedure leaves this checkout's/project AGENTS.md untouched and makes working-directory `.omx/` state explicit.
- [ ] 3.2 Exercise the documented procedure twice against isolated user-authored AGENTS.md/configuration fixtures; verify content preservation, native plugin discovery, no duplicate registrations on the second run, and `omx doctor` results, distinguishing missing authentication from install defects. Record the tested merge/confirmation behavior and any limitations in the guide.
- [ ] 3.3 Document executable resolution/version checks, doctor checks, a separately labeled user-run authenticated execution check, the existing hcom/cmux launch boundary, and rollback; verify rollback distinguishes removing the declaration, uninstalling the Bun global, and cleaning up OMX runtime changes, without automatic deletion of user files.

## 4. Review integration boundaries

- [ ] 4.1 Review a focused `chezmoi diff` for the changed package-script target using a TTY when KeePassXC requires it, or fixture-backed rendering when unavailable; verify only the intended package command is introduced and no apply hook invokes OMX setup, no runtime files become chezmoi-managed, and no new shell exports/aliases are added. Record which verification path was used.
- [ ] 4.2 Run `openspec validate manage-oh-my-codex-installation --strict` and review the implementation diff against all scenarios in `specs/codex-omx-provisioning/spec.md`; verify the plan is satisfied without applying setup to real profiles or performing authenticated model requests as an automated check.

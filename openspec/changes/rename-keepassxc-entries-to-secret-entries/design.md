## Context

See `proposal.md` - Why. Complete inventory of every current reference to `keepassxc_entries` (excluding `openspec/changes/archive/**`, which stays as historical record):

- **Data**: `home/.chezmoidata/config.yaml` — the map itself, under all three machine sections (MacBook Pro, Mac Studio have `ssh`; Mac mini also has `ssh`).
- **Consuming templates** (all follow the same three-line pattern: pull `machine-settings`, `index` out `keepassxc_entries`, `index` out `ssh`):
  - `home/private_dot_ssh/private_id_ed25519.tmpl`
  - `home/private_dot_ssh/id_ed25519.pub.tmpl`
  - `home/private_dot_ssh/known_hosts.tmpl`
  - `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl`
- **Reusable template docs/examples**: `home/.chezmoitemplates/machine-config` (comment + 1 example), `home/.chezmoitemplates/machine-settings` (comment example)
- **Repo docs**: `home/.chezmoitemplates/CLAUDE.md`, `README.md`
- **Specs**: `openspec/specs/secret-management/spec.md` (1 requirement), `openspec/specs/machine-config/spec.md` (3 requirements, already drafted as this change's spec deltas)

Every call site's actual secret retrieval call (`keepassxcAttribute $sshEntryName "..."`) is unaffected — only the map key and local variable names change.

## Goals / Non-Goals

**Goals:**
- Every reference to `keepassxc_entries` (data, templates, docs, specs) becomes `secret_entries`, consistently.
- `chezmoi diff`/`chezmoi apply` produce byte-identical rendered output before and after — this is a pure rename with zero behavioral change.

**Non-Goals:**
- No new secret backend, no dispatch mechanism, no `manager` field — already scoped out in the proposal's Non-goals.
- No change to `.chezmoitemplates/CLAUDE.md`'s or `machine-config`'s general documentation structure beyond swapping the stale example string.

## Decisions

**1. Rename local template variables alongside the data key, not just the map key.**
Each consuming template holds the map in a local variable named after the old key (`$keepassxcEntries`). Considered leaving these as-is and renaming only the YAML key and the string literal passed to `index`. Rejected: leaving `$keepassxcEntries := index $settings "secret_entries"` would immediately reintroduce the exact confusion this change exists to remove — a generic map stored in a KeePassXC-named variable. The variable rename is a pure find-and-replace within each file (`$keepassxcEntries` → `$secretEntries`), no added risk.

**2. Single flat commit-sized change, no phased/dual-read migration.**
Considered supporting both `keepassxc_entries` and `secret_entries` simultaneously for a transition period (read either, prefer new). Rejected: this is a single-user, single-repo dotfiles project with no external consumers of `config.yaml`'s schema and no rollout window to bridge — `git` history is the rollback mechanism, not a compatibility shim. A dual-read path would be dead code the moment this commit lands.

**3. Spec updates keep original requirement/scenario titles where only example text changes.**
For the three `machine-config` requirements that merely use `keepassxc_entries.ssh` as an illustrative dot-notation example (not the actual subject of the requirement), only the example string inside scenario bodies changes — titles stay identical. Only `secret-management`'s "Machine-Specific KeePassXC Entries" requirement is actually *about* this property, so that one gets a real RENAMED + MODIFIED treatment (new title, generalized description). This matches `openspec validate`'s expectation that a MODIFIED requirement block reproduce every scenario the current spec has (confirmed by hitting and fixing this exact validation error while drafting the specs delta for the earlier syncthing change in this same session).

## Risks / Trade-offs

- [Risk] Missing a reference during the rename leaves a stale `keepassxc_entries` lookup that silently returns empty (via `default dict`), causing SSH secret retrieval to fail quietly rather than erroring. → Mitigation: `tasks.md` includes a grep-based verification step to confirm zero remaining non-archived references after implementation.
- [Trade-off] Touching 4 templates + 2 template-doc files + 2 specs + `config.yaml` + `README.md` for a pure rename is a wide diff for a "no functional change" commit. Accepted: the alternative (leaving a misleading name in place) compounds every time a new consumer of the map is added, and the rename is mechanical/low-risk to review as a diff.

## Migration Plan

1. Rename the key in `home/.chezmoidata/config.yaml` for all three machines.
2. Update the four consuming templates (data key + local variable name).
3. Update the two `.chezmoitemplates/` doc-comment examples.
4. Update `home/.chezmoitemplates/CLAUDE.md` and `README.md` prose.
5. Verify via `tests/run-template` against each changed `.tmpl` and `grep -rn keepassxc_entries` (excluding `openspec/changes/archive/**`) returning no results.
6. Rollback: plain `git revert` — no data migration, no external state, no secret values touched.

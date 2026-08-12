## Context

See `proposal.md` - Why. Relevant current-state details this design builds on:

- `home/.chezmoidata/config.yaml` today declares `syncthing_shared_folders` as a top-level key with a YAML anchor (`&laptop_desktop_syncthing_folders`), above `machines:`. MacBook Pro and Mac Studio alias it (`syncthing_folders: *laptop_desktop_syncthing_folders`); Mac mini has no `syncthing_folders` key at all.
- chezmoi merges every file under `home/.chezmoidata/` (already includes `config.yaml` and `packages.yaml` side by side) into one flat root template-data namespace before any template executes. YAML anchors/aliases, by contrast, are resolved at YAML-parse time and are scoped to a single document — they cannot span two files even though both end up merged into the same chezmoi data map afterward.
- `run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` currently reads the machine's resolved `syncthing_folders` list via `includeTemplate "machine-settings" . | fromJson`, then `index $settings "syncthing_folders"`. Because the alias was already expanded at YAML-parse time, this value has always arrived as a plain list — the script has never needed to know the list came from an alias.
- `machine-config` and `machine-settings` are documented (`openspec/specs/machine-config/spec.md`, "Generic Lookup Design", "Extensibility Without Template Changes") as property-agnostic pass-throughs: they must not gain per-property special cases.

## Goals / Non-Goals

**Goals:**
- Let `syncthing_shared_folders` live in its own `.chezmoidata/` file, addressable directly as `.syncthing_shared_folders` by any template.
- Preserve today's behavior for all three machines with no functional change: MacBook Pro and Mac Studio still get the same five folders; Mac mini still gets none.
- Replace the alias with a mechanism that keeps working regardless of which `.chezmoidata/` file declares the shared data or the machine.
- Fail template rendering clearly if a machine's reference names a key that doesn't exist, rather than silently producing an empty folder list.

**Non-Goals:**
- Generalizing name-based reference resolution into `machine-config`/`machine-settings` as a reusable feature for other properties. Only `syncthing_folders` needs it today: building a generic mechanism now would be speculative and there's no second use case to validate the design against.
- Changing anything about how folders are created, versioned, or ignored once the script has the resolved list — that's `syncthing-folder-setup`'s concern and is untouched.

## Decisions

**1. Reference form: bare string naming the top-level key, not a typed wrapper.**
A machine's `syncthing_folders` property is either a YAML list (inline, as already supported) or a bare string (`syncthing_folders: syncthing_shared_folders`). Considered a typed wrapper instead (e.g. `syncthing_folders: {ref: syncthing_shared_folders}`) to make "this is a reference" more explicit and avoid any ambiguity with a literal value. Rejected: every existing and foreseeable folder-list entry is an object (`id`/`label`/`path`/...), never a bare string, so `kindIs "string"` vs `kindIs "slice"` is already an unambiguous discriminator. The wrapper adds a syntax layer with no disambiguation benefit.

**2. Resolution lives in the consuming script, not in `machine-settings`/`machine-config`.**
`run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` performs the `kindIs`/`index` dispatch itself, immediately after extracting `syncthing_folders` from the `machine-settings` dict. Considered adding this logic to `machine-settings` so any consumer gets pre-resolved data. Rejected: `machine-settings` is documented as returning the machine's raw settings dict verbatim for arbitrary properties (see "Extensibility Without Template Changes" in the machine-config spec); teaching it to specially interpret one property's value shape breaks that contract and would need revisiting for every future property with the same pattern.

**3. Fail-loud on an unresolved reference.**
If the string value doesn't match any top-level chezmoi data key, the script calls Go template's `fail` with a message naming the missing key, aborting `chezmoi apply`. Considered leaving it as a silent empty list (matching the existing "no `syncthing_folders` key → skip gracefully" path for machines that opt out entirely). Rejected: an *absent* key and a *misspelled reference* are different failure modes with different causes — one is intentional opt-out, the other is very likely a typo that should surface immediately. This also matches the project's existing convention of hard-failing on malformed machine config at render time (e.g. `claude_envs`/`claude_default` mismatches), rather than degrading silently.

**4. New file name: `home/.chezmoidata/syncthing.yaml`.**
Named for the domain (Syncthing) rather than matching the `syncthing_shared_folders` top-level key verbatim — shorter, and still immediately discoverable given the single key it declares, consistent with `config.yaml` and `packages.yaml` already being descriptively named for what they contain.

## Risks / Trade-offs

- [Risk] A future contributor adds a new machine and copies `syncthing_folders: syncthing_shared_folders` by habit without understanding it's a name reference, then later "fixes" it into an inline list, silently forking the shared data. → Mitigation: keep the doc comment (moved from `config.yaml` into the new file, plus a short note left in `config.yaml` at the `machines:` section) explaining both forms and pointing at the shared file.
- [Risk] `fail`-ing template rendering on a bad reference blocks `chezmoi apply`/`diff`/`status` entirely for *all* machines, not just the misconfigured one, since data files are shared global state. → Accepted: this matches the blast radius of the existing `claude_envs`/`claude_default` validation failures already present in this repo, and a broken shared-data reference should be caught immediately rather than deferred.
- [Trade-off] Losing YAML-native anchor/alias means the reference is no longer validated by a YAML parser (a typo in an alias name fails at YAML-parse time with a clear "unknown anchor" error; a typo in our string reference fails later, at Go-template execution). Accepted given Decision 3 makes that failure explicit and immediate rather than silent.

## Migration Plan

1. Add `home/.chezmoidata/syncthing.yaml` with the `syncthing_shared_folders` list and its doc comment, moved verbatim from `config.yaml`.
2. Remove the `syncthing_shared_folders` block and anchor from `config.yaml`; update the file's own top-of-file section comment (lines 1-5) accordingly.
3. Change `syncthing_folders: *laptop_desktop_syncthing_folders` to `syncthing_folders: syncthing_shared_folders` for MacBook Pro and Mac Studio; update the `syncthing_folders` doc comment in the `machines:` section to describe the string-reference form alongside the inline-list form.
4. Update `run_onchange_after_darwin-94-setup-syncthing-folders.sh.tmpl` to resolve a string `syncthing_folders` value against the root template data, with `fail` on no match.
5. Verify with `tests/run-template` (or `chezmoi execute-template`) against both the script and the raw data files, and with `chezmoi diff`/`chezmoi apply` on a machine that matches "MacBook Pro" or "Mac Studio" to confirm the rendered script is byte-identical in behavior to before the change.
6. No rollback complexity beyond `git revert` — this only touches static data files and one template; there's no data migration or external state to unwind. Syncthing folder state on disk is never touched by this change (the script already treats config-removal as a no-op for existing folders, per `syncthing-folder-setup`'s Non-Destructive Operation requirement, and folder *content* under `syncthing_shared_folders` is unchanged).

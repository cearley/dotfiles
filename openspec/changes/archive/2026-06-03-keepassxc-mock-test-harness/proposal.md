## Why

Chezmoi templates that call `keepassxcAttribute` cannot be tested without a live KeePassXC database and interactive password prompt, making template validation impossible in non-interactive environments (CI, scripted testing, fresh-machine bootstrap). A lightweight mock allows any template to be rendered locally without credentials.

## What Changes

- New `tests/bin/keepassxc-cli` mock script that handles chezmoi's `open`-mode interactive protocol and returns fixture data or auto-generated `mock:<entry>:<attr>` values
- New `tests/fixtures/keepassxc.json` with pinned overrides for entries requiring a specific format (SSH keys, PEM headers, JSON blobs); all other lookups auto-generate
- New `tests/run-template` runner that derives a test config from the live config (via `chezmoi dump-config`), overrides `keepassxc.command` to the mock and sets `prompt = false`, then runs `chezmoi execute-template`

## Capabilities

### New Capabilities

- `template-testing`: Developer-facing test harness for rendering any chezmoi template locally without a live KeePassXC database

### Modified Capabilities

<!-- none — no existing spec-level requirements are changing -->

## Impact

- `tests/` directory (new): `bin/keepassxc-cli`, `fixtures/keepassxc.json`, `run-template`
- No changes to any managed dotfile templates or chezmoi scripts
- No impact on `chezmoi apply` or live secret-management flows
- Depends on: `jq` (already installed via Homebrew), `chezmoi dump-config` (available in all chezmoi ≥ 2.x)
- Tags affected: none — test tooling is repo-level, not machine/tag scoped

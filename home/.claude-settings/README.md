# Claude Code persona settings

Each file here is the part of one persona's `settings.json` that chezmoi manages. It is
written in `settings.json`'s own shape, so you can copy blocks to and from a live file.

| File            | Target                           |
|-----------------|----------------------------------|
| `default.json`  | `~/.claude/settings.json`        |
| `personal.json` | `~/.claude-personal/settings.json` |
| `work.json`     | `~/.claude-work/settings.json`   |
| `bedrock.json`  | `~/.claude-bedrock/settings.json` |

chezmoi ignores this directory because its name starts with a dot: the files are neither
deployed nor parsed as templates. Each `dot_claude*/modify_settings.json.tmpl` reads its
file with `include` and passes it to `.chezmoitemplates/claude-settings-modifier`.

## What `chezmoi apply` does

- **Objects** merge key by key. Keys that Claude Code, plugins, or you add at runtime are kept.
- **Arrays** gain the elements listed here and keep their live order. Elements added at
  runtime survive.
- **Scalars** listed here overwrite the live value. A runtime change to a managed scalar,
  such as `/config` changing `permissions.defaultMode`, is reverted.
  `check-claude-overrides` flags these at session start. Run
  `check-claude-overrides --fix <persona> <kind> <key>` to keep a change by writing it here.
- **Removing** something from a file here removes it from the live file on the next apply.
  Array elements are always removed; a scalar is removed only if its live value is still
  what chezmoi wrote. The last-applied copy is kept in `settings.json` as the string
  `_chezmoiManaged`. Don't edit that key.

## Don'ts

- Don't `chezmoi add` or `chezmoi re-add` a persona `settings.json`. `add` replaces the
  merge script with a full snapshot of the live file.
- Don't put settings in the `modify_settings.json.tmpl` files.

Tests: `tests/test-claude-settings-ledger.sh`. Spec: `openspec/specs/claude-settings-ledger/`.

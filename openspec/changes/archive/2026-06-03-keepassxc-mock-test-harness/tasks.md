## 1. Mock binary

- [x] 1.1 Create `tests/bin/keepassxc-cli` implementing the chezmoi `open`-mode interactive protocol
- [x] 1.2 Implement `lookup()` with fixture file fallback to `mock:<entry>:<attr>` auto-generation
- [x] 1.3 Handle `open` subcommand: emit `> ` prompt, parse shell-quoted show commands via eval, dispatch to `handle_show_args`
- [x] 1.4 Handle `show` subcommand for direct-mode invocations (chezmoi `mode = "show"` configs)
- [x] 1.5 Make binary executable (`chmod +x`)

## 2. Fixture file

- [x] 2.1 Create `tests/fixtures/keepassxc.json` with pinned values for format-sensitive entries (SSH keys, PEM private keys, known_hosts, JSON blobs)
- [x] 2.2 Trim fixture to only format-sensitive entries — rely on auto-generation for everything else

## 3. Test runner

- [x] 3.1 Create `tests/run-template` that derives a test config via `chezmoi dump-config --format json | jq`
- [x] 3.2 Override `keepassxc.command`, `keepassxc.database`, and `keepassxc.prompt = false` in derived config
- [x] 3.3 Support `--inline '<template>'` for one-off expression testing
- [x] 3.4 Support `--fixtures <path>` to override the fixture file path
- [x] 3.5 Make runner executable (`chmod +x`)

## 4. Verification

- [x] 4.1 Verify `keepassxcAttribute` lookup returns pinned fixture value (`id_ed25519.pub`)
- [x] 4.2 Verify auto-generation returns `mock:<entry>:<attr>` for unlisted entries
- [x] 4.3 Verify `home/private_dot_zsh_secrets.tmpl` renders all five exports
- [x] 4.4 Verify `home/private_dot_ssh/private_id_ed25519.tmpl` renders PEM block
- [x] 4.5 Verify non-keepassxc template (`home/dot_zshenv.tmpl`) renders correctly
- [x] 4.6 Verify AWS credentials template renders all profiles

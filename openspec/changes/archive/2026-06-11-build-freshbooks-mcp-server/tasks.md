## 1. External Entry

- [x] 1.1 Add `[".local/share/freshbooks-mcp-server"]` git-repo entry to `home/.chezmoiexternal.toml.tmpl` gated on `ai` + `dev` tags with `refreshPeriod = "30d"`

## 2. Build Script

- [x] 2.1 Create `home/.chezmoiscripts/run_onchange_after_darwin-38-build-freshbooks-mcp-server.sh.tmpl` with `darwin` + `ai` + `dev` tag gate, 30-day time-bucket trigger, missing-dir guard, `require_tools npm`, and `npm install && npm run build`

## 3. Verification

- [x] 3.1 Validate the build script template: `tests/run-template home/.chezmoiscripts/run_onchange_after_darwin-38-build-freshbooks-mcp-server.sh.tmpl`
- [x] 3.2 Run `chezmoi status` to confirm no unintended file changes
- [x] 3.3 Run `chezmoi apply` on a machine with `ai` + `dev` tags to confirm the external is fetched and the build script executes successfully (produces `dist/` in `~/.local/share/freshbooks-mcp-server`)
- [ ] 3.4 Verify that on a machine without `ai` or `dev` tags the script template renders to an empty file (chezmoi skips it)

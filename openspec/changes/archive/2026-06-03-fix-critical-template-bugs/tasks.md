## 1. Fix `ech0` Typo in Defender Script

- [x] 1.1 In `home/.chezmoiscripts/run_once_after_darwin-80-setup-microsoft-defender.sh.tmpl:35`, change `ech0 ""` to `echo ""`
- [x] 1.2 Verify template renders cleanly: `chezmoi execute-template < home/.chezmoiscripts/run_once_after_darwin-80-setup-microsoft-defender.sh.tmpl`

## 2. Fix Double-Slash PATH Entry in zshrc

- [x] 2.1 In `home/dot_zshrc.tmpl:102`, change `{{- .chezmoi.homeDir -}}//bin` to `{{- .chezmoi.homeDir -}}/bin` (remove the duplicate slash)
- [x] 2.2 Verify the rendered PATH line contains a single slash: `chezmoi execute-template < home/dot_zshrc.tmpl | grep 'PATH.*bin'`

## 3. Fix Hardcoded Username in zshrc fpath

- [x] 3.1 In `home/dot_zshrc.tmpl:202`, change `"/Users/craig/.oh-my-zsh/custom/completions"` to `"{{ .chezmoi.homeDir }}/.oh-my-zsh/custom/completions"`
- [x] 3.2 Verify the rendered fpath line uses the correct home dir: `chezmoi execute-template < home/dot_zshrc.tmpl | grep 'fpath.*oh-my-zsh'`

## 4. Fix Hardcoded Paths in tools.json.tmpl

- [x] 4.1 In `home/private_dot_config/claude-extend/tools.json.tmpl:51`, replace the hardcoded `/Users/craig/.nvm/versions/node/v24.7.0/bin/node` command value with `"node"` (relies on nvm PATH shim, matching other entries in the file)
- [x] 4.2 In `home/private_dot_config/claude-extend/tools.json.tmpl:53`, replace `/Users/craig/work/whimsical-mcp-server/dist/index.js` with `{{ .chezmoi.homeDir }}/work/whimsical-mcp-server/dist/index.js`
- [x] 4.3 Verify the rendered JSON is valid and contains no hardcoded usernames: `chezmoi execute-template < home/private_dot_config/claude-extend/tools.json.tmpl | python3 -m json.tool | grep -v craig`

## 5. Final Verification

- [x] 5.1 Run `chezmoi diff` to confirm only the expected lines changed
- [x] 5.2 Confirm no remaining `/Users/craig` in template files: `grep -r '/Users/craig' home/ --include='*.tmpl'`

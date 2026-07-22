## 1. Update packages.yaml

- [x] 1.1 Add `python3` to `packages.darwin.core.brews` in `home/.chezmoidata/packages.yaml` (do this before removing miniforge from `dev`, per design.md decision 3, to avoid a window where dev-only machines have no Python source)
- [x] 1.2 Move `miniforge` out of `packages.darwin.dev.casks` in `home/.chezmoidata/packages.yaml`
- [x] 1.3 Add `miniforge` to `packages.darwin.datascience.casks` in `home/.chezmoidata/packages.yaml`

## 2. Update dot_zshrc.tmpl

- [x] 2.1 Extract the `# >>> conda initialize >>>` / `# <<< conda initialize <<<` block (currently `home/dot_zshrc.tmpl:156-169`, inside the `{{ if has "dev" .tags -}}` block) out to its own top-level block
- [x] 2.2 Wrap the extracted conda block in its own `{{ if has "datascience" .tags -}} ... {{- end }}` conditional
- [x] 2.3 Verify the remaining `dev`-tag block content (awslocal alias, dotnet64 alias, `source "$HOME"/.cargo/env`, frum init, liquibase env vars) is untouched and still renders under `{{ if has "dev" .tags -}}`

## 3. Update README.md

- [x] 3.1 Update the "Environment managers" bullet for `conda` in `README.md` (currently "**conda**: Python environment management (Miniforge)" with no tag qualifier) to note it requires the `datascience` tag, matching the style of the adjacent SDKMAN bullet ("requires `dev` tag")

## 4. Verify templates render correctly

- [x] 4.1 Run `chezmoi execute-template < home/dot_zshrc.tmpl` (or `tests/run-template`) with `datascience` tag selected — confirm the conda init block appears
- [x] 4.2 Run the same template render with `datascience` tag NOT selected (e.g., just `core,dev`) — confirm the conda init block is absent and the rest of the `dev`-tag block (awslocal, dotnet64, cargo, frum, liquibase) is still present
- [x] 4.3 Run `chezmoi status` (not `chezmoi diff`, per non-interactive limitations) to confirm `home/.chezmoidata/packages.yaml` and `home/dot_zshrc.tmpl` changes are picked up as expected (scoped to `$HOME/.zshrc` since an unrelated `.aws/credentials` modify_ script fails without a TTY in this session; `packages.yaml` is a data source, not a deployed target, so it has no direct `chezmoi status` entry of its own)

## 5. Validate the OpenSpec change

- [x] 5.1 Run `openspec validate --strict miniforge-datascience-tag` (or `openspec validate miniforge-datascience-tag`) and confirm it passes

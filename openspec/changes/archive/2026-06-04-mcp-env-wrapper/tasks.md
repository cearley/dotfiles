## 1. Wrapper Script

- [x] 1.1 Create `home/dot_local/bin/executable_mcp-env-wrapper` with env-file sourcing and `exec "$@"` passthrough
- [x] 1.2 Add comment block explaining both GUI and terminal client context, usage, and aws-mcp example

## 2. Claude Desktop Config Template

- [x] 2.1 Update `aws-mcp` entry in `modify_claude_desktop_config.json.tmpl` to use `mcp-env-wrapper` as command
- [x] 2.2 Prepend `aws-mcp` server name and `uvx` path to `args` array
- [x] 2.3 Remove `env` block from `aws-mcp` entry

## 3. Terminal Client Support

- [x] 3.1 Extend registration script parser to handle bare `-- ` separator (no `-e` flags before `--`)
- [x] 3.2 Switch `localstack-mcp-server` in `packages.yaml` from `-e LOCALSTACK_AUTH_TOKEN` to `-- mcp-env-wrapper localstack-mcp-server npx ...`

## 4. Cleanup

- [x] 4.1 Delete superseded `home/dot_local/bin/executable_aws-mcp-wrapper`

## 5. Verification

- [x] 5.1 Run `chezmoi apply` to deploy wrapper to `~/.local/bin/mcp-env-wrapper`
- [x] 5.2 Create `~/.config/mcp-env/aws-mcp.env` with `AWS_PROFILE` and `AWS_REGION`; restart Claude Desktop and confirm aws-mcp connects
- [x] 5.3 Confirm localstack-mcp-server registers and connects in Claude Code after `chezmoi apply` (`~/.config/mcp-env/localstack-mcp-server.env` is deployed automatically)

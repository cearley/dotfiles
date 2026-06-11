## Context

The FreshBooks MCP server (`github.com/bitovi/freshbooks-mcp-server`) is a TypeScript project. Chezmoi fetches it as a `git-repo` external into `~/.local/share/freshbooks-mcp-server` but does not run post-fetch commands. Without a build step, the `dist/` output directory is absent and any MCP client that tries to launch the server will fail immediately.

The external entry was added in the same session with `refreshPeriod = "30d"`, meaning chezmoi pulls updates at most once a month.

## Goals / Non-Goals

**Goals:**
- Compile the TypeScript source after every chezmoi apply where the time-bucket has elapsed
- Fail loudly if `npm` is unavailable (rather than silently leaving a broken build)
- Skip gracefully if the server directory is missing (e.g. on machines without the `ai`+`dev` tags where the external isn't fetched)

**Non-Goals:**
- Pinning the Node.js version used for the build (nvm manages Node separately)
- Registering the built server as an MCP server in Claude Code (handled by `38-install-claude-mcp-servers`)
- Supporting Linux or Windows

## Decisions

### Decision: Use `run_onchange_after` with a 30-day time-bucket rather than tracking the git HEAD

**Chosen**: Embed `{{ includeTemplate "time-bucket" (dict "days" 30) }}` in a comment inside the script template.

**Alternatives considered:**
- *Embed git HEAD via `output "git" ... "rev-parse" "HEAD"`*: Would re-build only on actual source changes, but chezmoi evaluates templates during the planning phase — before externals are fetched. On first apply the directory doesn't exist yet, causing `output` to error and halting `chezmoi apply`. Not viable.
- *`run_once_after`*: Only runs once ever; would never pick up upstream changes. Rejected.
- *`run_always_after`*: Runs on every `chezmoi apply`. Safe but wasteful — `npm install` on a cold `node_modules` takes ~10s. Rejected.

**Rationale**: The 30-day bucket matches the external's `refreshPeriod = "720h"` (Go's `time.ParseDuration` does not accept `d` units; `720h` = 30 days), so the build cadence aligns with the fetch cadence. At worst, the installed binary is one cycle behind source.

### Decision: Run `npm install` before `npm run build`

The external is a bare git clone; `node_modules/` is gitignored and absent after a fresh fetch or after updates pull in new dependencies. Running `npm install` first is therefore mandatory — `npm run build` (which invokes `tsc`) would fail without the TypeScript compiler in `node_modules/.bin/`.

### Decision: Script position 38 (MCP server group)

Alphabetically `38-build-freshbooks` sorts before `38-install-claude-mcp-servers`, so if a future MCP registration step depends on the build output it will naturally execute after the build. Position 38 places this in the correct semantic group.

## Risks / Trade-offs

- **`npm` not on PATH at apply time** → The script sources nvm (`[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"`) before calling `require_tools npm`, so npm is available even in non-interactive shells that haven't sourced `.zshrc`. If nvm itself is absent, `require_tools npm` exits 1 with a clear error message.
- **Long install on slow networks** → `npm install` fetches from the registry; no timeout is enforced. Acceptable for a periodic (30-day) operation.
- **Source directory deleted between runs** → the guard `[[ ! -d "$SERVER_DIR" ]]` skips the build with a warning rather than failing apply.

## Open Questions

- Should a specific Node version be required (e.g. via an `.nvmrc` check)? The upstream repo pins its Node version in `package.json` engines; for now we trust that.

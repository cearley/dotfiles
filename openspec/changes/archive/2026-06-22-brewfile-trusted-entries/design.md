## Context

Homebrew's tap trust model requires that third-party taps and/or their formulae/casks be explicitly trusted before `brew bundle` will install them. Without trust declarations, packages from untrusted taps are silently skipped.

The current `packages.yaml` partially addressed this by using a mixed-format entry style in `taps` and `brews` lists: some entries are plain strings, others are dicts (`{name: ..., trusted: true}`). This is inconsistent, doesn't extend to `casks`, and makes the YAML harder to read.

**Current state problems:**
1. Top-level `taps` already use dict format — these entries are currently broken in the template (the pre-tap section passes the whole dict to `quote`, producing garbage output)
2. No mechanism for trusted `casks` at all
3. Mixed entry types in the same list create visual noise

## Goals / Non-Goals

**Goals:**
- All `taps`, `brews`, and `casks` lists remain pure string lists
- Trust declarations live in a single, scannable `darwin.trusted` list
- Brewfile template appends `, trusted: true` via a one-line conditional per entry type
- Bring 4 orphan taps under management

**Non-Goals:**
- Per-category trusted scoping
- Automating `brew trust` CLI calls (Brewfile approach is sufficient)
- Trusting taps/formulae not managed by this repo

## Decisions

### Decision: Global trusted set over per-entry dict format

**Chosen:** `packages.darwin.trusted` flat list; all taps/brews/casks remain plain strings.

**Alternatives considered:**
- *Dict entries inline* (`{name: 'foo', trusted: true}`): Mixes types in a list, requires `kindIs "string"` guards in every template loop, breaks visual alignment with inline comments.
- *Per-category `trusted:` key*: Cleaner than dicts but requires listing a name in both its category list and the category's trusted sub-list (duplication).
- *Global set (chosen)*: Zero duplication, all lists stay uniform strings, template change is minimal. Single place to audit what's trusted.

### Decision: Tap-level trust for managed taps, formula-level for unmanaged

**Chosen:** Trust the tap (`isen-ng/dotnet-sdk-versions`, `localstack/tap`, `oven-sh/bun`, `buo/cask-upgrade`, `manaflow-ai/cmux` excluded) when the tap is explicitly listed. Trust individual formulae/casks when the tap is not listed as a standalone tap.

**Rationale:** Trusting a tap covers all its formulae, eliminating the need for per-formula entries. For formulae from taps that are referenced only by their full `owner/tap/formula` path and not registered as standalone taps, formula-level trust is necessary. For `manaflow-ai/cmux`, we use formula-level (`manaflow-ai/cmux/cmux`) as the user's preference for minimum trust surface.

**Trusted set (complete):**
```yaml
trusted:
- 'buo/cask-upgrade'                       # tap-level (command tap only)
- 'isen-ng/dotnet-sdk-versions'            # tap-level (covers all dotnet casks)
- 'itspriddle/brews/ical-guy'             # formula-level (tap not listed)
- 'localstack/tap'                         # tap-level (covers localstack-cli)
- 'manaflow-ai/cmux/cmux'                 # formula-level (user preference: min trust surface)
- 'microsoft/mssql-release/msodbcsql18'   # formula-level
- 'microsoft/mssql-release/mssql-tools18' # formula-level
- 'oven-sh/bun'                            # tap-level (covers oven-sh/bun/bun)
- 'postrv/narsil/narsil-mcp'             # formula-level (tap not listed)
- 'qltysh-archive/formulae/codeclimate'   # formula-level (tap not listed)
- 'supabase/tap/supabase'                 # formula-level
```

### Decision: Inline conditional over partial template

**Chosen:** Append `{{ if has . $.packages.darwin.trusted }}, trusted: true{{ end }}` inline to each `tap/brew/cask` line in the Brewfile heredoc.

**Alternatives considered:**
- *Partial template in `.chezmoitemplates/`*: Adds a new file, requires passing `dict` with `type` and `entry` keys — more indirection for marginal DRY benefit given it's only used in one script.
- *Inline (chosen)*: 4 one-line additions to existing lines. No new files. Pattern is self-evident.

### Decision: Fully-qualified names for formula-level trusted entries

**Chosen:** Formula-level entries in `brews`/`casks` lists use their fully-qualified `owner/tap/formula` name when they appear in the `trusted` set.

**Rationale:** The `has . $.packages.darwin.trusted` check is an exact string match. For it to fire on a brew entry, the entry name must match exactly what's in `trusted`. Since tap-level trusted entries implicitly cover their formulae (matched via the `tap` line), formula-level entries must be fully-qualified for the match to work on their `brew`/`cask` lines.

**Affected entries requiring name change:**
- `cmux` → `manaflow-ai/cmux/cmux` (ai.casks)

New entries added with fully-qualified names:
- `microsoft/mssql-release/msodbcsql18`, `microsoft/mssql-release/mssql-tools18` (work.brews)
- `supabase/tap/supabase` (ai.brews)
- `postrv/narsil/narsil-mcp` (ai.brews)
- `qltysh-archive/formulae/codeclimate` (dev.brews)

## Risks / Trade-offs

**[Risk] Pre-tap section currently broken for dict-format taps** → Fixed as a side-effect: converting all entries back to plain strings resolves the `{{ . | quote }}` issue for top-level taps.

**[Risk] Formula-level trust requires exact name match** → Mitigated by this design: only formula-level entries need fully-qualified names. Tap-level entries match their existing short names in the `taps:` lists.

**[Risk] New packages not yet installed on all machines** → Acceptable: the 4 new taps are orphans already present on the current machine. On fresh machines they'll install cleanly. The `work` tag entries only install on machines with the `work` tag.

**[Trade-off] Global trusted set is not scoped by category** → Acceptable: trust is a security-adjacent decision and having it visible in one place is an advantage, not a drawback. A name in `trusted` that appears in multiple categories (unlikely but possible) would be consistently trusted everywhere, which is correct.

## Migration Plan

1. Edit `packages.yaml`: add `darwin.trusted`, convert dict entries to strings, add 4 new tap/formula entries
2. Edit the Brewfile template: append trust conditional to 4 lines in the heredoc
3. Run `chezmoi apply` — the `run_onchange_before` trigger fires because `packages.yaml` changes
4. Verify `brew doctor` reports no untrusted taps for managed packages

No rollback complexity: reverting `packages.yaml` and the template restores previous behavior. `brew bundle` without trust annotations is safe (packages just won't be trusted).

## Open Questions

_(none — all decisions resolved during exploration)_

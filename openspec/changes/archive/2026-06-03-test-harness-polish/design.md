## Context

Two cosmetic/UX issues left over from the initial `keepassxc-mock-test-harness` implementation, surfaced during the `/opsx:verify` pass. Both are single-line fixes with no architectural implications.

## Goals / Non-Goals

**Goals:**
- `ls` output lists only real entry names, not JSON metadata keys
- Misspelled template paths produce a clear, runner-attributed error message

**Non-Goals:**
- Any change to the keepassxc attribute lookup path
- Generalising the `_`-prefix convention beyond the `ls` command

## Decisions

**D1: Filter `_`-prefixed keys in `ls`, not at write time**

The `_comment` key serves as inline documentation in the JSON fixture file — removing it would lose that context. Filtering at read time in the `ls` case is the minimal, non-destructive fix.

**D2: Validate template file existence in the runner, not in chezmoi**

Chezmoi does validate the path, but its error message names the chezmoi command, not `run-template`. A guard in the runner gives the user an error that names the file and points to the runner, making the source of the mistake obvious.

## Risks / Trade-offs

None — both changes are strictly additive guards with no effect on the happy path.

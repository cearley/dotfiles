# Business Continuity Capability Specification

## ADDED Requirements

### Requirement: Emergency Repository Synchronization
The system SHALL provide a command that pushes all work-in-progress git repositories to GitHub via isolated emergency branches.

#### Scenario: Discover repositories in configured directories
- **WHEN** emergency-sync is executed
- **THEN** it SHALL scan all directories listed in `emergency_sync_dirs` (default: `~/work`)
- **AND** it SHALL use `fd --hidden --glob '.git'` for recursive discovery
- **AND** it SHALL discover both standard repos (`.git` directory) and worktrees (`.git` file)

#### Scenario: Skip repository with no uncommitted changes
- **WHEN** a repository has no uncommitted changes
- **AND** `git status --porcelain` returns empty output
- **THEN** emergency-sync SHALL skip that repository silently
- **AND** it SHALL count the repository in the "skipped (clean)" summary total

#### Scenario: Skip repository with no remote
- **WHEN** a repository has no configured remote
- **THEN** emergency-sync SHALL skip that repository
- **AND** it SHALL warn the user that no remote is configured
- **AND** it SHALL count the repository as failed

#### Scenario: Sync repository with uncommitted changes
- **WHEN** a repository has uncommitted changes
- **AND** the repository has a configured remote
- **THEN** emergency-sync SHALL create a branch named `${GITHUB_USERNAME}-dev/emergency/YYYY-MM-DD-HHMM`
- **AND** it SHALL stage all changes with `git add -A`
- **AND** it SHALL commit with message `WIP: Emergency sync from <branch> on <hostname> - <datetime>`
- **AND** it SHALL push the emergency branch to origin
- **AND** it SHALL return to the original branch after pushing

#### Scenario: Handle push failure
- **WHEN** `git push` fails for a repository
- **THEN** emergency-sync SHALL report the failure for that repository
- **AND** it SHALL continue processing remaining repositories
- **AND** it SHALL include the repository in the failure summary

#### Scenario: Dry-run mode
- **WHEN** emergency-sync is executed with `--dry-run`
- **THEN** it SHALL display which repositories would be synced and to which branch
- **AND** it SHALL NOT create branches, commits, or push to any remote

#### Scenario: Summary reporting
- **WHEN** emergency-sync completes
- **THEN** it SHALL display a summary with counts of synced, skipped, and failed repositories
- **AND** it SHALL exit with non-zero status if any repositories failed

#### Scenario: Configured scan directories
- **WHEN** `emergency_sync_dirs` is set in chezmoi config
- **THEN** emergency-sync SHALL scan all listed directories instead of the default
- **AND** it SHALL warn if any configured directory does not exist

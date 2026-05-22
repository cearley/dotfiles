# Business Continuity Capability Specification

## ADDED Requirements

### Requirement: Emergency Repository Synchronization
The system SHALL provide automated emergency synchronization of all git repositories in designated work directories.

#### Scenario: Discover repositories in work directory
- **WHEN** emergency-sync.sh is executed
- **THEN** it SHALL scan ~/work directory for .git subdirectories
- **AND** it SHALL list all discovered repositories with their paths
- **AND** it SHALL report the total count of discovered repositories

#### Scenario: Sync repository with uncommitted changes
- **WHEN** a repository has uncommitted changes (tracked or untracked)
- **THEN** the system SHALL stash all changes including untracked files
- **AND** it SHALL create emergency branch named ${GITHUB_USERNAME}-dev/emergency/YYYY-MM-DD-HHMM
- **AND** it SHALL create a commit with message format "WIP: Emergency sync from <source-branch> on <hostname> - YYYY-MM-DD HH:MM:SS"
- **AND** it SHALL push to emergency branch without force
- **AND** it SHALL return to original branch
- **AND** it SHALL report success if push completes

#### Scenario: Sync repository with no changes
- **WHEN** a repository has no uncommitted changes
- **AND** git status --porcelain returns empty output
- **THEN** the system SHALL skip that repository
- **AND** it SHALL report "No changes to sync" for that repository

#### Scenario: Handle network failure during push
- **WHEN** git push fails due to network unavailability
- **THEN** the system SHALL preserve local commits
- **AND** it SHALL report the failure with repository name
- **AND** it SHALL continue processing remaining repositories
- **AND** it SHALL include failed repository in failure summary

#### Scenario: Force-with-lease prevents overwrite
- **WHEN** git push --force-with-lease fails due to remote divergence
- **THEN** the system SHALL preserve local commits
- **AND** it SHALL report the conflict with repository name
- **AND** it SHALL continue processing remaining repositories
- **AND** it SHALL include repository in failure summary with reason

#### Scenario: Dry-run mode
- **WHEN** emergency-sync.sh is executed with --dry-run flag
- **THEN** it SHALL display which repositories would be synced
- **AND** it SHALL show commit messages that would be created
- **AND** it SHALL NOT execute git commit operations
- **AND** it SHALL NOT execute git push operations
- **AND** it SHALL display "DRY RUN" prefix on all operations

#### Scenario: Progress reporting
- **WHEN** emergency-sync.sh processes multiple repositories
- **THEN** it SHALL display "Processing repository X of N" for each repository
- **AND** it SHALL display current repository name
- **AND** it SHALL display sync status (synced, skipped, failed) for each
- **AND** it SHALL display summary at end with counts

#### Scenario: Empty work directory
- **WHEN** ~/work directory contains no .git subdirectories
- **THEN** the system SHALL report "No repositories found"
- **AND** it SHALL exit successfully with status 0

#### Scenario: Work directory does not exist
- **WHEN** ~/work directory does not exist
- **THEN** the system SHALL report "Work directory not found"
- **AND** it SHALL exit successfully with status 0

---

### Requirement: Pre-Outage Preparation Workflow
The system SHALL provide a comprehensive pre-outage checklist script that verifies system readiness for machine switching.

#### Scenario: Execute emergency sync
- **WHEN** pre-outage.sh is executed
- **THEN** it SHALL call emergency-sync.sh
- **AND** it SHALL wait for emergency-sync.sh to complete
- **AND** it SHALL report if emergency sync succeeded or failed

#### Scenario: Pass dry-run flag to emergency sync
- **WHEN** pre-outage.sh is executed with --dry-run flag
- **THEN** it SHALL pass --dry-run flag to emergency-sync.sh
- **AND** it SHALL display "DRY RUN" prefix on operations

#### Scenario: Verify Syncthing sync status when running
- **WHEN** Syncthing is running
- **AND** REST API is accessible at http://localhost:8384
- **THEN** pre-outage.sh SHALL query /rest/db/completion endpoint
- **AND** it SHALL parse completion percentage from JSON response
- **AND** it SHALL report if sync is complete (100%)
- **AND** it SHALL warn if sync is incomplete with percentage

#### Scenario: Handle Syncthing not running
- **WHEN** Syncthing is not running
- **THEN** pre-outage.sh SHALL detect service is stopped
- **AND** it SHALL report "Syncthing not running - skipping sync check"
- **AND** it SHALL continue with remaining checks

#### Scenario: Handle Syncthing not installed
- **WHEN** Syncthing is not installed
- **THEN** pre-outage.sh SHALL skip Syncthing checks
- **AND** it SHALL continue with remaining checks

#### Scenario: Verify MacBook Pro accessibility
- **WHEN** pre-outage.sh checks backup machine
- **THEN** it SHALL attempt SSH connection to macbook-pro.local
- **AND** it SHALL use ConnectTimeout of 5 seconds
- **AND** it SHALL use BatchMode to prevent password prompts
- **AND** it SHALL execute simple command (exit 0)
- **AND** it SHALL report success if connection established

#### Scenario: Handle MacBook Pro not reachable
- **WHEN** SSH connection to MacBook Pro times out or fails
- **THEN** pre-outage.sh SHALL report "MacBook Pro not reachable"
- **AND** it SHALL warn user to check network and power state
- **AND** it SHALL continue displaying checklist

#### Scenario: Display machine-switch checklist
- **WHEN** pre-checks complete
- **THEN** pre-outage.sh SHALL display checklist header
- **AND** it SHALL list iPhone hotspot setup steps
- **AND** it SHALL list MacBook Pro activation steps
- **AND** it SHALL reference docs/machine-switch-workflow.md for details
- **AND** it SHALL display verification items

---

### Requirement: UPS Power Event Handling
The system SHALL integrate with PowerPanel to provide automated emergency response and graceful shutdown during power events.

#### Scenario: Log power event
- **WHEN** PowerPanel triggers ups-power-save.sh
- **THEN** the script SHALL log timestamp to ~/Library/Logs/ups-events.log
- **AND** it SHALL log event type "UPS on battery"
- **AND** it SHALL create log directory if it does not exist
- **AND** it SHALL append to existing log (not overwrite)

#### Scenario: Emergency sync on power event
- **WHEN** ups-power-save.sh is triggered
- **THEN** it SHALL call emergency-sync.sh (without --dry-run)
- **AND** it SHALL wait for emergency-sync.sh to complete
- **AND** it SHALL log sync completion status

#### Scenario: Graceful shutdown with sudo
- **WHEN** emergency sync completes successfully
- **AND** sudoers is configured for passwordless shutdown
- **THEN** ups-power-save.sh SHALL execute sudo -n shutdown -h now
- **AND** it SHALL log "Shutdown initiated" if successful
- **AND** it SHALL exit after initiating shutdown

#### Scenario: Graceful shutdown without sudo
- **WHEN** emergency sync completes
- **AND** sudoers is NOT configured (sudo requires password)
- **THEN** ups-power-save.sh SHALL attempt sudo -n shutdown
- **AND** it SHALL fail gracefully when password is required
- **AND** it SHALL log "Shutdown failed (check sudoers) - PowerPanel will handle shutdown"
- **AND** it SHALL exit successfully (rely on PowerPanel fallback)

#### Scenario: PowerPanel installation on Mac Studio
- **WHEN** studio-brewfile is processed via brew bundle
- **THEN** the cask "powerpanel" SHALL be installed
- **AND** PowerPanel app SHALL be available at /Applications/PowerPanel.app
- **AND** PowerPanel SHALL be available for UPS configuration

#### Scenario: UPS event propagation to other machines
- **WHEN** UPS-connected machine triggers ups-power-save.sh
- **THEN** it SHALL propagate event to other machines via SSH
- **AND** it SHALL execute emergency-sync.sh remotely on each machine
- **AND** it SHALL run SSH calls in background for parallel execution
- **AND** it SHALL wait for all SSH calls to complete before shutdown

#### Scenario: Remote emergency sync via SSH
- **WHEN** remote machine receives UPS event via SSH
- **THEN** it SHALL execute emergency-sync.sh locally
- **AND** it SHALL sync all repositories with uncommitted changes
- **AND** it SHALL complete before UPS-connected machine shuts down

#### Scenario: PowerPanel callback configuration
- **WHEN** PowerPanel Low Battery Action is configured
- **THEN** PowerPanel Preferences SHALL accept "Run Program" option
- **AND** user SHALL be able to specify full path to ups-power-save.sh
- **AND** PowerPanel SHALL execute script when battery threshold is reached

---

### Requirement: Machine Switching Workflow Documentation
The system SHALL provide clear, actionable documentation for switching between Mac Studio and MacBook Pro during emergencies.

#### Scenario: Pre-switch preparation documentation
- **WHEN** user consults docs/machine-switch-workflow.md
- **THEN** documentation SHALL list all pre-switch preparation steps
- **AND** it SHALL reference pre-outage.sh script
- **AND** it SHALL explain Syncthing verification
- **AND** it SHALL explain MacBook Pro reachability check
- **AND** it SHALL suggest noting current work context

#### Scenario: Network transition documentation
- **WHEN** user needs to switch to MacBook Pro
- **THEN** documentation SHALL explain iPhone Personal Hotspot setup
- **AND** it SHALL explain connecting MacBook Pro to hotspot
- **AND** it SHALL explain verifying internet connectivity
- **AND** it SHALL explain VPN reconnection for client work

#### Scenario: Laptop activation documentation
- **WHEN** user activates MacBook Pro for work
- **THEN** documentation SHALL explain pulling latest git changes
- **AND** it SHALL reference emergency-sync.sh for understanding what was synced
- **AND** it SHALL explain running chezmoi update
- **AND** it SHALL explain resuming work context

#### Scenario: Return to Mac Studio documentation
- **WHEN** power is restored and user returns to Mac Studio
- **THEN** documentation SHALL explain ensuring work is committed/pushed from laptop
- **AND** it SHALL explain pulling changes on Studio
- **AND** it SHALL explain verifying Syncthing sync
- **AND** it SHALL explain checking for diverged git branches
- **AND** it SHALL explain resuming work on Studio

#### Scenario: Troubleshooting documentation
- **WHEN** user encounters issues during machine switching
- **THEN** documentation SHALL provide troubleshooting for MacBook Pro not accessible
- **AND** it SHALL provide troubleshooting for Syncthing not syncing
- **AND** it SHALL provide troubleshooting for git push failures
- **AND** it SHALL provide troubleshooting for network connectivity issues
- **AND** it SHALL provide troubleshooting for VPN connection problems

---

### Requirement: Script Idempotency
The system SHALL support safe repeated execution of all business continuity scripts without unintended side effects.

#### Scenario: Multiple emergency-sync runs within minutes
- **WHEN** emergency-sync.sh is run multiple times in succession
- **AND** repositories have not changed between runs
- **THEN** the system SHALL skip repositories with no changes
- **AND** it SHALL NOT create duplicate commits
- **AND** it SHALL report "No changes to sync" for unchanged repositories

#### Scenario: Re-run after partial failure
- **WHEN** emergency-sync.sh partially completes (some repos succeed, some fail)
- **AND** user re-runs the script
- **THEN** the system SHALL re-attempt failed repositories
- **AND** it SHALL skip previously successful repositories if no new changes
- **AND** it SHALL report current status for all repositories

#### Scenario: Interruption recovery
- **WHEN** emergency-sync.sh is interrupted mid-execution (Ctrl+C, kill signal)
- **AND** user re-runs the script
- **THEN** it SHALL be safe to re-run
- **AND** it SHALL resume or skip completed operations
- **AND** it SHALL NOT corrupt git repositories
- **AND** repositories SHALL be in valid git state (no orphaned stashes)

#### Scenario: Multiple pre-outage.sh runs
- **WHEN** pre-outage.sh is run multiple times
- **THEN** each run SHALL perform same checks independently
- **AND** each run SHALL call emergency-sync.sh (which handles its own idempotency)
- **AND** each run SHALL provide current status of Syncthing and MacBook Pro

---

### Requirement: Error Handling and Recovery
The system SHALL handle failures gracefully with clear error messages and preserve work integrity.

#### Scenario: Partial repository sync failure
- **WHEN** one or more repositories fail to sync
- **AND** other repositories sync successfully
- **THEN** the system SHALL continue processing all remaining repositories
- **AND** it SHALL collect all failures in a list
- **AND** it SHALL report summary at end listing successful vs failed repositories
- **AND** it SHALL exit with non-zero status if any failures occurred

#### Scenario: All repositories fail to sync
- **WHEN** all repositories fail to sync due to network outage
- **THEN** the system SHALL report failure for each repository
- **AND** it SHALL preserve all local commits
- **AND** it SHALL exit with non-zero status
- **AND** it SHALL display clear message about network issues

#### Scenario: Critical error handling
- **WHEN** emergency-sync.sh encounters critical error (e.g., permission denied)
- **THEN** it SHALL display clear error message explaining the problem
- **AND** it SHALL exit with non-zero status
- **AND** it SHALL NOT corrupt or lose any repository data

#### Scenario: Network unavailability
- **WHEN** network is completely unavailable
- **AND** git push operations fail for all repositories
- **THEN** commits SHALL be preserved locally
- **AND** the system SHALL notify user to push when network returns
- **AND** the system SHALL provide instructions for manual push

#### Scenario: Sudo permission denied for shutdown
- **WHEN** ups-power-save.sh attempts shutdown
- **AND** sudoers is not configured (sudo requires password)
- **THEN** the script SHALL detect permission denied
- **AND** it SHALL log clear error message about sudoers configuration
- **AND** it SHALL NOT prompt for password (non-interactive)
- **AND** it SHALL exit successfully relying on PowerPanel fallback
- **AND** it SHALL NOT block emergency sync completion

#### Scenario: Repository in detached HEAD state
- **WHEN** a repository is in detached HEAD state
- **AND** emergency-sync.sh processes it
- **THEN** the system SHALL handle the state gracefully
- **AND** it SHALL report the special state to user
- **AND** it SHALL NOT attempt push (no branch to push to)
- **AND** it SHALL preserve commits locally

#### Scenario: Repository with merge conflict
- **WHEN** a repository has unresolved merge conflicts
- **AND** emergency-sync.sh processes it
- **THEN** the system SHALL detect the conflict state
- **AND** it SHALL report the conflict to user
- **AND** it SHALL NOT attempt stash or commit (would fail)
- **AND** it SHALL continue with other repositories
- **AND** it SHALL include in failure summary with reason "merge conflict"

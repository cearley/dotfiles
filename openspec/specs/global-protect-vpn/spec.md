# Global Protect VPN Setup

## Purpose
The Global Protect VPN integration provides guided installation of the Palo Alto GlobalProtect VPN client for work machines, with interactive prompts and post-installation instructions.

## Requirements

### Requirement: Work Tag Dependency
Global Protect setup SHALL only execute on machines with the `work` tag.

#### Scenario: Work tag present
- **WHEN** chezmoi applies configuration with the `work` tag selected
- **THEN** the GlobalProtect setup script SHALL execute at position 82

#### Scenario: Work tag absent
- **WHEN** the `work` tag is not selected
- **THEN** the GlobalProtect setup script SHALL NOT be executed
- **AND** SHALL be skipped via template conditional

### Requirement: Skip If Already Installed
The script SHALL detect existing GlobalProtect installations and skip setup.

#### Scenario: GlobalProtect already installed
- **WHEN** `/Applications/GlobalProtect.app` exists
- **THEN** the script SHALL display a skip message
- **AND** SHALL exit with status 0 without further action

### Requirement: Portal Page Opening
The script SHALL open the GlobalProtect download portal in the default browser.

#### Scenario: Open portal URL
- **WHEN** GlobalProtect is not installed
- **THEN** the script SHALL execute `open "https://gp.willdan.com"`
- **AND** SHALL open the portal in the user's default web browser

### Requirement: Manual Installation Instructions
The script SHALL display step-by-step manual installation instructions.

#### Scenario: Display installation steps
- **WHEN** the portal page is opened
- **THEN** the script SHALL display instructions for:
  1. Logging in through Okta with network credentials
  2. Completing MFA (multi-factor authentication)
  3. Clicking on 'GlobalProtect Agent'
  4. Downloading the Mac installer
  5. Running the downloaded GlobalProtect.pkg file
  6. Following the installer wizard

### Requirement: Installation Wait and Verification
The script SHALL wait for the user to complete manual installation using the `wait_for_app_installation()` utility function.

#### Scenario: Successful installation detection
- **WHEN** GlobalProtect.app is detected within the timeout period
- **THEN** the script SHALL display a success message
- **AND** SHALL proceed to show post-installation setup instructions

#### Scenario: Installation timeout or cancellation
- **WHEN** the user cancels (Ctrl+C) or the timeout is reached
- **THEN** the script SHALL display a warning message
- **AND** SHALL provide the manual installation URL
- **AND** SHALL continue with the script execution

### Requirement: Post-Installation Instructions
After successful installation, the script SHALL display GlobalProtect configuration instructions.

#### Scenario: Display setup instructions
- **WHEN** GlobalProtect installation is confirmed
- **THEN** the script SHALL display instructions for:
  1. Launching GlobalProtect from Applications
  2. Opening the GlobalProtect client from menu bar
  3. Entering 'gp.willdan.com' in the Portal Address field
  4. Connecting to the VPN
  5. Signing in with Willdan credentials
  6. Authenticating with Okta MFA
  7. Verifying connection via gray shield icon

### Requirement: User Continuation Prompt
The script SHALL prompt the user before continuing with the setup process.

#### Scenario: Wait for user acknowledgment
- **WHEN** post-installation instructions are displayed
- **THEN** the script SHALL call `prompt_ready "Press any key to continue..."`
- **AND** SHALL wait for user input before exiting

### Requirement: Execution Order
The GlobalProtect setup script SHALL execute in the system configuration stage.

#### Scenario: Script position
- **WHEN** scripts execute in order
- **THEN** the GlobalProtect setup SHALL run at position 82
- **AND** SHALL be in the 80-99 range (system configuration stage)
- **AND** SHALL execute after package installation and environment setup

## Design Decisions

### Manual Installation Approach
Using manual installation instead of automated package installation provides:
- Compliance with enterprise security policies
- Ensures user authentication through Okta before download
- Proper MFA verification during download process
- Avoids storing enterprise VPN installers in public repositories
- Ensures latest version is always downloaded

### Work Tag Requirement
Limiting to work tag ensures:
- Personal machines are not prompted for enterprise VPN
- Work-specific configuration is clearly separated
- No unnecessary prompts on non-work machines
- Clean separation of personal vs. work capabilities

### Interactive Wait Pattern
Using `wait_for_app_installation()` provides:
- User control over installation timing
- Ability to cancel without breaking setup
- Clear feedback during manual installation
- Graceful handling of timeouts or cancellations

### Position 82 Execution Order
Placing the script at position 82 ensures:
- Core system setup is complete
- Shared utilities are available
- User environment is configured
- Security tools can be installed late in the process
# Shared Utilities System

## Purpose
The shared utilities system provides common functions for scripts, ensuring consistency in messaging, error handling, and common operations across all installation and setup scripts.

## Requirements

### Requirement: Shared Utility Functions File
Common utility functions SHALL be provided in `scripts/shared-utils.sh` for sourcing by all scripts.

#### Scenario: Script sourcing utilities
- **WHEN** a script includes `source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"`
- **THEN** the script SHALL have access to all utility functions

#### Scenario: Template-based sourcing
- **WHEN** the source path uses chezmoi template variables
- **THEN** the path SHALL resolve to the correct location regardless of where chezmoi is installed

### Requirement: Consistent Messaging Function
The `print_message()` function SHALL provide consistent, emoji-enhanced messaging with stderr output.

#### Scenario: Info message
- **WHEN** `print_message "info" "Installing package"` is called
- **THEN** the output SHALL display "🔵 Installing package" to stderr

#### Scenario: Success message
- **WHEN** `print_message "success" "Installation complete"` is called
- **THEN** the output SHALL display "✅ Installation complete" to stderr

#### Scenario: Warning message
- **WHEN** `print_message "warning" "Package already installed"` is called
- **THEN** the output SHALL display "⚠️ Package already installed" to stderr

#### Scenario: Error message
- **WHEN** `print_message "error" "Installation failed"` is called
- **THEN** the output SHALL display "❌ Installation failed" to stderr

#### Scenario: Skip message
- **WHEN** `print_message "skip" "Skipping optional feature"` is called
- **THEN** the output SHALL display "⏭️ Skipping optional feature" to stderr

#### Scenario: Tip message
- **WHEN** `print_message "tip" "Use --verbose for more details"` is called
- **THEN** the output SHALL display "💡 Use --verbose for more details" to stderr

#### Scenario: Stderr output
- **WHEN** any `print_message()` call is made
- **THEN** output SHALL go to stderr (>&2)
- **AND** SHALL NOT interfere with function return values on stdout

### Requirement: Emoji Message Icons
The system SHALL use intuitive emoji icons for different message types.

#### Scenario: Info icon (🔵)
- **WHEN** displaying informational messages
- **THEN** the blue circle emoji SHALL indicate informational messages

#### Scenario: Success icon (✅)
- **WHEN** displaying success messages
- **THEN** the check mark emoji SHALL indicate completed actions

#### Scenario: Warning icon (⚠️)
- **WHEN** displaying warning messages
- **THEN** the triangle emoji SHALL indicate caution

#### Scenario: Error icon (❌)
- **WHEN** displaying error messages
- **THEN** the X mark emoji SHALL indicate failures

#### Scenario: Skip icon (⏭️)
- **WHEN** displaying skip messages
- **THEN** the next track emoji SHALL indicate skipped operations

#### Scenario: Tip icon (💡)
- **WHEN** displaying tip/hint messages
- **THEN** the light bulb emoji SHALL indicate helpful tips or suggestions

### Requirement: Command Existence Check
The `command_exists()` function SHALL verify if a command is available in PATH.

#### Scenario: Command available
- **WHEN** `command_exists "brew"` is called and brew is in PATH
- **THEN** the function SHALL return 0 (success)

#### Scenario: Command unavailable
- **WHEN** `command_exists "nonexistent"` is called
- **THEN** the function SHALL return 1 (failure)

### Requirement: Tool Requirements Validation
The `require_tools()` function SHALL validate that required tools are installed before proceeding.

#### Scenario: All tools available
- **WHEN** `require_tools "git" "curl" "brew"` is called and all tools exist
- **THEN** the function SHALL return 0 and continue execution

#### Scenario: Missing required tool
- **WHEN** `require_tools "git" "nonexistent"` is called
- **THEN** the function SHALL display an error message
- **AND** SHALL exit with a non-zero status code

### Requirement: File Download Helper
The `download_file()` function SHALL download files with progress indication and error handling.

#### Scenario: Successful download
- **WHEN** `download_file "https://example.com/file" "/tmp/file"` is called
- **THEN** the file SHALL be downloaded to the specified location
- **AND** SHALL display progress during download

#### Scenario: Download failure
- **WHEN** a download fails (network error, 404, etc.)
- **THEN** the function SHALL return a non-zero exit code
- **AND** SHALL display an error message

### Requirement: Directory Utilities
The `ensure_directory()` function SHALL create directories with optional sudo support.

#### Scenario: User directory creation
- **WHEN** `ensure_directory "/Users/user/.config"` is called
- **THEN** the directory SHALL be created with appropriate permissions
- **AND** SHALL create parent directories as needed

#### Scenario: System directory creation
- **WHEN** `ensure_directory "/etc/custom" "sudo"` is called
- **THEN** the directory SHALL be created using sudo
- **AND** SHALL handle permission requirements

#### Scenario: Directory exists
- **WHEN** `ensure_directory` is called for an existing directory
- **THEN** the function SHALL succeed without error
- **AND** SHALL not modify existing permissions

### Requirement: Temporary Directory Cleanup
The `cleanup_temp_dir()` function SHALL safely remove temporary directories.

#### Scenario: Temporary directory removal
- **WHEN** `cleanup_temp_dir "/tmp/myapp-XXXXX"` is called
- **THEN** the directory and all contents SHALL be removed
- **AND** SHALL handle nested files and directories

#### Scenario: Cleanup failure handling
- **WHEN** cleanup fails (permissions, locked files)
- **THEN** the function SHALL log a warning
- **AND** SHALL NOT cause script termination

### Requirement: macOS Application Check
The `is_app_installed()` function SHALL check if a macOS application is installed.

#### Scenario: App installed
- **WHEN** `is_app_installed "Visual Studio Code"` is called and the app exists
- **THEN** the function SHALL return 0 (success)

#### Scenario: App not installed
- **WHEN** `is_app_installed "NonexistentApp"` is called
- **THEN** the function SHALL return 1 (failure)

#### Scenario: Multiple app location check
- **WHEN** checking for an app
- **THEN** the function SHALL check both `/Applications` and `~/Applications`

### Requirement: Architecture Detection Helper
The `get_macos_arch()` function SHALL return a consistent architecture string.

#### Scenario: Apple Silicon detection
- **WHEN** running on an Apple Silicon Mac
- **THEN** the function SHALL return "arm64"

#### Scenario: Intel Mac detection
- **WHEN** running on an Intel Mac
- **THEN** the function SHALL return "x64" or "x86_64"

### Requirement: Function Return Values
Utility functions SHALL use stdout for return values and stderr for messages.

#### Scenario: Clean return values
- **WHEN** a function returns a value via `echo`
- **THEN** the value SHALL go to stdout
- **AND** logging messages SHALL go to stderr
- **AND** calling scripts can capture the return value without noise

#### Scenario: Message separation
- **WHEN** a function calls `print_message()` and returns a value
- **THEN** the message SHALL appear in stderr
- **AND** the return value SHALL be capturable via command substitution

### Requirement: Root Privilege Check
The `is_root()` function SHALL check if the script is running with sudo/root privileges.

#### Scenario: Running as root
- **WHEN** `is_root` is called and the effective user ID is 0
- **THEN** the function SHALL return 0 (success)

#### Scenario: Running as normal user
- **WHEN** `is_root` is called and the effective user ID is not 0
- **THEN** the function SHALL return 1 (failure)

### Requirement: Application Installation Waiting
The `wait_for_app_installation()` function SHALL wait for an application to be installed with timeout and progress updates.

#### Scenario: App already installed
- **WHEN** `wait_for_app_installation "/Applications/App.app" "App"` is called and the app already exists
- **THEN** the function SHALL return 0 immediately
- **AND** SHALL display a success message

#### Scenario: App installs before timeout
- **WHEN** waiting for an app and the app is detected within the timeout period
- **THEN** the function SHALL return 0 (success)
- **AND** SHALL display progress updates every minute

#### Scenario: User cancels with Ctrl+C
- **WHEN** the user presses Ctrl+C during the wait
- **THEN** the function SHALL trap the interrupt signal
- **AND** SHALL return 1 with a skip message
- **AND** SHALL allow the script to continue

#### Scenario: Installation timeout
- **WHEN** the timeout period (default 30 minutes) is reached without detecting the app
- **THEN** the function SHALL return 1 (failure)
- **AND** SHALL display a warning about the timeout

### Requirement: User Prompt Helper
The `prompt_ready()` function SHALL prompt the user to press any key to continue.

#### Scenario: Default prompt
- **WHEN** `prompt_ready` is called without arguments
- **THEN** it SHALL display "Press any key to continue..."
- **AND** SHALL wait for a single keypress

#### Scenario: Custom prompt
- **WHEN** `prompt_ready "Custom message"` is called
- **THEN** it SHALL display the custom message
- **AND** SHALL wait for a single keypress

### Requirement: iCloud Sign-In Check
The `is_icloud_signed_in()` function SHALL check if the user is signed into iCloud.

#### Scenario: User signed into iCloud
- **WHEN** `is_icloud_signed_in` is called and an iCloud account is configured
- **THEN** the function SHALL return 0 (success)

#### Scenario: User not signed into iCloud
- **WHEN** `is_icloud_signed_in` is called and no iCloud account is configured
- **THEN** the function SHALL return 1 (failure)

#### Scenario: MobileMeAccounts plist missing
- **WHEN** the MobileMeAccounts.plist file does not exist
- **THEN** the function SHALL return 1 (failure)

### Requirement: Error Handling Standards
Utility functions SHALL follow consistent error handling patterns.

#### Scenario: Non-zero exit codes
- **WHEN** a utility function encounters an error
- **THEN** it SHALL return a non-zero exit code
- **AND** SHALL display an error message via `print_message "error"`

#### Scenario: Graceful degradation
- **WHEN** a non-critical error occurs
- **THEN** the function MAY log a warning and continue
- **OR** SHALL return a status code indicating partial success

## Design Decisions

### Shared Utilities Architecture
Centralizing utilities provides:
- Consistency: All scripts use identical messaging and error patterns
- Maintainability: Fix once, benefit everywhere
- Testability: Test shared functions independently
- Simplicity: Scripts focus on their specific logic, not utility implementation

### Stderr for Messages
Outputting messages to stderr ensures:
- Function return values on stdout are clean and capturable
- Messages appear in terminal but don't interfere with piping
- Standard Unix convention for logging vs. data output
- Easy separation of diagnostics from results

### Intuitive Emoji Icons
Using recognizable emojis provides:
- Visual clarity: Quickly identify message type at a glance
- Modern UX: Aligns with contemporary CLI tools
- Accessibility: Paired with text labels for screen readers
- Fallback: ASCII alternatives available if UTF-8 not supported

### Template-Based Sourcing
Using chezmoi templates in source paths allows:
- Location independence: Works regardless of installation path
- Consistency: Same pattern across all scripts
- Flexibility: Supports different chezmoi configurations

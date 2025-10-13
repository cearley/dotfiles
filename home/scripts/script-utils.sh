#!/bin/bash
# Shared utility functions for chezmoi scripts
# Source this file in your scripts with: source "{{ .chezmoi.sourceDir -}}/scripts/script-utils.sh"

# Print messages with consistent formatting and optional emoji support
# Messages are sent to stderr by default to avoid interfering with function return values
print_message() {
    local level="$1"
    local message="$2"
    
    # Check if UTF-8 is supported for emoji rendering
    if [ "${LANG}" != "${LANG%UTF-8*}" ]; then
        case "$level" in
            "info") echo "🔵 $message" >&2 ;;
            "success") echo "✅ $message" >&2 ;;
            "warning") echo "⚠️  $message" >&2 ;;
            "error") echo "❌ $message" >&2 ;;
            "skip") echo "⏭️ $message" >&2 ;;
        esac
    else
        case "$level" in
            "info") echo "[INFO] $message" >&2 ;;
            "success") echo "[SUCCESS] $message" >&2 ;;
            "warning") echo "[WARNING] $message" >&2 ;;
            "error") echo "[ERROR] $message" >&2 ;;
            "skip") echo "[SKIP] $message" >&2 ;;
        esac
    fi
}

# Check if a command exists and is executable
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're running with sudo/root privileges
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Cleanup function that can be used with trap
cleanup_temp_dir() {
    local temp_dir="$1"
    if [ -d "$temp_dir" ]; then
        print_message "info" "Cleaning up temporary files: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# Check if a directory exists and create it if it doesn't
ensure_directory() {
    local dir="$1"
    local use_sudo="${2:-false}"
    
    if [ ! -d "$dir" ]; then
        print_message "info" "Creating directory: $dir"
        if [ "$use_sudo" = "true" ]; then
            sudo mkdir -p "$dir"
        else
            mkdir -p "$dir"
        fi
    fi
}

# Download file with progress indication
download_file() {
    local url="$1"
    local output_path="$2"
    local description="${3:-file}"
    
    print_message "info" "Downloading $description..."
    print_message "info" "URL: $url"
    
    if command_exists curl; then
        if ! curl -L -o "$output_path" "$url"; then
            print_message "error" "Failed to download $description from: $url"
            return 1
        fi
    else
        print_message "error" "curl is required but not installed"
        return 1
    fi
    
    # Verify download
    if [ ! -f "$output_path" ] || [ ! -s "$output_path" ]; then
        print_message "error" "Downloaded file is missing or empty: $output_path"
        return 1
    fi
    
    local file_size
    file_size=$(wc -c < "$output_path" | tr -d ' ')
    print_message "success" "Downloaded $description successfully (${file_size} bytes)"
    
    return 0
}

# Check if a package/application is installed
is_app_installed() {
    local app_path="$1"
    [ -d "$app_path" ]
}

# Get macOS architecture in a consistent format
get_macos_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        "arm64") echo "arm64" ;;
        "x86_64") echo "x64" ;;
        *) echo "x64" ;;  # fallback
    esac
}

# Validate that required tools are available
require_tools() {
    local missing_tools=()
    
    for tool in "$@"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_message "error" "Required tools missing: ${missing_tools[*]}"
        print_message "info" "Please install missing tools and try again"
        return 1
    fi
    
    return 0
}

# Wait for an application to be installed, with timeout and progress updates
# Usage: wait_for_app_installation "/Applications/AppName.app" "AppName" [timeout_seconds]
wait_for_app_installation() {
    local app_path="$1"
    local app_name="$2"
    local timeout="${3:-1800}"  # Default 30 minutes
    local elapsed=0
    local interval=10
    
    # Check if already installed
    if is_app_installed "$app_path"; then
        print_message "success" "$app_name is already installed"
        return 0
    fi
    
    print_message "info" "Waiting for $app_name installation to complete..."
    echo "This script will continue once $app_name is detected at: $app_path"
    echo "Press Ctrl+C to cancel if you don't want to install $app_name now."
    echo ""
    
    # Poll for the app installation with timeout
    while [ "$elapsed" -lt "$timeout" ]; do
        if is_app_installed "$app_path"; then
            print_message "success" "$app_name has been successfully installed!"
            return 0
        fi
        
        # Show progress every minute
        if [ $((elapsed % 60)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            print_message "info" "Still waiting for $app_name installation... (${elapsed}s elapsed)"
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    # Timeout reached
    print_message "warning" "Installation timeout reached ($((timeout / 60)) minutes). You can run 'chezmoi apply' again later to retry."
    return 1
}

# Prompt user to press any key to continue, ensuring they see the message
# Usage: prompt_ready [custom_message]
prompt_ready() {
    local message="${1:-Press any key to continue...}"
    echo ""
    print_message "info" "$message"
    read -n 1 -s -r
    echo ""
}

# Check if user is signed into iCloud
# Returns 0 if signed in, 1 if not signed in
# Note: This checks for iCloud account, not Mac App Store specifically
is_icloud_signed_in() {
    # Check if MobileMeAccounts plist exists
    if [ ! -f ~/Library/Preferences/MobileMeAccounts.plist ]; then
        return 1
    fi

    # Extract account ID from MobileMeAccounts
    local account_id
    account_id=$(defaults read MobileMeAccounts Accounts 2>/dev/null | grep -m 1 "AccountID" | sed 's/.*= "\(.*\)";/\1/')

    # If we found an account ID, user is signed in
    if [ -n "$account_id" ]; then
        return 0
    fi

    return 1
}
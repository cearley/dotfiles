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
            "info") echo "💡 $message" >&2 ;;
            "success") echo "✅ $message" >&2 ;;
            "warning") echo "⚠️  $message" >&2 ;;
            "error") echo "❌ $message" >&2 ;;
            "skip") echo "⏩ $message" >&2 ;;
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
#!/bin/bash
# Shared utility functions for chezmoi scripts
# Source this file in your scripts with: source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"

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
            "tip") echo "💡 $message" >&2 ;;
        esac
    else
        case "$level" in
            "info") echo "[INFO] $message" >&2 ;;
            "success") echo "[SUCCESS] $message" >&2 ;;
            "warning") echo "[WARNING] $message" >&2 ;;
            "error") echo "[ERROR] $message" >&2 ;;
            "skip") echo "[SKIP] $message" >&2 ;;
            "tip") echo "[TIP] $message" >&2 ;;
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
# Returns: 0 (success) or 1 (skipped/timeout)
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
    echo "You can press Ctrl+C at any time to skip and continue with the rest of the setup."
    echo ""

    # Set up trap to handle Ctrl+C gracefully
    trap 'print_message "skip" "Skipping $app_name installation. You can install it manually later."; return 1' INT

    # Poll for the app installation with timeout
    while [ "$elapsed" -lt "$timeout" ]; do
        if is_app_installed "$app_path"; then
            trap - INT  # Remove trap
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

    # Remove trap and handle timeout
    trap - INT
    print_message "warning" "Installation timeout reached ($((timeout / 60)) minutes)."
    print_message "skip" "Skipping $app_name installation. You can install it manually later."
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

# Check iCloud sign-in at runtime; print standard warning and return 1 if not signed in.
# Returns 0 if signed in, 1 if not.
warn_icloud_not_signed_in() {
    local account_id=""
    if [[ -f ~/Library/Preferences/MobileMeAccounts.plist ]]; then
        account_id=$(defaults read MobileMeAccounts Accounts 2>/dev/null \
            | grep -m 1 "AccountID" | sed 's/.*= "\(.*\)";/\1/')
    fi
    if [[ -z "$account_id" ]]; then
        print_message "warning" "Not signed into iCloud - Mac App Store packages will be skipped"
        return 1
    fi
    return 0
}

# Iterate over Claude environment directories, expanding ~ and skipping missing dirs.
# Usage: for_each_claude_env <callback_fn> [<raw_dir>...]
# The callback receives the fully-expanded directory path as $1.
for_each_claude_env() {
    local callback_fn="$1"
    shift
    local raw_dir env_dir
    for raw_dir in "$@"; do
        env_dir="${raw_dir/#\~/$HOME}"
        if [[ ! -d "$env_dir" ]]; then
            print_message "skip" "Skipping $(basename "$env_dir") — directory not found"
            continue
        fi
        "$callback_fn" "$env_dir"
    done
}

# Determine whether a long-running package-update layer should be skipped for
# this chezmoi apply run. Layers: homebrew, sdkman, uv, bun, cargo, claude.
# Resolution order: CHEZMOI_SKIP_PACKAGE_UPDATES env var -> per-run cache file
# (keyed by $PPID, the chezmoi apply process that spawned this script) ->
# TTY-gated two-step prompt -> default (run everything).
# Usage: if package_layer_should_skip "homebrew"; then ...; fi
package_layer_should_skip() {
    local layer="$1"

    if [ -n "${CHEZMOI_SKIP_PACKAGE_UPDATES:-}" ]; then
        return 0
    fi

    local cache_file="${TMPDIR:-/tmp}/chezmoi-package-update-skip.${PPID}"
    _package_update_skip_load_or_prompt "$cache_file"

    local var_name
    var_name="SKIP_$(echo "$layer" | tr '[:lower:]' '[:upper:]')"
    [ "${!var_name:-0}" = "1" ]
}

# Reuse a fresh (< 1 hour old) cached decision, or resolve and cache a new one.
_package_update_skip_load_or_prompt() {
    local cache_file="$1"

    if [ -f "$cache_file" ]; then
        local mtime now age
        mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$(( now - mtime ))
        if [ "$age" -lt 3600 ]; then
            # shellcheck source=/dev/null
            source "$cache_file"
            return 0
        fi
    fi

    _package_update_skip_resolve_and_cache "$cache_file"
}

# Prompt (if a TTY is attached) or default to "run everything", then write the
# decision to the cache file so subsequent layer scripts in this apply run reuse it.
_package_update_skip_resolve_and_cache() {
    local cache_file="$1"
    local skip_homebrew=0 skip_sdkman=0 skip_uv=0 skip_bun=0 skip_cargo=0 skip_claude=0
    local skip_all=0

    if [ -t 0 ]; then
        local skip_reply="" selective_reply="" layer layer_reply

        read -r -p "⏭️  Skip ALL long-running package-update checks this run? (y/N): " skip_reply || skip_reply=""
        if [[ "$skip_reply" =~ ^[Yy]$ ]]; then
            skip_all=1
        else
            read -r -p "🎯 Selectively skip specific layers instead? (y/N): " selective_reply || selective_reply=""
            if [[ "$selective_reply" =~ ^[Yy]$ ]]; then
                for layer in homebrew sdkman uv bun cargo claude; do
                    layer_reply=""
                    read -r -p "   Skip ${layer} package updates this run? (y/N): " layer_reply || layer_reply=""
                    if [[ "$layer_reply" =~ ^[Yy]$ ]]; then
                        eval "skip_${layer}=1"
                    fi
                done
            fi
        fi
    fi

    if [ "$skip_all" = "1" ]; then
        skip_homebrew=1
        skip_sdkman=1
        skip_uv=1
        skip_bun=1
        skip_cargo=1
        skip_claude=1
    fi

    {
        echo "SKIP_HOMEBREW=$skip_homebrew"
        echo "SKIP_SDKMAN=$skip_sdkman"
        echo "SKIP_UV=$skip_uv"
        echo "SKIP_BUN=$skip_bun"
        echo "SKIP_CARGO=$skip_cargo"
        echo "SKIP_CLAUDE=$skip_claude"
    } > "$cache_file"

    # shellcheck source=/dev/null
    source "$cache_file"
}
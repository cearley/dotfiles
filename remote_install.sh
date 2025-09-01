#!/usr/bin/env sh

# Install remotely from single shell command
# Usage : sh -c "$(curl -fsSL https://raw.githubusercontent.com/cearley/dotfiles/remote_install.sh)"

set -e # -e: exit on error

case "$(uname -s)" in
    Darwin)
        # Determine architecture for Homebrew path
        if [ "$(uname -m)" = "arm64" ]; then
            HOMEBREW_PREFIX="/opt/homebrew"
        else
            HOMEBREW_PREFIX="/usr/local"
        fi

        # Check for Xcode Command Line Tools (required for git and compiler toolchain)
        if ! command -v git >/dev/null 2>&1 || ! command -v clang >/dev/null 2>&1; then
            echo "❌ Xcode Command Line Tools not found"
            echo "📋 Please install manually: xcode-select --install"
            echo "🔄 Then re-run this script"
            exit 1
        fi
        
        # Install Homebrew if not already installed
        if ! command -v brew >/dev/null 2>&1; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            (
                echo
                echo "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""
            ) >>"$HOME"/.zprofile
            eval "\$($HOMEBREW_PREFIX/bin/brew shellenv)"
            echo "Homebrew installed successfully!"
        fi
        
        # Install chezmoi via Homebrew if not already installed
        if ! command -v chezmoi >/dev/null 2>&1; then
            echo "Installing chezmoi via Homebrew..."
            brew install chezmoi
            echo "chezmoi installed successfully!"
        fi
        
        chezmoi=chezmoi
    ;;
    Linux)
        echo "Bootstrap for Linux is not implemented"
        exit 1
    ;;
    *)
        echo "unsupported OS"
        exit 1
    ;;
esac

# Replace current shell process with chezmoi, passing through all arguments
# This is more efficient than spawning a subprocess and ensures proper signal handling
exec "$chezmoi" "$@"

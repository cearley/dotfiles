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
        if ! test -x "$HOMEBREW_PREFIX/bin/brew"; then
            echo "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            (
                echo
                echo "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""
            ) >>"$HOME"/.zprofile
            eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
            echo "Homebrew installed successfully!"
        fi
        
        # Install chezmoi via Homebrew if not already installed
        if ! test -x "$HOMEBREW_PREFIX/bin/chezmoi"; then
            echo "Installing chezmoi via Homebrew..."
            brew install chezmoi
            echo "chezmoi installed successfully!"
        fi
        
        chezmoi="$HOMEBREW_PREFIX/bin/chezmoi"
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

# If REPO points at an existing local chezmoi source checkout (e.g. CI's
# own checkout of this repo), use it directly instead of letting chezmoi
# clone a fresh, disconnected copy. chezmoi only clones when it finds no
# Git repository at the source path, so an already-checked-out $REPO is
# used as-is.
if [ -n "${REPO:-}" ]; then
    set -- --source "$REPO" "$@"
fi

# Replace current shell process with chezmoi, passing through all arguments
# This is more efficient than spawning a subprocess and ensures proper signal handling
exec "$chezmoi" "$@"

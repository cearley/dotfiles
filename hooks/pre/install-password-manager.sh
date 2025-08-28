#!/usr/bin/env sh

# Exit immediately if keepassxc-cli is already in $PATH
type keepassxc-cli >/dev/null 2>&1 && exit

case "$(uname -s)" in
Darwin)
    # Check if Homebrew is installed
    if ! command -v brew >/dev/null 2>&1; then
        echo "Error: Homebrew is not installed. Please install Homebrew first."
        echo "Visit https://brew.sh for installation instructions."
        exit 1
    fi
    
    echo "Installing KeePassXC via Homebrew..."
    brew install --cask keepassxc
    ;;
Linux)
    echo "Installing keepassxc-cli on Linux is not implemented"
    exit 1
    ;;
*)
    echo "unsupported OS"
    exit 1
    ;;
esac

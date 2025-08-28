#!/usr/bin/env sh

# Exit immediately if brew is already in $PATH
command -v brew >/dev/null 2>&1 && exit

case "$(uname -s)" in
Darwin)
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    (
        echo
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    ) >>"$HOME"/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo "Homebrew installed successfully!"
    ;;
Linux)
    echo "Installing package manager on Linux is not implemented"
    exit 1
    ;;
*)
    echo "unsupported OS"
    exit 1
    ;;
esac
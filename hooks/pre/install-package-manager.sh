#!/usr/bin/env sh

# Exit immediately if brew is already in $PATH
command -v brew >/dev/null 2>&1 && exit

case "$(uname -s)" in
    Darwin)
        # Determine architecture for Homebrew path
        if [ "$(uname -m)" = "arm64" ]; then
            HOMEBREW_PREFIX="/opt/homebrew"
        else
            HOMEBREW_PREFIX="/usr/local"
        fi

        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        (
            echo
            echo "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\""
        ) >>"$HOME"/.zprofile
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
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
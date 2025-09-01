#!/bin/sh

# Install remotely from single shell command
# Usage : sh -c "$(curl -fsSL https://raw.githubusercontent.com/cearley/dotfiles/chezmoi/remote_install.sh)"

# Check for Xcode Command Line Tools to ensure `git` is available.
if ! command -v git >/dev/null 2>&1 || ! command -v clang >/dev/null 2>&1; then
    echo "❌ Xcode Command Line Tools not found"
    echo "📋 Please install manually: xcode-select --install"
    echo "🔄 Then re-run this script"
    exit 1
fi

set -e # -e: exit on error

if [ ! "$(command -v chezmoi)" ]; then
  bin_dir="$HOME/.local/bin"
  chezmoi="$bin_dir/chezmoi"
  if [ "$(command -v curl)" ]; then
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$bin_dir"
  elif [ "$(command -v wget)" ]; then
    sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$bin_dir"
  else
    echo "To install chezmoi, you must have curl or wget installed." >&2
    exit 1
  fi
else
  chezmoi=chezmoi
fi

# exec: replace current process with chezmoi with all provided arguments
# If no arguments provided, default to init --apply cearley --keep-going
if [ $# -eq 0 ]; then
  exec "$chezmoi" init --apply cearley --keep-going
else
  exec "$chezmoi" "$@"
fi

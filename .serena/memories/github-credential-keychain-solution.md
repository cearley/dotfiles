# GitHub Authentication: macOS Keychain Integration

## Problem

On fresh macOS installations, users were prompted for GitHub password on first `git push` despite having GitHub token stored in KeePassXC and configured in chezmoi templates.

**Root Cause:**
- Git credential helper was set to `cache` (temporary, in-memory storage)
- Token was never pre-populated into the credential store
- First Git operation requiring authentication triggered password prompt

## Solution (Implemented in Commit 54973b8)

Changed GitHub authentication to use macOS Keychain with automatic token pre-population.

### Changes Made

#### 1. Updated `home/.chezmoiscripts/run_onchange_after_darwin-45-setup-github-auth.sh.tmpl`

**Changed Lines 22-37 (setup_git_credentials function):**

**Before (commit 4566c8f):**
```bash
setup_git_credentials() {
    print_message "info" "Configuring git credential helper"
    
    # Set up git credential helper to cache credentials
    git config --global credential.helper cache
    
    # Configure git to use the token for GitHub
    git config --global credential.https://github.com.username "$GITHUB_USERNAME"
    
    print_message "success" "Git credential helper configured"
}
```

**After (commit 54973b8):**
```bash
setup_git_credentials() {
    print_message "info" "Configuring git credential helper"

    # Set up git credential helper to use macOS Keychain (persistent, secure storage)
    git config --global credential.helper osxkeychain

    # Configure git to use the token for GitHub
    git config --global credential.https://github.com.username "$GITHUB_USERNAME"

    # Pre-populate the GitHub token in macOS Keychain to avoid password prompt
    print_message "info" "Storing GitHub token in macOS Keychain"
    printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" \
        "$GITHUB_USERNAME" "$GITHUB_TOKEN" | git credential approve

    print_message "success" "Git credential helper configured and token stored in Keychain"
}
```

**Key Improvements:**
- Changed from `cache` to `osxkeychain` for persistent, encrypted storage
- Added `git credential approve` to pre-populate token in Keychain
- Token injected before first Git operation, preventing password prompt

#### 2. Updated `home/dot_gitconfig.tmpl`

**Line 5-6:**

**Before (commit 4566c8f):**
```toml
[credential]
	helper = cache
```

**After (commit 54973b8):**
```toml
[credential]
	helper = osxkeychain
```

### How It Works

1. **chezmoi applies configuration** → gitconfig sets `credential.helper = osxkeychain`
2. **Setup script runs** → Fetches token from KeePassXC via template
3. **Token pre-population** → Uses `git credential approve` to inject token into macOS Keychain
4. **Automatic updates** → `run_onchange_` tracks rendered script hash; token changes trigger re-run

### Benefits

- ✅ **Persistent storage:** Credentials survive reboots (unlike `cache`)
- ✅ **Secure:** Uses macOS Keychain encryption
- ✅ **No prompts:** Token pre-populated before first use
- ✅ **Automatic sync:** Token updates in KeePassXC → `chezmoi apply` → Keychain updated
- ✅ **Native integration:** Uses macOS-native credential management

### Reversion Instructions

To revert to previous behavior (if needed):

```bash
# Revert both files to pre-solution state
git checkout 4566c8f -- home/.chezmoiscripts/run_onchange_after_darwin-45-setup-github-auth.sh.tmpl
git checkout 4566c8f -- home/dot_gitconfig.tmpl

# Or revert the entire commit
git revert 54973b8
```

**Warning:** Reverting will restore the password prompt issue on fresh installations.

### Related Files

- `home/.chezmoiscripts/run_onchange_after_darwin-45-setup-github-auth.sh.tmpl` (authentication script)
- `home/dot_gitconfig.tmpl` (Git credential configuration)
- KeePassXC entry: "GitHub" → "Access Token" attribute

### References

- Commit introducing fix: `54973b8`
- Previous working version: `4566c8f`
- chezmoi `run_onchange_` documentation: hashes rendered template content

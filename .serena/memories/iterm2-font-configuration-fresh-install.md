# iTerm2 Font Configuration on Fresh Install

## Problem

When running chezmoi on a fresh macOS install, the PlistBuddy command to set iTerm2's default profile font to MesloLGSNF-Regular 13 appeared to execute without errors, but the font wasn't actually applied in iTerm2. When opening iTerm2 for the first time, the Default profile would fall back to a system default font instead.

### Root Cause

The issue occurred because:

1. Fonts are installed via Homebrew (`font-meslo-lg-nerd-font`) in `run_onchange_before_darwin-23-install-packages.sh.tmpl`
2. Fonts are placed in `~/Library/Fonts/` by Homebrew
3. **macOS font daemon (`fontd`) doesn't immediately register newly installed fonts**
4. PlistBuddy command runs in `run_once_after_darwin-85-configure-system-defaults.sh.tmpl` and successfully sets the font preference
5. **When iTerm2 launches for the first time, it can't find "MesloLGSNF-Regular" because fontd hasn't registered it yet**
6. iTerm2 falls back to a default font

### Timing Issue

The problem only manifests on fresh installs when:
- Fonts are installed for the first time
- Configuration happens immediately after
- No logout/restart has occurred
- fontd hasn't naturally refreshed its font cache

## Solution

Created `run_once_after_darwin-84-refresh-font-cache.sh.tmpl` to restart the font daemon after font installation, forcing it to re-scan and register newly installed fonts before the PlistBuddy configuration runs.

### Script Execution Order

```
23 → Install packages (includes fonts via Homebrew)
   ↓
84 → Refresh font cache (killall fontd - NEW SCRIPT)
   ↓
85 → Configure system defaults (PlistBuddy sets iTerm2 font)
```

### Implementation

```bash
{{- if eq .chezmoi.os "darwin" -}}
#!/bin/bash

source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"

print_message "info" "Refreshing font cache to register newly installed fonts..."

# Restart the font daemon (fontd) to re-scan installed fonts
# Killing fontd is safe - macOS will automatically respawn it
if killall fontd 2>/dev/null; then
    print_message "success" "Font daemon restarted - new fonts are now available"
    # Give fontd a moment to respawn and re-scan fonts
    sleep 2
else
    print_message "warning" "Font daemon not found or could not restart"
    print_message "info" "Fonts will be available after logout/login"
fi

{{ end -}}
```

### Technical Details

- **Uses `killall fontd`**: Simple, reliable, and safe
  - macOS automatically respawns fontd when killed
  - fontd re-scans font directories on startup
- **Why not `launchctl kickstart`**: Modern macOS blocks this for system services due to SIP (System Integrity Protection)
- **Why not `atsutil`**: Deprecated by Apple and warned against in documentation
- **2-second delay**: Gives fontd time to fully respawn and scan fonts
- **Error handling**: Shows fallback message if fontd restart fails

### PlistBuddy Font Configuration

The font is set in `run_once_after_darwin-85-configure-system-defaults.sh.tmpl`:

```bash
# iTerm2: Set default profile font to MesloLGSNF size 13
# Note: This requires iTerm2 to be quit first, otherwise changes may be overwritten
if pgrep -q "iTerm2"; then
    print_message "warning" "iTerm2 is running - font changes may not persist until restart"
fi

if /usr/libexec/PlistBuddy -c "Set 'New Bookmarks':0:'Normal Font' 'MesloLGSNF-Regular 13'" ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null; then
    print_message "success" "iTerm2 font set to MesloLGSNF-Regular 13"
else
    print_message "warning" "Could not set iTerm2 font (profile may not exist yet)"
fi
```

### Alternative Solution: Dynamic Profiles

An alternative approach using iTerm2's Dynamic Profiles feature is also available at:
`home/private_Library/private_Application Support/iTerm2/DynamicProfiles/DefaultProfile.json.tmpl`

Dynamic Profiles have advantages:
- Font resolution happens when iTerm2 launches, not during chezmoi apply
- No timing issues with font cache
- Officially supported by iTerm2
- Changes apply immediately without restarting iTerm2

However, Dynamic Profiles create a new profile instead of modifying the built-in Default profile.

## Key Learnings

### macOS Font Cache Management

1. **Font Installation Locations**:
   - `~/Library/Fonts/` - User-specific (default for Homebrew casks)
   - `/Library/Fonts/` - System-wide (requires `--fontdir=/Library/Fonts` flag)

2. **Font Registration**:
   - `fontd` daemon manages font registration on macOS
   - New fonts require fontd to be restarted or system logout/restart
   - Font cache is automatically rebuilt when fontd starts

3. **Safe Font Cache Refresh Methods**:
   - `killall fontd` - Safest and most reliable (automatic respawn)
   - `sudo atsutil databases -remove` + logout/restart (deprecated)
   - Safe boot (hold Shift during startup) - rebuilds all caches

4. **System Integrity Protection (SIP)**:
   - Modern macOS protects system services from `launchctl kickstart`
   - Font daemon (`fontd`) is SIP-protected
   - `killall` works because it doesn't require privileged operations

## Related Files

- Font installation: `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`
- Font cache refresh: `home/.chezmoiscripts/run_once_after_darwin-84-refresh-font-cache.sh.tmpl`
- iTerm2 configuration: `home/.chezmoiscripts/run_once_after_darwin-85-configure-system-defaults.sh.tmpl`
- Font package: `home/.chezmoidata/packages.yaml` (contains `font-meslo-lg-nerd-font`)
- Dynamic Profile alternative: `home/private_Library/private_Application Support/iTerm2/DynamicProfiles/DefaultProfile.json.tmpl`
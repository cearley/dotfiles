## REMOVED Requirements

### Requirement: Global Environment Variable Override
**Reason**: With only one gated prompt left in the system (Homebrew cask/mas installs), a global bypass env var is redundant surface area — answering "n" at that single prompt achieves the same thing, and unattended runs already skip by default with no TTY attached.
**Migration**: Remove any `CHEZMOI_SKIP_PACKAGE_UPDATES` usage from shell profiles, CI configs, or scripts. It has no effect; unattended applies now skip Homebrew cask/mas installs automatically (see `package-management`: "User Confirmation for Additional Packages"), and every other package layer always runs.

### Requirement: Per-Invocation Cached Decision
**Reason**: The `$PPID`-keyed cache file was intended to share one decision across scripts within a single `chezmoi apply` invocation, but macOS PID reuse let a stale decision from an earlier invocation silently apply to a later, unrelated run within the 1-hour TTL — the opposite of the intended "ask fresh each run" behavior. The new design has no cache at all: the one remaining prompt (Homebrew cask/mas) is asked fresh on every run.
**Migration**: None. The cache file (`${TMPDIR:-/tmp}/chezmoi-package-update-skip.$PPID`) is no longer written or read; any stale copies left on disk from prior runs are inert and safe to delete manually.

### Requirement: Two-Step Interactive Prompt
**Reason**: The "skip ALL / select specific layers" two-step flow existed to let a single decision fan out across six layers. With five of those six layers (SDKMAN, uv, Bun, Cargo, Claude) no longer gated at all, and Homebrew reduced to one cask/mas confirmation, there is nothing left to select between — a single yes/no question replaces the two-step flow.
**Migration**: None. Users see a single "Install casks/mas? (y/N)" style prompt per Homebrew script instead of the two-step selection flow.

### Requirement: Non-Interactive Default
**Reason**: This requirement defaulted every layer to "run" when no TTY was attached, to keep bootstrap/CI safe. The replacement behavior (see `package-management`: "User Confirmation for Additional Packages") intentionally defaults the opposite way for the one remaining prompt — no TTY means the cask/mas confirmation is silently declined, matching the pre-existing behavior of the machine-specific Brewfile prompt this mechanism was modeled on.
**Migration**: Any unattended/CI apply that previously relied on casks/mas installing without a TTY will now need an interactive run (or a manually-installed cask/mas set) to pick those up. Non-Homebrew layers are unaffected — they always run regardless of TTY.

### Requirement: Shared Layer-Check Helper
**Reason**: `package_layer_should_skip()` and its cache/prompt-resolution helpers existed to serve six layers uniformly. With only Homebrew casks/mas retaining a skip concept, a generic multi-layer helper is unneeded machinery — the two Homebrew scripts use a plain, uncached `read -p` confirmation instead (see `package-management`).
**Migration**: Any script sourcing `shared-utils.sh` and calling `package_layer_should_skip()` must remove that call; the function no longer exists. The five non-Homebrew scripts that used it now run unconditionally with no guard at all.

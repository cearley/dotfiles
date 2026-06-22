## 1. Core Helper Function

- [x] 1.1 Add `print_uninstall_hint(prefix, mode, orphans)` function to `home/scripts/audit-packages.sh`, above `report_orphans`, with UTF-8/non-UTF-8 prefix detection and `one_line`/`per_line` mode support
- [x] 1.2 Extend `report_orphans` with two optional parameters (`uninstall_prefix`, `uninstall_mode`; default empty/`one_line`) and call `print_uninstall_hint` when prefix is non-empty and orphans are found

## 2. Wire Hints — report_orphans Call Sites

- [x] 2.1 Pass `"brew uninstall" "one_line"` to the `audit_brews` call of `report_orphans`
- [x] 2.2 Pass `"brew uninstall --cask" "one_line"` to the `audit_casks` call of `report_orphans`
- [x] 2.3 Pass `"brew untap" "per_line"` to the `audit_taps` call of `report_orphans`
- [x] 2.4 Pass `"cargo uninstall" "one_line"` to the `audit_cargo` call of `report_orphans`
- [x] 2.5 Pass `"claude plugins uninstall" "per_line"` to the `audit_claude_plugins` call of `report_orphans`
- [x] 2.6 Pass `"claude plugins marketplace remove" "per_line"` to the `audit_claude_marketplaces` call of `report_orphans`
- [x] 2.7 Pass `"claude mcp remove" "per_line"` to the `audit_claude_mcp_servers` call of `report_orphans`

## 3. Wire Hints — Custom Audit Sections

- [x] 3.1 In `audit_uv`: call `print_uninstall_hint "uv tool uninstall" "one_line" "$orphans"` after counting orphans
- [x] 3.2 In `audit_bun`: call `print_uninstall_hint "bun remove -g" "one_line" "$orphans"` after counting orphans
- [x] 3.3 In `audit_sdkman`: accumulate orphans in a `sdkman_orphans` variable during the loop; call `print_uninstall_hint "sdk uninstall" "per_line" "$sdkman_orphans"` in the `has_orphans` branch
- [x] 3.4 In `audit_claude_skills`: extract clean orphan list to a `clean_orphans` variable; call `print_uninstall_hint "claude skills remove" "per_line" "$clean_orphans"` after counting

## 4. Spec Update

- [x] 4.1 Verify `openspec/changes/audit-packages-uninstall-hints/specs/package-audit/spec.md` accurately describes the implemented behavior (hint format, mode per manager, stderr channel, UTF-8 fallback)

## 5. Verification

- [x] 5.1 Run `audit-packages` and confirm a 💡 hint appears after each section with orphans
- [x] 5.2 Confirm sections with no orphans show no hint
- [x] 5.3 Confirm `audit-packages 2>/dev/null` suppresses hints while preserving orphan names on stdout
- [x] 5.4 Confirm `audit-packages | cat` shows only orphan names (hints on stderr, not captured)

# Implementation Tasks

## Phase 1: Create New Template

### Task 1.1: Implement machine-settings template
**Description:** Create new `home/.chezmoitemplates/machine-settings` template that returns all machine settings as JSON.

**Implementation:**
- Use `machine-config` with `return_key: true` to get matched machine pattern
- Iterate over machines.yaml to find matching machine
- Build dict with all machine properties
- Add special `_machine_key` property
- Return JSON-encoded dict via `toJson`

**Validation:**
```bash
# Should output JSON dict with all properties for current machine
chezmoi execute-template < home/.chezmoitemplates/machine-settings
```

**Acceptance Criteria:**
- Template executes without errors
- Output is valid JSON
- Contains all properties from machines.yaml for matched machine
- Includes `_machine_key` property
- Returns `{}` when no machine matches

---

### Task 1.2: Test machine-settings template across all machines
**Description:** Verify template works correctly for all defined machines.

**Implementation:**
- Manually test output for each machine pattern in machines.yaml
- Verify nested properties are preserved
- Confirm empty dict returned when pattern doesn't match

**Validation:**
```bash
# Test with different computer names (may need to temporarily modify computer-name template)
# Or inspect JSON output manually
chezmoi execute-template < home/.chezmoitemplates/machine-settings | jq .
```

**Acceptance Criteria:**
- All machine patterns return correct settings
- Nested structures (e.g., keepassxc_entries) preserved
- No template execution errors
- JSON is well-formed

---

## Phase 2: Update Call Sites

### Task 2.1: Update Brewfile symlink template
**Description:** Update `home/symlink_Brewfile.tmpl` to use `machine-settings`.

**Current:**
```go-template
{{- $brewfilePath := includeTemplate "machine-brewfile-path" . -}}
```

**New:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- if $settings.brewfile -}}
{{- printf "%s/brewfiles/%s" .chezmoi.sourceDir $settings.brewfile -}}
{{- end -}}
```

**Validation:**
```bash
# Should show same Brewfile path as before
cat home/symlink_Brewfile.tmpl | chezmoi execute-template
```

**Acceptance Criteria:**
- Template executes without errors
- Output path identical to previous implementation
- Symlink resolves to correct Brewfile

---

### Task 2.2: Update brew-bundle-install script
**Description:** Update `home/.chezmoiscripts/run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl` to use `machine-settings`.

**Current:**
```go-template
{{ $brewfilePath := includeTemplate "machine-brewfile-path" . }}
```

**New:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- if $settings.brewfile -}}
{{ $brewfilePath := printf "%s/brewfiles/%s" .chezmoi.sourceDir $settings.brewfile }}
{{- end -}}
```

**Validation:**
```bash
# Should show same script output as before
cat home/.chezmoiscripts/run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl | chezmoi execute-template
```

**Acceptance Criteria:**
- Script template executes without errors
- Brewfile path variable correct
- Script logic unchanged

---

### Task 2.3: Update SSH private key template
**Description:** Update `home/private_dot_ssh/private_id_ed25519.tmpl` to use `machine-settings`.

**Current:**
```go-template
{{ $sshEntryName := includeTemplate "machine-keepassxc-entry" (merge (dict "entry" "ssh") .) }}
```

**New:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{ $sshEntryName := $settings.keepassxc_entries.ssh }}
```

**Validation:**
```bash
# Should retrieve same KeePassXC entry name
chezmoi execute-template < home/private_dot_ssh/private_id_ed25519.tmpl | head -n 5
```

**Acceptance Criteria:**
- Template executes without errors
- SSH entry name correct
- KeePassXC attribute retrieval works

---

### Task 2.4: Update SSH known_hosts template
**Description:** Update `home/private_dot_ssh/known_hosts.tmpl` to use `machine-settings`.

**Current:**
```go-template
{{ $sshEntryName := includeTemplate "machine-keepassxc-entry" (merge (dict "entry" "ssh") .) }}
```

**New:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{ $sshEntryName := $settings.keepassxc_entries.ssh }}
```

**Validation:**
```bash
# Should generate same known_hosts content
chezmoi execute-template < home/private_dot_ssh/known_hosts.tmpl
```

**Acceptance Criteria:**
- Template executes without errors
- SSH entry name correct
- File content unchanged

---

### Task 2.5: Update SSH public key template
**Description:** Update `home/private_dot_ssh/id_ed25519.pub.tmpl` to use `machine-settings`.

**Current:**
```go-template
{{ $sshEntryName := includeTemplate "machine-keepassxc-entry" (merge (dict "entry" "ssh") .) }}
```

**New:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{ $sshEntryName := $settings.keepassxc_entries.ssh }}
```

**Validation:**
```bash
# Should generate same public key content
chezmoi execute-template < home/private_dot_ssh/id_ed25519.pub.tmpl
```

**Acceptance Criteria:**
- Template executes without errors
- SSH entry name correct
- Public key content unchanged

---

## Phase 3: Integration Testing

### Task 3.1: Dry-run validation
**Description:** Verify no unexpected changes in dry-run mode.

**Implementation:**
```bash
# Capture current state
chezmoi apply --dry-run > /tmp/before_simplify.txt

# Apply all template changes
# ... (after completing Phase 2)

# Compare dry-run output
chezmoi apply --dry-run > /tmp/after_simplify.txt
diff /tmp/before_simplify.txt /tmp/after_simplify.txt
```

**Acceptance Criteria:**
- No differences in dry-run output
- All managed files show correct target state
- No template execution errors

---

### Task 3.2: Verify Brewfile symlink resolution
**Description:** Ensure Brewfile symlink points to correct machine-specific file.

**Implementation:**
```bash
ls -la ~/Brewfile
# Should point to correct brewfile in source directory
```

**Acceptance Criteria:**
- Symlink exists
- Points to correct machine-specific Brewfile
- Brewfile path matches machine configuration

---

### Task 3.3: Verify SSH key template execution
**Description:** Ensure SSH key templates can still retrieve KeePassXC entries.

**Implementation:**
```bash
# Test SSH key retrieval (won't actually create files, just test template)
chezmoi execute-template < home/private_dot_ssh/private_id_ed25519.tmpl > /dev/null
echo "Exit code: $?"  # Should be 0
```

**Acceptance Criteria:**
- Templates execute without errors
- KeePassXC entries correctly retrieved
- SSH key content properly formatted

---

## Phase 4: Cleanup

### Task 4.1: Remove machine-brewfile-path template
**Description:** Delete `home/.chezmoitemplates/machine-brewfile-path` as it's no longer used.

**Implementation:**
```bash
rm home/.chezmoitemplates/machine-brewfile-path
```

**Validation:**
```bash
# Ensure no remaining references
rg "machine-brewfile-path" home/
# Should return no results
```

**Acceptance Criteria:**
- File deleted
- No remaining references in codebase
- chezmoi apply still works

---

### Task 4.2: Remove machine-keepassxc-entry template
**Description:** Delete `home/.chezmoitemplates/machine-keepassxc-entry` as it's no longer used.

**Implementation:**
```bash
rm home/.chezmoitemplates/machine-keepassxc-entry
```

**Validation:**
```bash
# Ensure no remaining references
rg "machine-keepassxc-entry" home/
# Should return no results
```

**Acceptance Criteria:**
- File deleted
- No remaining references in codebase
- chezmoi apply still works

---

### Task 4.3: Remove machine-key-name template
**Description:** Delete `home/.chezmoitemplates/machine-key-name` as it's no longer used.

**Implementation:**
```bash
rm home/.chezmoitemplates/machine-key-name
```

**Validation:**
```bash
# Ensure no remaining references
rg "machine-key-name" home/
# Should return no results
```

**Acceptance Criteria:**
- File deleted
- No remaining references in codebase
- chezmoi apply still works

---

## Phase 5: Documentation

### Task 5.1: Update openspec machine-config spec
**Description:** Apply spec delta to `openspec/specs/machine-config/spec.md`.

**Implementation:**
- Remove old convenience wrapper requirement scenarios
- Add new machine-settings requirement and scenarios
- Update design decisions section
- Add usage examples for new pattern

**Acceptance Criteria:**
- Spec accurately reflects new architecture
- All scenarios are testable
- Examples are clear and correct

---

### Task 5.2: Update project.md architecture section
**Description:** Update `openspec/project.md` to document new machine configuration approach.

**Changes Required:**
- Update "Machine Configuration System" section (lines 119-143)
- Change "Convenience wrappers" to "Machine Settings Template"
- Update example from line 126-142

**New Example:**
```yaml
# Adding new properties still works automatically:
MacBook Pro:
  brewfile: mbp-brewfile
  keepassxc_entries:
    ssh: SSH (MacBook Pro)
  # Access via: $settings.ssh_key_id
  ssh_key_id: macbook_ed25519
```

**Acceptance Criteria:**
- Architecture section accurate
- Examples updated
- No outdated references to removed templates

---

### Task 5.3: Update machine-settings template documentation
**Description:** Ensure `machine-settings` template has comprehensive inline documentation.

**Documentation Should Include:**
- Purpose and usage
- Parameter expectations (none)
- Return value format (JSON dict)
- Property access examples
- Special `_machine_key` property explanation
- Empty dict handling

**Acceptance Criteria:**
- Template header comment is comprehensive
- Examples are clear and correct
- Edge cases documented

---

## Phase 6: Final Validation

### Task 6.1: Full system test
**Description:** Run complete chezmoi apply and verify system state.

**Implementation:**
```bash
# Clean apply
chezmoi apply --verbose

# Verify key files
ls -la ~/Brewfile
ls -la ~/.ssh/id_ed25519
ls -la ~/.ssh/id_ed25519.pub
ls -la ~/.ssh/known_hosts

# Verify no errors in chezmoi state
chezmoi verify
```

**Acceptance Criteria:**
- All files applied successfully
- No template execution errors
- File contents correct
- Symlinks valid

---

### Task 6.2: Validate with OpenSpec
**Description:** Run OpenSpec validation to ensure change spec is complete and correct.

**Implementation:**
```bash
openspec validate simplify-machine-templates --strict
```

**Acceptance Criteria:**
- Validation passes with no errors
- All requirements have scenarios
- All scenarios are testable
- No orphaned or incomplete requirements

---

## Task Dependencies

```
Phase 1 (Create)
  └─→ Task 1.1 → Task 1.2

Phase 2 (Update) - Can run in parallel after Phase 1
  └─→ Task 2.1
  └─→ Task 2.2
  └─→ Task 2.3
  └─→ Task 2.4
  └─→ Task 2.5

Phase 3 (Integration) - After Phase 2
  └─→ Task 3.1 → Task 3.2, Task 3.3

Phase 4 (Cleanup) - After Phase 3
  └─→ Task 4.1, Task 4.2, Task 4.3 (parallel)

Phase 5 (Documentation) - Can start after Phase 2
  └─→ Task 5.1
  └─→ Task 5.2
  └─→ Task 5.3 (parallel with 5.1, 5.2)

Phase 6 (Final) - After all phases
  └─→ Task 6.1 → Task 6.2
```

## Parallelization Opportunities

- **Phase 2 tasks** (2.1-2.5): All can run in parallel
- **Phase 4 tasks** (4.1-4.3): All can run in parallel
- **Phase 5 tasks** (5.1-5.3): Can run in parallel
- **Phase 2 and Phase 5**: Phase 5 can start as soon as Phase 2 is done (don't need to wait for Phase 3)

## Rollback Plan

If issues are discovered:
1. Revert all Phase 2 changes (restore old template calls)
2. Restore deleted templates from Phase 4 (from git)
3. Remove machine-settings template
4. Verify system returns to working state

All changes are reversible via git.

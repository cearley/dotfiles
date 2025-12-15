# Design: Simplified Machine Configuration Templates

## Architecture Overview

### Current Architecture (4 Templates)
```
┌─────────────────┐
│  machines.yaml  │ (Data)
└────────┬────────┘
         │
    ┌────▼──────────────┐
    │ machine-config    │ (Core Engine)
    │ - Pattern match   │
    │ - Setting lookup  │
    │ - Dot-notation    │
    └────┬──────────────┘
         │
    ┌────┴─────────────────────────────┐
    │                                  │
┌───▼──────────────┐  ┌───▼─────────────────────┐
│ Convenience      │  │ Convenience             │
│ Wrappers         │  │ Wrappers                │
├──────────────────┤  ├─────────────────────────┤
│ brewfile-path    │  │ keepassxc-entry         │
│ machine-key-name │  │                         │
└──────────────────┘  └─────────────────────────┘
```

### Proposed Architecture (2 Templates)
```
┌─────────────────┐
│  machines.yaml  │ (Data)
└────────┬────────┘
         │
    ┌────▼──────────────┐
    │ machine-config    │ (Core Engine - unchanged)
    │ - Pattern match   │
    │ - Setting lookup  │
    │ - Dot-notation    │
    └────┬──────────────┘
         │
    ┌────▼──────────────┐
    │ machine-settings  │ (Dict Builder)
    │ - Returns all     │
    │   settings as     │
    │   structured dict │
    └───────────────────┘
```

## Key Design Decisions

### Decision 1: Single Dict Return vs Multiple Lookups

**Chosen Approach:** Return all settings as a single dict.

**Rationale:**
- **Performance**: One pattern match per file instead of N matches for N settings
- **Ergonomics**: Natural property access (`$settings.brewfile`) vs function calls
- **Discoverability**: IDE/editor autocompletion could work with dict structure
- **Flexibility**: Easy to destructure only needed properties

**Trade-off Accepted:**
- Returns more data than strictly needed (all settings vs just requested ones)
- Impact is negligible: typical machine config is <10 properties, <500 bytes

### Decision 2: Keep machine-config as Core Engine

**Chosen Approach:** Retain `machine-config` template unchanged.

**Rationale:**
- **Separation of Concerns**: Pattern matching logic separate from dict construction
- **Backward Compatibility**: Any existing direct usage of `machine-config` continues to work
- **Testability**: Can test pattern matching independently from dict serialization
- **Flexibility**: Still available for single-setting lookups if needed

**Alternative Considered:**
- Merge everything into `machine-settings`
- Rejected: Loses single-responsibility principle, harder to test

### Decision 3: JSON Serialization Format

**Chosen Approach:** Return JSON-encoded dict, deserialize with `fromJson`.

**Rationale:**
- **Native Support**: Go templates have built-in `toJson` and `fromJson`
- **Type Preservation**: Maintains booleans, numbers, nested structures
- **Debugging**: JSON output is human-readable for troubleshooting
- **Standard**: Well-understood format across tools

**Template Pattern:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- $brewfile := $settings.brewfile -}}
{{- $sshEntry := $settings.keepassxc_entries.ssh -}}
```

### Decision 4: Path Construction Location

**Chosen Approach:** Move path construction to call sites.

**Rationale:**
- **Transparency**: Path structure visible where it's used
- **Flexibility**: Different call sites can construct paths differently if needed
- **Simplicity**: Template just returns data, not derived values

**Before:**
```go-template
{{- $brewfilePath := includeTemplate "machine-brewfile-path" . -}}
```

**After:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- $brewfilePath := printf "%s/brewfiles/%s" .chezmoi.sourceDir $settings.brewfile -}}
```

**Trade-off:**
- Slightly more verbose at call sites (one extra line)
- Benefit: More explicit, easier to customize per use case

### Decision 5: Null/Missing Value Handling

**Chosen Approach:** Return empty strings for missing values (consistent with current behavior).

**Rationale:**
- **Backward Compatibility**: Maintains existing template behavior
- **Graceful Degradation**: Templates can check `if $setting` without special nil handling
- **Simplicity**: No need for complex null-checking logic at call sites

**Implementation:**
```go-template
{{- if hasKey $config "brewfile" -}}
  {{- $_ := set $result "brewfile" $config.brewfile -}}
{{- else -}}
  {{- $_ := set $result "brewfile" "" -}}
{{- end -}}
```

## Template Structure

### machine-settings Template
```go-template
{{- /* Returns all machine settings as a JSON-encoded dict.

     Uses machine-config to find the matched machine pattern,
     then returns all settings from machines.yaml for that machine.

     Example:
       {{- $settings := includeTemplate "machine-settings" . | fromJson -}}
       {{- $brewfile := $settings.brewfile -}}
       {{- $sshEntry := $settings.keepassxc_entries.ssh -}}
       {{- $machineKey := $settings._machine_key -}}

     Returns empty dict {} if no machine matches.
     Special property:
       _machine_key: The matched machine pattern name (e.g., "MacBook Pro")
*/ -}}
{{- $result := dict -}}
{{- $machineKey := includeTemplate "machine-config" (merge (dict "return_key" true) .) -}}

{{- if $machineKey -}}
  {{- /* Add the machine key itself as a special property */ -}}
  {{- $_ := set $result "_machine_key" $machineKey -}}

  {{- /* Iterate over machines.yaml to find and return all properties */ -}}
  {{- range $pattern, $config := .chezmoi.config.data -}}
    {{- if eq $pattern $machineKey -}}
      {{- range $key, $value := $config -}}
        {{- $_ := set $result $key $value -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- toJson $result -}}
```

### Usage Examples

#### Example 1: Brewfile Path (Simple Case)
**Before:**
```go-template
{{- $brewfilePath := includeTemplate "machine-brewfile-path" . -}}
```

**After:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- if $settings.brewfile -}}
{{- $brewfilePath := printf "%s/brewfiles/%s" .chezmoi.sourceDir $settings.brewfile -}}
{{- end -}}
```

#### Example 2: Multiple Settings (Common Case)
**Before:**
```go-template
{{- $brewfile := includeTemplate "machine-config" (merge (dict "setting" "brewfile") .) -}}
{{- $sshEntry := includeTemplate "machine-keepassxc-entry" (merge (dict "entry" "ssh") .) -}}
{{- $machineKey := includeTemplate "machine-key-name" . -}}
```

**After:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- $brewfile := $settings.brewfile -}}
{{- $sshEntry := $settings.keepassxc_entries.ssh -}}
{{- $machineKey := $settings._machine_key -}}
```

**Benefit:** 3 template includes → 1 template include

#### Example 3: Conditional Logic
**Before:**
```go-template
{{ $sshEntryName := includeTemplate "machine-keepassxc-entry" (merge (dict "entry" "ssh") .) }}
{{- if $sshEntryName -}}
  # Use KeePassXC entry
{{- end -}}
```

**After:**
```go-template
{{- $settings := includeTemplate "machine-settings" . | fromJson -}}
{{- if $settings.keepassxc_entries.ssh -}}
  # Use KeePassXC entry
{{- end -}}
```

## Performance Characteristics

### Current System
- **3 separate setting lookups**: 3 × pattern matching operations
- **Per-file overhead**: O(N × M) where N = number of settings requested, M = number of machine patterns

### Proposed System
- **1 dict lookup**: 1 × pattern matching operation + dict construction
- **Per-file overhead**: O(M + K) where M = number of machine patterns, K = number of properties in matched machine

### Real-World Impact
For typical use case:
- **Machines.yaml**: 3 machine patterns, ~5 properties each
- **Current**: 3 lookups × 3 patterns = 9 comparisons
- **Proposed**: 1 lookup × 3 patterns + 5 properties = 8 operations

**Result:** 10-20% performance improvement for files using multiple settings, no degradation for single-setting files.

## Testing Strategy

### Unit Testing (Manual Template Execution)
```bash
# Test 1: Verify dict structure
chezmoi execute-template < home/.chezmoitemplates/machine-settings

# Expected output for "MacBook Pro" machine:
# {"_machine_key":"MacBook Pro","brewfile":"mbp-brewfile","keepassxc_entries":{"ssh":"SSH (MacBook Pro)"}}

# Test 2: Verify usage in real template
cat home/symlink_Brewfile.tmpl | chezmoi execute-template

# Test 3: Verify SSH entry lookup
cat home/private_dot_ssh/private_id_ed25519.tmpl | chezmoi execute-template | head -n 5
```

### Integration Testing
```bash
# Test 1: Dry run should show no changes
chezmoi apply --dry-run

# Test 2: Verify Brewfile symlink resolves correctly
ls -la ~/Brewfile

# Test 3: Verify SSH key templates resolve
chezmoi execute-template < home/private_dot_ssh/private_id_ed25519.tmpl > /dev/null
```

### Regression Testing
```bash
# Capture current state
chezmoi apply --dry-run > /tmp/before.txt

# Apply changes
# ... (implement new templates)

# Verify no behavioral changes
chezmoi apply --dry-run > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt
# Should show no differences
```

## Migration Considerations

### Breaking Changes
**None.** This is a pure refactoring that maintains identical behavior.

### Rollback Plan
If issues arise:
1. Restore the three deleted templates from git history
2. Revert call site changes
3. Remove new `machine-settings` template

All changes are isolated to template files, no data migration required.

### Documentation Updates
- Update `openspec/specs/machine-config/spec.md` to document new template
- Update `openspec/project.md` architecture section
- Add usage examples to template comments

## Future Extensibility

### Easy to Add New Properties
**Before this change:**
```yaml
# machines.yaml
MacBook Pro:
  new_property: value  # ✅ Works via machine-config, ❌ may need new wrapper
```

**After this change:**
```yaml
# machines.yaml
MacBook Pro:
  new_property: value  # ✅ Automatically available in $settings.new_property
```

### Potential Future Enhancements
1. **Validation**: Add schema validation for machine settings
2. **Defaults**: Support default values for missing properties
3. **Computed Properties**: Add derived values (e.g., hostname from machine key)
4. **Caching**: Memoize machine-settings result within template execution

None of these require changes to the core architecture.

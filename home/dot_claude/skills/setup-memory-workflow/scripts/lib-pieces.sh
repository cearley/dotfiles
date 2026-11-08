# shellcheck shell=bash
# lib-pieces.sh — sourced by check-drift.sh. Generic engines for templated-file
# and hook-command pieces. No memory-content logic here.

render() {
  local content; content=$(cat "$1")
  content=${content//__PROJECT__/$PROJECT}
  content=${content//__SMW_VERSION__/$SMW_VERSION}
  printf '%s\n' "$content"
}

# ---- templated-file piece engine ----
piece_status() {
  local installed="$1" template="$2" executable="${3:-no}"
  if [ ! -f "$installed" ]; then
    render "$template" > "$installed"
    [ "$executable" = "yes" ] && chmod +x "$installed"
    echo "CREATED"; return
  fi
  local marker name_match
  marker=$(grep -o 'setup-memory-workflow-version:[0-9]*' "$installed" | grep -o '[0-9]*$' || true)
  name_match=$(grep -qF "$PROJECT" "$installed" && echo yes || echo no)
  if [ "$name_match" = "no" ]; then
    echo "NAME-MISMATCH"
  elif [ "$marker" = "$SMW_VERSION" ]; then
    echo "UP-TO-DATE"
  else
    echo "DRIFT"
  fi
}
apply_templated_file() {
  local installed="$1" template="$2" executable="${3:-no}"
  render "$template" > "$installed"
  [ "$executable" = "yes" ] && chmod +x "$installed"
  echo "APPLIED: $installed"
}
report_templated_piece() {
  local installed="$1" template="$2" executable="${3:-no}" status
  status=$(piece_status "$installed" "$template" "$executable")
  case "$status" in
    CREATED) echo "CREATED: $installed" ;;
    UP-TO-DATE) echo "UP-TO-DATE: $installed" ;;
    DRIFT)
      local marker
      marker=$(grep -o 'setup-memory-workflow-version:[0-9]*' "$installed" | grep -o '[0-9]*$' || true)
      echo "DRIFT (version ${marker:-none} -> $SMW_VERSION): $installed"; echo "  fix with: check-drift.sh update"
      echo "--- current ---"; cat "$installed"
      echo "--- canonical ---"; render "$template"
      ;;
    NAME-MISMATCH)
      echo "NAME-MISMATCH: $installed does not refer to \"$PROJECT\" — was this directory renamed, or the override file changed?"
      echo "  never auto-repaired; fix with: check-drift.sh apply <piece>  (only after confirming this is intentional)"
      ;;
  esac
}
update_templated_piece() {
  local piece_name="$1" installed="$2" template="$3" executable="${4:-no}" status
  status=$(piece_status "$installed" "$template" "$executable")
  case "$status" in
    DRIFT) apply_templated_file "$installed" "$template" "$executable" ;;
    NAME-MISMATCH) echo "SKIPPED (NAME-MISMATCH — use 'apply $piece_name' after confirming): $installed" ;;
    CREATED) echo "CREATED: $installed" ;;
    UP-TO-DATE) ;;
  esac
}

# ---- hook-command piece engine (no $PROJECT; no NAME-MISMATCH) ----
_hook_append() {
  local settings_file="$1" event="$2" matcher="$3" cmd="$4"
  jq --arg ev "$event" --arg mt "$matcher" --arg cmd "$cmd" \
    '.hooks[$ev] += [{"matcher": $mt, "hooks": [{"type": "command", "command": $cmd}]}]' \
    "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
}
hook_piece_status() {
  local settings_file="$1" event="$2" matcher="$3" match_substr="$4" canonical_cmd="$5" existing_cmd
  existing_cmd=$(jq -r --arg ev "$event" --arg m "$match_substr" \
    '[.hooks[$ev][]?.hooks[]?.command // empty] | map(select(contains($m)))[0] // empty' "$settings_file")
  if [ -z "$existing_cmd" ]; then
    _hook_append "$settings_file" "$event" "$matcher" "$canonical_cmd"; echo "CREATED"
  elif [ "$existing_cmd" = "$canonical_cmd" ]; then
    echo "UP-TO-DATE"
  else
    echo "DRIFT"
  fi
}
hook_piece_apply() {
  local settings_file="$1" event="$2" matcher="$3" match_substr="$4" canonical_cmd="$5"
  [ -f "$settings_file" ] || echo '{}' > "$settings_file"
  if jq -e --arg ev "$event" --arg m "$match_substr" \
    '[.hooks[$ev][]?.hooks[]?.command // empty] | map(select(contains($m))) | length > 0' \
    "$settings_file" >/dev/null 2>&1; then
    jq --arg ev "$event" --arg m "$match_substr" --arg cmd "$canonical_cmd" '
      .hooks[$ev] |= map(.hooks |= map(if (.command // "" | contains($m)) then .command = $cmd else . end))
    ' "$settings_file" > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
  else
    _hook_append "$settings_file" "$event" "$matcher" "$canonical_cmd"
  fi
  echo "APPLIED: $settings_file"
}

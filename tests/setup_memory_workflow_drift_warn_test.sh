#!/usr/bin/env bash
# bashunit coverage for check_drift_warn (lib-drift-warn.sh), extracted out
# of executable_check-drift.sh's cmd_drift_warn so SessionStart can call it
# in-process from executable_session-reminder.sh instead of exec'ing
# check-drift.sh as a second subprocess (fix-save-session-redundancy).
# Asserts the standalone `check-drift.sh drift-warn` entry point keeps its
# exact pre-refactor output: both warnings on stderr, nothing on stdout,
# exit 0 regardless.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_DRIFT="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh"

function set_up() {
    SCRATCH="$(bashunit::temp_dir)"
    mkdir -p "$SCRATCH/proj/.claude/skills/save-session"
    # Canonicalize: consent_status compares the stored repository_root against
    # `pwd -P`, which resolves /var -> /private/var on macOS.
    PROJECT_DIR="$(cd "$SCRATCH/proj" && pwd -P)"
    cat >"$PROJECT_DIR/.claude/skills/save-session/SKILL.md" <<'EOF'
<!-- setup-memory-workflow-version:20 -->
<!-- setup-memory-workflow-project:proj -->
EOF
}

function write_consent() {
    local automatic="$1"
    cat >"$PROJECT_DIR/.basic-memory-workflow.json" <<EOF
{"version":1,"project":"proj","repository_root":"$PROJECT_DIR","automatic_recording":$automatic,"granted_at":"2026-01-01T00:00:00Z"}
EOF
}

function run_drift_warn() {
    (cd "$PROJECT_DIR" && HOME="$SCRATCH" bash "$CHECK_DRIFT" drift-warn)
}

function test_outdated_version_and_revoked_consent_warns_on_stderr_only() {
    write_consent false
    local out err ec=0
    out=$(run_drift_warn 2>"$SCRATCH/err") || ec=$?
    err=$(cat "$SCRATCH/err")
    assert_same "0" "$ec"
    assert_empty "$out"
    assert_contains "save-session v20" "$err"
    assert_contains "Automatic recording disabled: REVOKED" "$err"
}

function test_granted_consent_only_warns_about_version() {
    write_consent true
    local out err ec=0
    out=$(run_drift_warn 2>"$SCRATCH/err") || ec=$?
    err=$(cat "$SCRATCH/err")
    assert_same "0" "$ec"
    assert_empty "$out"
    assert_contains "save-session v20" "$err"
    assert_not_contains "Automatic recording disabled" "$err"
}

function test_missing_installed_skill_warns_about_nothing() {
    rm -f "$PROJECT_DIR/.claude/skills/save-session/SKILL.md"
    local out err ec=0
    out=$(run_drift_warn 2>"$SCRATCH/err") || ec=$?
    err=$(cat "$SCRATCH/err")
    assert_same "0" "$ec"
    assert_empty "$out"
    assert_empty "$err"
}

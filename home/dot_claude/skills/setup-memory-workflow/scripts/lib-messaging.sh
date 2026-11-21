# shellcheck shell=bash
# lib-messaging.sh — sourced by check-drift.sh before any other lib.
# home/scripts/shared-utils.sh is never deployed (home/.chezmoiignore.tmpl ignores
# scripts/), so this deployed, non-templated script can't source it; inline the
# two functions it actually needs instead.
print_message() {
    local level="$1"
    local message="$2"
    local icon ascii
    case "$level" in
        "info")
            icon="🔵"
            ascii="[INFO]"
            ;;
        "success")
            icon="✅"
            ascii="[SUCCESS]"
            ;;
        "warning")
            icon="⚠️ "
            ascii="[WARNING]"
            ;;
        "error")
            icon="❌"
            ascii="[ERROR]"
            ;;
        "skip")
            icon="⏭️"
            ascii="[SKIP]"
            ;;
        "tip")
            icon="💡"
            ascii="[TIP]"
            ;;
        *) return ;;
    esac
    if [ "${LANG}" != "${LANG%UTF-8*}" ]; then
        echo "$icon $message" >&2
    else
        echo "$ascii $message" >&2
    fi
}
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

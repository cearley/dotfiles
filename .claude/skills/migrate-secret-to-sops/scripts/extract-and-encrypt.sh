#!/usr/bin/env bash
# Extracts one or more secrets from KeePassXC and encrypts them with sops in
# one pipeline, so plaintext never touches disk. Requires the KeePassXC
# master password interactively — run this yourself, it cannot be run
# non-interactively.
#
# Usage:
#   extract-and-encrypt.sh attachment <db> <entry> <attachment-name> <target-sops-path> [type]
#   extract-and-encrypt.sh attribute  <db> <entry> <attribute-name>  <target-sops-path> [type]
#   extract-and-encrypt.sh combine    <db> <target-sops-path> <type> <path>=<entry>:<attribute> [<path>=<entry>:<attribute> ...]
#
# <type> is a sops --input-type/--output-type value: binary (default for the
# single-value modes), json, yaml, dotenv, or ini. Use a structured type only
# if the plaintext is genuinely structured data you want partial-value (not
# whole-file) encryption for.
#
# The `combine` mode builds one structured JSON document out of several
# attribute lookups — use it whenever a consolidated secrets file needs more
# than one value (e.g. several KeePassXC entries feeding one profile-keyed
# credentials file). <path> is a dot-separated key path into the resulting
# JSON object, e.g. "di-dev.aws_access_key_id"; nested paths build nested
# objects. Only attribute lookups are supported in combine mode (attachments
# are whole files, not individual field values, so they don't compose the
# same way). Example:
#   extract-and-encrypt.sh combine "$HOME/Sync/data2.kdbx" \
#     home/dot_aws/credentials.json.sops json \
#     "di-dev.aws_access_key_id=AWS (DI Dev):aws_access_key_id" \
#     "di-dev.aws_secret_access_key=AWS (DI Dev):aws_secret_access_key" \
#     "ces.aws_access_key_id=AWS (CES):aws_access_key_id"
#
# --filename-override is required here: sops's .sops.yaml creation rules match
# against the file path given as an argument, not the shell redirect target.
# Piping through /dev/stdin gives sops no real filename to match, so without
# --filename-override this fails with "no matching creation rules found".

set -euo pipefail

usage() {
    echo "usage: $0 {attachment|attribute} <db> <entry> <name> <target-sops-path> [type]" >&2
    echo "       $0 combine <db> <target-sops-path> <type> <path>=<entry>:<attribute> [...]" >&2
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

mode="$1"
shift

case "$mode" in
attachment | attribute)
    if [[ $# -lt 4 ]]; then
        usage
    fi
    db="$1"
    entry="$2"
    name="$3"
    target="$4"
    type="${5:-binary}"

    if [[ "$mode" == attachment ]]; then
        keepassxc-cli attachment-export --stdout "$db" "$entry" "$name" |
            sops --encrypt --filename-override "$target" --input-type "$type" --output-type "$type" /dev/stdin \
                >"$target"
    else
        keepassxc-cli show -s -a "$name" "$db" "$entry" |
            sops --encrypt --filename-override "$target" --input-type "$type" --output-type "$type" /dev/stdin \
                >"$target"
    fi
    ;;

combine)
    if [[ $# -lt 4 ]]; then
        usage
    fi
    db="$1"
    target="$2"
    type="$3"
    shift 3

    json='{}'
    for pair in "$@"; do
        path="${pair%%=*}"
        rest="${pair#*=}"
        entry="${rest%%:*}"
        attr="${rest#*:}"

        if [[ -z "$path" || "$path" == "$pair" || -z "$entry" || "$entry" == "$rest" ]]; then
            echo "malformed combine argument (expected <path>=<entry>:<attribute>): $pair" >&2
            exit 1
        fi

        value=$(keepassxc-cli show -s -a "$attr" "$db" "$entry")

        IFS='.' read -ra parts <<<"$path"
        jqpath=""
        for part in "${parts[@]}"; do
            jqpath+="\"${part}\","
        done
        jqpath="[${jqpath%,}]"

        json=$(echo "$json" | jq --arg v "$value" "setpath(${jqpath}; \$v)")
    done

    echo "$json" |
        sops --encrypt --filename-override "$target" --input-type "$type" --output-type "$type" /dev/stdin \
            >"$target"
    ;;

*)
    usage
    ;;
esac

echo "Encrypted -> $target"
echo
echo "Verify the round-trip without printing the real plaintext:"
echo "  sops --decrypt --input-type ${type:-binary} --output-type ${type:-binary} '$target' | shasum -a 256"

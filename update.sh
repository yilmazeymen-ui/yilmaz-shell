#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for cmd in git python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Hata: '$cmd' kurulu değil." >&2
        exit 1
    fi
done

if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
    echo "Hata: '$SCRIPT_DIR' bir git reposu değil." >&2
    exit 1
fi

ARGS=()
if [[ $# -gt 0 && "$1" != -* ]]; then
    ARGS+=(--branch "$1")
    shift
fi

cd "$SCRIPT_DIR"
exec python3 -m hyprdots_cli.cli update --apply "${ARGS[@]}" "$@"

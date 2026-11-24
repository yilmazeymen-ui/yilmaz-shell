#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${HYPRDOTS_REPO:-}"
INSTALL_DIR="${HYPRDOTS_DIR:-$HOME/.local/share/hyprdots}"
BRANCH=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --branch|-b)
            BRANCH="$2"
            shift 2
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

for cmd in git python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Hata: '$cmd' kurulu değil." >&2
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/manifest.toml" && -d "$SCRIPT_DIR/hyprdots_cli" ]]; then
    TARGET_DIR="$SCRIPT_DIR"
else
    if [[ -z "$REPO_URL" ]]; then
        echo "Hata: --repo <github_url> veya HYPRDOTS_REPO belirtilmelidir." >&2
        exit 1
    fi
    TARGET_DIR="$INSTALL_DIR"
    if [[ ! -d "$TARGET_DIR/.git" ]]; then
        mkdir -p "$(dirname "$TARGET_DIR")"
        if [[ -n "$BRANCH" ]]; then
            git clone --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
        else
            git clone "$REPO_URL" "$TARGET_DIR"
        fi
    fi
fi

cd "$TARGET_DIR"
if [[ -n "$BRANCH" && -d "$TARGET_DIR/.git" ]]; then
    python3 -m hyprdots_cli.cli update --branch "$BRANCH" --apply "${EXTRA_ARGS[@]}"
else
    python3 -m hyprdots_cli.cli install "${EXTRA_ARGS[@]}"
fi

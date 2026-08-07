#!/usr/bin/env bash
# Package a completed bootchain as one AES-256 password-protected ZIP file.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=env.sh
source "$ROOT/env.sh"

BOOTCHAIN_DIR=""
PASSWORD_ENV=""

usage() {
    cat <<'EOF'
usage: ./protect_bootchain.sh [--bootchain DIR] [--password-env NAME]

Creates protected/<bootchain-name>.zip containing the complete bootchain.
7-Zip requests the password without echoing it and encrypts file contents with
ZIP AES-256. The original bootchain is retained because boot.sh requires plain
IMG4 files.

If --bootchain is omitted, the most recently built bootchain is used.
For CI only, --password-env reads the password from the named environment
variable. Interactive use is safer because the password is never an argument.

Test or extract the archive with:
  7z t protected/NAME.zip
  7z x protected/NAME.zip
EOF
}

while (($#)); do
    case "$1" in
        --bootchain)
            (($# >= 2)) || { usage >&2; exit 64; }
            BOOTCHAIN_DIR="$2"
            shift 2
            ;;
        --password-env)
            (($# >= 2)) || { usage >&2; exit 64; }
            PASSWORD_ENV="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "unknown option: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

command -v 7z >/dev/null || {
    echo "missing required command: 7z (install package: 7zip or p7zip-full)" >&2
    exit 1
}
[[ -n "$PASSWORD_ENV" || -t 0 ]] || {
    echo "a terminal is required so 7-Zip can request the password securely" >&2
    exit 1
}

if [[ -z "$BOOTCHAIN_DIR" ]]; then
    [[ -s "$NR_LAST_BOOTCHAIN_FILE" ]] || {
        echo "no completed bootchain found; run ./build.sh first" >&2
        exit 1
    }
    BOOTCHAIN_DIR="$NR_BOOTCHAIN_ROOT/$(<"$NR_LAST_BOOTCHAIN_FILE")"
elif [[ "$BOOTCHAIN_DIR" != /* ]]; then
    BOOTCHAIN_DIR="$ROOT/$BOOTCHAIN_DIR"
fi

[[ -d "$BOOTCHAIN_DIR" ]] || {
    echo "bootchain directory not found: $BOOTCHAIN_DIR" >&2
    exit 1
}
find "$BOOTCHAIN_DIR" -type f -print -quit | grep -q . || {
    echo "bootchain contains no files: $BOOTCHAIN_DIR" >&2
    exit 1
}

NAME="$(basename "$BOOTCHAIN_DIR")"
DEST_DIR="$ROOT/protected"
DEST="$DEST_DIR/$NAME.zip"
mkdir -p "$DEST_DIR"
rm -f "$DEST"

echo "Creating AES-256 ZIP: $DEST"
if [[ -n "$PASSWORD_ENV" ]]; then
    PASSWORD="${!PASSWORD_ENV:-}"
    [[ -n "$PASSWORD" ]] || {
        echo "environment variable $PASSWORD_ENV is empty or unset" >&2
        exit 1
    }
    (
        cd "$BOOTCHAIN_DIR"
        7z a -tzip -mem=AES256 "-p$PASSWORD" "$DEST" .
    )
    unset PASSWORD
else
    echo "Enter the requested archive password at the 7-Zip prompt."
    (
        cd "$BOOTCHAIN_DIR"
        7z a -tzip -mem=AES256 -p "$DEST" .
    )
fi

[[ -s "$DEST" ]] || {
    echo "archive was not created: $DEST" >&2
    exit 1
}

echo "Protected archive: $DEST"
echo "Original bootchain: $BOOTCHAIN_DIR"

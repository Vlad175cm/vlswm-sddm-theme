#!/usr/bin/env bash
set -euo pipefail

NAME="vlswm"
DEST="/usr/share/sddm/themes/$NAME"
CONF="/etc/sddm.conf.d/theme.conf"

if [[ ${EUID} -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

rm -rf "$DEST"

if [[ -f "$CONF" ]]; then
    BACKUP="$(ls -1t "$CONF".bak.* 2>/dev/null | head -n 1 || true)"
    if [[ -n "$BACKUP" ]]; then
        cp -a "$BACKUP" "$CONF"
        echo "Restored: $BACKUP -> $CONF"
    elif grep -q "^Current=$NAME$" "$CONF"; then
        sed -i "/^Current=$NAME$/d" "$CONF"
        echo "Removed Current=$NAME from $CONF"
    fi
fi

echo "Removed: $DEST"

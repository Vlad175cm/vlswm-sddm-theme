#!/usr/bin/env bash
set -euo pipefail

NAME="vlswm"
THEMES_DIR="/usr/share/sddm/themes"
CONF_DIR="/etc/sddm.conf.d"
CONF="$CONF_DIR/theme.conf"
DEST="$THEMES_DIR/$NAME"

die() {
    echo "error: $*" >&2
    exit 1
}

if [[ ${EUID} -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

if [[ -d "$DEST" ]]; then
    rm -rf "$DEST"
    echo "Removed: $DEST"
else
    echo "Not installed: $DEST"
fi

if [[ -f "$CONF" ]]; then
    BACKUP="$(ls -1t "$CONF".bak.* 2>/dev/null | head -n 1 || true)"
    if [[ -n "$BACKUP" ]]; then
        cp -a "$BACKUP" "$CONF"
        echo "Restored: $BACKUP -> $CONF"
    elif awk -v name="$NAME" '
        /^\[Theme\]/ { in_theme = 1; next }
        /^\[/ { in_theme = 0 }
        in_theme && $0 == "Current=" name { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$CONF"; then
        tmp="$(mktemp "$CONF.XXXXXX")"
        trap 'rm -f "$tmp"' EXIT
        awk -v name="$NAME" '
            /^\[/ { in_theme = ($0 == "[Theme]"); print; next }
            { if (in_theme && $0 == "Current=" name) next; print }
        ' "$CONF" > "$tmp"
        cp "$tmp" "$CONF"
        rm -f "$tmp"
        trap - EXIT
        echo "Removed Current=$NAME from $CONF"
    fi
fi

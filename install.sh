#!/usr/bin/env bash
set -euo pipefail

NAME="vlswm"
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="/usr/share/sddm/themes/$NAME"
CONF="/etc/sddm.conf.d/theme.conf"

if [[ ${EUID} -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

install -d -m755 "$DEST" "$DEST/assets"
install -m644 "$SRC/Main.qml" "$SRC/PasswordField.qml" "$SRC/theme.conf" "$SRC/metadata.desktop" "$DEST/"
install -m644 "$SRC/LICENSE" "$DEST/LICENSE"
install -m644 "$SRC/assets/"*.png "$DEST/assets/"

install -d -m755 "$(dirname "$CONF")"
if [[ -f "$CONF" ]]; then
    cp -a "$CONF" "$CONF.bak.$(date +%Y-%m-%d-%H%M%S)"
    if grep -q '^\[Theme\]' "$CONF"; then
        if grep -q '^Current=' "$CONF"; then
            sed -i "s|^Current=.*|Current=$NAME|" "$CONF"
        else
            sed -i "/^\[Theme\]/a Current=$NAME" "$CONF"
        fi
    else
        printf '\n[Theme]\nCurrent=%s\n' "$NAME" >> "$CONF"
    fi
else
    printf '[Theme]\nCurrent=%s\n' "$NAME" > "$CONF"
fi

echo "Installed:  $DEST"
echo "Activated:  $CONF (Current=$NAME)"
echo "The theme is used by the next SDDM login screen."

#!/usr/bin/env bash
set -euo pipefail

NAME="vlswm"
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="/usr/share/sddm/themes"
CONF_DIR="/etc/sddm.conf.d"
CONF="$CONF_DIR/theme.conf"
MAIN_CONF="/etc/sddm.conf"
DEST="$THEMES_DIR/$NAME"

die() {
    echo "error: $*" >&2
    exit 1
}

config_current() {
    [[ -f "$1" ]] || return 0
    awk '
        /^\[Theme\]/ { in_theme = 1; next }
        /^\[/ { in_theme = 0 }
        in_theme && /^Current=/ { sub(/^Current=/, ""); print; exit }
    ' "$1"
}

if [[ ${EUID} -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

command -v sddm >/dev/null 2>&1 || die "SDDM is not installed (sddm not found in PATH)"

for f in Main.qml PasswordField.qml theme.conf metadata.desktop LICENSE; do
    [[ -f "$SRC/$f" ]] || die "missing source file: $SRC/$f"
done
[[ -d "$SRC/assets" ]] || die "missing source directory: $SRC/assets"

for d in "$THEMES_DIR" "$CONF_DIR"; do
    if [[ -e "$d" && ! -d "$d" ]]; then
        die "$d exists but is not a directory"
    fi
    if [[ ! -d "$d" ]]; then
        install -d -m755 "$d"
        echo "Created: $d"
    fi
done

if [[ -L "$DEST" ]]; then
    die "$DEST is a symlink; refusing to install"
fi
if [[ -e "$DEST" && ! -d "$DEST" ]]; then
    die "$DEST exists but is not a directory"
fi
if [[ -e "$CONF" && ! -f "$CONF" ]]; then
    die "$CONF is not a regular file"
fi

install -d -m755 "$DEST" "$DEST/assets"
install -m644 "$SRC/Main.qml" "$SRC/PasswordField.qml" "$SRC/theme.conf" "$SRC/metadata.desktop" "$DEST/"
install -m644 "$SRC/LICENSE" "$DEST/LICENSE"
if compgen -G "$SRC/assets/*.png" >/dev/null; then
    install -m644 "$SRC/assets/"*.png "$DEST/assets/"
fi

# Create the SDDM config if missing, otherwise back it up and change only
# Current= inside the [Theme] section. Other sections are preserved.
if [[ ! -s "$CONF" ]]; then
    printf '[Theme]\nCurrent=%s\n' "$NAME" > "$CONF"
    echo "Created: $CONF"
elif [[ "$(config_current "$CONF")" == "$NAME" ]]; then
    echo "Already active: $CONF (Current=$NAME)"
else
    bak="$CONF.bak.$(date +%Y-%m-%d-%H%M%S)"
    [[ -e "$bak" ]] && bak="$bak.$$"
    cp -a "$CONF" "$bak"
    if ! grep -q '^\[Theme\]' "$CONF"; then
        printf '\n[Theme]\nCurrent=%s\n' "$NAME" >> "$CONF"
    else
        tmp="$(mktemp "$CONF.XXXXXX")"
        trap 'rm -f "$tmp"' EXIT
        awk -v name="$NAME" '
            function flush() {
                if (in_theme && !done) {
                    print "Current=" name
                    done = 1
                }
            }
            /^\[/ {
                flush()
                in_theme = ($0 == "[Theme]")
                print
                next
            }
            {
                if (in_theme && $0 ~ /^Current=/) {
                    print "Current=" name
                    done = 1
                } else {
                    print
                }
            }
            END { flush() }
        ' "$CONF" > "$tmp"
        cp "$tmp" "$CONF"
        rm -f "$tmp"
        trap - EXIT
    fi
fi

if [[ -f "$MAIN_CONF" ]] && awk '
    /^\[Theme\]/ { in_theme = 1; next }
    /^\[/ { in_theme = 0 }
    in_theme && /^Current=/ { found = 1 }
    END { exit(found ? 0 : 1) }
' "$MAIN_CONF"; then
    echo "warning: $MAIN_CONF also sets [Theme] Current=...; it can override $CONF." >&2
fi

[[ -f "$DEST/Main.qml" && -f "$DEST/theme.conf" ]] || die "installed theme is incomplete"

echo "Installed:  $DEST"
echo "Activated:  $CONF (Current=$NAME)"
echo "The theme is used by the next SDDM login screen."

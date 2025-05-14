#!/bin/bash

# ----------- 🔍 Abhängigkeiten prüfen -----------

declare -A CMD_TO_PACKAGE=(
    [pv]=pv
    [xz]=xz-utils
    [dd]=coreutils
    [mount]=mount
    [umount]=mount
    [blkid]=util-linux
    [mkfs.exfat]=exfatprogs
    [mail]=mailutils
    [df]=coreutils
    [find]=findutils
    [stat]=coreutils
)

MISSING_CMDS=()
APT_PACKAGES=()

for cmd in "${!CMD_TO_PACKAGE[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_CMDS+=("$cmd")
        APT_PACKAGES+=("${CMD_TO_PACKAGE[$cmd]}")
    fi
done

if [ "${#MISSING_CMDS[@]}" -gt 0 ]; then
    echo "❌ Folgende benötigte Programme fehlen:"
    for cmd in "${MISSING_CMDS[@]}"; do
        echo "   - $cmd"
    done
    echo ""
    echo "👉 Installiere ${APT_PACKAGES[*]}"
    sudo apt update && sudo apt install ${APT_PACKAGES[*]} -y
fi

# ----------- 🐍 Prüfen ob pyudev in Python 3 verfügbar ist -----------
if ! python3 -c "import pyudev" &>/dev/null; then
    echo "❌ Das Python-Modul 'pyudev' ist nicht installiert."
    echo ""
    echo "👉 Installiere python3-pyudev"
    sudo apt update && sudo apt install python3-pyudev -y
fi

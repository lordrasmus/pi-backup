#!/bin/bash
set -e

# 🔧 GitHub-Daten
GITHUB_USER="lordrasmus"
REPO_NAME="pi-backup"
SCRIPT_NAME="pi-backup.sh"
DOWNLOAD_DIR="/usr/local/pi-backup"
UDEV_RULE_NAME="99-rpi-usb-backup.rules"

# 🛡️ Warnung, wenn nicht als Root ausgeführt
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ Dieses Setup muss mit Root-Rechten ausgeführt werden (z. B. per: sudo run-last-pi-backup.sh )."
    exit 1
fi

# Prüfe auf --update Parameter
UPDATE_ONLY=false
for arg in "$@"; do
    if [ "$arg" = "--update" ]; then
        UPDATE_ONLY=true
        break
    fi
done

# 📁 Zielverzeichnis erstellen, falls nötig
if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo "📁 Erstelle Verzeichnis $DOWNLOAD_DIR..."
    sudo mkdir -p "$DOWNLOAD_DIR"
    sudo chown "$(whoami)" "$DOWNLOAD_DIR"
fi

# 🛰️ Neuestes Release-Tag holen
echo "🔍 Suche neuestes Release von $GITHUB_USER/$REPO_NAME..."
API_URL="https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/releases/latest"
TAG=$(curl -s "$API_URL" | grep '"tag_name":' | cut -d '"' -f 4)

if [ -z "$TAG" ]; then
    echo "❌ Konnte kein Release-Tag ermitteln. skip update"
    
else

    # 🧹 Aufräumen: Alte Dateien entfernen
    #echo "🧹 Räume alte Dateien auf..."
    #rm -rf "$DOWNLOAD_DIR"/*

    # 📥 Archiv-Download
    TARBALL_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/tags/$TAG.tar.gz"
    ARCHIVE_PATH="/tmp/${REPO_NAME}-${TAG}.tar.gz"

    echo "⬇️ Lade Release-Archiv: $TARBALL_URL"
    curl -sSL "$TARBALL_URL" -o "$ARCHIVE_PATH"

    # 📂 Entpacken direkt in das Zielverzeichnis
    echo "📂 Entpacke Archiv..."
    tar -xzf "$ARCHIVE_PATH" -C "$DOWNLOAD_DIR" --strip-components=1

    # 🧹 Temporäres Archiv entfernen
    rm -f "$ARCHIVE_PATH"
fi


SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Script $SCRIPT_NAME wurde im Archiv nicht gefunden."
    exit 1
fi

# 🔧 Udev-Regel aktualisieren falls geändert
if [ -f "$DOWNLOAD_DIR/$UDEV_RULE_NAME" ]; then
    if ! cmp -s "$DOWNLOAD_DIR/$UDEV_RULE_NAME" "/etc/udev/rules.d/$UDEV_RULE_NAME"; then
        echo "📄 Neue Version der Udev-Regel gefunden, aktualisiere in /etc/udev/rules.d/"
        cp "$DOWNLOAD_DIR/$UDEV_RULE_NAME" /etc/udev/rules.d/
        udevadm control --reload-rules
        echo "✅ Udev-Regel erfolgreich aktualisiert."
    fi
else
    echo "⚠️ Udev-Regel $UDEV_RULE_NAME nicht im Release gefunden."
fi

chmod +x "$SCRIPT_PATH"

if [ "$UPDATE_ONLY" = true ]; then
    echo "✅ Update abgeschlossen."
    exit 0
fi
exec "$SCRIPT_PATH" "$@"

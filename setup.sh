#!/bin/bash
set -e

# 🛡️ Warnung, wenn nicht als Root ausgeführt
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ Dieses Setup muss mit Root-Rechten ausgeführt werden (z. B. per: sudo bash setup.sh oder curl ... | sudo bash)."
    exit 1
fi

# 🔧 Konfiguration
GITHUB_USER="lordrasmus"
REPO_NAME="pi-backup"
DOWNLOAD_DIR="/usr/local/pi-backup"
UDEV_RULE_NAME="99-rpi-usb-backup.rules"

# 📁 Zielverzeichnis für Entpacken vorbereiten
if [ ! -d "$DOWNLOAD_DIR" ]; then
    echo "📁 Erstelle Zielverzeichnis: $DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"
fi

# 🛰️ Neuestes Release-Tag ermitteln
echo "🔍 Suche neuestes Release von $GITHUB_USER/$REPO_NAME..."
API_URL="https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/releases/latest"
TAG=$(curl -s "$API_URL" | grep '"tag_name":' | cut -d '"' -f 4)

if [ -z "$TAG" ]; then
    echo "❌ Konnte kein Release-Tag ermitteln."
    exit 1
fi

# 📥 Archiv herunterladen
TARBALL_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/tags/$TAG.tar.gz"
ARCHIVE_PATH="/tmp/$REPO_NAME-$TAG.tar.gz"

echo "⬇️ Lade Release-Archiv: $TARBALL_URL"
curl -sSL "$TARBALL_URL" -o "$ARCHIVE_PATH"

# 📂 Entpacken
echo "📂 Entpacke Archiv nach $DOWNLOAD_DIR..."
tar -xzf "$ARCHIVE_PATH" -C "$DOWNLOAD_DIR" --strip-components=1

# 🧩 Udev-Regel installieren
if [ -f "$DOWNLOAD_DIR/$UDEV_RULE_NAME" ]; then
    echo "📄 Installiere Udev-Regel nach /etc/udev/rules.d/"
    cp "$DOWNLOAD_DIR/$UDEV_RULE_NAME" /etc/udev/rules.d/
    udevadm control --reload-rules
    echo "✅ Udev-Regel erfolgreich installiert."
else
    echo "⚠️ Udev-Regel $UDEV_RULE_NAME nicht im Release gefunden."
fi

# 🔗 Symlink für run-last-pi-backup.sh anlegen
echo "🔗 Erstelle Symlink für run-last-pi-backup.sh in /usr/local/bin"
ln -sf "$DOWNLOAD_DIR/run-last-pi-backup.sh" /usr/local/bin/run-last-pi-backup.sh

echo "🎉 Setup abgeschlossen."

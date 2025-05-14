#!/bin/bash
set -e

# 🔧 GitHub-Daten
GITHUB_USER="lordrasmus"
REPO_NAME="pi-backup"
SCRIPT_NAME="pi-backup.sh"
DOWNLOAD_DIR="/usr/local/pi-backup"

# 🛡️ Warnung, wenn nicht als Root ausgeführt
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ Dieses Setup muss mit Root-Rechten ausgeführt werden (z. B. per: sudo run-last-pi-backup.sh )."
    exit 1
fi

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
    echo "❌ Konnte kein Release-Tag ermitteln. Stelle sicher, dass ein Release existiert."
    exit 1
fi

# 📥 Archiv-Download
TARBALL_URL="https://github.com/$GITHUB_USER/$REPO_NAME/archive/refs/tags/$TAG.tar.gz"
ARCHIVE_PATH="$DOWNLOAD_DIR/$TAG.tar.gz"

echo "⬇️ Lade Release-Archiv: $TARBALL_URL"
curl -sSL "$TARBALL_URL" -o "$ARCHIVE_PATH"

# 📂 Entpacken
echo "📂 Entpacke Archiv..."
tar -xzf "$ARCHIVE_PATH" -C "$DOWNLOAD_DIR"

# 🔍 Extrahierter Ordner (GitHub hängt Tag an Repo-Name an)
EXTRACTED_DIR="$DOWNLOAD_DIR/${REPO_NAME}-${TAG#v}"
SCRIPT_PATH="$EXTRACTED_DIR/$SCRIPT_NAME"

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Script $SCRIPT_NAME wurde im Archiv nicht gefunden."
    exit 1
fi

chmod +x "$SCRIPT_PATH"

# 🚀 Script ausführen
echo "🚀 Starte Backup-Script..."
exec "$SCRIPT_PATH"

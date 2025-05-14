#!/bin/bash
set -e

# 🔧 GitHub-Daten
GITHUB_USER="lordrasmus"
REPO_NAME="pi-backup"
SCRIPT_NAME="rpi-backup.sh"
DOWNLOAD_DIR="/tmp"
TARGET_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

# 🛰️ Neuestes Release von GitHub abfragen
echo "🔍 Suche neuestes Release von $GITHUB_USER/$REPO_NAME..."
API_URL="https://api.github.com/repos/$GITHUB_USER/$REPO_NAME/releases/latest"
TAG=$(curl -s "$API_URL" | grep '"tag_name":' | cut -d '"' -f 4)

if [ -z "$TAG" ]; then
    echo "❌ Konnte kein Release-Tag ermitteln. Stelle sicher, dass ein Release existiert."
    exit 1
fi

# 📥 Direktlink zur Script-Datei aus dem Tag
RAW_URL="https://raw.githubusercontent.com/$GITHUB_USER/$REPO_NAME/$TAG/$SCRIPT_NAME"

echo "⬇️ Lade $SCRIPT_NAME aus Release $TAG..."
curl -sSL "$RAW_URL" -o "$TARGET_PATH"

chmod +x "$TARGET_PATH"

# 🚀 Script ausführen
echo "🚀 Starte Backup-Script..."
exec "$TARGET_PATH"

#!/bin/bash

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

    CUR_VERS=""
    if [ -e $DOWNLOAD_DIR/vers ] ; then
        CUR_VERS=$(cat $DOWNLOAD_DIR/vers)
    fi
    
    if [[ ! $CUR_VERS == $TAG ]] ; then

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
        
        echo $TAG > $DOWNLOAD_DIR/vers
    else
        echo "📂 Version : $CUR_VERS"
    fi
fi


SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"




# 🔧 Udev-Regel löschen falls vorhanden
if [ -e "/etc/udev/rules.d/$UDEV_RULE_NAME" ] ; then
    rm "/etc/udev/rules.d/$UDEV_RULE_NAME"
    udevadm control --reload-rules
    echo "✅ Udev-Regel erfolgreich entfernt."
fi

/usr/local/pi-backup/install-deps.sh

if ! cmp -s "/usr/local/pi-backup/usb-watcher.py" "/usr/local/pi-backup/usb-watcher-run.py"; then
    echo "📄 Neue Version des usb-watcher.py gefunden, aktualisiere.."
    cp "/usr/local/pi-backup/usb-watcher.py" "/usr/local/pi-backup/usb-watcher-run.py"
    if [ -e /etc/systemd/system/usb-watcher.service ] ; then
        systemctl restart usb-watcher
    fi
    echo "✅ USB Watcher Daemon erfolgreich aktualisiert."
fi

if ! cmp -s "/usr/local/pi-backup/usb-watcher.service" "/etc/systemd/system/usb-watcher.service"; then
    echo "📄 Neue Version des usb-watcher.service gefunden, aktualisiere/"
    cp "/usr/local/pi-backup/usb-watcher.service" "/etc/systemd/system/"
    systemctl daemon-reload
    systemctl restart usb-watcher
    echo "✅ USB Watcher Service erfolgreich aktualisiert."
fi

if [ ! -e /etc/systemd/system/multi-user.target.wants/usb-watcher.service ] ; then
    systemctl enable usb-watcher
    echo "✅ USB Watcher Service erfolgreich aktiviert."
fi

if ! cmp -s "/usr/local/pi-backup/pi-backup.cron" "/etc/cron.hourly/pi-backup.cron"; then
    cp /usr/local/pi-backup/pi-backup.cron /etc/cron.hourly/
    echo "✅ PI Backup cron erfolgreich aktualisiert."
fi

chmod +x /etc/cron.hourly/pi-backup.cron

chmod +x "$SCRIPT_PATH"

if [ "$UPDATE_ONLY" = true ]; then
    echo "✅ Update abgeschlossen."
    exit 0
fi

exec "$SCRIPT_PATH" "$@"

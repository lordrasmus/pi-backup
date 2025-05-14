#!/bin/bash
set -e

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
    echo "👉 Installiere sie mit:"
    echo "    sudo apt update && sudo apt install ${APT_PACKAGES[*]}"
    exit 1
fi

# ----------- ⚙️ Konfiguration -----------

SRCDEV="/dev/mmcblk0"
DATE=$(date +'%Y-%m-%d_%H-%M')
IMG_FILE="rpi-backup-$DATE.img.xz"
MOUNT_POINT="/mnt/backup"

IS_UDEV=false
if ! tty &>/dev/null; then
    IS_UDEV=true
    LOGFILE="/tmp/rpi-backup-$DATE.log"
    exec > "$LOGFILE" 2>&1
    echo "🔧 Script gestartet durch udev am $(date)"
fi

USBDEV="${1:-/dev/sda1}"

# ----------- 🔒 Sicherheitsprüfungen -----------

if [ ! -b "$USBDEV" ]; then
    echo "❌ Fehler: USB-Gerät $USBDEV existiert nicht."
    exit 1
fi

if [[ "$USBDEV" == "$SRCDEV"* ]]; then
    echo "❌ Fehler: Backup-Ziel darf nicht die SD-Karte selbst sein."
    exit 1
fi

# ----------- 💾 Dateisystem prüfen/formatieren -----------

FSTYPE=$(blkid -s TYPE -o value "$USBDEV" || echo "unknown")

if [ "$FSTYPE" != "exfat" ]; then
    echo "📁 Dateisystem ist '$FSTYPE' – formatiere $USBDEV als exFAT..."
    umount "$USBDEV" 2>/dev/null || true
    mkfs.exfat -n BACKUP "$USBDEV"
    sleep 1
fi

# ----------- 🔐 Clean Exit sichern -----------

trap 'echo "🔌 Unmounting..."; umount "$MOUNT_POINT" || true' EXIT

mkdir -p "$MOUNT_POINT"
mount "$USBDEV" "$MOUNT_POINT"

DEST_PATH="$MOUNT_POINT/$IMG_FILE"

# ----------- 🚀 Backup starten -----------

DEVICE_SIZE=$(blockdev --getsize64 "$SRCDEV")
DEVICE_SIZE_MB=$((DEVICE_SIZE / 1024 / 1024))
echo "📦 Backup von $SRCDEV (${DEVICE_SIZE_MB} MB) → $DEST_PATH"

if [ "$IS_UDEV" = false ]; then
    pv --progress --eta --size "$DEVICE_SIZE" "$SRCDEV" | xz -z -6 -T0 > "$DEST_PATH"
else
    dd if="$SRCDEV" bs=4M status=none | xz -z -6 -T0 > "$DEST_PATH"
fi

# ----------- 📊 Backup-Infos -----------

FINAL_SIZE=$(stat --printf="%s" "$DEST_PATH")
FINAL_SIZE_MB=$((FINAL_SIZE / 1024 / 1024))
RATIO=$(awk "BEGIN {printf \"%.2f\", $FINAL_SIZE / $DEVICE_SIZE}")

echo "✅ Backup abgeschlossen: $DEST_PATH"
echo "📦 Größe: ${FINAL_SIZE_MB} MB"
echo "📉 Kompression: $(awk "BEGIN {printf \"%.2f\", 100 * $RATIO}") % der Originalgröße"

# ----------- 🧹 Alte Backups löschen -----------

echo ""
echo "🧹 Entferne Backups älter als 60 Tage..."
find "$MOUNT_POINT" -name "rpi-backup-*.img.xz" -type f -mtime +60 -exec rm -v {} \;

# ----------- 📊 Status anzeigen -----------

FREI_MB=$(df -m "$MOUNT_POINT" | awk 'NR==2 {print $4}')
BACKUP_COUNT=$(find "$MOUNT_POINT" -name "rpi-backup-*.img.xz" -type f | wc -l)
echo ""
echo "📊 Backups auf USB-Stick: $BACKUP_COUNT"
echo "💾 Freier Speicher: ${FREI_MB} MB"

# ----------- 🔐 Unmount vor Log-Versand -----------

umount "$MOUNT_POINT" && echo "✅ USB-Stick ausgehängt."

# ----------- 📧 Mailversand -----------

if [ "$IS_UDEV" = true ]; then
    echo ""
    echo "📧 Sende Logfile an lordrasmus@gmail.com..."
    mail -s "📦 Raspberry Pi Backup abgeschlossen am $DATE" lordrasmus@gmail.com < "$LOGFILE"
    rm -f "$LOGFILE"
fi

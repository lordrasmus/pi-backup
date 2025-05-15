#!/bin/bash
set -e


# ----------- ⚙️ Konfiguration -----------

# Ermittle das Verzeichnis des aktuellen Scripts
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

SRCDEV="/dev/mmcblk0"
DATE=$(date +'%Y-%m-%d_%H-%M')
MOUNT_POINT="/mnt/backup"

# Parameter verarbeiten
IS_SYSTEMD=false
USBDEV="/dev/sda1"  # Standard-Device

while [ $# -gt 0 ]; do
    case "$1" in
        --systemd)
            IS_SYSTEMD=true
            ;;
        /dev/*)
            USBDEV="$1"
            ;;
        *)
            echo "❌ Unbekannter Parameter: $1"
            echo "Verwendung: $0 [--systemd] [/dev/sdXY]"
            exit 1
            ;;
    esac
    shift
done

# Temporäres Verzeichnis für Logs erstellen
mkdir -p /tmp/piboot
mount -t tmpfs -o size=10M tmpfs /tmp/piboot
LOGFILE="/tmp/piboot/rpi-backup-$DATE.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo ""
echo "   PI Backup "$(cat /usr/local/pi-backup/vers) 
echo ""

echo "🔧 Script gestartet am $(date)"

# Start-Benachrichtigung senden
"$SCRIPT_DIR/send_log_mail.py" "🔧 Backup gestartet am $(date)"



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

#FSTYPE=$(blkid -s TYPE -o value "$USBDEV" || echo "unknown")
#if [ "$FSTYPE" != "exfat" ]; then
#    echo "📁 Dateisystem ist '$FSTYPE' – formatiere $USBDEV als exFAT..."
#    umount "$USBDEV" 2>/dev/null || true
#    mkfs.exfat -n BACKUP "$USBDEV"
#    sleep 1
#fi




# ----------- 🔐 Clean Exit sichern -----------

trap 'echo "🔌 Unmounting..."; umount "$MOUNT_POINT" || true; if [ ! -e /skip-backup ]; then echo "🔄 Starte System neu..."; reboot; fi' EXIT

echo "🔌 Mounting... $USBDEV -> $MOUNT_POINT"
mkdir -p "$MOUNT_POINT"
mount "$USBDEV" "$MOUNT_POINT"

DEST_PATH="$MOUNT_POINT/$IMG_FILE"

# ----------- 🚀 Backup starten -----------

# 📜 Modell des Raspberry Pi erkennen und Kompression festlegen
PI_MODEL=$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}')


# Festlegen der Kompression je nach Modell
case "$PI_MODEL" in
    # Raspberry Pi 1 Modelle
    "0002"|"0003"|"0004"|"0005"|"0006"|"0007"|"0008"|"0009"|"0010"|"0011"|"0012"|"0013"|"0014"|"0015"|"0016"|"0017"|"0018"|"0019"|"001a"|"001b"|"001c"|"001d"|"001e"|"001f")
        
        #COMPRESSION_TYPE="gzip"
        #COMPRESSION_LEVEL="1"
        #IMG_EXT="gz"
        
        COMPRESSION_TYPE="zstd"
        COMPRESSION_LEVEL="1"
        IMG_EXT="zstd"
        
        echo "🔍 Raspberry Pi 1 erkannt, verwende verwende $COMPRESSION_TYPE $COMPRESSION_LEVEL"
        ;;
    # Raspberry Pi 4 und neuere Modelle (z.B. 4B, 400, CM4)
    "a02082"|"a020a0"|"a03111"|"a03140"|"a22082"|"a220a0"|"a03130"|"c03131")
        #COMPRESSION_TYPE="xz"
        #COMPRESSION_LEVEL="5"
        #IMG_EXT="xz"
        
        COMPRESSION_TYPE="zstd"
        COMPRESSION_LEVEL="3"
        IMG_EXT="zstd"
        
        echo "🔍 Raspberry Pi 4 oder neuer erkannt, verwende $COMPRESSION_TYPE $COMPRESSION_LEVEL"
        ;;
    *)
        
        #COMPRESSION_TYPE="xz"
        #COMPRESSION_LEVEL="5"
        #IMG_EXT="xz"
        
        COMPRESSION_TYPE="zstd"
        COMPRESSION_LEVEL="6"
        IMG_EXT="zstd"
        
        echo "🔍 Unbekanntes Pi-Modell <$PI_MODEL>, verwende $COMPRESSION_TYPE $COMPRESSION_LEVEL"
        ;;
esac


# Backup-Dateiname mit korrekter Endung
IMG_FILE="rpi-backup-$DATE.img.$IMG_EXT"
DEST_PATH="$MOUNT_POINT/$IMG_FILE"

DEVICE_SIZE=$(blockdev --getsize64 "$SRCDEV")
DEVICE_SIZE_MB=$((DEVICE_SIZE / 1024 / 1024))
echo "📦 Backup von $SRCDEV (${DEVICE_SIZE_MB} MB) → $DEST_PATH"

if [ -e /skip-backup ] ; then
    echo "⚠️ skip backup"
else
    # ----------- 🧹 Alte Backups löschen -----------

    echo ""
    echo "🧹 Entferne Backups älter als 60 Tage..."
    find "$MOUNT_POINT" -name "rpi-backup-*.img.*" -type f -mtime +60 -exec rm -v {} \;
    
    # ----------- 🔒 Setze alle Partitionen auf readonly -----------
    echo "🔒 Setze Partitionen auf readonly..."
    for mnt in $(cat /proc/mounts | grep "$SRCDEV" | cut -d' ' -f2); do
        if [ "$mnt" != "/tmp/piboot" ]; then
            echo "   Setze $mnt auf readonly..."
            mount -o remount,ro "$mnt"
        fi
    done


    if [ "$IS_SYSTEMD" = false ]; then
    
        if [ "$COMPRESSION_TYPE" = "gzip" ]; then
            pv --progress --eta --size "$DEVICE_SIZE" "$SRCDEV" | gzip -$COMPRESSION_LEVEL -c > "$DEST_PATH"
        else
            pv --progress --eta --size "$DEVICE_SIZE" "$SRCDEV" | $COMPRESSION_TYPE -$COMPRESSION_LEVEL -T0 > "$DEST_PATH"
        fi
    else
        if [ "$COMPRESSION_TYPE" = "gzip" ]; then
            dd if="$SRCDEV" bs=4M status=none | gzip -$COMPRESSION_LEVEL -c > "$DEST_PATH"
        else
            dd if="$SRCDEV" bs=4M status=none | $COMPRESSION_TYPE -$COMPRESSION_LEVEL -T0 > "$DEST_PATH"
        fi
    fi


    # ----------- 📊 Backup-Infos -----------

    FINAL_SIZE=$(stat --printf="%s" "$DEST_PATH")
    FINAL_SIZE_MB=$((FINAL_SIZE / 1024 / 1024))
    RATIO=$(awk "BEGIN {printf \"%.2f\", $FINAL_SIZE / $DEVICE_SIZE}")

    echo "✅ Backup abgeschlossen: $DEST_PATH"
    echo "📦 Größe: ${FINAL_SIZE_MB} MB"
    echo "📉 Kompression: $(awk "BEGIN {printf \"%.2f\", 100 * $RATIO}") % der Originalgröße"

fi



# ----------- 📊 Status anzeigen -----------

FREI_MB=$(df -m "$MOUNT_POINT" | awk 'NR==2 {print $4}')
BACKUP_COUNT=$(find "$MOUNT_POINT" -name "rpi-backup-*.img.*" -type f | wc -l)
echo ""
echo "📊 Backups auf USB-Stick: $BACKUP_COUNT"
echo "💾 Freier Speicher: ${FREI_MB} MB"

# ----------- 🔐 Unmount vor Log-Versand -----------
#umount "$MOUNT_POINT" && echo "✅ USB-Stick ausgehängt."

# ----------- 📧 Mailversand -----------



echo ""
echo "📧 Sende Logfile ..."
"$SCRIPT_DIR/send_log_mail.py" "$LOGFILE"
rm -f "$LOGFILE"

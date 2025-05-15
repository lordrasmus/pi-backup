#!/usr/bin/env python3
import pyudev
import subprocess
import os

# Beobachte Udev-Events
context = pyudev.Context()
monitor = pyudev.Monitor.from_netlink(context)
monitor.filter_by(subsystem='block')

# Reagieren auf neue Geräte
print("🔌 USB-Watcher läuft...")

for device in iter(monitor.poll, None):
    if device.action == 'add':
        # Beispiel: Nur Partitionen auf USB-Geräten (z. B. /dev/sda1)
        
        #SUBSYSTEM=="block", ENV{ID_USB_DRIVER}=="usb-storage", ENV{DEVTYPE}=="partition", RUN+="/usr/local/bin/rpi-usb-backup.sh %E{DEVNAME} &"

        if device.get('ID_BUS') == 'usb' and device.device_node and device.device_node[-1].isdigit():
            devnode = device.device_node
            print(f"📦 USB-Stick erkannt: {devnode}")

            print("starte pi-backup.sh als background prozess")
            subprocess.Popen(
                ['/usr/local/pi-backup/pi-backup.sh', devnode, '--systemd'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )

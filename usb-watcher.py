#!/usr/bin/env python3
import pyudev
import subprocess
import os
import sys
import time



print("🔌 USB-Watcher läuft...")
sys.stdout.flush()

# Beobachte Udev-Events
context = pyudev.Context()
monitor = pyudev.Monitor.from_netlink(context)
monitor.filter_by(subsystem='block')

# Reagieren auf neue Geräte


for device in iter(monitor.poll, None):
    if device.action == 'add':
        # Beispiel: Nur Partitionen auf USB-Geräten (z. B. /dev/sda1)
        
        #SUBSYSTEM=="block", ENV{ID_USB_DRIVER}=="usb-storage", ENV{DEVTYPE}=="partition", RUN+="/usr/local/bin/rpi-usb-backup.sh %E{DEVNAME} &"

        print("was ?? ")
        sys.stdout.flush()

        if device.get('ID_BUS') == 'usb' and device.device_node and device.device_node[-1].isdigit():
            devnode = device.device_node
            print(f"📦 USB-Stick erkannt: {devnode}")
            sys.stdout.flush()

            print("starte pi-backup.sh als background prozess")
            sys.stdout.flush()
            subprocess.Popen( ["/usr/local/pi-backup/pi-backup.sh", devnode, "--systemd" ]  )
            subprocess.Popen( f'screen -S -- /usr/local/pi-backup/pi-backup.sh {devnode} --systemd', shell=True  )
            #subprocess.Popen( f'screen -S -- /usr/local/pi-backup/pi-backup.sh {devnode} --systemd', shell=True,  stdout=subprocess.DEVNULL,  stderr=subprocess.DEVNULL  )
            #subprocess.Popen( f'screen -S -- /usr/local/pi-backup/pi-backup.sh {devnode} --systemd', shell=True,  stdout=subprocess.DEVNULL,  stderr=subprocess.DEVNULL  )
            #os.system(f"screen -d -m /usr/local/pi-backup/pi-backup.sh {devnode} --systemd")

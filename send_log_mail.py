#!/usr/bin/env python3
import smtplib
import ssl
import sys
import os
import configparser
from email.message import EmailMessage

from pprint import pprint

CONFIG_FILE = '/etc/pi-backup.conf'

# Standard-Konfiguration
DEFAULT_CONFIG = {
    'SMTP': {
        'server': 'smtp.gmail.com',
        'port': '465',
        'sender': 'lordrasmus@gmail.com',
        'password': 'app-spezifisches-passwort',
        'recipient': 'lordrasmus@gmail.com'
    }
}

def ensure_config_exists():
    config = configparser.ConfigParser()
    
    if os.path.exists(CONFIG_FILE):
        config.read(CONFIG_FILE)
    
    # Überprüfen und Ergänzen fehlender Werte
    if 'SMTP' not in config:
        config['SMTP'] = {}
    
    smtp_section = config['SMTP']
    for key, value in DEFAULT_CONFIG['SMTP'].items():
        if key not in smtp_section:
            smtp_section[key] = value
    
    # Konfigurationsdatei speichern
    try:
        with open(CONFIG_FILE, 'w') as configfile:
            config.write(configfile)
    except PermissionError:
        print(f"❌ Keine Schreibrechte für {CONFIG_FILE}")
        print(f"Bitte als Root ausführen: sudo python3 {sys.argv[0]}")
        sys.exit(1)
    
    return config

def send_mail(config, subject, content):
    # E-Mail vorbereiten
    msg = EmailMessage()
    msg['Subject'] = subject
    msg['From'] = config['SMTP']['sender']
    msg['To'] = config['SMTP']['recipient']
    msg.set_content(content)

    try:
        # E-Mail senden
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(config['SMTP']['server'], 
                             int(config['SMTP']['port']), 
                             context=context) as server:
            server.login(config['SMTP']['sender'], 
                        config['SMTP']['password'])
            server.send_message(msg)
    except smtplib.SMTPAuthenticationError as e:
        print("❌ SMTP AuthenticationError")
        print(e.smtp_error.decode())
        sys.exit(1)

    print("📧 E-Mail erfolgreich versendet.")

# Konfiguration laden
config = ensure_config_exists()

if len(sys.argv) < 2:
    print("❌ Bitte Logfile oder Nachricht als Parameter angeben")
    sys.exit(1)

# Prüfen ob der Parameter ein existierendes Logfile ist
if os.path.exists(sys.argv[1]):
    # Logfile senden
    with open(sys.argv[1], 'r') as f:
        send_mail(config, '📦 Raspberry Pi Backup Log', f.read())
else:
    # Nachricht senden
    send_mail(config, '🚀 Raspberry Pi Backup', sys.argv[1])

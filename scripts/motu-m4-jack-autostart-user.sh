#!/bin/bash

# Pfad zum Log-File
LOG="/run/motu-m4/jack-autostart-user.log"

# Logging-Funktion
log() {
    echo "$(date): $1" >> $LOG
}

log "M4 Audio Interface erkannt - Starte JACK direkt (User-Kontext)"

# Aktueller Benutzer
USER=$(whoami)
USER_ID=$(id -u)

log "Benutzer: $USER (ID: $USER_ID)"

# Auf DBUS-Socket warten
DBUS_SOCKET="/run/user/$USER_ID/bus"
WAIT_TIME=0
MAX_WAIT=30

log "Prüfe DBUS-Socket: $DBUS_SOCKET"
while [ ! -e "$DBUS_SOCKET" ] && [ $WAIT_TIME -lt $MAX_WAIT ]; do
    log "Warte auf DBUS-Socket... ($WAIT_TIME/$MAX_WAIT s)"
    sleep 1
    WAIT_TIME=$((WAIT_TIME + 1))
done

if [ ! -e "$DBUS_SOCKET" ]; then
    log "DBUS-Socket nicht gefunden nach $MAX_WAIT Sekunden. Versuche trotzdem fortzufahren."
fi

log "Starte JACK direkt für Benutzer: $USER"

# Umgebungsvariablen setzen
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=$DBUS_SOCKET
export XDG_RUNTIME_DIR=/run/user/$USER_ID

# JACK-Init-Script direkt ausführen (wir sind bereits der richtige Benutzer)
/usr/local/bin/motu-m4-jack-init.sh >> $LOG 2>&1

log "JACK-Startbefehl abgeschlossen"

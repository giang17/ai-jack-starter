#!/bin/bash

# Pfad zum Log-File im eigenen /run-Unterverzeichnis
LOG="/run/motu-m4/jack-autostart.log"

# Sicherstellen, dass das Verzeichnis existiert
mkdir -p /run/motu-m4 2>/dev/null

# Logging-Funktion
log() {
    echo "$(date): $1" >> $LOG
}

log "M4 Audio Interface erkannt - Starte JACK direkt"

# Dynamische Erkennung des aktiven Benutzers (flexibler)
ACTIVE_USER=$(who | grep "(:" | head -n1 | awk '{print $1}')

# Fallback: Wenn kein aktiver User erkannt wird, Script beenden
if [ -z "$ACTIVE_USER" ]; then
    log "FEHLER: Kein aktiver Benutzer erkannt - kann JACK nicht starten"
    exit 1
fi
USER="$ACTIVE_USER"

log "Erkannter aktiver Benutzer: $USER"

USER_ID=$(id -u "$USER")
USER_HOME=$(getent passwd "$USER" | cut -d: -f6)

if [ -z "$USER_ID" ]; then
    log "Benutzer $USER nicht gefunden"
    exit 1
fi

# Prüfen, ob der Benutzer angemeldet ist
if ! who | grep -q "^$USER "; then
    log "Benutzer $USER ist noch nicht angemeldet. Warte 30 Sekunden..."
    sleep 30

    # Erneut prüfen
    if ! who | grep -q "^$USER "; then
        log "Benutzer ist nach dem Warten immer noch nicht angemeldet. Breche ab."
        exit 1
    fi
fi

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

log "Starte JACK direkt für Benutzer: $USER (ID: $USER_ID)"

# Direkter Aufruf ohne su - wir sind bereits root
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=$DBUS_SOCKET
export XDG_RUNTIME_DIR=/run/user/$USER_ID
export HOME=$USER_HOME

# JACK-Init-Script als Benutzer ausführen
runuser -l "$USER" -c "/usr/local/bin/motu-m4-jack-init.sh" >> $LOG 2>&1

log "JACK-Startbefehl abgeschlossen"

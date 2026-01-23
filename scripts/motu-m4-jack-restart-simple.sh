#!/bin/bash

# Pfad zum Log-File (konsistent mit anderen Skripten)
LOG="/run/motu-m4/jack-restart.log"

# Logging-Funktion
log() {
    echo "$(date): $1" >> $LOG
}

# Funktion zum Beenden mit Fehlermeldung
fail() {
    echo "ERROR: $1"
    log "ERROR: $1"
    exit 1
}

# Pfad zu den Scripts (anpassen falls nötig)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHUTDOWN_SCRIPT="$SCRIPT_DIR/motu-m4-jack-shutdown.sh"
INIT_SCRIPT="$SCRIPT_DIR/motu-m4-jack-init.sh"

echo "=== MOTU M4 JACK Server Restart ==="
log "=== MOTU M4 JACK Server Restart gestartet ==="

# Dynamische Erkennung des aktiven Benutzers (wie im Shutdown-Script)
ACTIVE_USER=$(who | grep "(:" | head -n1 | awk '{print $1}')

# Fallback: Wenn kein aktiver User erkannt wird, versuche über SUDO_USER
if [ -z "$ACTIVE_USER" ]; then
    ACTIVE_USER="${SUDO_USER:-}"
fi

if [ -z "$ACTIVE_USER" ]; then
    log "FEHLER: Kein aktiver Benutzer erkannt - kann JACK nicht restarten"
    exit 1
fi
USER="$ACTIVE_USER"
USER_ID=$(id -u "$USER")

log "Erkannter Benutzer: $USER (ID: $USER_ID)"
echo "Erkannter Benutzer: $USER"

# Prüfen ob Scripts existieren
if [ ! -f "$SHUTDOWN_SCRIPT" ]; then
    fail "Shutdown-Script nicht gefunden: $SHUTDOWN_SCRIPT"
fi

if [ ! -f "$INIT_SCRIPT" ]; then
    fail "Init-Script nicht gefunden: $INIT_SCRIPT"
fi

# Phase 1: JACK herunterfahren
echo "Phase 1: Beende JACK Server..."
log "Rufe Shutdown-Script auf: $SHUTDOWN_SCRIPT"
bash "$SHUTDOWN_SCRIPT" || fail "Shutdown-Script fehlgeschlagen"

# Kurze Pause zwischen Shutdown und Start
echo "Warte 2 Sekunden..."
sleep 2

# Phase 2: JACK starten
echo "Phase 2: Starte JACK Server..."
log "Rufe Init-Script auf: $INIT_SCRIPT (absoluter Pfad)"
echo "Verwende absoluten Pfad: $INIT_SCRIPT"

# Init-Script als erkannter Benutzer ausführen mit korrekten Umgebungsvariablen
runuser -l "$USER" -c "
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus
export XDG_RUNTIME_DIR=/run/user/$USER_ID
bash '$INIT_SCRIPT'
" >> $LOG 2>&1 || fail "Init-Script fehlgeschlagen"

echo "=== RESTART ERFOLGREICH ABGESCHLOSSEN ==="
log "=== RESTART ERFOLGREICH ABGESCHLOSSEN ==="

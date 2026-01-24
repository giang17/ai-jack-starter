#!/bin/bash

# =============================================================================
# MOTU M4 UDEV Event Handler
# =============================================================================
# This script is triggered by UDEV when a sound device is added/removed.
# It detects M4 connections and calls appropriate startup/shutdown scripts.
#
# Parameters from UDEV:
#   $1 (ACTION): "add" or "remove"
#   $2 (KERNEL): Device kernel name (e.g., "controlC0", "card0")
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# UDEV event parameters
ACTION="$1"
KERNEL="$2"

# Log file path
LOG="/run/motu-m4/jack-udev-handler.log"

# Ensure log directory exists
mkdir -p /run/motu-m4
chmod 777 /run/motu-m4

# =============================================================================
# Logging and Error Handling
# =============================================================================

# Logging function with error handling
log() {
    echo "$(date): $1" >> $LOG 2>&1
}

# Set error trap to catch failures
set -e
trap 'log "ERROR: Script failed at line $LINENO"' ERR

log "UDEV handler called: ACTION=$ACTION KERNEL=$KERNEL"

# =============================================================================
# Device Addition Handler (when M4 is connected)
# =============================================================================

if [ "$ACTION" = "add" ] && [[ "$KERNEL" == controlC* ]]; then
    log "Sound controller added, checking for M4..."

    # Check for logged-in user (flexible X11 session detection)
    log "DEBUG: Running who command..."
    WHO_OUTPUT=$(who 2>&1 || echo "who command failed")
    log "DEBUG: who output: $WHO_OUTPUT"

    # Search for any X11 display session (:0, :1, etc.)
    USER_LOGGED_IN=$(echo "$WHO_OUTPUT" | grep "(:" | head -n1 | awk '{print $1}' || echo "")
    log "DEBUG: Found user: [$USER_LOGGED_IN]"

    if [ -z "$USER_LOGGED_IN" ]; then
        log "No user logged in, creating trigger file"
        touch /run/motu-m4/m4-detected
        log "DEBUG: Trigger file created"
        exit 0
    fi

    log "DEBUG: User is logged in, checking hardware"
    sleep 2

    log "DEBUG: Running aplay -l..."
    APLAY_OUTPUT=$(aplay -l 2>&1 || echo "aplay command failed")
    log "DEBUG: aplay output: $APLAY_OUTPUT"

    if echo "$APLAY_OUTPUT" | grep -q "M4"; then
        log "M4 found, user $USER_LOGGED_IN logged in, starting JACK"
        log "DEBUG: Calling motu-m4-jack-autostart.sh..."
        /usr/local/bin/motu-m4-jack-autostart.sh >> $LOG 2>&1 || log "ERROR: Autostart script failed"

        # NOTE: Dynamic optimizer runs separately as system service
        log "DEBUG: Dynamic optimizer runs independently as system service"

        # Async execution (commented out - runs synchronously instead)
        # nohup /usr/local/bin/motu-m4-jack-autostart.sh >> $LOG 2>&1 &
    else
        log "No M4 found"
    fi

# =============================================================================
# Device Removal Handler (when M4 is disconnected)
# =============================================================================

elif [ "$ACTION" = "remove" ] && [[ "$KERNEL" == card* ]]; then
    log "Sound device removed, checking for M4..."

    # Remove trigger file
    rm -f /run/motu-m4/m4-detected 2>/dev/null

    # Check for logged-in user (flexible search)
    USER_LOGGED_IN=$(who | grep "(:" | head -n1 | awk '{print $1}' || echo "")

    if [ -z "$USER_LOGGED_IN" ]; then
        log "No user logged in, skipping JACK shutdown"
        exit 0
    fi

    sleep 2

    if ! aplay -l | grep -q "M4"; then
        log "M4 no longer available, user $USER_LOGGED_IN logged in, stopping JACK"
        /usr/local/bin/motu-m4-jack-shutdown.sh >> $LOG 2>&1 || log "ERROR: Shutdown script failed"
    else
        log "M4 still available"
    fi
fi

log "UDEV handler completed"

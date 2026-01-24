#!/bin/bash

# =============================================================================
# MOTU M4 JACK Autostart Script - Root Context
# =============================================================================
# Triggered by UDEV when M4 is connected. Detects active user and switches
# to user context to start JACK with appropriate environment variables.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path in dedicated /run subdirectory
LOG="/run/motu-m4/jack-autostart.log"

# Ensure log directory exists
mkdir -p /run/motu-m4 2>/dev/null

# =============================================================================
# Logging Function
# =============================================================================

log() {
    echo "$(date): $1" >> $LOG
}

log "M4 Audio Interface detected - Starting JACK directly"

# =============================================================================
# User Detection
# =============================================================================

# Dynamic detection of active user (flexible X11 session detection)
ACTIVE_USER=$(who | grep "(:" | head -n1 | awk '{print $1}')

# Fallback: If no active user detected, exit script
if [ -z "$ACTIVE_USER" ]; then
    log "ERROR: No active user detected - cannot start JACK"
    exit 1
fi
USER="$ACTIVE_USER"

log "Detected active user: $USER"

USER_ID=$(id -u "$USER")
USER_HOME=$(getent passwd "$USER" | cut -d: -f6)

if [ -z "$USER_ID" ]; then
    log "User $USER not found"
    exit 1
fi

# =============================================================================
# User Session Verification
# =============================================================================

# Check if user is fully logged in
if ! who | grep -q "^$USER "; then
    log "User $USER not yet logged in. Waiting 30 seconds..."
    sleep 30

    # Check again
    if ! who | grep -q "^$USER "; then
        log "User still not logged in after waiting. Aborting."
        exit 1
    fi
fi

# =============================================================================
# DBus Session Bus Verification
# =============================================================================

# Wait for DBUS socket to become available
DBUS_SOCKET="/run/user/$USER_ID/bus"
WAIT_TIME=0
MAX_WAIT=30

log "Checking DBUS socket: $DBUS_SOCKET"
while [ ! -e "$DBUS_SOCKET" ] && [ $WAIT_TIME -lt $MAX_WAIT ]; do
    log "Waiting for DBUS socket... ($WAIT_TIME/$MAX_WAIT s)"
    sleep 1
    WAIT_TIME=$((WAIT_TIME + 1))
done

if [ ! -e "$DBUS_SOCKET" ]; then
    log "DBUS socket not found after $MAX_WAIT seconds. Continuing anyway."
fi

log "Starting JACK directly for user: $USER (ID: $USER_ID)"

# =============================================================================
# User Context Execution
# =============================================================================

# Set environment variables for user context
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=$DBUS_SOCKET
export XDG_RUNTIME_DIR=/run/user/$USER_ID
export HOME=$USER_HOME

# Execute JACK initialization script as user
runuser -l "$USER" -c "/usr/local/bin/motu-m4-jack-init.sh" >> $LOG 2>&1

log "JACK startup command completed"

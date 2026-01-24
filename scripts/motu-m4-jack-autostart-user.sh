#!/bin/bash

# =============================================================================
# MOTU M4 JACK Autostart Script - User Context
# =============================================================================
# Called from motu-m4-login-check.service after user login.
# Runs in user context with appropriate environment variables already set.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path
LOG="/run/motu-m4/jack-autostart-user.log"

# =============================================================================
# Logging Function
# =============================================================================

log() {
    echo "$(date): $1" >> $LOG
}

log "M4 Audio Interface detected - Starting JACK directly (user context)"

# =============================================================================
# User and Session Information
# =============================================================================

# Current user information
USER=$(whoami)
USER_ID=$(id -u)

log "User: $USER (ID: $USER_ID)"

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

log "Starting JACK directly for user: $USER"

# =============================================================================
# User Context Execution
# =============================================================================

# Set environment variables
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=$DBUS_SOCKET
export XDG_RUNTIME_DIR=/run/user/$USER_ID

# Execute JACK initialization script directly (we are already the correct user)
/usr/local/bin/motu-m4-jack-init.sh >> $LOG 2>&1

log "JACK startup command completed"

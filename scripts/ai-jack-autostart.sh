#!/bin/bash

# =============================================================================
# Audio Interface JACK Autostart Script - Root Context - v3.0
# =============================================================================
# Triggered by UDEV when audio interface is connected. Detects active user and
# switches to user context to start JACK with appropriate environment variables.
# Works with any JACK-compatible audio interface.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path - use /run/ai-jack if writable, otherwise /tmp
if mkdir -p /run/ai-jack 2>/dev/null && [ -w /run/ai-jack ]; then
    LOG="/run/ai-jack/jack-autostart.log"
else
    mkdir -p /tmp/ai-jack 2>/dev/null
    LOG="/tmp/ai-jack/jack-autostart.log"
fi

# =============================================================================
# Logging Function
# =============================================================================

log() {
    echo "$(date): $1" >> $LOG
}

log "Audio Interface detected - Starting JACK directly"

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
# Configuration Loading
# =============================================================================

# Load DBus timeout from configuration (default: 30 seconds)
DBUS_TIMEOUT=30

# Try system config first
if [ -f "/etc/ai-jack/jack-setting.conf" ]; then
    CONF_TIMEOUT=$(grep -E "^DBUS_TIMEOUT=" /etc/ai-jack/jack-setting.conf 2>/dev/null | cut -d= -f2)
    if [ -n "$CONF_TIMEOUT" ]; then
        DBUS_TIMEOUT="$CONF_TIMEOUT"
        log "Loaded DBUS_TIMEOUT=$DBUS_TIMEOUT from system config"
    fi
fi

# User config overrides system config
USER_CONFIG="$USER_HOME/.config/ai-jack/jack-setting.conf"
if [ -f "$USER_CONFIG" ]; then
    CONF_TIMEOUT=$(grep -E "^DBUS_TIMEOUT=" "$USER_CONFIG" 2>/dev/null | cut -d= -f2)
    if [ -n "$CONF_TIMEOUT" ]; then
        DBUS_TIMEOUT="$CONF_TIMEOUT"
        log "Loaded DBUS_TIMEOUT=$DBUS_TIMEOUT from user config"
    fi
fi

# =============================================================================
# DBus Session Bus Verification
# =============================================================================

# Wait for DBUS socket to become available
DBUS_SOCKET="/run/user/$USER_ID/bus"
WAIT_TIME=0

log "Checking DBUS socket: $DBUS_SOCKET (timeout: ${DBUS_TIMEOUT}s)"
while [ ! -e "$DBUS_SOCKET" ] && [ $WAIT_TIME -lt $DBUS_TIMEOUT ]; do
    log "Waiting for DBUS socket... ($WAIT_TIME/${DBUS_TIMEOUT}s)"
    sleep 1
    WAIT_TIME=$((WAIT_TIME + 1))
done

if [ ! -e "$DBUS_SOCKET" ]; then
    log "WARNING: DBUS socket not found after $DBUS_TIMEOUT seconds. Continuing anyway."
    log "HINT: Increase DBUS_TIMEOUT in /etc/ai-jack/jack-setting.conf if this happens frequently."
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
runuser -l "$USER" -c "/usr/local/bin/ai-jack-init.sh" >> $LOG 2>&1

log "JACK startup command completed"

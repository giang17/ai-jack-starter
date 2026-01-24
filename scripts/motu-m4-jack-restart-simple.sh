#!/bin/bash

# =============================================================================
# MOTU M4 JACK Server Restart Script
# =============================================================================
# Performs a clean restart of JACK server: shutdown + startup with new parameters.
# This script is called when configuration changes are applied.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path (consistent with other scripts)
LOG="/run/motu-m4/jack-restart.log"

# =============================================================================
# Logging Functions
# =============================================================================

# Logging function
log() {
    echo "$(date): $1" >> $LOG
}

# Function to exit with error message
fail() {
    echo "ERROR: $1"
    log "ERROR: $1"
    exit 1
}

# =============================================================================
# Script Paths
# =============================================================================

# Path to scripts (adjust if needed)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHUTDOWN_SCRIPT="$SCRIPT_DIR/motu-m4-jack-shutdown.sh"
INIT_SCRIPT="$SCRIPT_DIR/motu-m4-jack-init.sh"

echo "=== MOTU M4 JACK Server Restart ==="
log "=== MOTU M4 JACK Server Restart started ==="

# =============================================================================
# User Detection
# =============================================================================

# Dynamic detection of active user (same as shutdown script)
ACTIVE_USER=$(who | grep "(:" | head -n1 | awk '{print $1}')

# Fallback: If no active user detected, try SUDO_USER
if [ -z "$ACTIVE_USER" ]; then
    ACTIVE_USER="${SUDO_USER:-}"
fi

if [ -z "$ACTIVE_USER" ]; then
    log "ERROR: No active user detected - cannot restart JACK"
    exit 1
fi
USER="$ACTIVE_USER"
USER_ID=$(id -u "$USER")

log "Detected user: $USER (ID: $USER_ID)"
echo "Detected user: $USER"

# =============================================================================
# Script Existence Check
# =============================================================================

# Check if shutdown script exists
if [ ! -f "$SHUTDOWN_SCRIPT" ]; then
    fail "Shutdown script not found: $SHUTDOWN_SCRIPT"
fi

# Check if init script exists
if [ ! -f "$INIT_SCRIPT" ]; then
    fail "Init script not found: $INIT_SCRIPT"
fi

# =============================================================================
# Phase 1: Shutdown
# =============================================================================

echo "Phase 1: Shutting down JACK server..."
log "Calling shutdown script: $SHUTDOWN_SCRIPT"
bash "$SHUTDOWN_SCRIPT" || fail "Shutdown script failed"

# Brief pause between shutdown and startup
echo "Waiting 2 seconds..."
sleep 2

# =============================================================================
# Phase 2: Startup
# =============================================================================

echo "Phase 2: Starting JACK server..."
log "Calling init script: $INIT_SCRIPT (absolute path)"
echo "Using absolute path: $INIT_SCRIPT"

# Execute init script as detected user with correct environment variables
runuser -l "$USER" -c "
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus
export XDG_RUNTIME_DIR=/run/user/$USER_ID
bash '$INIT_SCRIPT'
" >> $LOG 2>&1 || fail "Init script failed"

echo "=== RESTART COMPLETED SUCCESSFULLY ==="
log "=== RESTART COMPLETED SUCCESSFULLY ==="

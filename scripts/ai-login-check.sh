#!/bin/bash

# =============================================================================
# Audio Interface Login Check Service - v3.0
# =============================================================================
# Runs after user login (via systemd ai-login-check.service).
# Checks if audio interface was connected before user login and starts JACK
# if needed. Works with any JACK-compatible audio interface.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path - use /run/ai-jack if writable, otherwise /tmp
if mkdir -p /run/ai-jack 2>/dev/null && [ -w /run/ai-jack ]; then
    LOG="/run/ai-jack/jack-login-check.log"
else
    mkdir -p /tmp/ai-jack 2>/dev/null
    LOG="/tmp/ai-jack/jack-login-check.log"
fi

# =============================================================================
# Logging Function
# =============================================================================

log() {
    echo "$(date): $1" >> $LOG
}

log "Login check: Starting after boot"

# =============================================================================
# Configuration Loading
# =============================================================================
SYSTEM_CONFIG_FILE="/etc/ai-jack/jack-setting.conf"
DEVICE_PATTERN=""

# Load DEVICE_PATTERN from config if available
if [ -f "$SYSTEM_CONFIG_FILE" ]; then
    DEVICE_PATTERN=$(grep "^DEVICE_PATTERN=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
fi

log "Login check: DEVICE_PATTERN=${DEVICE_PATTERN:-<not set>}"

# =============================================================================
# Wait for User Login
# =============================================================================

# Wait until user is fully logged in
MAX_WAIT=120  # Wait maximum 2 minutes
WAIT_TIME=0

log "Login check: Waiting for user login..."

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check for logged-in user with X11 display
    USER_LOGGED_IN=$(who | grep "(:" | head -n1 | awk '{print $1}')

    if [ -n "$USER_LOGGED_IN" ]; then
        log "Login check: User $USER_LOGGED_IN logged in after $WAIT_TIME seconds"
        break
    fi

    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

if [ -z "$USER_LOGGED_IN" ]; then
    log "Login check: No user logged in after $MAX_WAIT seconds, aborting"
    exit 1
fi

log "Login check: Checking for pre-connected audio interface"

# =============================================================================
# Pre-Boot Audio Interface Detection
# =============================================================================

# Check if trigger file exists (device was detected during boot)
if [ -f /run/ai-jack/device-detected ]; then
    log "Login check: Device trigger file found, checking hardware"

    # Check if device is still actually connected
    DEVICE_FOUND=false
    if [ -n "$DEVICE_PATTERN" ]; then
        if LC_ALL=C aplay -l | grep -q "$DEVICE_PATTERN"; then
            DEVICE_FOUND=true
            log "Login check: Device matching '$DEVICE_PATTERN' is connected"
        fi
    else
        # No pattern - assume device is present if any sound card exists
        if LC_ALL=C aplay -l | grep -q "card"; then
            DEVICE_FOUND=true
            log "Login check: Audio device is connected (no pattern configured)"
        fi
    fi

    if [ "$DEVICE_FOUND" = true ]; then
        log "Login check: Starting JACK"
        # Use user script since we are running as user
        /usr/local/bin/ai-jack-autostart-user.sh >> $LOG 2>&1
    else
        log "Login check: Audio interface no longer connected"
    fi

    # Remove trigger file
    rm -f /run/ai-jack/device-detected
    log "Login check: Trigger file removed"
else
    log "Login check: No device trigger file found"
fi

# =============================================================================
# Service Notes
# =============================================================================

# NOTE: Dynamic optimizer runs separately as system service
log "Login check: Dynamic optimizer runs independently as system service"

log "Login check: Completed"

#!/bin/bash

# =============================================================================
# MOTU M4 Login Check Service
# =============================================================================
# Runs after user login (via systemd motu-m4-login-check.service).
# Checks if M4 was connected before user login and starts JACK if needed.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path
LOG="/run/motu-m4/jack-login-check.log"

# =============================================================================
# Logging Function
# =============================================================================

log() {
    echo "$(date): $1" >> $LOG
}

# Ensure log directory exists
mkdir -p /run/motu-m4

log "Login check: Starting after boot"

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

log "Login check: Checking for pre-connected M4"

# =============================================================================
# Pre-Boot M4 Detection
# =============================================================================

# Check if trigger file exists (M4 was detected during boot)
if [ -f /run/motu-m4/m4-detected ]; then
    log "Login check: M4 trigger file found, checking hardware"

    # Check if M4 is still actually connected
    if aplay -l | grep -q "M4"; then
        log "Login check: M4 is connected, starting JACK"
        # Use user script since we are running as user
        /usr/local/bin/motu-m4-jack-autostart-user.sh >> $LOG 2>&1
    else
        log "Login check: M4 no longer connected"
    fi

    # Remove trigger file
    rm -f /run/motu-m4/m4-detected
    log "Login check: Trigger file removed"
else
    log "Login check: No M4 trigger file found"
fi

# =============================================================================
# Service Notes
# =============================================================================

# NOTE: Dynamic optimizer runs separately as system service
log "Login check: Dynamic optimizer runs independently as system service"

log "Login check: Completed"

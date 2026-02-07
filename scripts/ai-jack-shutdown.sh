#!/bin/bash

# =============================================================================
# Audio Interface JACK Shutdown Script - v3.0
# =============================================================================
# Cleanly stops JACK server and A2J MIDI bridge when audio interface is
# disconnected. Works with any JACK-compatible audio interface.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# =============================================================================
# Logging Setup
# =============================================================================
# Source centralized logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/ai-jack-logging.sh" ]; then
    source "$SCRIPT_DIR/ai-jack-logging.sh"
elif [ -f "/usr/local/bin/ai-jack-logging.sh" ]; then
    source "/usr/local/bin/ai-jack-logging.sh"
else
    # Fallback: define minimal logging functions
    log_debug() { :; }
    log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"; }
    log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >&2; }
    log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2; }
fi

# Initialize logging for this script
init_logging "shutdown" "jack-shutdown.log"

# Legacy LOG variable and log() function for compatibility
LOG=$(get_log_file)
log() { log_info "$1"; }

log_info "Audio Interface removed - Shutting down JACK"

# Dynamic detection of active user
ACTIVE_SESSION=$(who | grep "(:" | head -n1)
ACTIVE_USER=$(echo "$ACTIVE_SESSION" | awk '{print $1}')
ACTIVE_DISPLAY=$(echo "$ACTIVE_SESSION" | grep -oP '\(:\K[0-9]+' | head -1)
ACTIVE_DISPLAY=":${ACTIVE_DISPLAY:-0}"

# Fallback: If no active user detected, try via SUDO_USER
if [ -z "$ACTIVE_USER" ]; then
    ACTIVE_USER="${SUDO_USER:-}"
fi

if [ -z "$ACTIVE_USER" ]; then
    log_warn "No active user detected - trying to continue anyway"
    USER="${USER:-root}"
else
    USER="$ACTIVE_USER"
fi
USER_ID=$(id -u "$USER" 2>/dev/null || echo "")

log_info "Stopping JACK for user: $USER"

# Set environment variables
export DISPLAY=$ACTIVE_DISPLAY
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus
export XDG_RUNTIME_DIR=/run/user/$USER_ID

# Stop JACK and A2J cleanly
runuser -l "$USER" -c "
# First stop A2J MIDI Bridge cleanly (if running)
# Use pgrep instead of a2j_control to avoid DBus activation issues
if pgrep -x a2jmidid >/dev/null 2>&1; then
    echo 'Stopping A2J MIDI Bridge...'
    killall a2jmidid 2>/dev/null || true
    sleep 1
fi

# Then stop JACK cleanly
jack_control stop 2>/dev/null || true
sleep 2

# Check if processes are still running and terminate gracefully
if pgrep jackdbus >/dev/null 2>&1; then
    echo 'Terminating jackdbus gracefully...'
    killall jackdbus 2>/dev/null || true
    sleep 1
fi

if pgrep jackd >/dev/null 2>&1; then
    echo 'Terminating jackd gracefully...'
    killall jackd 2>/dev/null || true
    sleep 1
fi

if pgrep a2jmidid >/dev/null 2>&1; then
    echo 'Terminating a2jmidid gracefully...'
    killall a2jmidid 2>/dev/null || true
    sleep 1
fi

# If processes are still running, force termination
if pgrep 'jack|a2j' >/dev/null 2>&1; then
    echo 'Force terminating remaining processes...'
    killall -9 jackdbus jackd a2jmidid 2>/dev/null || true
fi

# Clean up temporary files
rm -f /tmp/jack-*-$USER_ID 2>/dev/null
rm -f /dev/shm/jack-*-$USER_ID 2>/dev/null
" >> $LOG 2>&1

# Brief pause to ensure all resources are released
sleep 2

log_info "JACK server completely stopped and cleaned up"

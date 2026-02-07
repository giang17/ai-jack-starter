#!/bin/bash

# =============================================================================
# Audio Interface JACK Autostart Script - User Context - v3.0
# =============================================================================
# Called from ai-login-check.service after user login.
# Runs in user context with appropriate environment variables already set.
# Works with any JACK-compatible audio interface.
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
init_logging "autostart-user" "jack-autostart-user.log"

# Legacy LOG variable and log() function for compatibility
LOG=$(get_log_file)
log() { log_info "$1"; }

log_info "Audio Interface detected - Starting JACK directly (user context)"

# =============================================================================
# User and Session Information
# =============================================================================

# Current user information
USER=$(whoami)
USER_ID=$(id -u)

log_info "User: $USER (ID: $USER_ID)"

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
        log_debug "Loaded DBUS_TIMEOUT=$DBUS_TIMEOUT from system config"
    fi
fi

# User config overrides system config
USER_CONFIG="$HOME/.config/ai-jack/jack-setting.conf"
if [ -f "$USER_CONFIG" ]; then
    CONF_TIMEOUT=$(grep -E "^DBUS_TIMEOUT=" "$USER_CONFIG" 2>/dev/null | cut -d= -f2)
    if [ -n "$CONF_TIMEOUT" ]; then
        DBUS_TIMEOUT="$CONF_TIMEOUT"
        log_debug "Loaded DBUS_TIMEOUT=$DBUS_TIMEOUT from user config"
    fi
fi

# =============================================================================
# DBus Session Bus Verification
# =============================================================================

# Wait for DBUS socket to become available
DBUS_SOCKET="/run/user/$USER_ID/bus"
WAIT_TIME=0

log_debug "Checking DBUS socket: $DBUS_SOCKET (timeout: ${DBUS_TIMEOUT}s)"
while [ ! -e "$DBUS_SOCKET" ] && [ $WAIT_TIME -lt $DBUS_TIMEOUT ]; do
    log_debug "Waiting for DBUS socket... ($WAIT_TIME/${DBUS_TIMEOUT}s)"
    sleep 1
    WAIT_TIME=$((WAIT_TIME + 1))
done

if [ ! -e "$DBUS_SOCKET" ]; then
    log_warn "DBUS socket not found after $DBUS_TIMEOUT seconds. Continuing anyway."
    log_info "HINT: Increase DBUS_TIMEOUT in /etc/ai-jack/jack-setting.conf if this happens frequently."
fi

log_info "Starting JACK directly for user: $USER"

# =============================================================================
# User Context Execution
# =============================================================================

# Detect active display from session
ACTIVE_DISPLAY=$(who | grep "^$(whoami).*(:.*)" | head -n1 | grep -oP '\(:\K[0-9]+' | head -1)
export DISPLAY=":${ACTIVE_DISPLAY:-0}"
log_debug "Detected DISPLAY=$DISPLAY"
export DBUS_SESSION_BUS_ADDRESS=unix:path=$DBUS_SOCKET
export XDG_RUNTIME_DIR=/run/user/$USER_ID

# Execute JACK initialization script directly (we are already the correct user)
/usr/local/bin/ai-jack-init.sh >> $LOG 2>&1

log_info "JACK startup command completed"

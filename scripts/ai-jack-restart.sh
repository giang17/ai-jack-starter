#!/bin/bash

# =============================================================================
# Audio Interface JACK Server Restart Script - v3.0
# =============================================================================
# Performs a clean restart of JACK server: shutdown + startup with new parameters.
# This script is called when configuration changes are applied.
# Works with any JACK-compatible audio interface.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# =============================================================================
# Logging Setup
# =============================================================================
# Source centralized logging library
SCRIPT_DIR_LOGGING="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR_LOGGING/ai-jack-logging.sh" ]; then
    source "$SCRIPT_DIR_LOGGING/ai-jack-logging.sh"
elif [ -f "/usr/local/bin/ai-jack-logging.sh" ]; then
    source "/usr/local/bin/ai-jack-logging.sh"
else
    # Fallback: define minimal logging functions
    log_debug() { :; }
    log_info() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"; }
    log_warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >&2; }
    log_error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2; }
    fail() { log_error "$1"; exit 1; }
fi

# Initialize logging for this script
init_logging "restart" "jack-restart.log"

# Legacy LOG variable and log() function for compatibility
LOG=$(get_log_file)
log() { log_info "$1"; }

# =============================================================================
# Script Paths
# =============================================================================

# Path to scripts (adjust if needed)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHUTDOWN_SCRIPT="$SCRIPT_DIR/ai-jack-shutdown.sh"
INIT_SCRIPT="$SCRIPT_DIR/ai-jack-init.sh"

echo "=== Audio Interface JACK Server Restart ==="
log_info "=== Audio Interface JACK Server Restart started ==="

# =============================================================================
# User Detection
# =============================================================================

# Dynamic detection of active user and display
ACTIVE_SESSION=$(who | grep "(:" | head -n1)
ACTIVE_USER=$(echo "$ACTIVE_SESSION" | awk '{print $1}')
ACTIVE_DISPLAY=$(echo "$ACTIVE_SESSION" | grep -oP '\(:\K[0-9]+' | head -1)
ACTIVE_DISPLAY=":${ACTIVE_DISPLAY:-0}"

# Fallback: If no active user detected, try SUDO_USER
if [ -z "$ACTIVE_USER" ]; then
    ACTIVE_USER="${SUDO_USER:-}"
fi

if [ -z "$ACTIVE_USER" ]; then
    log_error "No active user detected - cannot restart JACK"
    exit 1
fi
USER="$ACTIVE_USER"
USER_ID=$(id -u "$USER")

log_info "Detected user: $USER (ID: $USER_ID)"
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
log_info "Calling shutdown script: $SHUTDOWN_SCRIPT"
bash "$SHUTDOWN_SCRIPT" || fail "Shutdown script failed"

# Brief pause between shutdown and startup
echo "Waiting 2 seconds..."
sleep 2

# =============================================================================
# Phase 2: Startup
# =============================================================================

echo "Phase 2: Starting JACK server..."
log_info "Calling init script: $INIT_SCRIPT (absolute path)"
echo "Using absolute path: $INIT_SCRIPT"

# Execute init script as detected user with correct environment variables
runuser -l "$USER" -c "
export DISPLAY=$ACTIVE_DISPLAY
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$USER_ID/bus
export XDG_RUNTIME_DIR=/run/user/$USER_ID
bash '$INIT_SCRIPT'
" >> $LOG 2>&1 || fail "Init script failed"

echo "=== RESTART COMPLETED SUCCESSFULLY ==="
log_info "=== RESTART COMPLETED SUCCESSFULLY ==="

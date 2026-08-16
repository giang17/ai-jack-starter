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
init_logging "login-check" "jack-login-check.log"

# Legacy LOG variable and log() function for compatibility
LOG=$(get_log_file)
log() { log_info "$1"; }

# =============================================================================
# Session Detection Setup
# =============================================================================
# Source session detection library (display-server agnostic: X11 + Wayland)
if [ -f "$SCRIPT_DIR/ai-jack-session.sh" ]; then
    source "$SCRIPT_DIR/ai-jack-session.sh"
elif [ -f "/usr/local/bin/ai-jack-session.sh" ]; then
    source "/usr/local/bin/ai-jack-session.sh"
else
    # Fallback: legacy X11-only detection (finds nothing under Wayland)
    log_warn "ai-jack-session.sh not found - falling back to X11-only detection"
    get_active_session_user() { who | grep "(:" | head -n1 | awk '{print $1}'; }
    get_active_session_display() { echo "${DISPLAY:-:0}"; }
    get_active_session_type() { echo "unknown"; }
fi

log_info "Login check: Starting after boot"

# =============================================================================
# Auto-Detection Helper
# =============================================================================
# Patterns to filter out internal/onboard audio devices
INTERNAL_DEVICE_PATTERNS="HDA NVidia|HDA Intel|HDA ATI|HDA AMD|HDMI|sof-|PCH"

# Check if any external USB audio interface is connected
any_external_audio_device_present() {
    local aplay_output
    aplay_output=$(LC_ALL=C aplay -l 2>/dev/null)

    # Parse aplay output to find USB audio devices (exclude internal devices)
    while IFS= read -r line; do
        if [[ "$line" =~ ^card\ ([0-9]+):\ ([a-zA-Z0-9_]+)\ \[([^\]]+)\] ]]; then
            local card_name="${BASH_REMATCH[3]}"
            local card_id="${BASH_REMATCH[2]}"

            # Skip internal devices
            if echo "$card_name $card_id" | grep -qiE "$INTERNAL_DEVICE_PATTERNS"; then
                continue
            fi

            # Found an external USB audio device
            log_debug "Found external audio device: $card_name ($card_id)"
            return 0
        fi
    done <<< "$aplay_output"

    return 1
}

# =============================================================================
# JACK Server Status Check
# =============================================================================

# Check whether the JACK server is actually started.
# jackdbus can be auto-activated by D-Bus and sit idle without a running server,
# so pgrep would give a false positive - ask jack_control for the real state.
# We already run in the user's context here, so no runuser/D-Bus juggling needed.
jack_server_is_running() {
    local status_output
    status_output=$(timeout 15 jack_control status 2>&1) || true
    log_debug "jack_control status: $status_output"
    echo "$status_output" | grep -q "started"
}

# =============================================================================
# Wait for User Login
# =============================================================================

# Wait until user is fully logged in
MAX_WAIT=120  # Wait maximum 2 minutes
WAIT_TIME=0

log_info "Login check: Waiting for user login..."

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check for logged-in user (works for both X11 and Wayland sessions)
    USER_LOGGED_IN=$(get_active_session_user)

    if [ -n "$USER_LOGGED_IN" ]; then
        log_info "Login check: User $USER_LOGGED_IN logged in after $WAIT_TIME seconds (session type: $(get_active_session_type))"
        break
    fi

    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
done

if [ -z "$USER_LOGGED_IN" ]; then
    log_warn "Login check: No user logged in after $MAX_WAIT seconds, aborting"
    exit 1
fi

log_info "Login check: Checking for pre-connected audio interface"

# =============================================================================
# Pre-Boot Audio Interface Detection
# =============================================================================

# The trigger file is written by the udev handler when a device shows up before
# anyone is logged in. It is a hint, not a precondition: the first login of a boot
# consumes it, so a second login - e.g. after switching from X11 to Wayland, or
# any re-login - would never start JACK if we required it. Decide on the actual
# state instead: interface present and no JACK server running.
if [ -f /run/ai-jack/device-detected ]; then
    log_debug "Login check: Device trigger file found (device connected before login)"
    rm -f /run/ai-jack/device-detected
    log_debug "Login check: Trigger file removed"
else
    log_debug "Login check: No device trigger file found, checking hardware anyway"
fi

# Check for ANY external audio device using auto-detection
# This filters out internal devices (HDA Intel, HDMI, etc.)
if any_external_audio_device_present; then
    if jack_server_is_running; then
        log_info "Login check: External audio interface detected, JACK already running - nothing to do"
    else
        log_info "Login check: External audio interface detected, starting JACK"
        # Use user script since we are running as user
        /usr/local/bin/ai-jack-autostart-user.sh >> $LOG 2>&1
    fi
else
    log_warn "Login check: No external audio interface found (internal devices filtered)"
fi

# =============================================================================
# Service Notes
# =============================================================================

# NOTE: Dynamic optimizer runs separately as system service
log_debug "Login check: Dynamic optimizer runs independently as system service"

log_info "Login check: Completed"

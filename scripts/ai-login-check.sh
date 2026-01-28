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
# Wait for User Login
# =============================================================================

# Wait until user is fully logged in
MAX_WAIT=120  # Wait maximum 2 minutes
WAIT_TIME=0

log_info "Login check: Waiting for user login..."

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check for logged-in user with X11 display
    USER_LOGGED_IN=$(who | grep "(:" | head -n1 | awk '{print $1}')

    if [ -n "$USER_LOGGED_IN" ]; then
        log_info "Login check: User $USER_LOGGED_IN logged in after $WAIT_TIME seconds"
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

# Check if trigger file exists (device was detected during boot)
if [ -f /run/ai-jack/device-detected ]; then
    log_debug "Login check: Device trigger file found, checking hardware"

    # Check for ANY external audio device using auto-detection
    # This filters out internal devices (HDA Intel, HDMI, etc.)
    if any_external_audio_device_present; then
        log_info "Login check: External audio interface detected, starting JACK"
        # Use user script since we are running as user
        /usr/local/bin/ai-jack-autostart-user.sh >> $LOG 2>&1
    else
        log_warn "Login check: No external audio interface found (internal devices filtered)"
    fi

    # Remove trigger file
    rm -f /run/ai-jack/device-detected
    log_debug "Login check: Trigger file removed"
else
    log_debug "Login check: No device trigger file found"
fi

# =============================================================================
# Service Notes
# =============================================================================

# NOTE: Dynamic optimizer runs separately as system service
log_debug "Login check: Dynamic optimizer runs independently as system service"

log_info "Login check: Completed"

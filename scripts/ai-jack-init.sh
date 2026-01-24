#!/bin/bash

# =============================================================================
# Audio Interface JACK Initialization Script - v3.0
# =============================================================================
# Flexible JACK configuration with customizable sample rate, buffer size,
# periods, and audio device. Works with any JACK-compatible audio interface.
#
# Configuration file format (v3.0):
#   AUDIO_DEVICE=hw:M4,0
#   DEVICE_PATTERN=M4
#   JACK_RATE=48000
#   JACK_PERIOD=256
#   JACK_NPERIODS=3
#
# Legacy format (v1.x/v2.0) is still supported.
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
    fail() { log_error "$1"; exit 1; }
fi

# Initialize logging for this script
init_logging "jack-init" "jack-init.log"

# Legacy LOG variable for compatibility (used by subshell redirections)
LOG=$(get_log_file)
export LOG

# =============================================================================
# Default Configuration
# =============================================================================
DEFAULT_RATE=48000
DEFAULT_PERIOD=256
DEFAULT_NPERIODS=3
DEFAULT_A2J_ENABLE=false
DEFAULT_AUDIO_DEVICE="hw:0,0"
DEFAULT_DEVICE_PATTERN=""

# =============================================================================
# Legacy Presets (for backward compatibility with v1.x)
# =============================================================================
# Setting 1: Low Latency (Default)
PRESET1_RATE=48000
PRESET1_NPERIODS=2
PRESET1_PERIOD=128

# Setting 2: Medium Latency
PRESET2_RATE=48000
PRESET2_NPERIODS=2
PRESET2_PERIOD=256

# Setting 3: Ultra-Low Latency
PRESET3_RATE=48000
PRESET3_NPERIODS=2
PRESET3_PERIOD=64

# =============================================================================
# Configuration Files
# =============================================================================
SYSTEM_CONFIG_FILE="/etc/ai-jack/jack-setting.conf"

# Determine actual user and user config path
ACTUAL_USER=""
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    ACTUAL_USER="$SUDO_USER"
elif [ "$(whoami)" != "root" ]; then
    ACTUAL_USER="$(whoami)"
else
    # Fallback: Detect active desktop user
    ACTUAL_USER=$(who | grep "(:" | head -n1 | awk '{print $1}')
fi

if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
    USER_CONFIG_FILE="/home/$ACTUAL_USER/.config/ai-jack/jack-setting.conf"
else
    USER_CONFIG_FILE="$HOME/.config/ai-jack/jack-setting.conf"
fi

# =============================================================================
# Legacy Logging Wrapper (for backward compatibility)
# =============================================================================
# The log() function is now provided by ai-jack-logging.sh
# This wrapper ensures old code using log() still works
log() {
    log_info "$1"
}

# =============================================================================
# Configuration Reading Functions
# =============================================================================

# Read a value from a config file
read_config_value() {
    local config_file="$1"
    local key="$2"
    if [ -f "$config_file" ]; then
        local value
        value=$(grep "^${key}=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    fi
    return 1
}

# Check if config file uses new v2.0+ format
is_v2_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        if grep -q "^JACK_RATE=" "$config_file" || \
           grep -q "^JACK_PERIOD=" "$config_file" || \
           grep -q "^JACK_NPERIODS=" "$config_file" || \
           grep -q "^AUDIO_DEVICE=" "$config_file"; then
            return 0
        fi
    fi
    return 1
}

# Check if config file uses legacy v1.x format
is_legacy_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        if grep -q "^JACK_SETTING=" "$config_file"; then
            return 0
        fi
    fi
    return 1
}

# Convert legacy setting number to parameters
apply_legacy_preset() {
    local setting="$1"
    case "$setting" in
        2)
            ACTIVE_RATE=$PRESET2_RATE
            ACTIVE_NPERIODS=$PRESET2_NPERIODS
            ACTIVE_PERIOD=$PRESET2_PERIOD
            ;;
        3)
            ACTIVE_RATE=$PRESET3_RATE
            ACTIVE_NPERIODS=$PRESET3_NPERIODS
            ACTIVE_PERIOD=$PRESET3_PERIOD
            ;;
        *)
            # Default to preset 1
            ACTIVE_RATE=$PRESET1_RATE
            ACTIVE_NPERIODS=$PRESET1_NPERIODS
            ACTIVE_PERIOD=$PRESET1_PERIOD
            ;;
    esac
}

# Load configuration from file (supports v1.x, v2.0, and v3.0 formats)
load_config_from_file() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Check for v2.0+ format first
    if is_v2_config "$config_file"; then
        local rate
        local period
        local nperiods
        local a2j_enable
        local audio_device
        local device_pattern
        rate=$(read_config_value "$config_file" "JACK_RATE")
        period=$(read_config_value "$config_file" "JACK_PERIOD")
        nperiods=$(read_config_value "$config_file" "JACK_NPERIODS")
        a2j_enable=$(read_config_value "$config_file" "A2J_ENABLE")
        audio_device=$(read_config_value "$config_file" "AUDIO_DEVICE")
        device_pattern=$(read_config_value "$config_file" "DEVICE_PATTERN")

        if [ -n "$rate" ]; then
            ACTIVE_RATE="$rate"
        fi
        if [ -n "$period" ]; then
            ACTIVE_PERIOD="$period"
        fi
        if [ -n "$nperiods" ]; then
            ACTIVE_NPERIODS="$nperiods"
        fi
        if [ -n "$a2j_enable" ]; then
            ACTIVE_A2J_ENABLE="$a2j_enable"
        fi
        if [ -n "$audio_device" ]; then
            ACTIVE_AUDIO_DEVICE="$audio_device"
        fi
        if [ -n "$device_pattern" ]; then
            ACTIVE_DEVICE_PATTERN="$device_pattern"
        fi

        log "Loaded v3.0 config from $config_file: Device=$ACTIVE_AUDIO_DEVICE, Pattern=$ACTIVE_DEVICE_PATTERN, Rate=$ACTIVE_RATE, Period=$ACTIVE_PERIOD, Nperiods=$ACTIVE_NPERIODS, A2J=$ACTIVE_A2J_ENABLE"
        return 0
    fi

    # Fallback to legacy v1.x format
    if is_legacy_config "$config_file"; then
        local setting
        setting=$(read_config_value "$config_file" "JACK_SETTING")
        if [ -n "$setting" ]; then
            apply_legacy_preset "$setting"
            log "Loaded legacy v1.x config from $config_file: Setting=$setting (Rate=$ACTIVE_RATE, Period=$ACTIVE_PERIOD, Nperiods=$ACTIVE_NPERIODS)"
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# Main Configuration Loading
# =============================================================================

# Initialize with defaults
ACTIVE_RATE=$DEFAULT_RATE
ACTIVE_PERIOD=$DEFAULT_PERIOD
ACTIVE_NPERIODS=$DEFAULT_NPERIODS
ACTIVE_A2J_ENABLE=$DEFAULT_A2J_ENABLE
ACTIVE_AUDIO_DEVICE=$DEFAULT_AUDIO_DEVICE
ACTIVE_DEVICE_PATTERN=$DEFAULT_DEVICE_PATTERN

# Configuration priority:
# 1. Environment variables (AUDIO_DEVICE, DEVICE_PATTERN, JACK_RATE, etc.)
# 2. User config file (~/.config/ai-jack/jack-setting.conf)
# 3. System config file (/etc/ai-jack/jack-setting.conf)
# 4. Defaults

config_source="defaults"

# Try system config first (lowest priority of files)
if load_config_from_file "$SYSTEM_CONFIG_FILE"; then
    config_source="system config ($SYSTEM_CONFIG_FILE)"
fi

# Try user config (higher priority)
if load_config_from_file "$USER_CONFIG_FILE"; then
    config_source="user config ($USER_CONFIG_FILE)"
fi

# Environment variables have highest priority
if [ -n "${AUDIO_DEVICE:-}" ]; then
    ACTIVE_AUDIO_DEVICE="$AUDIO_DEVICE"
    config_source="environment variables"
fi
if [ -n "${DEVICE_PATTERN:-}" ]; then
    ACTIVE_DEVICE_PATTERN="$DEVICE_PATTERN"
    config_source="environment variables"
fi
if [ -n "${JACK_RATE:-}" ]; then
    ACTIVE_RATE="$JACK_RATE"
    config_source="environment variables"
fi
if [ -n "${JACK_PERIOD:-}" ]; then
    ACTIVE_PERIOD="$JACK_PERIOD"
    config_source="environment variables"
fi
if [ -n "${JACK_NPERIODS:-}" ]; then
    ACTIVE_NPERIODS="$JACK_NPERIODS"
    config_source="environment variables"
fi
if [ -n "${A2J_ENABLE:-}" ]; then
    ACTIVE_A2J_ENABLE="$A2J_ENABLE"
    config_source="environment variables"
fi

# Legacy environment variable support
if [ -n "${JACK_SETTING:-}" ] && [ -z "${JACK_RATE:-}" ]; then
    apply_legacy_preset "$JACK_SETTING"
    config_source="environment variable (legacy JACK_SETTING=$JACK_SETTING)"
fi

# =============================================================================
# Validation
# =============================================================================

# Validate sample rate
case "$ACTIVE_RATE" in
    22050|44100|48000|88200|96000|176400|192000)
        ;;
    *)
        log_warn "Unusual sample rate $ACTIVE_RATE - using anyway"
        ;;
esac

# Validate period (buffer size)
if [ "$ACTIVE_PERIOD" -lt 16 ] || [ "$ACTIVE_PERIOD" -gt 8192 ]; then
    log_warn "Period $ACTIVE_PERIOD outside typical range (16-8192)"
fi

# Validate nperiods
if [ "$ACTIVE_NPERIODS" -lt 2 ] || [ "$ACTIVE_NPERIODS" -gt 8 ]; then
    log_warn "Nperiods $ACTIVE_NPERIODS outside typical range (2-8)"
fi

# Calculate latency for logging
LATENCY_MS=$(echo "scale=2; ($ACTIVE_PERIOD * $ACTIVE_NPERIODS) / $ACTIVE_RATE * 1000" | bc)
ACTIVE_DESC="Custom (${ACTIVE_RATE}Hz, ${ACTIVE_NPERIODS}x${ACTIVE_PERIOD}, ~${LATENCY_MS}ms)"

# =============================================================================
# Debug Logging
# =============================================================================
log_config_debug() {
    log_debug "CONFIG - ACTUAL_USER: ${ACTUAL_USER:-unset}"
    log_debug "CONFIG - USER_CONFIG_FILE: $USER_CONFIG_FILE"
    log_debug "CONFIG - SYSTEM_CONFIG_FILE: $SYSTEM_CONFIG_FILE"
    log_debug "CONFIG - Config source: $config_source"
    log_debug "CONFIG - Audio Device: $ACTIVE_AUDIO_DEVICE"
    log_debug "CONFIG - Device Pattern: ${ACTIVE_DEVICE_PATTERN:-<none>}"
    log_debug "CONFIG - Final config: Rate=$ACTIVE_RATE, Period=$ACTIVE_PERIOD, Nperiods=$ACTIVE_NPERIODS, A2J=$ACTIVE_A2J_ENABLE"
    log_debug "CONFIG - Calculated latency: ${LATENCY_MS}ms"
}

# Log debug information
log_config_debug

# =============================================================================
# Auto-Detect Function
# =============================================================================

# Patterns to filter out internal/onboard audio devices
INTERNAL_DEVICE_PATTERNS="HDA NVidia|HDA Intel|HDA ATI|HDA AMD|HDMI|sof-|PCH"

# Auto-detect the first available USB audio interface
auto_detect_device() {
    local aplay_output
    aplay_output=$(LC_ALL=C aplay -l 2>/dev/null)

    # Parse aplay output to find USB audio devices (exclude internal devices)
    while IFS= read -r line; do
        if [[ "$line" =~ ^card\ ([0-9]+):\ ([a-zA-Z0-9_]+)\ \[([^\]]+)\] ]]; then
            # card_num unused but kept for regex clarity: local card_num="${BASH_REMATCH[1]}"
            local card_id="${BASH_REMATCH[2]}"
            local card_name="${BASH_REMATCH[3]}"

            # Skip internal devices
            if echo "$card_name $card_id" | grep -qiE "$INTERNAL_DEVICE_PATTERNS"; then
                continue
            fi

            # Found an external USB audio device
            echo "hw:${card_id},0"
            return 0
        fi
    done <<< "$aplay_output"

    return 1
}

# =============================================================================
# Hardware Check and Auto-Detection
# =============================================================================

# ALWAYS auto-detect the currently available device
# This ensures hotplug works correctly when switching between devices
# The config file is only used for audio parameters (rate, period, nperiods)

log "Auto-detecting available audio interface..."
detected_device=$(auto_detect_device)

if [ -n "$detected_device" ]; then
    # Extract card_id for pattern
    detected_card_id=$(echo "$detected_device" | sed -n 's/hw:\([^,]*\).*/\1/p')

    if [ "$detected_device" != "$ACTIVE_AUDIO_DEVICE" ]; then
        log "Auto-detected audio device: $detected_device (config had: $ACTIVE_AUDIO_DEVICE)"
        echo "Auto-detected audio device: $detected_device"
    else
        log "Using configured audio device: $detected_device"
    fi

    ACTIVE_AUDIO_DEVICE="$detected_device"
    ACTIVE_DEVICE_PATTERN="$detected_card_id"

    # Recalculate description
    ACTIVE_DESC="Custom (${ACTIVE_RATE}Hz, ${ACTIVE_NPERIODS}x${ACTIVE_PERIOD}, ~${LATENCY_MS}ms)"
else
    fail "No audio interface found. Please connect a USB audio device."
fi

# =============================================================================
# JACK Configuration and Start
# =============================================================================

# Check JACK status and stop if running
echo "Checking JACK status..."
log "Checking JACK status..."
if jack_control status 2>/dev/null | grep -q "started"; then
    echo "JACK is running - stopping for parameter configuration..."
    log "JACK is running - stopping for parameter configuration..."
    jack_control stop
    sleep 1
fi

# Configure JACK parameters
echo "Configuring JACK with $ACTIVE_DESC..."
echo "Using audio device: $ACTIVE_AUDIO_DEVICE"
log "Configuring JACK: Device=$ACTIVE_AUDIO_DEVICE, Rate=$ACTIVE_RATE, Periods=$ACTIVE_NPERIODS, Period=$ACTIVE_PERIOD"

jack_control ds alsa
jack_control dps device "$ACTIVE_AUDIO_DEVICE"
jack_control dps rate "$ACTIVE_RATE"
jack_control dps nperiods "$ACTIVE_NPERIODS"
jack_control dps period "$ACTIVE_PERIOD"

# Start JACK
echo "Starting JACK server with new parameters..."
log "Starting JACK server..."
jack_control start || fail "JACK server could not be started"

# Verify status
jack_control status || fail "JACK server is not running correctly"

# =============================================================================
# A2J MIDI Bridge (Optional)
# =============================================================================

# Helper function to safely call a2j_control (handles DBus errors at early boot)
safe_a2j_control() {
    local cmd="$1"
    local result
    result=$(a2j_control "$cmd" 2>&1)
    local exit_code=$?

    # Check for DBus errors
    if echo "$result" | grep -qi "dbus\|autolaunch"; then
        log_warn "a2j_control $cmd failed - DBus not available"
        echo "Note: a2j_control $cmd unavailable (DBus not ready)"
        return 1
    fi

    if [ $exit_code -ne 0 ]; then
        log_warn "a2j_control $cmd returned $exit_code: $result"
    fi
    return $exit_code
}

# Helper function to safely check a2j status (handles DBus errors at early boot)
check_a2j_bridge_active() {
    local status
    status=$(a2j_control --status 2>&1)

    # Check for DBus errors - if DBus not ready, assume not active
    if echo "$status" | grep -qi "dbus\|autolaunch"; then
        return 1
    fi

    # Check if bridging is enabled
    if echo "$status" | grep -q "Bridging enabled"; then
        return 0
    fi
    return 1
}

# Convert string to boolean
case "${ACTIVE_A2J_ENABLE,,}" in
    true|yes|1|on)
        A2J_SHOULD_START=true
        ;;
    *)
        A2J_SHOULD_START=false
        ;;
esac

if [ "$A2J_SHOULD_START" = true ]; then
    echo "Starting ALSA-MIDI Bridge with --export-hw..."
    log "Starting ALSA-MIDI Bridge (A2J_ENABLE=$ACTIVE_A2J_ENABLE)..."

    # Check if a2j bridge is already active (handles DBus errors)
    if check_a2j_bridge_active; then
        echo "A2J MIDI Bridge is already active."
        log "A2J MIDI Bridge is already active."
    else
        # Enable hardware export (allows ALSA apps to still access hardware)
        safe_a2j_control --ehw || echo "Hardware export possibly already enabled"

        # Start A2J bridge
        safe_a2j_control --start || echo "A2J MIDI Bridge could not be started, possibly already active"

        # Check and log Real-Time priority for a2j
        sleep 1  # Brief wait for a2j process to start
        a2j_pid=$(pgrep a2j)
        if [ -n "$a2j_pid" ]; then
            rt_class=$(ps -o cls= -p "$a2j_pid" 2>/dev/null | tr -d ' ')
            if [ "$rt_class" = "FF" ]; then
                echo "A2J is running with Real-Time priority"
                log "A2J running with Real-Time priority (PID: $a2j_pid)"
            else
                echo "A2J is running without Real-Time priority - this is normal"
                log "A2J running without RT priority (PID: $a2j_pid, Class: $rt_class)"
            fi
        fi
    fi
else
    echo "A2J MIDI Bridge disabled (A2J_ENABLE=false)"
    log "A2J MIDI Bridge disabled by configuration"

    # Stop a2j if it's running (handles DBus errors)
    if check_a2j_bridge_active || pgrep -x "a2jmidid" > /dev/null 2>&1; then
        echo "Stopping existing A2J MIDI Bridge..."
        log "Stopping A2J MIDI Bridge as it's disabled in config"
        if ! safe_a2j_control --stop; then
            # Fallback: use killall if a2j_control fails
            killall a2jmidid 2>/dev/null || true
        fi
    fi
fi

# =============================================================================
# Success Message
# =============================================================================
echo ""
echo "=== JACK Audio System Started Successfully ==="
echo "Audio Device: $ACTIVE_AUDIO_DEVICE"
echo "Configuration: $ACTIVE_DESC"
echo "  Sample Rate: $ACTIVE_RATE Hz"
echo "  Buffer Size: $ACTIVE_PERIOD frames"
echo "  Periods: $ACTIVE_NPERIODS"
echo "  Latency: ~${LATENCY_MS} ms"
echo "  A2J MIDI Bridge: $ACTIVE_A2J_ENABLE"
echo "=============================================="

log "JACK Audio System started successfully: Device=$ACTIVE_AUDIO_DEVICE, $ACTIVE_DESC (A2J: $ACTIVE_A2J_ENABLE)"

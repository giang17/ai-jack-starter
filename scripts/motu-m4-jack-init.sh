#!/bin/bash

# =============================================================================
# MOTU M4 JACK Initialization Script - v2.0
# =============================================================================
# Flexible JACK configuration with customizable sample rate, buffer size,
# and periods. Reads configuration from config file or uses defaults.
#
# Configuration file format (v2.0):
#   JACK_RATE=48000
#   JACK_PERIOD=256
#   JACK_NPERIODS=3
#
# Legacy format (v1.x) is still supported:
#   JACK_SETTING=1|2|3
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Log file path (consistent with other scripts)
LOG="/run/motu-m4/jack-init.log"

# Ensure log directory exists
mkdir -p /run/motu-m4 2>/dev/null || true

# =============================================================================
# Default Configuration
# =============================================================================
DEFAULT_RATE=48000
DEFAULT_PERIOD=256
DEFAULT_NPERIODS=3
DEFAULT_A2J_ENABLE=false

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
SYSTEM_CONFIG_FILE="/etc/motu-m4/jack-setting.conf"

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
    USER_CONFIG_FILE="/home/$ACTUAL_USER/.config/motu-m4/jack-setting.conf"
else
    USER_CONFIG_FILE="$HOME/.config/motu-m4/jack-setting.conf"
fi

# =============================================================================
# Logging Functions
# =============================================================================
log() {
    echo "$(date): $1" >> $LOG
}

fail() {
    echo "ERROR: $1"
    log "ERROR: $1"
    exit 1
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

# Check if config file uses new v2.0 format
is_v2_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        if grep -q "^JACK_RATE=" "$config_file" || \
           grep -q "^JACK_PERIOD=" "$config_file" || \
           grep -q "^JACK_NPERIODS=" "$config_file"; then
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

# Load configuration from file (supports both v1.x and v2.0 formats)
load_config_from_file() {
    local config_file="$1"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    # Check for v2.0 format first
    if is_v2_config "$config_file"; then
        local rate
        local period
        local nperiods
        local a2j_enable
        rate=$(read_config_value "$config_file" "JACK_RATE")
        period=$(read_config_value "$config_file" "JACK_PERIOD")
        nperiods=$(read_config_value "$config_file" "JACK_NPERIODS")
        a2j_enable=$(read_config_value "$config_file" "A2J_ENABLE")

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

        log "Loaded v2.0 config from $config_file: Rate=$ACTIVE_RATE, Period=$ACTIVE_PERIOD, Nperiods=$ACTIVE_NPERIODS, A2J=$ACTIVE_A2J_ENABLE"
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

# Configuration priority:
# 1. Environment variables (JACK_RATE, JACK_PERIOD, JACK_NPERIODS)
# 2. User config file (~/.config/motu-m4/jack-setting.conf)
# 3. System config file (/etc/motu-m4/jack-setting.conf)
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
        log "WARNING: Unusual sample rate $ACTIVE_RATE - using anyway"
        ;;
esac

# Validate period (buffer size)
if [ "$ACTIVE_PERIOD" -lt 16 ] || [ "$ACTIVE_PERIOD" -gt 8192 ]; then
    log "WARNING: Period $ACTIVE_PERIOD outside typical range (16-8192)"
fi

# Validate nperiods
if [ "$ACTIVE_NPERIODS" -lt 2 ] || [ "$ACTIVE_NPERIODS" -gt 8 ]; then
    log "WARNING: Nperiods $ACTIVE_NPERIODS outside typical range (2-8)"
fi

# Calculate latency for logging
LATENCY_MS=$(echo "scale=2; ($ACTIVE_PERIOD * $ACTIVE_NPERIODS) / $ACTIVE_RATE * 1000" | bc)
ACTIVE_DESC="Custom (${ACTIVE_RATE}Hz, ${ACTIVE_NPERIODS}x${ACTIVE_PERIOD}, ~${LATENCY_MS}ms)"

# =============================================================================
# Debug Logging
# =============================================================================
log_config_debug() {
    {
        echo "$(date): CONFIG DEBUG - ACTUAL_USER: ${ACTUAL_USER:-unset}"
        echo "$(date): CONFIG DEBUG - USER_CONFIG_FILE: $USER_CONFIG_FILE"
        echo "$(date): CONFIG DEBUG - SYSTEM_CONFIG_FILE: $SYSTEM_CONFIG_FILE"
        echo "$(date): CONFIG DEBUG - Config source: $config_source"
        echo "$(date): CONFIG DEBUG - Final config: Rate=$ACTIVE_RATE, Period=$ACTIVE_PERIOD, Nperiods=$ACTIVE_NPERIODS, A2J=$ACTIVE_A2J_ENABLE"
        echo "$(date): CONFIG DEBUG - Calculated latency: ${LATENCY_MS}ms"
    } >> $LOG
}

# Log debug information
log_config_debug

# =============================================================================
# Hardware Check
# =============================================================================

# Check if M4 interface is available
if ! aplay -l | grep -q "M4"; then
    fail "MOTU M4 Audio Interface not found. Please connect or power on the device."
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
log "Configuring JACK: Rate=$ACTIVE_RATE, Periods=$ACTIVE_NPERIODS, Period=$ACTIVE_PERIOD"

jack_control ds alsa
jack_control dps device hw:M4,0
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
        log "WARNING: a2j_control $cmd failed - DBus not available"
        echo "Note: a2j_control $cmd unavailable (DBus not ready)"
        return 1
    fi

    if [ $exit_code -ne 0 ]; then
        log "WARNING: a2j_control $cmd returned $exit_code: $result"
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
echo "Configuration: $ACTIVE_DESC"
echo "  Sample Rate: $ACTIVE_RATE Hz"
echo "  Buffer Size: $ACTIVE_PERIOD frames"
echo "  Periods: $ACTIVE_NPERIODS"
echo "  Latency: ~${LATENCY_MS} ms"
echo "  A2J MIDI Bridge: $ACTIVE_A2J_ENABLE"
echo "=============================================="

log "JACK Audio System started successfully: $ACTIVE_DESC (A2J: $ACTIVE_A2J_ENABLE)"

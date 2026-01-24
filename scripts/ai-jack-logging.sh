#!/bin/bash

# =============================================================================
# Audio Interface JACK Logging Library - v1.0
# =============================================================================
# Centralized structured logging with log levels (DEBUG, INFO, WARN, ERROR).
# Source this file in other scripts to use the logging functions.
#
# Usage:
#   source /usr/local/bin/ai-jack-logging.sh
#   init_logging "script-name"  # Optional: sets LOG_PREFIX
#   log_debug "Debug message"
#   log_info "Info message"
#   log_warn "Warning message"
#   log_error "Error message"
#
# Log Levels (from most to least verbose):
#   DEBUG (0) - Detailed debugging information
#   INFO  (1) - General operational information
#   WARN  (2) - Warning conditions
#   ERROR (3) - Error conditions
#
# Environment Variables:
#   AI_JACK_LOG_LEVEL - Minimum log level to output (default: INFO)
#   AI_JACK_LOG_FILE  - Override default log file path
#   AI_JACK_LOG_CONSOLE - Also output to console (true/false, default: false)
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# =============================================================================
# Log Level Definitions
# =============================================================================
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Map level names to numbers
declare -A LOG_LEVEL_MAP=(
    ["DEBUG"]=$LOG_LEVEL_DEBUG
    ["INFO"]=$LOG_LEVEL_INFO
    ["WARN"]=$LOG_LEVEL_WARN
    ["ERROR"]=$LOG_LEVEL_ERROR
)

# Map level numbers to names (reserved for future use)
# shellcheck disable=SC2034
declare -a LOG_LEVEL_NAMES=("DEBUG" "INFO" "WARN" "ERROR")

# =============================================================================
# Configuration
# =============================================================================

# Default log level (can be overridden by AI_JACK_LOG_LEVEL env var)
AI_JACK_LOG_LEVEL="${AI_JACK_LOG_LEVEL:-INFO}"

# Whether to also output to console
AI_JACK_LOG_CONSOLE="${AI_JACK_LOG_CONSOLE:-false}"

# Log prefix (script name, set via init_logging)
LOG_PREFIX=""

# Log file path (set via init_logging or AI_JACK_LOG_FILE env var)
LOG_FILE=""

# =============================================================================
# Internal Functions
# =============================================================================

# Get numeric log level from string
_get_log_level_num() {
    local level_str="${1^^}"  # Convert to uppercase
    echo "${LOG_LEVEL_MAP[$level_str]:-$LOG_LEVEL_INFO}"
}

# Get log directory based on permissions
_get_log_dir() {
    if mkdir -p /run/ai-jack 2>/dev/null && [ -w /run/ai-jack ]; then
        echo "/run/ai-jack"
    else
        mkdir -p /tmp/ai-jack 2>/dev/null
        echo "/tmp/ai-jack"
    fi
}

# Format timestamp
_get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Core logging function
_log() {
    local level_num=$1
    local level_name=$2
    local message=$3

    # Get configured minimum log level
    local min_level_num
    min_level_num=$(_get_log_level_num "$AI_JACK_LOG_LEVEL")

    # Skip if message level is below minimum
    if [ "$level_num" -lt "$min_level_num" ]; then
        return 0
    fi

    # Format the log entry
    local timestamp
    timestamp=$(_get_timestamp)
    local prefix=""
    [ -n "$LOG_PREFIX" ] && prefix="[$LOG_PREFIX] "

    local log_entry="$timestamp [$level_name] ${prefix}$message"

    # Write to log file
    if [ -n "$LOG_FILE" ]; then
        echo "$log_entry" >> "$LOG_FILE" 2>/dev/null
    fi

    # Optionally write to console
    if [ "$AI_JACK_LOG_CONSOLE" = "true" ]; then
        # Use stderr for WARN and ERROR, stdout for others
        if [ "$level_num" -ge "$LOG_LEVEL_WARN" ]; then
            echo "$log_entry" >&2
        else
            echo "$log_entry"
        fi
    fi
}

# =============================================================================
# Public Logging Functions
# =============================================================================

# Initialize logging for a script
# Usage: init_logging "script-name" ["log-filename"]
init_logging() {
    local script_name="$1"
    local log_filename="${2:-}"

    LOG_PREFIX="$script_name"

    # Set log file path
    if [ -n "$AI_JACK_LOG_FILE" ]; then
        LOG_FILE="$AI_JACK_LOG_FILE"
    elif [ -n "$log_filename" ]; then
        LOG_FILE="$(_get_log_dir)/$log_filename"
    else
        LOG_FILE="$(_get_log_dir)/ai-jack.log"
    fi

    # Ensure log directory exists
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir" 2>/dev/null
}

# Log at DEBUG level
log_debug() {
    _log $LOG_LEVEL_DEBUG "DEBUG" "$1"
}

# Log at INFO level
log_info() {
    _log $LOG_LEVEL_INFO "INFO" "$1"
}

# Log at WARN level
log_warn() {
    _log $LOG_LEVEL_WARN "WARN" "$1"
}

# Log at ERROR level
log_error() {
    _log $LOG_LEVEL_ERROR "ERROR" "$1"
}

# Legacy compatibility: simple log function (maps to INFO)
log_message() {
    log_info "$1"
}

# Fail function: logs error and exits
fail() {
    local message="$1"
    local exit_code="${2:-1}"

    log_error "$message"

    # Also output to stderr for immediate visibility
    echo "ERROR: $message" >&2

    exit "$exit_code"
}

# =============================================================================
# Utility Functions
# =============================================================================

# Log a separator line (useful for marking script start/end)
log_separator() {
    local char="${1:--}"
    local length="${2:-60}"
    local line=""
    for ((i=0; i<length; i++)); do
        line="${line}${char}"
    done
    log_info "$line"
}

# Log script start
log_script_start() {
    local script_name="${1:-$LOG_PREFIX}"
    log_info "========== $script_name started =========="
}

# Log script end
log_script_end() {
    local script_name="${1:-$LOG_PREFIX}"
    log_info "========== $script_name completed =========="
}

# Set log level at runtime
set_log_level() {
    AI_JACK_LOG_LEVEL="${1^^}"
}

# Enable/disable console output at runtime
set_console_output() {
    AI_JACK_LOG_CONSOLE="$1"
}

# Get current log file path
get_log_file() {
    echo "$LOG_FILE"
}

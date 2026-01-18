#!/bin/bash

# =============================================================================
# MOTU M4 JACK System-wide Setting Configuration - v2.0
# =============================================================================
# Script for system-wide JACK configuration (requires sudo)
#
# Usage (v2.0 - flexible):
#   sudo ./motu-m4-jack-setting-system.sh --rate=48000 --period=256 --nperiods=3 [--restart]
#
# Usage (v1.x compatible - presets):
#   sudo ./motu-m4-jack-setting-system.sh [1|2|3|show|remove|help] [--restart]
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Paths
SYSTEM_CONFIG_DIR="/etc/motu-m4"
SYSTEM_CONFIG_FILE="$SYSTEM_CONFIG_DIR/jack-setting.conf"

# =============================================================================
# Preset Definitions (for backward compatibility)
# =============================================================================
PRESET1_RATE=48000
PRESET1_NPERIODS=2
PRESET1_PERIOD=128
PRESET1_NAME="Low Latency"

PRESET2_RATE=48000
PRESET2_NPERIODS=2
PRESET2_PERIOD=256
PRESET2_NAME="Medium Latency"

PRESET3_RATE=48000
PRESET3_NPERIODS=2
PRESET3_PERIOD=64
PRESET3_NAME="Ultra-Low Latency"

# =============================================================================
# Valid Values
# =============================================================================
VALID_RATES="22050 44100 48000 88200 96000 176400 192000"
VALID_PERIODS="16 32 64 128 256 512 1024 2048 4096"

# =============================================================================
# Helper Functions
# =============================================================================

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error:${NC} This script requires root privileges."
        echo "Please run with sudo: sudo $0 $@"
        exit 1
    fi
}

# Calculate latency in milliseconds
calc_latency() {
    local rate=$1
    local period=$2
    local nperiods=$3
    echo "scale=1; ($period * $nperiods) / $rate * 1000" | bc
}

# Validate sample rate
validate_rate() {
    local rate=$1
    for valid in $VALID_RATES; do
        if [ "$rate" = "$valid" ]; then
            return 0
        fi
    done
    return 1
}

# Validate period (buffer size)
validate_period() {
    local period=$1
    for valid in $VALID_PERIODS; do
        if [ "$period" = "$valid" ]; then
            return 0
        fi
    done
    return 1
}

# Validate nperiods
validate_nperiods() {
    local nperiods=$1
    if [ "$nperiods" -ge 2 ] && [ "$nperiods" -le 8 ] 2>/dev/null; then
        return 0
    fi
    return 1
}

# =============================================================================
# Display Functions
# =============================================================================

# Show available presets
show_presets() {
    echo -e "${BLUE}Available Presets (v1.x compatible):${NC}"
    echo ""

    local latency1=$(calc_latency $PRESET1_RATE $PRESET1_PERIOD $PRESET1_NPERIODS)
    echo -e "${GREEN}Preset 1:${NC} $PRESET1_NAME"
    echo "  - Sample Rate: $(printf "%'d" $PRESET1_RATE) Hz"
    echo "  - Buffer Size: $PRESET1_PERIOD frames"
    echo "  - Periods: $PRESET1_NPERIODS"
    echo "  - Latency: ~${latency1} ms"
    echo ""

    local latency2=$(calc_latency $PRESET2_RATE $PRESET2_PERIOD $PRESET2_NPERIODS)
    echo -e "${GREEN}Preset 2:${NC} $PRESET2_NAME"
    echo "  - Sample Rate: $(printf "%'d" $PRESET2_RATE) Hz"
    echo "  - Buffer Size: $PRESET2_PERIOD frames"
    echo "  - Periods: $PRESET2_NPERIODS"
    echo "  - Latency: ~${latency2} ms"
    echo ""

    local latency3=$(calc_latency $PRESET3_RATE $PRESET3_PERIOD $PRESET3_NPERIODS)
    echo -e "${GREEN}Preset 3:${NC} $PRESET3_NAME"
    echo "  - Sample Rate: $(printf "%'d" $PRESET3_RATE) Hz"
    echo "  - Buffer Size: $PRESET3_PERIOD frames"
    echo "  - Periods: $PRESET3_NPERIODS"
    echo "  - Latency: ~${latency3} ms"
    echo ""
}

# Show valid values for custom configuration
show_valid_values() {
    echo -e "${BLUE}Valid Values for Custom Configuration:${NC}"
    echo ""
    echo -e "${CYAN}Sample Rates:${NC}"
    echo "  22050, 44100, 48000, 88200, 96000, 176400, 192000 Hz"
    echo ""
    echo -e "${CYAN}Buffer Sizes (frames):${NC}"
    echo "  16, 32, 64, 128, 256, 512, 1024, 2048, 4096"
    echo ""
    echo -e "${CYAN}Periods:${NC}"
    echo "  2 - 8 (integer)"
    echo ""
}

# Show current system-wide configuration
show_current() {
    echo -e "${BLUE}System-wide JACK Configuration:${NC}"
    echo ""

    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        # Check for v2.0 format
        local rate=$(grep "^JACK_RATE=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        local period=$(grep "^JACK_PERIOD=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        local nperiods=$(grep "^JACK_NPERIODS=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

        if [ -n "$rate" ] || [ -n "$period" ] || [ -n "$nperiods" ]; then
            # v2.0 format
            rate=${rate:-48000}
            period=${period:-256}
            nperiods=${nperiods:-3}

            local latency=$(calc_latency $rate $period $nperiods)

            echo -e "${GREEN}Configuration Format:${NC} v2.0 (flexible)"
            echo ""
            echo -e "${CYAN}Sample Rate:${NC}  $(printf "%'d" $rate) Hz"
            echo -e "${CYAN}Buffer Size:${NC}  $period frames"
            echo -e "${CYAN}Periods:${NC}      $nperiods"
            echo -e "${CYAN}Latency:${NC}      ~${latency} ms"
            echo ""
            echo -e "${BLUE}Config File:${NC} $SYSTEM_CONFIG_FILE"
        else
            # Check for legacy v1.x format
            local setting=$(grep "^JACK_SETTING=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

            if [ -n "$setting" ]; then
                echo -e "${GREEN}Configuration Format:${NC} v1.x (legacy preset)"
                echo -e "${CYAN}Active Preset:${NC} $setting"

                case "$setting" in
                    1)
                        local latency=$(calc_latency $PRESET1_RATE $PRESET1_PERIOD $PRESET1_NPERIODS)
                        echo -e "${CYAN}Description:${NC}   $PRESET1_NAME (${PRESET1_RATE}Hz, ${PRESET1_NPERIODS}x${PRESET1_PERIOD}, ~${latency}ms)"
                        ;;
                    2)
                        local latency=$(calc_latency $PRESET2_RATE $PRESET2_PERIOD $PRESET2_NPERIODS)
                        echo -e "${CYAN}Description:${NC}   $PRESET2_NAME (${PRESET2_RATE}Hz, ${PRESET2_NPERIODS}x${PRESET2_PERIOD}, ~${latency}ms)"
                        ;;
                    3)
                        local latency=$(calc_latency $PRESET3_RATE $PRESET3_PERIOD $PRESET3_NPERIODS)
                        echo -e "${CYAN}Description:${NC}   $PRESET3_NAME (${PRESET3_RATE}Hz, ${PRESET3_NPERIODS}x${PRESET3_PERIOD}, ~${latency}ms)"
                        ;;
                esac
                echo ""
                echo -e "${BLUE}Config File:${NC} $SYSTEM_CONFIG_FILE"
                echo ""
                echo -e "${YELLOW}Tip:${NC} Consider upgrading to v2.0 format for more flexibility."
            else
                echo -e "${YELLOW}Config file exists but has unknown format${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}No system-wide configuration found${NC}"
        echo "Using default: Preset 1 - Low Latency (48kHz, 3x256, ~5.3ms)"
    fi
}

# =============================================================================
# Configuration Functions
# =============================================================================

# Set system-wide configuration with v2.0 format
set_custom_setting() {
    local rate=$1
    local period=$2
    local nperiods=$3
    local restart_flag=$4

    # Validate parameters
    if ! validate_rate "$rate"; then
        echo -e "${RED}Error:${NC} Invalid sample rate '$rate'"
        echo "Valid rates: $VALID_RATES"
        exit 1
    fi

    if ! validate_period "$period"; then
        echo -e "${RED}Error:${NC} Invalid buffer size '$period'"
        echo "Valid sizes: $VALID_PERIODS"
        exit 1
    fi

    if ! validate_nperiods "$nperiods"; then
        echo -e "${RED}Error:${NC} Invalid periods '$nperiods'"
        echo "Valid range: 2-8"
        exit 1
    fi

    # Create directory if not present
    mkdir -p "$SYSTEM_CONFIG_DIR"

    # Calculate latency
    local latency=$(calc_latency $rate $period $nperiods)

    # Create configuration file (v2.0 format)
    cat > "$SYSTEM_CONFIG_FILE" << EOF
# MOTU M4 JACK System-wide Configuration
# Format: v2.0
# Generated by motu-m4-jack-setting-system.sh on $(date)
#
# Sample Rate: $(printf "%'d" $rate) Hz
# Buffer Size: $period frames
# Periods: $nperiods
# Calculated Latency: ~${latency} ms

JACK_RATE=$rate
JACK_PERIOD=$period
JACK_NPERIODS=$nperiods
EOF

    # Set permissions (readable for all)
    chmod 644 "$SYSTEM_CONFIG_FILE"

    echo -e "${GREEN}System-wide configuration saved!${NC}"
    echo ""
    echo -e "${CYAN}Sample Rate:${NC}  $(printf "%'d" $rate) Hz"
    echo -e "${CYAN}Buffer Size:${NC}  $period frames"
    echo -e "${CYAN}Periods:${NC}      $nperiods"
    echo -e "${CYAN}Latency:${NC}      ~${latency} ms"
    echo ""
    echo -e "${BLUE}Saved to:${NC} $SYSTEM_CONFIG_FILE"

    # Warning for very low latency
    if [ "$(echo "$latency < 3" | bc)" -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}Warning:${NC} Very low latency (~${latency}ms) may cause audio glitches"
        echo "on systems that are not optimized for real-time audio."
    fi

    # Automatic restart if requested
    if [ "$restart_flag" = "--restart" ] || [ "$restart_flag" = "-r" ]; then
        perform_jack_restart
    fi
}

# Set legacy preset (v1.x compatibility)
set_preset() {
    local preset=$1
    local restart_flag=$2

    case "$preset" in
        1)
            set_custom_setting $PRESET1_RATE $PRESET1_PERIOD $PRESET1_NPERIODS "$restart_flag"
            ;;
        2)
            set_custom_setting $PRESET2_RATE $PRESET2_PERIOD $PRESET2_NPERIODS "$restart_flag"
            ;;
        3)
            set_custom_setting $PRESET3_RATE $PRESET3_PERIOD $PRESET3_NPERIODS "$restart_flag"
            ;;
        *)
            echo -e "${RED}Error:${NC} Invalid preset '$preset'. Use 1, 2, or 3."
            exit 1
            ;;
    esac
}

# Remove system-wide configuration
remove_system_setting() {
    if [ -f "$SYSTEM_CONFIG_FILE" ]; then
        rm -f "$SYSTEM_CONFIG_FILE"
        echo -e "${GREEN}System-wide configuration removed!${NC}"
        echo "The system will now use the default settings (Low Latency: 48kHz, 3x256)"

        # Remove directory if empty
        if [ -d "$SYSTEM_CONFIG_DIR" ] && [ -z "$(ls -A "$SYSTEM_CONFIG_DIR")" ]; then
            rmdir "$SYSTEM_CONFIG_DIR"
            echo "Empty configuration directory removed."
        fi
    else
        echo -e "${YELLOW}No system-wide configuration found${NC}"
    fi
}

# =============================================================================
# JACK Restart Function
# =============================================================================

perform_jack_restart() {
    echo ""
    echo -e "${BLUE}=== Automatic JACK Restart ===${NC}"

    # Check if MOTU M4 is available
    if ! aplay -l | grep -q "M4"; then
        echo -e "${YELLOW}Warning:${NC} MOTU M4 not found - restart skipped"
        echo "Please connect M4 and restart manually with:"
        echo "  sudo motu-m4-jack-restart-simple.sh"
        return 1
    fi

    # Check if JACK is running
    local jack_running=false
    if runuser -l "$(who | grep "(:" | head -n1 | awk '{print $1}')" -c "jack_control status 2>/dev/null | grep -q started" 2>/dev/null; then
        jack_running=true
    fi

    if [ "$jack_running" = false ]; then
        echo -e "${YELLOW}Info:${NC} JACK is not running - starting JACK"
    else
        echo -e "${GREEN}Info:${NC} JACK is running - restarting to apply new settings"
    fi

    # Call restart script
    if [ -f "/usr/local/bin/motu-m4-jack-restart-simple.sh" ]; then
        echo "Executing JACK restart..."
        /usr/local/bin/motu-m4-jack-restart-simple.sh
    else
        echo -e "${RED}Error:${NC} motu-m4-jack-restart-simple.sh not found in /usr/local/bin/"
        return 1
    fi

    echo -e "${GREEN}JACK restart completed!${NC}"
    echo ""
}

# =============================================================================
# Help Function
# =============================================================================

show_help() {
    echo -e "${BLUE}MOTU M4 JACK System-wide Configuration - v2.0${NC}"
    echo ""
    echo "Usage:"
    echo ""
    echo -e "${GREEN}Flexible Configuration (v2.0):${NC}"
    echo "  sudo $0 --rate=<Hz> --period=<frames> --nperiods=<n> [--restart]"
    echo ""
    echo -e "${GREEN}Quick Presets (v1.x compatible):${NC}"
    echo "  sudo $0 [1|2|3] [--restart]"
    echo ""
    echo -e "${GREEN}Other Commands:${NC}"
    echo "  sudo $0 show      - Show all presets and valid values"
    echo "  sudo $0 current   - Show current configuration"
    echo "  sudo $0 remove    - Remove system-wide configuration"
    echo "  sudo $0 help      - Show this help"
    echo ""
    echo -e "${CYAN}Parameters:${NC}"
    echo "  --rate=<Hz>       Sample rate (22050-192000)"
    echo "  --period=<frames> Buffer size (16-4096)"
    echo "  --nperiods=<n>    Number of periods (2-8)"
    echo "  --restart, -r     Automatically restart JACK after changes"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  # Custom high-quality configuration"
    echo "  sudo $0 --rate=96000 --period=256 --nperiods=2 --restart"
    echo ""
    echo "  # Ultra-low latency for live performance"
    echo "  sudo $0 --rate=48000 --period=64 --nperiods=3 --restart"
    echo ""
    echo "  # Use preset 2 (Medium Latency)"
    echo "  sudo $0 2 --restart"
    echo ""
    echo -e "${CYAN}Configuration Priority:${NC}"
    echo "  1. Environment variables (JACK_RATE, JACK_PERIOD, JACK_NPERIODS)"
    echo "  2. User config (~/.config/motu-m4/jack-setting.conf)"
    echo "  3. System config (/etc/motu-m4/jack-setting.conf)"
    echo "  4. Default (48000 Hz, 256 frames, 3 periods)"
    echo ""
}

# =============================================================================
# Argument Parsing
# =============================================================================

parse_arguments() {
    local rate=""
    local period=""
    local nperiods=""
    local restart_flag=""
    local preset=""
    local command=""

    for arg in "$@"; do
        case "$arg" in
            --rate=*)
                rate="${arg#*=}"
                ;;
            --period=*)
                period="${arg#*=}"
                ;;
            --nperiods=*)
                nperiods="${arg#*=}"
                ;;
            --restart|-r)
                restart_flag="--restart"
                ;;
            1|2|3)
                preset="$arg"
                ;;
            show|current|remove|help|-h|--help)
                command="$arg"
                ;;
            *)
                echo -e "${RED}Error:${NC} Unknown argument '$arg'"
                echo "Use '$0 help' for more information."
                exit 1
                ;;
        esac
    done

    # Handle commands
    if [ -n "$command" ]; then
        case "$command" in
            show)
                show_presets
                echo ""
                show_valid_values
                ;;
            current)
                show_current
                ;;
            remove)
                check_root
                remove_system_setting
                ;;
            help|-h|--help)
                show_help
                ;;
        esac
        exit 0
    fi

    # Handle preset (legacy mode)
    if [ -n "$preset" ] && [ -z "$rate" ] && [ -z "$period" ] && [ -z "$nperiods" ]; then
        check_root
        set_preset "$preset" "$restart_flag"
        exit 0
    fi

    # Handle custom configuration
    if [ -n "$rate" ] || [ -n "$period" ] || [ -n "$nperiods" ]; then
        check_root

        # Use defaults for missing values
        rate=${rate:-48000}
        period=${period:-256}
        nperiods=${nperiods:-3}

        set_custom_setting "$rate" "$period" "$nperiods" "$restart_flag"
        exit 0
    fi

    # No arguments - show current and help
    echo -e "${YELLOW}No options specified.${NC}"
    echo ""
    show_current
    echo ""
    show_presets
    echo "Use '$0 help' for more information."
}

# =============================================================================
# Main Entry Point
# =============================================================================

parse_arguments "$@"

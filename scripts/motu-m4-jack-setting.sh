#!/bin/bash

# =============================================================================
# MOTU M4 JACK Setting Helper - v2.0
# =============================================================================
# Helper script for easy JACK configuration selection (user-level)
#
# Usage (v2.0 - flexible):
#   ./motu-m4-jack-setting.sh --rate=48000 --period=256 --nperiods=3 [--restart]
#
# Usage (v1.x compatible - presets):
#   ./motu-m4-jack-setting.sh [1|2|3|show|help] [--restart]
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

# User config path
USER_CONFIG_DIR="$HOME/.config/motu-m4"
USER_CONFIG_FILE="$USER_CONFIG_DIR/jack-setting.conf"
SYSTEM_CONFIG_FILE="/etc/motu-m4/jack-setting.conf"

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
    echo -e "${BLUE}Available Presets:${NC}"
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

# Show current configuration
show_current() {
    echo -e "${BLUE}Current JACK Configuration:${NC}"
    echo ""

    local config_source="default"
    local rate=""
    local period=""
    local nperiods=""

    # Check user config first
    if [ -f "$USER_CONFIG_FILE" ]; then
        config_source="user config ($USER_CONFIG_FILE)"

        # Check for v2.0 format
        rate=$(grep "^JACK_RATE=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        period=$(grep "^JACK_PERIOD=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        nperiods=$(grep "^JACK_NPERIODS=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

        if [ -z "$rate" ] && [ -z "$period" ] && [ -z "$nperiods" ]; then
            # Check for legacy format
            local setting=$(grep "^JACK_SETTING=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            if [ -n "$setting" ]; then
                case "$setting" in
                    1) rate=$PRESET1_RATE; period=$PRESET1_PERIOD; nperiods=$PRESET1_NPERIODS ;;
                    2) rate=$PRESET2_RATE; period=$PRESET2_PERIOD; nperiods=$PRESET2_NPERIODS ;;
                    3) rate=$PRESET3_RATE; period=$PRESET3_PERIOD; nperiods=$PRESET3_NPERIODS ;;
                esac
                echo -e "${YELLOW}Note:${NC} Using legacy v1.x format (preset $setting)"
            fi
        fi
    elif [ -f "$SYSTEM_CONFIG_FILE" ]; then
        config_source="system config ($SYSTEM_CONFIG_FILE)"

        rate=$(grep "^JACK_RATE=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        period=$(grep "^JACK_PERIOD=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
        nperiods=$(grep "^JACK_NPERIODS=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')

        if [ -z "$rate" ] && [ -z "$period" ] && [ -z "$nperiods" ]; then
            local setting=$(grep "^JACK_SETTING=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
            if [ -n "$setting" ]; then
                case "$setting" in
                    1) rate=$PRESET1_RATE; period=$PRESET1_PERIOD; nperiods=$PRESET1_NPERIODS ;;
                    2) rate=$PRESET2_RATE; period=$PRESET2_PERIOD; nperiods=$PRESET2_NPERIODS ;;
                    3) rate=$PRESET3_RATE; period=$PRESET3_PERIOD; nperiods=$PRESET3_NPERIODS ;;
                esac
            fi
        fi
    fi

    # Use defaults if nothing found
    rate=${rate:-$PRESET1_RATE}
    period=${period:-$PRESET1_PERIOD}
    nperiods=${nperiods:-$PRESET1_NPERIODS}

    local latency=$(calc_latency $rate $period $nperiods)

    echo -e "${CYAN}Sample Rate:${NC}  $(printf "%'d" $rate) Hz"
    echo -e "${CYAN}Buffer Size:${NC}  $period frames"
    echo -e "${CYAN}Periods:${NC}      $nperiods"
    echo -e "${CYAN}Latency:${NC}      ~${latency} ms"
    echo ""
    echo -e "${BLUE}Source:${NC} $config_source"
}

# =============================================================================
# Configuration Functions
# =============================================================================

# Set user configuration with v2.0 format
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
    mkdir -p "$USER_CONFIG_DIR"

    # Calculate latency
    local latency=$(calc_latency $rate $period $nperiods)

    # Create configuration file (v2.0 format)
    cat > "$USER_CONFIG_FILE" << EOF
# MOTU M4 JACK User Configuration
# Format: v2.0
# Generated by motu-m4-jack-setting.sh on $(date)
#
# Sample Rate: $(printf "%'d" $rate) Hz
# Buffer Size: $period frames
# Periods: $nperiods
# Calculated Latency: ~${latency} ms

JACK_RATE=$rate
JACK_PERIOD=$period
JACK_NPERIODS=$nperiods
EOF

    echo -e "${GREEN}User configuration saved!${NC}"
    echo ""
    echo -e "${CYAN}Sample Rate:${NC}  $(printf "%'d" $rate) Hz"
    echo -e "${CYAN}Buffer Size:${NC}  $period frames"
    echo -e "${CYAN}Periods:${NC}      $nperiods"
    echo -e "${CYAN}Latency:${NC}      ~${latency} ms"
    echo ""
    echo -e "${BLUE}Saved to:${NC} $USER_CONFIG_FILE"

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

# Remove user configuration
remove_user_setting() {
    if [ -f "$USER_CONFIG_FILE" ]; then
        rm -f "$USER_CONFIG_FILE"
        echo -e "${GREEN}User configuration removed!${NC}"
        echo "The system will now use the system-wide or default settings."

        # Remove directory if empty
        if [ -d "$USER_CONFIG_DIR" ] && [ -z "$(ls -A "$USER_CONFIG_DIR")" ]; then
            rmdir "$USER_CONFIG_DIR"
            echo "Empty configuration directory removed."
        fi
    else
        echo -e "${YELLOW}No user configuration found${NC}"
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
        echo "  motu-m4-jack-restart-simple.sh"
        return 1
    fi

    # Check if JACK is running
    local jack_running=false
    if jack_control status 2>/dev/null | grep -q started; then
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
    echo -e "${BLUE}MOTU M4 JACK Setting Helper - v2.0${NC}"
    echo ""
    echo "Usage:"
    echo ""
    echo -e "${GREEN}Flexible Configuration (v2.0):${NC}"
    echo "  $0 --rate=<Hz> --period=<frames> --nperiods=<n> [--restart]"
    echo ""
    echo -e "${GREEN}Quick Presets (v1.x compatible):${NC}"
    echo "  $0 [1|2|3] [--restart]"
    echo ""
    echo -e "${GREEN}Other Commands:${NC}"
    echo "  $0 show      - Show all presets and valid values"
    echo "  $0 current   - Show current configuration"
    echo "  $0 remove    - Remove user configuration"
    echo "  $0 help      - Show this help"
    echo ""
    echo -e "${CYAN}Parameters:${NC}"
    echo "  --rate=<Hz>       Sample rate (22050-192000)"
    echo "  --period=<frames> Buffer size (16-4096)"
    echo "  --nperiods=<n>    Number of periods (2-8)"
    echo "  --restart, -r     Automatically restart JACK after changes"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  # Custom high-quality configuration"
    echo "  $0 --rate=96000 --period=256 --nperiods=2 --restart"
    echo ""
    echo "  # Ultra-low latency for live performance"
    echo "  $0 --rate=48000 --period=64 --nperiods=3 --restart"
    echo ""
    echo "  # Use preset 2 (Medium Latency)"
    echo "  $0 2 --restart"
    echo ""
    echo -e "${CYAN}Configuration Priority:${NC}"
    echo "  1. Environment variables (JACK_RATE, JACK_PERIOD, JACK_NPERIODS)"
    echo "  2. User config (~/.config/motu-m4/jack-setting.conf)"
    echo "  3. System config (/etc/motu-m4/jack-setting.conf)"
    echo "  4. Default (48000 Hz, 256 frames, 3 periods)"
    echo ""
    echo -e "${CYAN}Note:${NC}"
    echo "  User settings override system-wide settings."
    echo "  Use 'sudo motu-m4-jack-setting-system.sh' for system-wide config."
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
                remove_user_setting
                ;;
            help|-h|--help)
                show_help
                ;;
        esac
        exit 0
    fi

    # Handle preset (legacy mode)
    if [ -n "$preset" ] && [ -z "$rate" ] && [ -z "$period" ] && [ -z "$nperiods" ]; then
        set_preset "$preset" "$restart_flag"
        exit 0
    fi

    # Handle custom configuration
    if [ -n "$rate" ] || [ -n "$period" ] || [ -n "$nperiods" ]; then
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

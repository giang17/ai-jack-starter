#!/bin/bash

# =============================================================================
# MOTU M4 JACK Configuration Debug Script
# =============================================================================
# Analyzes the configuration priority hierarchy and displays all sources.
# Helps troubleshoot JACK configuration issues.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MOTU M4 JACK Configuration Debug ===${NC}"
echo ""

# =============================================================================
# 1. Check Environment Variables
# =============================================================================

echo -e "${BLUE}1. Environment Variables (JACK_SETTING):${NC}"
if [ -n "${JACK_SETTING:-}" ]; then
    echo -e "${GREEN}   Set: JACK_SETTING=$JACK_SETTING${NC}"
    echo -e "${YELLOW}   Priority: HIGHEST (overrides all others)${NC}"
else
    echo -e "${YELLOW}   Not set${NC}"
fi
echo ""

# =============================================================================
# 2. Check User Configuration File
# =============================================================================

echo -e "${BLUE}2. User Configuration File:${NC}"
USER_CONFIG_FILE="$HOME/.config/motu-m4/jack-setting.conf"
if [ -f "$USER_CONFIG_FILE" ]; then
    echo -e "${GREEN}   Found: $USER_CONFIG_FILE${NC}"
    echo -e "${GREEN}   Content:${NC}"
    while read -r line; do
        echo "      $line"
    done < "$USER_CONFIG_FILE"
    USER_SETTING=$(grep "^JACK_SETTING=" "$USER_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$USER_SETTING" ]; then
        echo -e "${GREEN}   Value: JACK_SETTING=$USER_SETTING${NC}"
    else
        echo -e "${RED}   No JACK_SETTING found${NC}"
    fi
else
    echo -e "${YELLOW}   Not found: $USER_CONFIG_FILE${NC}"
fi
echo ""

# =============================================================================
# 3. Check System Configuration File
# =============================================================================

echo -e "${BLUE}3. System Configuration File:${NC}"
SYSTEM_CONFIG_FILE="/etc/motu-m4/jack-setting.conf"
if [ -f "$SYSTEM_CONFIG_FILE" ]; then
    echo -e "${GREEN}   Found: $SYSTEM_CONFIG_FILE${NC}"
    echo -e "${GREEN}   Content:${NC}"
    while read -r line; do
        echo "      $line"
    done < "$SYSTEM_CONFIG_FILE"
    SYSTEM_SETTING=$(grep "^JACK_SETTING=" "$SYSTEM_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$SYSTEM_SETTING" ]; then
        echo -e "${GREEN}   Value: JACK_SETTING=$SYSTEM_SETTING${NC}"
    else
        echo -e "${RED}   No JACK_SETTING found${NC}"
    fi
else
    echo -e "${YELLOW}   Not found: $SYSTEM_CONFIG_FILE${NC}"
fi
echo ""

# =============================================================================
# 4. Simulate Priority Resolution
# =============================================================================

echo -e "${BLUE}4. Priority Resolution (as in motu-m4-jack-init.sh):${NC}"

# Function to read configuration file (copied from init script)
read_config_file() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        local setting
        setting=$(grep "^JACK_SETTING=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$setting" ]; then
            echo "$setting"
            return 0
        fi
    fi
    return 1
}

# Setting selection with fallback mechanism (copied from init script)
RESOLVED_JACK_SETTING=${JACK_SETTING:-}
RESOLUTION_SOURCE="Default (Fallback)"

if [ -n "$RESOLVED_JACK_SETTING" ]; then
    RESOLUTION_SOURCE="Environment Variable"
    echo -e "${GREEN}   Using environment variable: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
else
    # Try to read user config file
    RESOLVED_JACK_SETTING=$(read_config_file "$USER_CONFIG_FILE")
    if [ -n "$RESOLVED_JACK_SETTING" ]; then
        RESOLUTION_SOURCE="User Configuration File"
        echo -e "${GREEN}   Using user config: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
    else
        # Try to read system config file
        RESOLVED_JACK_SETTING=$(read_config_file "$SYSTEM_CONFIG_FILE")
        if [ -n "$RESOLVED_JACK_SETTING" ]; then
            RESOLUTION_SOURCE="System Configuration File"
            echo -e "${GREEN}   Using system config: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
        else
            # Fallback to default setting
            RESOLVED_JACK_SETTING=1
            echo -e "${YELLOW}   Using default setting: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
        fi
    fi
fi

echo ""

# =============================================================================
# 5. Show Final Setting
# =============================================================================

echo -e "${BLUE}5. Final Setting:${NC}"
echo -e "${GREEN}   JACK_SETTING = $RESOLVED_JACK_SETTING${NC}"
echo -e "${GREEN}   Source: $RESOLUTION_SOURCE${NC}"

if [ "$RESOLVED_JACK_SETTING" = "2" ]; then
    echo -e "${GREEN}   Description: Medium Latency (48kHz, 3x256)${NC}"
elif [ "$RESOLVED_JACK_SETTING" = "3" ]; then
    echo -e "${GREEN}   Description: Ultra-Low Latency (48kHz, 2x64)${NC}"
else
    echo -e "${GREEN}   Description: Low Latency (48kHz, 2x128)${NC}"
fi
echo ""

# =============================================================================
# 6. Show Current JACK Parameters (if running)
# =============================================================================

echo -e "${BLUE}6. Current JACK Parameters:${NC}"
if command -v jack_control >/dev/null 2>&1; then
    if jack_control status 2>/dev/null | grep -q started; then
        echo -e "${GREEN}   JACK is running. Current parameters:${NC}"

        # Device
        DEVICE=$(jack_control dp 2>/dev/null | grep "device" | awk '{print $NF}')
        echo "      Device: $DEVICE"

        # Sample Rate
        RATE=$(jack_control dp 2>/dev/null | grep "rate" | awk '{print $NF}')
        echo "      Sample Rate: $RATE Hz"

        # Period Size
        PERIOD=$(jack_control dp 2>/dev/null | grep "period" | awk '{print $NF}')
        echo "      Period Size: $PERIOD frames"

        # Number of Periods
        NPERIODS=$(jack_control dp 2>/dev/null | grep "nperiods" | awk '{print $NF}')
        echo "      Number of Periods: $NPERIODS"

    else
        echo -e "${YELLOW}   JACK is not running${NC}"
    fi
else
    echo -e "${RED}   jack_control not available${NC}"
fi
echo ""

# =============================================================================
# 7. Recommendations
# =============================================================================

echo -e "${BLUE}7. Recommendations:${NC}"
if [ -n "${JACK_SETTING:-}" ]; then
    echo -e "${YELLOW}   Issue: Environment variable JACK_SETTING is set!${NC}"
    echo -e "${YELLOW}   Solution: Run 'unset JACK_SETTING'${NC}"
    echo ""
fi

echo -e "${GREEN}   For testing:${NC}"
echo "   1. unset JACK_SETTING"
echo "   2. bash motu-m4-jack-setting.sh current"
echo "   3. bash motu-m4-jack-setting.sh 2"
echo "   4. bash motu-m4-jack-setting.sh current"
echo ""
echo -e "${GREEN}   Available Settings:${NC}"
echo "   Setting 1: Low Latency (48kHz, 2x128)"
echo "   Setting 2: Medium Latency (48kHz, 3x256)"
echo "   Setting 3: Ultra-Low Latency (48kHz, 2x64)"
echo ""

echo -e "${BLUE}=== Debug Analysis Complete ===${NC}"

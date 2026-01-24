#!/bin/bash

# =============================================================================
# MOTU M4 JACK Display Detection Helper
# =============================================================================
# Automatically detects the active X11 DISPLAY for JACK operations.
# Can be sourced as a library or run standalone for display analysis.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Display Detection Function
# =============================================================================

# Function to detect active X11 DISPLAY
detect_display() {
    local user="$1"
    local display=""

    # Method 1: Extract from who command
    local who_display
    who_display=$(who | grep "($user)" | grep "(:" | head -n1 | sed 's/.*(\(:[0-9]*\)).*/\1/' | grep -o ':[0-9]*')
    if [ -n "$who_display" ]; then
        display="$who_display"
        echo "$display"
        return 0
    fi

    # Method 2: Extract from who command without username filter
    local who_display_alt
    who_display_alt=$(who | grep "(:" | head -n1 | sed 's/.*(\(:[0-9]*\)).*/\1/' | grep -o ':[0-9]*')
    if [ -n "$who_display_alt" ]; then
        display="$who_display_alt"
        echo "$display"
        return 0
    fi

    # Method 3: Process-based detection
    if [ -n "$user" ]; then
        local proc_display
        proc_display=$(ps -u "$user" -o args | grep -E 'Xorg|X11' | grep -o -- '-display [^ ]*' | head -n1 | awk '{print $2}')
        if [ -n "$proc_display" ]; then
            display="$proc_display"
            echo "$display"
            return 0
        fi

        # Alternative process detection
        local proc_display_alt
        proc_display_alt=$(ps -u "$user" -o args | grep -E '/usr/lib/xorg/Xorg' | grep -o -- ':[0-9]*' | head -n1)
        if [ -n "$proc_display_alt" ]; then
            display="$proc_display_alt"
            echo "$display"
            return 0
        fi
    fi

    # Method 4: Check /tmp/.X11-unix directory
    if [ -d "/tmp/.X11-unix" ]; then
        local x11_socket
        x11_socket=$(find /tmp/.X11-unix/ -maxdepth 1 -name 'X[0-9]*' -printf '%f\n' | head -n1 | sed 's/X//')
        if [ -n "$x11_socket" ]; then
            display=":$x11_socket"
            echo "$display"
            return 0
        fi
    fi

    # Method 5: User's DISPLAY environment variable
    if [ -n "$user" ]; then
        local user_display
        user_display=$(su - "$user" -c 'echo $DISPLAY' 2>/dev/null | grep -o ':[0-9]*')
        if [ -n "$user_display" ]; then
            display="$user_display"
            echo "$display"
            return 0
        fi
    fi

    # Fallback: Standard display
    echo ":0"
    return 1
}

# =============================================================================
# Display Analysis Function
# =============================================================================

# Function for detailed display analysis
analyze_display() {
    local user="$1"

    echo -e "${BLUE}=== Display Analysis for User: ${user:-'current'} ===${NC}"
    echo ""

    echo -e "${BLUE}1. who Command Output:${NC}"
    who | while read -r line; do
        echo "   $line"
    done
    echo ""

    echo -e "${BLUE}2. X11 Sockets in /tmp/.X11-unix:${NC}"
    if [ -d "/tmp/.X11-unix" ]; then
        find /tmp/.X11-unix/ -maxdepth 1 -ls | while read -r line; do
            echo "   $line"
        done
    else
        echo "   Directory not found"
    fi
    echo ""

    if [ -n "$user" ]; then
        echo -e "${BLUE}3. X11 Processes for User $user:${NC}"
        ps -u "$user" -o pid,args | grep -E 'Xorg|X11|xinit' | while read -r line; do
            echo "   $line"
        done
        echo ""

        echo -e "${BLUE}4. DISPLAY Environment Variable for $user:${NC}"
        local user_display
        user_display=$(su - "$user" -c 'echo $DISPLAY' 2>/dev/null)
        echo "   $user_display"
        echo ""
    fi

    echo -e "${BLUE}5. Detected DISPLAY:${NC}"
    local detected
    detected=$(detect_display "$user")
    echo -e "${GREEN}   $detected${NC}"
    echo ""

    # Test if DISPLAY works
    if [ -n "$user" ] && [ -n "$detected" ]; then
        echo -e "${BLUE}6. DISPLAY Test:${NC}"
        if su - "$user" -c "DISPLAY=$detected xdpyinfo >/dev/null 2>&1"; then
            echo -e "${GREEN}   ✅ DISPLAY $detected is working${NC}"
        else
            echo -e "${RED}   ❌ DISPLAY $detected is not working${NC}"
        fi
    fi
}

# =============================================================================
# Main Logic (when executed standalone)
# =============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "$1" in
        "analyze"|"debug")
            analyze_display "$2"
            ;;
        "detect")
            detect_display "$2"
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}MOTU M4 JACK Display Detection Helper${NC}"
            echo ""
            echo "Usage:"
            echo "  $0 detect [username]    - Detect DISPLAY for user"
            echo "  $0 analyze [username]   - Detailed display analysis"
            echo "  $0 help                 - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 detect               # Detect DISPLAY for current active user"
            echo "  $0 detect username      # Detect DISPLAY for user 'username'"
            echo "  $0 analyze username     # Complete analysis for user 'username'"
            echo ""
            echo "As include in other scripts:"
            echo "  source detect-display.sh"
            echo "  DISPLAY=\$(detect_display \"username\")"
            ;;
        "")
            # No parameters: detect for current active user
            active_user=$(who | grep "(:" | head -n1 | awk '{print $1}')
            if [ -n "$active_user" ]; then
                detect_display "$active_user"
            else
                echo ":0"  # Fallback
            fi
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option '$1'"
            echo "Use '$0 help' for more information."
            exit 1
            ;;
    esac
fi

#!/bin/bash

# =============================================================================
# Audio Interface JACK Display Detection Helper
# =============================================================================
# Detects the active DISPLAY for JACK operations and provides a diagnostic
# view of the current session. Can be sourced as a library or run standalone.
#
# The actual detection logic lives in ai-jack-session.sh, which handles X11
# and Wayland alike. This script keeps the historic CLI (detect/analyze) as a
# troubleshooting front-end.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Session Library
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/ai-jack-session.sh" ]; then
    source "$SCRIPT_DIR/ai-jack-session.sh"
elif [ -f "/usr/local/bin/ai-jack-session.sh" ]; then
    source "/usr/local/bin/ai-jack-session.sh"
else
    echo -e "${RED}Error:${NC} ai-jack-session.sh not found - cannot detect session" >&2
    exit 1
fi

# =============================================================================
# Display Detection Function
# =============================================================================

# Detect the active DISPLAY (X11 display, or Xwayland display under Wayland).
# Usage: detect_display [username]
detect_display() {
    get_active_session_display "$1"
}

# =============================================================================
# Display Analysis Function
# =============================================================================

# Detailed session and display analysis for troubleshooting
analyze_display() {
    local user="$1"
    [ -z "$user" ] && user=$(get_active_session_user)

    echo -e "${BLUE}=== Session Analysis for User: ${user:-'<none detected>'} ===${NC}"
    echo ""

    echo -e "${BLUE}1. logind Sessions:${NC}"
    if command -v loginctl >/dev/null 2>&1; then
        loginctl list-sessions --no-legend 2>/dev/null | while read -r line; do
            echo "   $line"
        done
        echo ""
        local sid
        sid=$(get_active_session_id)
        if [ -n "$sid" ]; then
            echo -e "${BLUE}   Active graphical session: $sid${NC}"
            local prop
            for prop in Name Class Type Display Remote Active State; do
                echo "     $prop = $(loginctl show-session "$sid" -p "$prop" --value 2>/dev/null)"
            done
        else
            echo -e "${YELLOW}   No active graphical session found${NC}"
        fi
    else
        echo -e "${YELLOW}   loginctl not available${NC}"
    fi
    echo ""

    echo -e "${BLUE}2. who Command Output (legacy, X11-only):${NC}"
    who | while read -r line; do
        echo "   $line"
    done
    if ! who | grep -q "(:"; then
        echo -e "${YELLOW}   Note: no '(:N)' display entry - expected under Wayland${NC}"
    fi
    echo ""

    echo -e "${BLUE}3. X11 Sockets in /tmp/.X11-unix:${NC}"
    if [ -d "/tmp/.X11-unix" ]; then
        find /tmp/.X11-unix/ -maxdepth 1 -ls 2>/dev/null | while read -r line; do
            echo "   $line"
        done
    else
        echo "   Directory not found"
    fi
    echo ""

    if [ -n "$user" ]; then
        echo -e "${BLUE}4. Desktop Processes for User $user:${NC}"
        pgrep -u "$user" -f 'Xorg|Xwayland|kwin|plasmashell|gnome-shell' -a 2>/dev/null | while read -r line; do
            echo "   $line"
        done
        echo ""
    fi

    echo -e "${BLUE}5. Detected Session Type:${NC}"
    echo -e "${GREEN}   $(get_active_session_type)${NC}"
    echo ""

    echo -e "${BLUE}6. Detected DISPLAY:${NC}"
    local detected
    detected=$(detect_display "$user")
    echo -e "${GREEN}   $detected${NC}"
    echo ""

    # Test if DISPLAY works
    if [ -n "$user" ] && [ -n "$detected" ]; then
        echo -e "${BLUE}7. DISPLAY Test:${NC}"
        if runuser -u "$user" -- env DISPLAY="$detected" xdpyinfo >/dev/null 2>&1 \
           || DISPLAY="$detected" xdpyinfo >/dev/null 2>&1; then
            echo -e "${GREEN}   DISPLAY $detected is working${NC}"
        else
            echo -e "${YELLOW}   DISPLAY $detected not reachable (harmless if no X client is needed)${NC}"
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
        "user")
            get_active_session_user
            ;;
        "type")
            get_active_session_type
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}Audio Interface JACK Display Detection Helper${NC}"
            echo ""
            echo "Usage:"
            echo "  $0 detect [username]    - Detect DISPLAY for user"
            echo "  $0 user                 - Print active session user"
            echo "  $0 type                 - Print session type (wayland/x11/tty)"
            echo "  $0 analyze [username]   - Detailed session analysis"
            echo "  $0 help                 - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 detect               # Detect DISPLAY for current active user"
            echo "  $0 detect username      # Detect DISPLAY for user 'username'"
            echo "  $0 analyze              # Complete analysis of the active session"
            echo ""
            echo "As include in other scripts:"
            echo "  source detect-display.sh"
            echo "  DISPLAY=\$(detect_display \"username\")"
            ;;
        "")
            # No parameters: detect for current active user
            detect_display ""
            ;;
        *)
            echo -e "${RED}Error:${NC} Unknown option '$1'"
            echo "Use '$0 help' for more information."
            exit 1
            ;;
    esac
fi

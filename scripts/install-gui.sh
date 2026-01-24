#!/bin/bash

# =============================================================================
# MOTU M4 JACK GUI - Installation Script
# =============================================================================
# Installs the GUI application for MOTU M4 JACK settings management.
#
# Usage: sudo ./install-gui.sh
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Root Privilege Check
# =============================================================================

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error:${NC} This script requires root privileges."
    echo "Please run with sudo: sudo $0"
    exit 1
fi

echo -e "${BLUE}=== MOTU M4 JACK GUI Installation ===${NC}"
echo ""

# =============================================================================
# Script Directory Detection
# =============================================================================

# Detect script directory (parent directory since we are in scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# =============================================================================
# Dependency Check
# =============================================================================

echo -e "${YELLOW}Checking dependencies...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error:${NC} Python3 not found"
    echo "Install with: sudo apt install python3"
    exit 1
fi

# Check GTK3 Python bindings
if ! python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk" 2>/dev/null; then
    echo -e "${RED}Error:${NC} Python GTK3 bindings not found"
    echo "Install with: sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0"
    exit 1
fi

echo -e "${GREEN}✓ Python3 and GTK3 available${NC}"

# Check polkit (for pkexec)
if ! command -v pkexec &> /dev/null; then
    echo -e "${YELLOW}Warning:${NC} pkexec not found - GUI needs pkexec for sudo operations"
    echo "Install with: sudo apt install policykit-1"
fi

# =============================================================================
# GUI Script Installation
# =============================================================================

echo ""
echo -e "${YELLOW}Installing GUI script...${NC}"

if [ -f "$SCRIPT_DIR/gui/motu-m4-jack-gui.py" ]; then
    cp "$SCRIPT_DIR/gui/motu-m4-jack-gui.py" /usr/local/bin/
    chmod +x /usr/local/bin/motu-m4-jack-gui.py
    echo -e "${GREEN}✓ GUI script installed to /usr/local/bin/motu-m4-jack-gui.py${NC}"
else
    echo -e "${RED}Error:${NC} motu-m4-jack-gui.py not found in $SCRIPT_DIR/gui"
    exit 1
fi

# =============================================================================
# Desktop Entry Installation
# =============================================================================

echo ""
echo -e "${YELLOW}Installing desktop entry...${NC}"

if [ -f "$SCRIPT_DIR/system/motu-m4-jack-settings.desktop" ]; then
    cp "$SCRIPT_DIR/system/motu-m4-jack-settings.desktop" /usr/share/applications/
    chmod 644 /usr/share/applications/motu-m4-jack-settings.desktop
    echo -e "${GREEN}✓ Desktop entry installed${NC}"

    # Update desktop database
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database /usr/share/applications/ 2>/dev/null
    fi
else
    echo -e "${YELLOW}Warning:${NC} motu-m4-jack-settings.desktop not found - skipped"
fi

# =============================================================================
# Icon Installation
# =============================================================================

echo ""
echo -e "${YELLOW}Installing icon...${NC}"

if [ -f "$SCRIPT_DIR/gui/motu-m4-jack-settings.svg" ]; then
    # Create hicolor icon directory if not present
    mkdir -p /usr/share/icons/hicolor/scalable/apps/
    cp "$SCRIPT_DIR/gui/motu-m4-jack-settings.svg" /usr/share/icons/hicolor/scalable/apps/
    chmod 644 /usr/share/icons/hicolor/scalable/apps/motu-m4-jack-settings.svg
    echo -e "${GREEN}✓ Icon installed${NC}"

    # Update icon cache
    if command -v gtk-update-icon-cache &> /dev/null; then
        gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null
    fi
else
    echo -e "${YELLOW}Warning:${NC} motu-m4-jack-settings.svg not found - skipped"
    echo "  The GUI will use the default 'audio-card' icon."
fi

# =============================================================================
# Polkit Rule Installation
# =============================================================================

echo ""
echo -e "${YELLOW}Installing Polkit rule...${NC}"

if [ -f "$SCRIPT_DIR/system/50-motu-m4-jack-settings.rules" ]; then
    cp "$SCRIPT_DIR/system/50-motu-m4-jack-settings.rules" /etc/polkit-1/rules.d/
    chmod 644 /etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules
    echo -e "${GREEN}✓ Polkit rule installed${NC}"
    echo -e "  ${BLUE}Info:${NC} Members of 'audio' group can change settings without password"

    # Check if current user is in audio group
    ACTUAL_USER="${SUDO_USER:-$USER}"
    if id -nG "$ACTUAL_USER" | grep -qw "audio"; then
        echo -e "  ${GREEN}✓ User '$ACTUAL_USER' is already in 'audio' group${NC}"
    else
        echo -e "  ${YELLOW}Note:${NC} User '$ACTUAL_USER' is not in 'audio' group"
        echo "    Add with: sudo usermod -aG audio $ACTUAL_USER"
        echo "    (Logout required)"
    fi
else
    echo -e "${YELLOW}Warning:${NC} 50-motu-m4-jack-settings.rules not found - skipped"
    echo "  The GUI will prompt for password on each settings change."
fi

# =============================================================================
# System Scripts Check
# =============================================================================

echo ""
echo -e "${YELLOW}Checking system scripts...${NC}"

if [ -f "/usr/local/bin/motu-m4-jack-setting-system.sh" ]; then
    echo -e "${GREEN}✓ motu-m4-jack-setting-system.sh found${NC}"
else
    echo -e "${YELLOW}Warning:${NC} motu-m4-jack-setting-system.sh not in /usr/local/bin/"
    echo "  The GUI needs this script to change settings."
    echo "  Install with: sudo cp motu-m4-jack-setting-system.sh /usr/local/bin/"
fi

# =============================================================================
# Installation Summary
# =============================================================================

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo -e "The GUI can be started with:"
echo -e "  ${BLUE}motu-m4-jack-gui.py${NC}"
echo ""
echo -e "Or from the application menu:"
echo -e "  ${BLUE}Audio/Video → MOTU M4 JACK Settings${NC}"
echo ""
if [ -f "/etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules" ]; then
    echo -e "${GREEN}Note:${NC} Polkit rule active - no password required"
    echo "for members of 'audio' group."
else
    echo -e "${YELLOW}Note:${NC} When applying settings, you will be prompted"
    echo "for administrator password (via pkexec)."
fi

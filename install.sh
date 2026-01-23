#!/bin/bash
# =============================================================================
# MOTU M4 JACK Starter - Installation Script v2.0
# =============================================================================
# Installs all components of the MOTU M4 JACK automation system
# Usage: sudo ./install.sh
#
# Copyright (C) 2025
# License: GPL-3.0-or-later

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error:${NC} This script requires root privileges."
        echo "Please run with sudo: sudo $0"
        exit 1
    fi
}

# Get the actual user (not root)
get_actual_user() {
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
    else
        who | grep "(:" | head -n1 | awk '{print $1}'
    fi
}

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${BLUE}  MOTU M4 JACK Starter - Installation${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo ""
}

# Check dependencies
check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"

    local missing=()

    # Check for required commands
    if ! command -v jack_control &> /dev/null; then
        missing+=("jackd2")
    fi

    if ! command -v aplay &> /dev/null; then
        missing+=("alsa-utils")
    fi

    if ! command -v bc &> /dev/null; then
        missing+=("bc")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning:${NC} Missing packages: ${missing[*]}"
        echo "Install with: sudo apt install ${missing[*]}"
    else
        echo -e "${GREEN}✓ Core dependencies available${NC}"
    fi

    # Check Python GTK for GUI
    if python3 -c "import gi; gi.require_version('Gtk', '3.0'); from gi.repository import Gtk" 2>/dev/null; then
        echo -e "${GREEN}✓ Python GTK3 available (GUI support)${NC}"
    else
        echo -e "${YELLOW}Warning:${NC} Python GTK3 not found - GUI will not work"
        echo "Install with: sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0"
    fi
}

# Install scripts
install_scripts() {
    echo ""
    echo -e "${YELLOW}Installing scripts to /usr/local/bin/...${NC}"

    local scripts=(
        "motu-m4-udev-handler.sh"
        "motu-m4-jack-autostart.sh"
        "motu-m4-jack-autostart-user.sh"
        "motu-m4-jack-init.sh"
        "motu-m4-jack-shutdown.sh"
        "motu-m4-jack-restart-simple.sh"
        "motu-m4-jack-setting.sh"
        "motu-m4-jack-setting-system.sh"
        "motu-m4-login-check.sh"
        "debug-config.sh"
        "detect-display.sh"
    )

    for script in "${scripts[@]}"; do
        if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
            cp "$SCRIPT_DIR/scripts/$script" /usr/local/bin/
            chmod +x "/usr/local/bin/$script"
            echo -e "  ${GREEN}✓${NC} $script"
        else
            echo -e "  ${YELLOW}⚠${NC} $script not found - skipped"
        fi
    done
}

# Install GUI
install_gui() {
    echo ""
    echo -e "${YELLOW}Installing GUI...${NC}"

    # Install GUI script
    if [ -f "$SCRIPT_DIR/gui/motu-m4-jack-gui.py" ]; then
        cp "$SCRIPT_DIR/gui/motu-m4-jack-gui.py" /usr/local/bin/
        chmod +x /usr/local/bin/motu-m4-jack-gui.py
        echo -e "  ${GREEN}✓${NC} motu-m4-jack-gui.py"
    else
        echo -e "  ${RED}✗${NC} motu-m4-jack-gui.py not found"
    fi

    # Install desktop entry
    if [ -f "$SCRIPT_DIR/system/motu-m4-jack-settings.desktop" ]; then
        cp "$SCRIPT_DIR/system/motu-m4-jack-settings.desktop" /usr/share/applications/
        chmod 644 /usr/share/applications/motu-m4-jack-settings.desktop
        echo -e "  ${GREEN}✓${NC} Desktop entry installed"

        # Update desktop database
        if command -v update-desktop-database &> /dev/null; then
            update-desktop-database /usr/share/applications/ 2>/dev/null
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Desktop entry not found - skipped"
    fi

    # Install icon
    if [ -f "$SCRIPT_DIR/gui/motu-m4-jack-settings.svg" ]; then
        mkdir -p /usr/share/icons/hicolor/scalable/apps/
        cp "$SCRIPT_DIR/gui/motu-m4-jack-settings.svg" /usr/share/icons/hicolor/scalable/apps/
        chmod 644 /usr/share/icons/hicolor/scalable/apps/motu-m4-jack-settings.svg
        echo -e "  ${GREEN}✓${NC} Icon installed"

        # Update icon cache
        if command -v gtk-update-icon-cache &> /dev/null; then
            gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Icon not found - skipped"
    fi
}

# Install UDEV rule
install_udev() {
    echo ""
    echo -e "${YELLOW}Installing UDEV rule...${NC}"

    if [ -f "$SCRIPT_DIR/system/99-motu-m4-jack-combined.rules" ]; then
        cp "$SCRIPT_DIR/system/99-motu-m4-jack-combined.rules" /etc/udev/rules.d/
        chmod 644 /etc/udev/rules.d/99-motu-m4-jack-combined.rules
        udevadm control --reload-rules
        udevadm trigger
        echo -e "  ${GREEN}✓${NC} UDEV rule installed and reloaded"
    else
        echo -e "  ${RED}✗${NC} UDEV rule file not found"
    fi
}

# Install config example
install_config_example() {
    echo ""
    echo -e "${YELLOW}Installing configuration example...${NC}"

    mkdir -p /etc/motu-m4

    if [ -f "$SCRIPT_DIR/system/jack-setting.conf.example" ]; then
        cp "$SCRIPT_DIR/system/jack-setting.conf.example" /etc/motu-m4/
        chmod 644 /etc/motu-m4/jack-setting.conf.example
        echo -e "  ${GREEN}✓${NC} Config example installed to /etc/motu-m4/"

        # Create default config if none exists
        if [ ! -f "/etc/motu-m4/jack-setting.conf" ]; then
            cat > /etc/motu-m4/jack-setting.conf << 'EOF'
# MOTU M4 JACK Configuration
# See jack-setting.conf.example for detailed documentation

JACK_RATE=48000
JACK_PERIOD=256
JACK_NPERIODS=2

# ALSA-to-JACK MIDI Bridge
# Set to true if you need MIDI routing in JACK
# Set to false for modern DAWs (Bitwig, Reaper) - recommended
A2J_ENABLE=false
EOF
            chmod 644 /etc/motu-m4/jack-setting.conf
            echo -e "  ${GREEN}✓${NC} Default config created at /etc/motu-m4/jack-setting.conf"
        else
            echo -e "  ${BLUE}Info:${NC} Config file already exists, not overwriting"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Config example not found - skipped"
    fi
}

# Install polkit rule
install_polkit() {
    echo ""
    echo -e "${YELLOW}Installing Polkit rule (passwordless operation)...${NC}"

    if [ -f "$SCRIPT_DIR/system/50-motu-m4-jack-settings.rules" ]; then
        cp "$SCRIPT_DIR/system/50-motu-m4-jack-settings.rules" /etc/polkit-1/rules.d/
        chmod 644 /etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules
        echo -e "  ${GREEN}✓${NC} Polkit rule installed"
        echo -e "  ${BLUE}Info:${NC} Members of 'audio' group can change settings without password"
    else
        echo -e "  ${YELLOW}⚠${NC} Polkit rule not found - skipped"
        echo "  GUI will require password for each change"
    fi
}

# Install systemd user service
install_systemd_service() {
    echo ""
    echo -e "${YELLOW}Installing systemd user service...${NC}"

    local actual_user
    actual_user=$(get_actual_user)

    if [ -z "$actual_user" ]; then
        echo -e "  ${YELLOW}⚠${NC} Could not determine user - skipping systemd service"
        echo "  Install manually: cp motu-m4-login-check.service ~/.config/systemd/user/"
        return
    fi

    local user_home
    user_home=$(eval echo ~"$actual_user")
    local service_dir="$user_home/.config/systemd/user"

    if [ -f "$SCRIPT_DIR/system/motu-m4-login-check.service" ]; then
        # Create directory as user
        runuser -l "$actual_user" -c "mkdir -p $service_dir"

        # Copy service file
        cp "$SCRIPT_DIR/system/motu-m4-login-check.service" "$service_dir/"
        chown "$actual_user:$actual_user" "$service_dir/motu-m4-login-check.service"

        # Enable service as user
        runuser -l "$actual_user" -c "systemctl --user daemon-reload"
        runuser -l "$actual_user" -c "systemctl --user enable motu-m4-login-check.service"

        echo -e "  ${GREEN}✓${NC} Service installed for user '$actual_user'"
        echo -e "  ${GREEN}✓${NC} Service enabled"
    else
        echo -e "  ${RED}✗${NC} Service file not found"
    fi
}

# Check audio group membership
check_audio_group() {
    echo ""
    echo -e "${YELLOW}Checking audio group membership...${NC}"

    local actual_user
    actual_user=$(get_actual_user)

    if [ -z "$actual_user" ]; then
        echo -e "  ${YELLOW}⚠${NC} Could not determine user"
        return
    fi

    if id -nG "$actual_user" | grep -qw "audio"; then
        echo -e "  ${GREEN}✓${NC} User '$actual_user' is in 'audio' group"
    else
        echo -e "  ${YELLOW}⚠${NC} User '$actual_user' is NOT in 'audio' group"
        echo "  Add with: sudo usermod -aG audio $actual_user"
        echo "  (Logout required for changes to take effect)"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BLUE}=============================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Configure JACK (flexible v2.0 syntax):"
    echo -e "     ${BLUE}sudo motu-m4-jack-setting-system.sh --rate=48000 --period=256 --nperiods=3 --restart${NC}"
    echo ""
    echo "     Or use a preset:"
    echo -e "     ${BLUE}sudo motu-m4-jack-setting-system.sh 2 --restart${NC}"
    echo ""
    echo "  2. Start the GUI:"
    echo -e "     ${BLUE}motu-m4-jack-gui.py${NC}"
    echo "     Or find it in: Audio/Video → MOTU M4 JACK Settings"
    echo ""
    echo "  3. Connect your MOTU M4 - JACK will start automatically!"
    echo ""
    echo "For detailed documentation, see:"
    echo "  - README.md (overview)"
    echo "  - INSTALL.md (detailed guide)"
    echo ""
}

# Main installation
main() {
    check_root
    print_header
    check_dependencies
    install_scripts
    install_gui
    install_udev
    install_config_example
    install_polkit
    install_systemd_service
    check_audio_group
    print_summary
}

# Run main
main "$@"

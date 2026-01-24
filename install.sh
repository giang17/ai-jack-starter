#!/bin/bash
# =============================================================================
# Audio Interface JACK Starter - Installation Script v3.0
# =============================================================================
# Installs all components of the Audio Interface JACK automation system
# Works with any JACK-compatible audio interface
# Usage: sudo ./install.sh
#
# Copyright (C) 2025
# License: GPL-3.0-or-later

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${BLUE}  Audio Interface JACK Starter - Installation${NC}"
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

# Detect and configure audio device
configure_audio_device() {
    echo ""
    echo -e "${YELLOW}Audio Device Configuration${NC}"
    echo -e "${BLUE}=============================================${NC}"
    echo ""

    # Show detected audio devices (force English output with LC_ALL=C)
    echo -e "${CYAN}Detected audio devices:${NC}"
    echo ""
    LC_ALL=C aplay -l 2>/dev/null | grep -E "^card [0-9]+" || echo "  No audio devices found"
    echo ""

    # Get actual user for later
    local actual_user
    actual_user=$(get_actual_user)

    # Check if config already exists
    if [ -f "/etc/ai-jack/jack-setting.conf" ]; then
        echo -e "${BLUE}Existing configuration found at /etc/ai-jack/jack-setting.conf${NC}"

        # Show current settings
        local current_device current_pattern
        current_device=$(grep "^AUDIO_DEVICE=" /etc/ai-jack/jack-setting.conf 2>/dev/null | cut -d'=' -f2)
        current_pattern=$(grep "^DEVICE_PATTERN=" /etc/ai-jack/jack-setting.conf 2>/dev/null | cut -d'=' -f2)

        echo "  Current AUDIO_DEVICE: ${current_device:-<not set>}"
        echo "  Current DEVICE_PATTERN: ${current_pattern:-<not set>}"
        echo ""

        read -p "Keep existing configuration? [Y/n] " keep_config
        if [[ "$keep_config" =~ ^[Nn] ]]; then
            configure_device_interactive
        else
            echo -e "${GREEN}✓ Keeping existing configuration${NC}"
        fi
    else
        configure_device_interactive
    fi
}

# Interactive device configuration
configure_device_interactive() {
    echo ""
    echo -e "${CYAN}Configure your audio interface:${NC}"
    echo ""
    echo "Examples:"
    echo "  MOTU M4:           AUDIO_DEVICE=hw:M4,0       DEVICE_PATTERN=M4"
    echo "  Focusrite Scarlett: AUDIO_DEVICE=hw:USB,0     DEVICE_PATTERN=Scarlett"
    echo "  RME Babyface:      AUDIO_DEVICE=hw:Babyface,0 DEVICE_PATTERN=Babyface"
    echo "  First USB device:  AUDIO_DEVICE=hw:0,0       DEVICE_PATTERN="
    echo ""

    # Try to auto-detect a reasonable default
    local default_device="hw:0,0"
    local default_pattern=""

    # Check for common interfaces (force English output with LC_ALL=C)
    if LC_ALL=C aplay -l 2>/dev/null | grep -q "M4"; then
        default_device="hw:M4,0"
        default_pattern="M4"
    elif LC_ALL=C aplay -l 2>/dev/null | grep -q "Scarlett"; then
        default_device="hw:USB,0"
        default_pattern="Scarlett"
    elif LC_ALL=C aplay -l 2>/dev/null | grep -q "Babyface"; then
        default_device="hw:Babyface,0"
        default_pattern="Babyface"
    elif LC_ALL=C aplay -l 2>/dev/null | grep -q "Focusrite"; then
        default_device="hw:USB,0"
        default_pattern="Focusrite"
    fi

    echo -e "Enter AUDIO_DEVICE (ALSA device ID for JACK):"
    read -p "  [default: $default_device] " input_device
    AUDIO_DEVICE="${input_device:-$default_device}"

    echo ""
    echo -e "Enter DEVICE_PATTERN (for hardware detection, or leave empty):"
    read -p "  [default: $default_pattern] " input_pattern
    DEVICE_PATTERN="${input_pattern:-$default_pattern}"

    echo ""
    echo -e "${GREEN}Configuration:${NC}"
    echo "  AUDIO_DEVICE=$AUDIO_DEVICE"
    echo "  DEVICE_PATTERN=$DEVICE_PATTERN"

    # Store for later use in config creation
    export CONFIGURED_AUDIO_DEVICE="$AUDIO_DEVICE"
    export CONFIGURED_DEVICE_PATTERN="$DEVICE_PATTERN"
}

# Install scripts
install_scripts() {
    echo ""
    echo -e "${YELLOW}Installing scripts to /usr/local/bin/...${NC}"

    local scripts=(
        "ai-udev-handler.sh"
        "ai-jack-autostart.sh"
        "ai-jack-autostart-user.sh"
        "ai-jack-init.sh"
        "ai-jack-shutdown.sh"
        "ai-jack-restart.sh"
        "ai-jack-setting.sh"
        "ai-jack-setting-system.sh"
        "ai-login-check.sh"
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
    if [ -f "$SCRIPT_DIR/gui/ai-jack-gui.py" ]; then
        cp "$SCRIPT_DIR/gui/ai-jack-gui.py" /usr/local/bin/
        chmod +x /usr/local/bin/ai-jack-gui.py
        echo -e "  ${GREEN}✓${NC} ai-jack-gui.py"
    else
        echo -e "  ${RED}✗${NC} ai-jack-gui.py not found"
    fi

    # Install desktop entry
    if [ -f "$SCRIPT_DIR/system/ai-jack-settings.desktop" ]; then
        cp "$SCRIPT_DIR/system/ai-jack-settings.desktop" /usr/share/applications/
        chmod 644 /usr/share/applications/ai-jack-settings.desktop
        echo -e "  ${GREEN}✓${NC} Desktop entry installed"

        # Update desktop database
        if command -v update-desktop-database &> /dev/null; then
            update-desktop-database /usr/share/applications/ 2>/dev/null
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} Desktop entry not found - skipped"
    fi

    # Install icon
    if [ -f "$SCRIPT_DIR/gui/ai-jack-settings.svg" ]; then
        mkdir -p /usr/share/icons/hicolor/scalable/apps/
        cp "$SCRIPT_DIR/gui/ai-jack-settings.svg" /usr/share/icons/hicolor/scalable/apps/
        chmod 644 /usr/share/icons/hicolor/scalable/apps/ai-jack-settings.svg
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

    if [ -f "$SCRIPT_DIR/system/99-ai-jack.rules" ]; then
        cp "$SCRIPT_DIR/system/99-ai-jack.rules" /etc/udev/rules.d/
        chmod 644 /etc/udev/rules.d/99-ai-jack.rules
        udevadm control --reload-rules
        udevadm trigger
        echo -e "  ${GREEN}✓${NC} UDEV rule installed and reloaded"
    else
        echo -e "  ${RED}✗${NC} UDEV rule file not found"
    fi
}

# Install config
install_config() {
    echo ""
    echo -e "${YELLOW}Installing configuration...${NC}"

    mkdir -p /etc/ai-jack

    # Install example config
    if [ -f "$SCRIPT_DIR/system/jack-setting.conf.example" ]; then
        cp "$SCRIPT_DIR/system/jack-setting.conf.example" /etc/ai-jack/
        chmod 644 /etc/ai-jack/jack-setting.conf.example
        echo -e "  ${GREEN}✓${NC} Config example installed to /etc/ai-jack/"
    fi

    # Create default config if none exists
    if [ ! -f "/etc/ai-jack/jack-setting.conf" ]; then
        # Use configured values or defaults
        local audio_device="${CONFIGURED_AUDIO_DEVICE:-hw:0,0}"
        local device_pattern="${CONFIGURED_DEVICE_PATTERN:-}"

        cat > /etc/ai-jack/jack-setting.conf << EOF
# Audio Interface JACK Starter Configuration
# See jack-setting.conf.example for detailed documentation

# === Device Settings ===
AUDIO_DEVICE=$audio_device
DEVICE_PATTERN=$device_pattern

# === JACK Settings ===
JACK_RATE=48000
JACK_PERIOD=256
JACK_NPERIODS=2

# === ALSA-to-JACK MIDI Bridge ===
# Set to true if you need MIDI routing in JACK
# Set to false for modern DAWs (Bitwig, Reaper) - recommended
A2J_ENABLE=false

# === DBus Timeout ===
# Timeout in seconds for JACK startup (increase if JACK starts slowly)
DBUS_TIMEOUT=30
EOF
        chmod 644 /etc/ai-jack/jack-setting.conf
        echo -e "  ${GREEN}✓${NC} Config created at /etc/ai-jack/jack-setting.conf"
    else
        echo -e "  ${BLUE}Info:${NC} Config file already exists, not overwriting"
    fi
}

# Install polkit rule
install_polkit() {
    echo ""
    echo -e "${YELLOW}Installing Polkit rule (passwordless operation)...${NC}"

    if [ -f "$SCRIPT_DIR/system/50-ai-jack-settings.rules" ]; then
        cp "$SCRIPT_DIR/system/50-ai-jack-settings.rules" /etc/polkit-1/rules.d/
        chmod 644 /etc/polkit-1/rules.d/50-ai-jack-settings.rules
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
        echo "  Install manually: cp ai-login-check.service ~/.config/systemd/user/"
        return
    fi

    local user_home
    user_home=$(eval echo ~"$actual_user")
    local service_dir="$user_home/.config/systemd/user"

    if [ -f "$SCRIPT_DIR/system/ai-login-check.service" ]; then
        # Create directory as user
        runuser -l "$actual_user" -c "mkdir -p $service_dir"

        # Copy service file
        cp "$SCRIPT_DIR/system/ai-login-check.service" "$service_dir/"
        chown "$actual_user:$actual_user" "$service_dir/ai-login-check.service"

        # Enable service as user
        runuser -l "$actual_user" -c "systemctl --user daemon-reload"
        runuser -l "$actual_user" -c "systemctl --user enable ai-login-check.service"

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

# Cleanup old motu-m4 installation
cleanup_old_installation() {
    echo ""
    echo -e "${YELLOW}Checking for old motu-m4 installation...${NC}"

    local old_files_found=false

    # Check for old scripts
    if ls /usr/local/bin/motu-m4-* 2>/dev/null | head -1 > /dev/null; then
        old_files_found=true
    fi

    # Check for old config
    if [ -d "/etc/motu-m4" ]; then
        old_files_found=true
    fi

    # Check for old udev rules
    if [ -f "/etc/udev/rules.d/99-motu-m4-jack-combined.rules" ]; then
        old_files_found=true
    fi

    if [ "$old_files_found" = true ]; then
        echo -e "  ${YELLOW}Found old motu-m4 installation files${NC}"
        read -p "  Remove old motu-m4 files? [y/N] " remove_old

        if [[ "$remove_old" =~ ^[Yy] ]]; then
            # Remove old scripts
            rm -f /usr/local/bin/motu-m4-*.sh 2>/dev/null
            rm -f /usr/local/bin/motu-m4-jack-gui.py 2>/dev/null

            # Remove old udev rules
            rm -f /etc/udev/rules.d/99-motu-m4-jack-combined.rules 2>/dev/null

            # Remove old polkit rules
            rm -f /etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules 2>/dev/null

            # Remove old desktop entry
            rm -f /usr/share/applications/motu-m4-jack-settings.desktop 2>/dev/null

            # Remove old icon
            rm -f /usr/share/icons/hicolor/scalable/apps/motu-m4-jack-settings.svg 2>/dev/null

            # Optionally migrate config
            if [ -d "/etc/motu-m4" ] && [ ! -d "/etc/ai-jack" ]; then
                read -p "  Migrate config from /etc/motu-m4 to /etc/ai-jack? [Y/n] " migrate_config
                if [[ ! "$migrate_config" =~ ^[Nn] ]]; then
                    mkdir -p /etc/ai-jack
                    cp /etc/motu-m4/* /etc/ai-jack/ 2>/dev/null
                    echo -e "  ${GREEN}✓${NC} Config migrated"
                fi
            fi

            # Remove old config directory
            rm -rf /etc/motu-m4 2>/dev/null

            echo -e "  ${GREEN}✓${NC} Old installation cleaned up"

            # Reload udev
            udevadm control --reload-rules 2>/dev/null
        else
            echo -e "  ${BLUE}Info:${NC} Keeping old files (may cause conflicts)"
        fi
    else
        echo -e "  ${GREEN}✓${NC} No old installation found"
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
    echo "  1. Configure JACK settings:"
    echo -e "     ${BLUE}sudo ai-jack-setting-system.sh --rate=48000 --period=256 --nperiods=3 --restart${NC}"
    echo ""
    echo "     Or use a preset:"
    echo -e "     ${BLUE}sudo ai-jack-setting-system.sh 2 --restart${NC}"
    echo ""
    echo "  2. Start the GUI:"
    echo -e "     ${BLUE}ai-jack-gui.py${NC}"
    echo "     Or find it in: Audio/Video → Audio Interface JACK Settings"
    echo ""
    echo "  3. Connect your audio interface - JACK will start automatically!"
    echo ""
    echo "Configuration file: /etc/ai-jack/jack-setting.conf"
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
    cleanup_old_installation
    configure_audio_device
    install_scripts
    install_gui
    install_udev
    install_config
    install_polkit
    install_systemd_service
    check_audio_group
    print_summary
}

# Run main
main "$@"

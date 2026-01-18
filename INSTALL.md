# Installation & Configuration Guide

Complete installation, configuration, and troubleshooting guide for the MOTU M4 JACK Automation System.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [JACK Settings Explained](#jack-settings-explained)
- [System Components](#system-components)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Prerequisites

### System Requirements

- **OS**: Ubuntu Studio 24.04 or later
- **Audio Stack**: Pipewire with JACK compatibility
- **Hardware**: MOTU M4 USB Audio Interface

### Required Packages

```bash
# Core dependencies (usually pre-installed on Ubuntu Studio)
sudo apt install jackd2 a2jmidid

# GUI dependencies
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0
```

### User Groups

Ensure your user is in the `audio` group:

```bash
# Check current groups
groups

# Add to audio group if needed
sudo usermod -aG audio $USER

# Logout and login for changes to take effect
```

---

## Installation

### Quick Installation (Recommended)

The easiest way to install everything is using the automated installer:

```bash
# Clone repository
git clone https://github.com/giang17/motu-m4-jack-starter.git
cd motu-m4-jack-starter

# Run installer
sudo ./install.sh
```

The installer automatically:
- Checks dependencies
- Installs all scripts to `/usr/local/bin/`
- Installs the GUI with desktop entry and icon
- Configures UDEV rules
- Sets up Polkit for passwordless operation
- Enables the systemd user service
- Verifies audio group membership

### Manual Installation

If you prefer manual installation or need more control:

#### Step 1: Clone Repository

```bash
git clone https://github.com/giang17/motu-m4-jack-starter.git
cd motu-m4-jack-starter
```

#### Step 2: Install Scripts

```bash
sudo cp motu-m4-*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-*.sh
sudo cp debug-config.sh detect-display.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/debug-config.sh /usr/local/bin/detect-display.sh
```

#### Step 3: Install UDEV Rule

```bash
sudo cp 99-motu-m4-jack-combined.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

#### Step 4: Enable Login Check Service

```bash
mkdir -p ~/.config/systemd/user/
cp motu-m4-login-check.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable motu-m4-login-check.service
```

#### Step 5: Install GUI (Optional)

```bash
sudo cp motu-m4-jack-gui.py /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-jack-gui.py
sudo cp motu-m4-jack-settings.desktop /usr/share/applications/
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps/
sudo cp motu-m4-jack-settings.svg /usr/share/icons/hicolor/scalable/apps/
sudo gtk-update-icon-cache /usr/share/icons/hicolor/
```

#### Step 6: Install Polkit Rule (Passwordless Operation)

```bash
sudo cp 50-motu-m4-jack-settings.rules /etc/polkit-1/rules.d/
```

This allows audio group members to change JACK settings without password prompts.

---

## Configuration

### Configure JACK Setting

System-wide configuration is recommended:

```bash
# Medium latency - recommended for most users
sudo motu-m4-jack-setting-system.sh 2 --restart

# Low latency
sudo motu-m4-jack-setting-system.sh 1 --restart

# Ultra-low latency (optimized systems only)
sudo motu-m4-jack-setting-system.sh 3 --restart

# Check current setting
sudo motu-m4-jack-setting-system.sh current
```

### Configuration Priority

The system uses this priority hierarchy:

1. **Environment variable** `JACK_SETTING` (highest)
2. **User config** `~/.config/motu-m4/jack-setting.conf`
3. **System config** `/etc/motu-m4/jack-setting.conf`
4. **Default** (Setting 1)

> **Note**: User config overrides system config. Remove user config if unexpected behavior occurs:
> ```bash
> rm ~/.config/motu-m4/jack-setting.conf
> ```

### Using the GUI

```bash
# Start from terminal
motu-m4-jack-gui.py

# Or find in application menu:
# Audio/Video → MOTU M4 JACK Settings
```

---

## JACK Settings Explained

### Setting 1: Low Latency (Default)

```
Sample Rate: 48,000 Hz
Periods: 3
Period Size: 256 frames
Latency: ~5.3 ms
```

Good for general audio work and most production tasks.

### Setting 2: Medium Latency (Recommended)

```
Sample Rate: 48,000 Hz
Periods: 2
Period Size: 512 frames
Latency: ~10.7 ms
```

Most stable option. Recommended for standard systems.

### Setting 3: Ultra-Low Latency

```
Sample Rate: 48,000 Hz
Periods: 3
Period Size: 128 frames
Latency: ~2.7 ms
```

**Warning**: Requires an optimized system with:
- Real-time kernel or kernel with RT patches
- CPU isolation for audio cores
- IRQ threading enabled

Without these optimizations, expect XRuns (audio dropouts).

### Latency Calculation

```
Latency (ms) = (Period Size / Sample Rate) × 1000
```

---

## System Components

### Files Overview

| File | Location | Purpose |
|------|----------|---------|
| `motu-m4-udev-handler.sh` | `/usr/local/bin/` | UDEV event handler |
| `motu-m4-jack-autostart.sh` | `/usr/local/bin/` | JACK autostart (root context) |
| `motu-m4-jack-autostart-user.sh` | `/usr/local/bin/` | JACK autostart (user context) |
| `motu-m4-jack-init.sh` | `/usr/local/bin/` | JACK initialization |
| `motu-m4-jack-shutdown.sh` | `/usr/local/bin/` | Clean JACK shutdown |
| `motu-m4-jack-restart-simple.sh` | `/usr/local/bin/` | JACK restart |
| `motu-m4-jack-setting.sh` | `/usr/local/bin/` | User setting helper |
| `motu-m4-jack-setting-system.sh` | `/usr/local/bin/` | System setting helper |
| `motu-m4-jack-gui.py` | `/usr/local/bin/` | GTK3 GUI |
| `99-motu-m4-jack-combined.rules` | `/etc/udev/rules.d/` | UDEV rules |
| `motu-m4-login-check.service` | `~/.config/systemd/user/` | Login check service |
| `50-motu-m4-jack-settings.rules` | `/etc/polkit-1/rules.d/` | Polkit rule |

### Configuration Files

| File | Purpose |
|------|---------|
| `/etc/motu-m4/jack-setting.conf` | System-wide JACK setting |
| `~/.config/motu-m4/jack-setting.conf` | User-specific JACK setting |

### Log Files

All logs are stored in `/run/motu-m4/`:

| Log | Content |
|-----|---------|
| `jack-uvdev-handler.log` | UDEV handler activity |
| `jack-autostart.log` | Autostart (root context) |
| `jack-autostart-user.log` | Autostart (user context) |
| `jack-login-check.log` | Login check service |
| `jack-init.log` | JACK initialization details |

### Supported Scenarios

| Scenario | Behavior |
|----------|----------|
| Boot with M4 connected | JACK starts after user login |
| Connect M4 after login | JACK starts immediately |
| Disconnect M4 | JACK stops cleanly |
| Multi-monitor setup | Automatic display detection |

---

## Troubleshooting

### Check JACK Status

```bash
# JACK running?
jack_control status

# Current parameters
jack_control dp

# Detailed status
jack_lsp -c
```

### View Logs

```bash
# All logs
ls -la /run/motu-m4/

# UDEV handler
cat /run/motu-m4/jack-uvdev-handler.log

# JACK start details
cat /run/motu-m4/jack-autostart-user.log

# Login check
cat /run/motu-m4/jack-login-check.log
```

### Debug Configuration

```bash
# Full configuration analysis
debug-config.sh

# Shows:
# - Active configuration file
# - Priority resolution
# - Current JACK parameters
```

### Check Services

```bash
# Login check service status
systemctl --user status motu-m4-login-check.service

# Service logs
journalctl --user -u motu-m4-login-check.service
```

### Common Problems

#### JACK won't start

1. Check if MOTU M4 is detected:
   ```bash
   aplay -l | grep M4
   ```

2. Check JACK errors:
   ```bash
   jack_control status
   cat /run/motu-m4/jack-init.log
   ```

3. Verify user is in audio group:
   ```bash
   groups | grep audio
   ```

#### XRuns (audio dropouts)

1. Use a higher latency setting:
   ```bash
   sudo motu-m4-jack-setting-system.sh 2 --restart
   ```

2. Check CPU load and disable power management

3. For Setting 3, ensure kernel optimizations are in place

#### GUI shows wrong status

1. Click "Refresh" button

2. Verify JACK is actually running:
   ```bash
   jack_control status
   ```

#### Permission denied errors

1. Ensure polkit rule is installed:
   ```bash
   ls /etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules
   ```

2. Verify audio group membership:
   ```bash
   groups | grep audio
   ```

---

## Advanced Configuration

### Kernel Optimizations (for Ultra-Low Latency)

For Setting 3 to work reliably, add these kernel boot parameters:

```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX="preempt=full threadirqs"

# Update grub
sudo update-grub
```

For even better performance (advanced users):

```bash
# CPU isolation example (adjust core numbers for your system)
isolcpus=14-19 nohz_full=14-19 rcu_nocbs=14-19
```

### Custom JACK Settings

Edit `/usr/local/bin/motu-m4-jack-init.sh` to add custom settings:

```bash
# Example: Add Setting 4
SETTING4_RATE=192000
SETTING4_NPERIODS=2
SETTING4_PERIOD=64
SETTING4_DESC="Extreme (192kHz, 2x64, ~0.3ms)"
```

### Adapting for Other Audio Interfaces

1. Modify UDEV rule device detection
2. Change `aplay -l | grep "M4"` to match your device
3. Adjust JACK device parameter in `motu-m4-jack-init.sh`

### Environment Variable Override

For temporary testing:

```bash
export JACK_SETTING=3
motu-m4-jack-init.sh
```

---

## Uninstallation

```bash
# Remove scripts
sudo rm /usr/local/bin/motu-m4-*.sh
sudo rm /usr/local/bin/motu-m4-jack-gui.py
sudo rm /usr/local/bin/debug-config.sh

# Remove UDEV rule
sudo rm /etc/udev/rules.d/99-motu-m4-jack-combined.rules
sudo udevadm control --reload-rules

# Remove systemd service
systemctl --user disable motu-m4-login-check.service
rm ~/.config/systemd/user/motu-m4-login-check.service
systemctl --user daemon-reload

# Remove polkit rule
sudo rm /etc/polkit-1/rules.d/50-motu-m4-jack-settings.rules

# Remove desktop entry and icon
sudo rm /usr/share/applications/motu-m4-jack-settings.desktop
sudo rm /usr/share/icons/hicolor/scalable/apps/motu-m4-jack-settings.svg

# Remove configuration
sudo rm -rf /etc/motu-m4/
rm -rf ~/.config/motu-m4/
```

---

## Support

- **Issues**: [GitHub Issues](https://github.com/giang17/motu-m4-jack-starter/issues)
- **License**: GPL-3.0-or-later
# Installation & Configuration Guide

Complete installation, configuration, and troubleshooting guide for the MOTU M4 JACK Automation System.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [JACK Configuration Options](#jack-configuration-options)
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
sudo apt install jackd2 a2jmidid bc

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
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-*.sh
sudo chmod +x /usr/local/bin/debug-config.sh /usr/local/bin/detect-display.sh
```

#### Step 3: Install UDEV Rule

```bash
sudo cp system/99-motu-m4-jack-combined.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

#### Step 4: Enable Login Check Service

```bash
mkdir -p ~/.config/systemd/user/
cp system/motu-m4-login-check.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable motu-m4-login-check.service
```

#### Step 5: Install GUI (Optional)

```bash
sudo cp gui/motu-m4-jack-gui.py /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-jack-gui.py
sudo cp system/motu-m4-jack-settings.desktop /usr/share/applications/
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps/
sudo cp gui/motu-m4-jack-settings.svg /usr/share/icons/hicolor/scalable/apps/
sudo gtk-update-icon-cache /usr/share/icons/hicolor/
```

#### Step 6: Install Polkit Rule (Passwordless Operation)

```bash
sudo cp system/50-motu-m4-jack-settings.rules /etc/polkit-1/rules.d/
```

This allows audio group members to change JACK settings without password prompts.

---

## Configuration

### Quick Start

```bash
# Apply a custom configuration
sudo motu-m4-jack-setting-system.sh --rate=48000 --period=256 --nperiods=3 --restart

# Or use a preset
sudo motu-m4-jack-setting-system.sh 2 --restart

# Check current configuration
sudo motu-m4-jack-setting-system.sh current
```

### Using the GUI

```bash
# Start from terminal
motu-m4-jack-gui.py

# Or find in application menu:
# Audio/Video → MOTU M4 JACK Settings
```

The GUI provides:
- Dropdown menus for sample rate and buffer size
- Spin button for periods
- Live latency calculation
- Quick preset buttons
- Automatic JACK restart option

### Configuration Priority

The system uses this priority hierarchy:

1. **Environment variables** `JACK_RATE`, `JACK_PERIOD`, `JACK_NPERIODS` (highest)
2. **User config** `~/.config/motu-m4/jack-setting.conf`
3. **System config** `/etc/motu-m4/jack-setting.conf`
4. **Default** (48000 Hz, 256 frames, 3 periods)

> **Note**: User config overrides system config. Remove user config if unexpected behavior occurs:
> ```bash
> rm ~/.config/motu-m4/jack-setting.conf
> ```

---

## JACK Configuration Options

### Flexible Configuration (v2.0)

Configure any combination of sample rate, buffer size, and periods:

```bash
# Full syntax
sudo motu-m4-jack-setting-system.sh --rate=<Hz> --period=<frames> --nperiods=<n> [--restart]

# Examples
sudo motu-m4-jack-setting-system.sh --rate=96000 --period=128 --nperiods=2 --restart
sudo motu-m4-jack-setting-system.sh --rate=44100 --period=512 --nperiods=3 --restart
sudo motu-m4-jack-setting-system.sh --rate=192000 --period=64 --nperiods=2 --restart
```

### Valid Values

| Parameter | Valid Values | Description |
|-----------|--------------|-------------|
| `--rate` | 22050, 44100, 48000, 88200, 96000, 176400, 192000 | Sample rate in Hz |
| `--period` | 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 | Buffer size in frames |
| `--nperiods` | 2, 3, 4, 5, 6, 7, 8 | Number of periods |

### Quick Presets

For convenience, presets are still available (v1.x compatible):

| Preset | Sample Rate | Buffer | Periods | Latency | Use Case |
|--------|-------------|--------|---------|---------|----------|
| 1 | 48,000 Hz | 128 | 2 | ~5.3 ms | General audio work |
| 2 | 48,000 Hz | 256 | 2 | ~10.7 ms | Stable, recommended |
| 3 | 48,000 Hz | 64 | 2 | ~2.7 ms | Optimized systems only |

```bash
# Use preset
sudo motu-m4-jack-setting-system.sh 1 --restart
sudo motu-m4-jack-setting-system.sh 2 --restart
sudo motu-m4-jack-setting-system.sh 3 --restart
```

### Latency Calculation

The formula for calculating audio latency:

```
Latency (ms) = (Buffer Size × Periods) / Sample Rate × 1000
```

Examples:
- 256 × 3 / 48000 × 1000 = **5.3 ms**
- 512 × 2 / 48000 × 1000 = **10.7 ms**
- 128 × 3 / 48000 × 1000 = **2.7 ms**
- 128 × 2 / 96000 × 1000 = **2.7 ms** (higher sample rate, same latency)

### Latency Recommendations

| Latency | Stability | Use Case |
|---------|-----------|----------|
| > 10 ms | Very stable | Recording, mixing, general work |
| 5-10 ms | Stable | Most production tasks |
| 3-5 ms | Good | Live monitoring, virtual instruments |
| < 3 ms | Requires optimization | Real-time performance |

**Warning**: Very low latency (< 3 ms) requires an optimized system. See [Advanced Configuration](#kernel-optimizations-for-ultra-low-latency).

### Configuration File Format

The v2.0 configuration format (`/etc/motu-m4/jack-setting.conf`):

```bash
# MOTU M4 JACK Configuration
# Format: v2.0

JACK_RATE=48000
JACK_PERIOD=256
JACK_NPERIODS=3
```

Legacy v1.x format is still supported:

```bash
JACK_SETTING=1
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
| `/etc/motu-m4/jack-setting.conf` | System-wide JACK configuration |
| `~/.config/motu-m4/jack-setting.conf` | User-specific JACK configuration |

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

# JACK initialization
cat /run/motu-m4/jack-init.log

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

1. Increase latency (use larger buffer or more periods):
   ```bash
   sudo motu-m4-jack-setting-system.sh --rate=48000 --period=512 --nperiods=2 --restart
   ```

2. Check CPU load and disable power management

3. For very low latency, ensure kernel optimizations are in place

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

#### Settings not being applied

1. Check for conflicting user config:
   ```bash
   cat ~/.config/motu-m4/jack-setting.conf
   ```

2. Remove user config to use system config:
   ```bash
   rm ~/.config/motu-m4/jack-setting.conf
   ```

---

## Advanced Configuration

### Kernel Optimizations (for Ultra-Low Latency)

For latency below 3ms to work reliably, add these kernel boot parameters:

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

### Environment Variable Override

For temporary testing without changing config files:

```bash
# v2.0 style
export JACK_RATE=96000
export JACK_PERIOD=128
export JACK_NPERIODS=2
motu-m4-jack-init.sh

# Or legacy style
export JACK_SETTING=3
motu-m4-jack-init.sh
```

### Adapting for Other Audio Interfaces

1. Modify UDEV rule device detection (`99-motu-m4-jack-combined.rules`)
2. Change `aplay -l | grep "M4"` to match your device name
3. Adjust JACK device parameter in `motu-m4-jack-init.sh`:
   ```bash
   jack_control dps device hw:YourDevice,0
   ```

### High Sample Rate Configurations

For professional audio work at higher sample rates:

```bash
# 96 kHz studio quality
sudo motu-m4-jack-setting-system.sh --rate=96000 --period=256 --nperiods=2 --restart
# Latency: ~5.3 ms

# 192 kHz high-resolution
sudo motu-m4-jack-setting-system.sh --rate=192000 --period=128 --nperiods=2 --restart
# Latency: ~1.3 ms (requires optimized system)
```

---

## Uninstallation

```bash
# Remove scripts
sudo rm /usr/local/bin/motu-m4-*.sh
sudo rm /usr/local/bin/motu-m4-jack-gui.py
sudo rm /usr/local/bin/debug-config.sh
sudo rm /usr/local/bin/detect-display.sh

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
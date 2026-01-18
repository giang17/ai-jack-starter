# MOTU M4 JACK Automation System for Ubuntu Studio

## Overview

This system provides full automation of the JACK audio server for the MOTU M4 audio interface on Ubuntu Studio. It automatically starts and stops JACK based on hardware detection and user login status.

## System Specifications

- **OS**: Ubuntu 24.04 (Ubuntu Studio Audio Config)
- **Kernel**: 6.11.0-1022-oem (Dell OEM Kernel)
- **Audio Stack**: Pipewire with JACK compatibility
- **Hardware**: MOTU M4 USB Audio Interface
- **Performance**: 10.2ms latency, DSP < 4%, no XRuns

### Kernel Optimizations
```bash
# Boot parameters
preempt=full threadirqs isolcpus=14-19 nohz_full=14-19 rcu_nocbs=14-19
```

- **CPU Isolation**: Cores 14-19 reserved for audio
- **IRQ Threading**: Improved interrupt handling
- **No-Hz/RCU**: Reduced timer interrupts on isolated cores

## System Components

### 1. UDEV Rule (`99-motu-m4-jack-combined.rules`)
- Automatically detects MOTU M4 connection/disconnection
- Calls appropriate handler scripts
- Creates trigger files for boot scenarios

### 2. UDEV Handler (`motu-m4-udev-handler.sh`)
- Runs as root via UDEV
- Checks user login status
- Manages JACK start/stop for hot-plug scenarios

### 3. JACK Autostart Scripts
- **`motu-m4-jack-autostart.sh`**: For root context (UDEV)
- **`motu-m4-jack-autostart-user.sh`**: For user context (systemd)
- **`motu-m4-jack-init.sh`**: Actual JACK startup with parameters
- **`motu-m4-jack-shutdown.sh`**: Clean JACK shutdown

### 4. Login Check Service (`motu-m4-login-check.service`)
- Systemd user service
- Checks for already connected M4 after login
- Starts JACK for boot scenarios

### 5. Setting Helper (`motu-m4-jack-setting.sh`)
- Simple selection between JACK configurations
- Persistent storage in ~/.config/motu-m4/jack-setting.conf
- Clear display of available settings

### 6. System Setting Helper (`motu-m4-jack-setting-system.sh`)
- System-wide JACK configuration (requires sudo)
- Configuration for all users
- Robust solution for UDEV/root contexts

### 7. GUI (`motu-m4-jack-gui.py`)
- Minimalistic GTK3 interface
- Display of JACK status and hardware connection
- Selection between 3 JACK settings
- Automatic restart with pkexec for administrator privileges

## JACK Configuration

The system supports three preconfigured JACK parameter sets:

### Setting 1: Low Latency (Default)
```bash
Device: hw:M4,0
Sample Rate: 48000 Hz
Periods: 3
Period Size: 256 frames
Latency: ~5.3 ms
Backend: ALSA
MIDI: ALSA-JACK Bridge (a2j)
```

### Setting 2: Medium Latency
```bash
Device: hw:M4,0
Sample Rate: 48000 Hz
Periods: 2
Period Size: 512 frames
Latency: ~10.7 ms
Backend: ALSA
MIDI: ALSA-JACK Bridge (a2j)
```

### Setting 3: Ultra-Low Latency
```bash
Device: hw:M4,0
Sample Rate: 96000 Hz
Periods: 3
Period Size: 128 frames
Latency: ~1.3 ms
Backend: ALSA
MIDI: ALSA-JACK Bridge (a2j)
```

### Setting Selection

The system uses a **priority hierarchy** for configuration:

1. **Environment variable** `JACK_SETTING` (highest priority)
2. **User configuration** `~/.config/motu-m4/jack-setting.conf`
3. **System-wide configuration** `/etc/motu-m4/jack-setting.conf`
4. **Default setting** (Setting 1)

```bash
# Via environment variable (temporary)
export JACK_SETTING=1  # Default (low latency)
export JACK_SETTING=2  # Medium latency
export JACK_SETTING=3  # Ultra-low latency

# With user helper script (persistent)
./motu-m4-jack-setting.sh 1  # Activate Setting 1
./motu-m4-jack-setting.sh 2  # Activate Setting 2 (Medium latency)
./motu-m4-jack-setting.sh 3  # Activate Setting 3

# With system helper script (system-wide, requires sudo - RECOMMENDED)
sudo ./motu-m4-jack-setting-system.sh 1 --restart  # Low latency (~5.3ms)
sudo ./motu-m4-jack-setting-system.sh 2 --restart  # Medium latency (~10.7ms)
sudo ./motu-m4-jack-setting-system.sh 3 --restart  # Ultra-low latency (~1.3ms)
```

### Why This Hierarchy?
- **UDEV handler** (root context) cannot read user's `.bashrc`
- **Systemd services** have limited environment variables
- **Configuration files** work in all contexts
- **Flexibility** for different use cases

### Automatic Restart
Both setting scripts support automatic JACK restart with `--restart`:
- **Checks** if MOTU M4 is available
- **Detects** if JACK is running (restart vs. start)
- **Applies** new settings immediately
- **Robust** error handling

## Supported Scenarios

| Scenario | Behavior | Component |
|----------|----------|-----------|
| **Boot with M4 connected** | Trigger file → JACK after login | UDEV + Login-Check |
| **Connect M4 after login** | JACK starts immediately | UDEV Handler |
| **Disconnect M4** | JACK stops cleanly | UDEV Handler |
| **Multi-monitor** | Flexible display detection | All components |

## Installation

### 1. Install Scripts
```bash
sudo cp motu-m4-*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-*.sh
```

### 1a. Install GUI (optional)
```bash
# Automatic installation
sudo ./install-gui.sh

# Or manually:
sudo cp motu-m4-jack-gui.py /usr/local/bin/
sudo chmod +x /usr/local/bin/motu-m4-jack-gui.py
sudo cp motu-m4-jack-settings.desktop /usr/share/applications/
```

**GUI Dependencies:**
```bash
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0
```

### 2. Install UDEV Rule
```bash
sudo cp 99-motu-m4-jack-combined.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### 3. Enable Systemd User Service
```bash
mkdir -p ~/.config/systemd/user/
cp motu-m4-login-check.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable motu-m4-login-check.service
```

### 4. Configure JACK Setting

#### System-wide Configuration (RECOMMENDED for production use)
```bash
# Configure system-wide once - works for all scenarios
sudo ./motu-m4-jack-setting-system.sh 2 --restart  # Medium latency (recommended)

# All available settings:
sudo ./motu-m4-jack-setting-system.sh 1 --restart  # Low latency (48kHz, 3x256, ~5.3ms)
sudo ./motu-m4-jack-setting-system.sh 2 --restart  # Medium latency (48kHz, 2x512, ~10.7ms)  
sudo ./motu-m4-jack-setting-system.sh 3 --restart  # Ultra-low latency (96kHz, 3x128, ~1.3ms)

# Check status
sudo ./motu-m4-jack-setting-system.sh current
jack_settings.sh  # Display current JACK parameters
```

#### User-specific Configuration (optional)
```bash
# Only use if user-specific settings are desired
./motu-m4-jack-setting.sh 2 --restart

# Show available settings
./motu-m4-jack-setting.sh show

# IMPORTANT: User config overrides system config!
# To remove: rm ~/.config/motu-m4/jack-setting.conf
```

#### Quick Start (Recommended Configuration)
```bash
# Perfect for most use cases:
sudo ./motu-m4-jack-setting-system.sh 2 --restart
```

## Files in the System

```
/usr/local/bin/
├── motu-m4-udev-handler.sh          # UDEV handler (root)
├── motu-m4-jack-autostart.sh        # Autostart for UDEV context
├── motu-m4-jack-autostart-user.sh   # Autostart for user context
├── motu-m4-jack-init.sh             # JACK initialization
├── motu-m4-jack-shutdown.sh         # JACK shutdown
├── motu-m4-jack-restart-simple.sh   # JACK restart
├── motu-m4-jack-setting.sh          # User setting helper
├── motu-m4-jack-setting-system.sh   # System setting helper
├── motu-m4-jack-gui.py              # GTK3 GUI
└── debug-config.sh                  # Configuration debug tool

/usr/share/applications/
└── motu-m4-jack-settings.desktop    # Desktop entry for GUI

/etc/udev/rules.d/
└── 99-motu-m4-jack-combined.rules   # Hardware detection rules

~/.config/systemd/user/
└── motu-m4-login-check.service      # Login check service

~/.config/motu-m4/                    # User configuration
└── jack-setting.conf                # User JACK setting

/etc/motu-m4/                         # System configuration
└── jack-setting.conf                # System JACK setting

/run/motu-m4/                         # Runtime logs
├── jack-autostart.log
├── jack-autostart-user.log
├── jack-login-check.log
├── jack-uvdev-handler.log
├── jack-init.log
└── m4-detected                      # Trigger file
```

## Solved Technical Challenges

### 1. Display Detection
**Problem**: Dual-monitor setup changed display from `:0` to `:1`
**Solution**: Flexible detection with `grep "(:"`

### 2. User Permissions
**Problem**: `runuser` only works as root
**Solution**: Separate scripts for different execution contexts

### 3. Timing Issues
**Problem**: DBUS socket not available on early start
**Solution**: Wait loops and login detection

### 4. Log Permissions
**Problem**: Conflicting write permissions between root and user
**Solution**: Separate log files in `/run/motu-m4/`

### 5. Configuration in Different Contexts
**Problem**: UDEV (root) cannot read user's `.bashrc`
**Solution**: Hierarchical configuration via files with fallback mechanism

### 6. User-Config vs. System-Config Conflicts
**Problem**: User configuration overrides system-wide settings unnoticed
**Solution**: Debug tools and clear recommendation for system-wide configuration

## Debugging

### Check Log Files
```bash
# Show all logs
ls -la /run/motu-m4/

# UDEV handler activity
cat /run/motu-m4/jack-uvdev-handler.log

# Login check activity
cat /run/motu-m4/jack-login-check.log

# JACK start details
cat /run/motu-m4/jack-autostart-user.log
```

### Check JACK Status
```bash
jack_control status
jack_control dp  # Show parameters
jack_settings.sh  # Clear parameter display
```

### Debug Configuration
```bash
# Full configuration analysis:
bash debug-config.sh

# Shows priority resolution and current parameters
```

### Check Services
```bash
systemctl --user status motu-m4-login-check.service
```

## Advanced Configuration

### IRQ Affinity (optional)
```bash
# set_irq_affinity.sh for optimal IRQ distribution
# Can be run automatically via systemd service
```

### Alternative Audio Interfaces
- Scripts can be adapted for other USB audio interfaces
- Change `aplay -l | grep "INTERFACE_NAME"` in the scripts
- Adjust JACK parameters in `motu-m4-jack-init.sh`
- Define new settings via variables at the beginning of the script

### Customize JACK Parameters
```bash
# Add new settings in motu-m4-jack-init.sh:
SETTING4_RATE=192000
SETTING4_NPERIODS=2
SETTING4_PERIOD=64
SETTING4_DESC="Extreme Latency (192kHz, 2x64)"
```

### Understanding Configuration Priority
The **priority hierarchy** makes the system robust for different scenarios:

- **Development/Testing**: Environment variable for temporary changes
- **Normal Operation**: User configuration for personal settings
- **System Administration**: System-wide configuration for all users
- **Fallback**: Default setting as a safe base

### Using Automatic Restart
```bash
# Recommended usage (immediate application):
sudo ./motu-m4-jack-setting-system.sh 2 --restart

# Without automatic restart (manually later):
sudo ./motu-m4-jack-setting-system.sh 2
sudo ./motu-m4-jack-restart-simple.sh
```

### Production Recommendations
```bash
# Optimal configuration for most setups:
sudo ./motu-m4-jack-setting-system.sh 2 --restart

# Avoid user configurations:
rm ~/.config/motu-m4/jack-setting.conf  # If present

# Check status regularly:
bash debug-config.sh
```

### Using the GUI
```bash
# Start GUI
motu-m4-jack-gui.py

# Or via application menu:
# Audio/Video → MOTU M4 JACK Settings
```

The GUI offers:
- **Status Display**: JACK server status and hardware connection
- **Setting Selection**: All 3 latency profiles with details
- **Automatic Restart**: Optional after changes
- **Administrator Privileges**: Via pkexec (password prompt)

## Compatibility

- **Ubuntu Studio 24.04+**
- **Pipewire-based audio stacks**
- **JACK2 via D-Bus**
- **USB audio interfaces with ALSA support**
- **Multi-monitor setups**

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPL-3.0).

You may freely use, modify, and distribute this software, provided you:
- Retain the license
- Make the source code available
- Document changes

See [LICENSE](LICENSE) for the full license text.

---

**Developed and tested**: January 2026  
**License**: GPL-3.0-or-later  
**Status**: Production Ready ✅
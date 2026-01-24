# Changelog

All notable changes to this project are documented here.

For detailed release notes, see [GitHub Releases](https://github.com/giang17/motu-m4-jack-starter/releases).

## [v2.1.3](https://github.com/giang17/motu-m4-jack-starter/releases/tag/v2.1.3) - 2026-01-24

### Improved Error Handling (Python GUI)
- Add comprehensive exception handling for DBus operations with logging
- Add logging module with file output to `~/.local/share/motu-m4/gui.log`
- Replace generic `Exception` catches with specific types (`TimeoutExpired`, `FileNotFoundError`, `CalledProcessError`, `PermissionError`)
- Add DBus error detection and warning logs when DBus is unavailable at boot time
- Improve file I/O error handling for config reading

### Code Quality Improvements
- Fix ShellCheck warnings in `detect-display.sh`
- Translate all shell script comments from German to English
- Add ShellCheck CI workflow for automated code quality checks

## [v2.1.2](https://github.com/giang17/motu-m4-jack-starter/releases/tag/v2.1.2) - 2026-01-23

### Bugfixes
- **jack_control**: Status check now handles DBus errors gracefully
- **a2j_control**: All calls (--ehw, --start, --stop) now use safe wrapper
- **Fallback**: Uses killall if a2j_control --stop fails due to DBus issues

## [v2.1.1](https://github.com/giang17/motu-m4-jack-starter/releases/tag/v2.1.1) - 2026-01-22

### Bugfixes
- **Fixed DBus crash at boot** - A2J status check now handles DBus errors gracefully
- **Fixed A2J status display** - Correctly detects "Bridging enabled" instead of "bridge is running"
- **Improved A2J stop logic** - Uses pgrep fallback when DBus is not available

## [v2.1.0](https://github.com/giang17/motu-m4-jack-starter/releases/tag/v2.1.0) - 2026-01-22

### New Features
- **A2J MIDI Bridge toggle** - Enable/disable a2jmidid directly from GUI
- **A2J status indicator** - Shows whether a2jmidid is running or stopped
- **Automatic status refresh** - Status updates every 5 seconds
- **Fixes "device busy" errors** - Modern DAWs (Bitwig, Reaper) can now access MIDI directly

## [v2.0.0](https://github.com/giang17/motu-m4-jack-starter/releases/tag/v2.0.0) - 2026-01-18

### Major Release - Fully customizable JACK audio settings!

#### Flexible Configuration
- **Sample Rate**: 22050, 44100, 48000, 88200, 96000, 176400, 192000 Hz
- **Buffer Size**: 16, 32, 64, 128, 256, 512, 1024, 2048, 4096 frames
- **Periods**: 2 - 8

#### Redesigned GUI
- Dropdown menus for sample rate and buffer size
- Spin button for periods
- **Live latency calculation** with color coding
- Quick preset buttons (Low ~5ms, Medium ~11ms, Ultra ~3ms)
- Status monitoring with current configuration display

#### Backward Compatible
- Legacy preset syntax still works
- Automatic migration from v1.x config format

## [v1.0.0](https://github.com/giang17/motu-m4-jack-starter/releases/tag/v1.0.0) - 2026-01-18

### Initial Release
- Automatic JACK start/stop when MOTU M4 is connected/disconnected
- Hot-plug support
- Boot detection - JACK starts after login if M4 is already connected
- GTK3 GUI for easy setting selection
- 3 latency profiles: Low (~5.3ms), Medium (~10.7ms), Ultra-Low (~2.7ms)
- Passwordless operation via polkit for audio group members

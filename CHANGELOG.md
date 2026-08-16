# Changelog

All notable changes to this project are documented here.

For detailed release notes, see [GitHub Releases](https://github.com/giang17/ai-jack-starter/releases).

## [Unreleased]

### Wayland Support

#### Fixed
- **Autostart under Wayland** - JACK now starts on Plasma/GNOME Wayland sessions.
  User detection relied on `who | grep "(:"`, which matches the X11 display entry
  in utmp. Wayland sessions carry no such entry, so `ai-login-check.service` waited
  the full 120 seconds and aborted with "No user logged in", leaving JACK stopped.
- **Hot-plug under Wayland** - the udev handler used the same X11-only check and
  therefore only ever wrote the trigger file instead of starting JACK when an
  interface was connected on a running desktop.
- **Display detection** - `DISPLAY` is now resolved to the Xwayland display on
  Wayland sessions instead of falling back to a hardcoded `:0`.
- **Autostart on re-login** - the login check treated `/run/ai-jack/device-detected`
  as a precondition for starting JACK. That file is written by the udev handler
  before anyone is logged in and is deleted once the first login has processed it,
  so any second login within the same boot - logging out of X11 and back into
  Wayland, or simply re-logging in - left JACK stopped. The check now decides on
  the actual state (interface present, no JACK server running) and treats the
  trigger file as a hint only. A running server is detected via `jack_control`,
  so an already-running JACK is left untouched.

#### Added
- **`ai-jack-session.sh`** - session detection library built on `loginctl`, which
  is display-server agnostic. Provides `get_active_session_user`,
  `get_active_session_display`, `get_active_session_type`, `is_user_logged_in`,
  `get_active_session_uid` and `get_active_session_dbus_socket`.
  Greeter sessions (SDDM/GDM) are skipped via `Class=user`, so JACK is no longer
  started for the display manager's account.
- **`detect-display.sh analyze`** - now reports logind session properties and
  session type alongside the legacy `who` output, plus `user` and `type`
  subcommands for quick diagnosis.

#### Changed
- All scripts detect the active session through the new library; the legacy
  X11-only lookup remains only as an inline fallback when the library is missing.

---

## [v1.0.1](https://github.com/giang17/ai-jack-starter/releases/tag/v1.0.1) - 2026-01-24

### Hotplug Fix

#### Fixed
- **Hot-plug device switching** - Switching between different audio interfaces (e.g., MOTU M4 ↔ Scarlett Solo) now works correctly
- **Device auto-detection** - JACK always uses the currently connected device, regardless of config file

#### Removed
- **Detection Pattern input field** - No longer needed, devices are fully auto-detected
- **"Custom (enter manually)" option** - Removed from device dropdown

#### Changed
- Init script now always auto-detects the available device instead of using config
- udev handler checks for any external USB audio device, not just configured pattern
- GUI shows the actually connected device in status display
- Pattern is auto-extracted from device name (e.g., `hw:M4,0` → `M4`)

---

## [v1.0.0](https://github.com/giang17/ai-jack-starter/releases/tag/v1.0.0) - 2026-01-24

### Initial Release - Universal Audio Interface JACK Starter

Forked from motu-m4-jack-starter and redesigned to support any USB audio interface.

#### Universal Device Support
- **Auto-detection** of any USB audio interface (MOTU, Focusrite, RME, Steinberg, etc.)
- **Dynamic device selection** - choose your interface from a dropdown menu
- **Hardware info display** - shows detected sample rates and channel configuration

#### Features
- Automatic JACK start/stop when audio interface is connected/disconnected
- Hot-plug support via udev rules
- Boot detection - JACK starts after login if interface is already connected
- GTK3 GUI for easy configuration
- Flexible settings: sample rate, buffer size, periods
- Live latency calculation with color coding
- Quick preset buttons (Low, Medium, Ultra-low latency)
- A2J MIDI bridge toggle with status indicator
- Configurable DBus timeout for reliable autostart

#### New App Icon
- Modern design with stylized audio jack plug
- Sound wave indicators and AI badge
- Settings gear icon

#### Technical Improvements
- Locale-independent hardware detection (works with any system language)
- Comprehensive error handling and logging
- ShellCheck-validated shell scripts

# Changelog

All notable changes to this project are documented here.

For detailed release notes, see [GitHub Releases](https://github.com/giang17/ai-jack-starter/releases).

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

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Audio Interface JACK Settings GUI - v3.0
A GTK3 GUI for flexible JACK audio configuration
for any JACK-compatible audio interface.

Features:
- Device selection dropdown (auto-detection via aplay -l)
- Flexible sample rate selection (22050 - 192000 Hz)
- Flexible buffer size selection (16 - 4096 frames)
- Adjustable periods (2-8)
- Live latency calculation
- Quick presets for common configurations
- Automatic system theme integration (KDE/GNOME/etc.)

Copyright (C) 2025
License: GPL-3.0-or-later
"""

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
import logging
import os
import re
import subprocess
import threading

from gi.repository import Gdk, GLib, Gtk

# Configure logging for DBus operations and error tracking
LOG_DIR = os.path.expanduser("~/.local/share/ai-jack")
LOG_FILE = os.path.join(LOG_DIR, "gui.log")

# Ensure log directory exists
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)


class AudioInterfaceJackGUI(Gtk.Window):
    """Main window for Audio Interface JACK Settings GUI"""

    # Paths
    SYSTEM_CONFIG_FILE = "/etc/ai-jack/jack-setting.conf"
    USER_CONFIG_FILE = os.path.expanduser("~/.config/ai-jack/jack-setting.conf")
    SETTING_SCRIPT = "/usr/local/bin/ai-jack-setting-system.sh"

    # Valid values
    SAMPLE_RATES = [22050, 44100, 48000, 88200, 96000, 176400, 192000]
    BUFFER_SIZES = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
    MIN_PERIODS = 2
    MAX_PERIODS = 8

    # Presets (for quick selection) - ordered by latency: Ultra -> Low -> Medium
    PRESETS = {
        "ultra": {"name": "Ultra-Low", "rate": 48000, "period": 64, "nperiods": 3},
        "low": {"name": "Low Latency", "rate": 48000, "period": 128, "nperiods": 2},
        "medium": {
            "name": "Medium Latency",
            "rate": 48000,
            "period": 256,
            "nperiods": 2,
        },
    }

    # Legacy preset mapping (for backward compatibility)
    LEGACY_PRESETS = {
        1: {"rate": 48000, "period": 128, "nperiods": 2},
        2: {"rate": 48000, "period": 256, "nperiods": 2},
        3: {"rate": 48000, "period": 64, "nperiods": 2},
    }

    # Icon path
    ICON_PATH = "/usr/share/icons/hicolor/scalable/apps/ai-jack-settings.svg"

    def __init__(self):
        super().__init__(title="Audio Interface JACK Settings")
        self.set_border_width(15)
        self.set_default_size(450, 600)
        self.set_resizable(False)

        # Timer ID for automatic status refresh
        self.status_timer_id = None

        # Flag to prevent recursive updates
        self.updating_ui = False

        # Detected audio devices
        self.detected_devices = []

        # Track previous hardware status for auto-refresh
        self.previous_hardware_found = None

        # Get theme colors
        self._init_theme_colors()

        # Set icon
        if os.path.exists(self.ICON_PATH):
            self.set_icon_from_file(self.ICON_PATH)
        else:
            self.set_icon_name("audio-card")

        # Main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.add(main_box)

        # Title
        title_label = Gtk.Label()
        title_label.set_markup("<b><big>Audio Interface JACK Settings</big></b>")
        main_box.pack_start(title_label, False, False, 5)

        # Status frame
        status_frame = Gtk.Frame(label=" Status ")
        status_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        status_box.set_border_width(10)
        status_frame.add(status_box)
        main_box.pack_start(status_frame, False, False, 0)

        # Status labels
        self.jack_status_label = Gtk.Label()
        self.jack_status_label.set_halign(Gtk.Align.START)
        status_box.pack_start(self.jack_status_label, False, False, 0)

        self.hardware_status_label = Gtk.Label()
        self.hardware_status_label.set_halign(Gtk.Align.START)
        status_box.pack_start(self.hardware_status_label, False, False, 0)

        self.current_config_label = Gtk.Label()
        self.current_config_label.set_halign(Gtk.Align.START)
        status_box.pack_start(self.current_config_label, False, False, 0)

        # Device Selection frame
        device_frame = Gtk.Frame(label=" Audio Device ")
        device_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        device_box.set_border_width(10)
        device_frame.add(device_box)
        main_box.pack_start(device_frame, False, False, 0)

        # Device dropdown
        device_grid = Gtk.Grid()
        device_grid.set_column_spacing(15)
        device_grid.set_row_spacing(8)
        device_box.pack_start(device_grid, False, False, 0)

        device_label = Gtk.Label(label="Device:")
        device_label.set_halign(Gtk.Align.END)
        device_grid.attach(device_label, 0, 0, 1, 1)

        device_hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        self.device_combo = Gtk.ComboBoxText()
        self.device_combo.set_hexpand(True)
        self.device_combo.connect("changed", self.on_device_changed)
        device_hbox.pack_start(self.device_combo, True, True, 0)

        # Refresh devices button
        refresh_devices_btn = Gtk.Button(label="Refresh")
        refresh_devices_btn.set_tooltip_text("Scan for audio devices")
        refresh_devices_btn.connect("clicked", self.on_refresh_devices_clicked)
        device_hbox.pack_start(refresh_devices_btn, False, False, 0)
        device_grid.attach(device_hbox, 1, 0, 1, 1)

        # Configuration frame
        config_frame = Gtk.Frame(label=" JACK Configuration ")
        config_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        config_box.set_border_width(10)
        config_frame.add(config_box)
        main_box.pack_start(config_frame, False, False, 0)

        # Grid for configuration options
        config_grid = Gtk.Grid()
        config_grid.set_column_spacing(15)
        config_grid.set_row_spacing(10)
        config_box.pack_start(config_grid, False, False, 0)

        # Sample Rate
        rate_label = Gtk.Label(label="Sample Rate:")
        rate_label.set_halign(Gtk.Align.END)
        config_grid.attach(rate_label, 0, 0, 1, 1)

        self.rate_combo = Gtk.ComboBoxText()
        for rate in self.SAMPLE_RATES:
            self.rate_combo.append_text(f"{rate:,} Hz".replace(",", "."))
        self.rate_combo.set_active(self.SAMPLE_RATES.index(48000))  # Default 48kHz
        self.rate_combo.connect("changed", self.on_config_changed)
        self.rate_combo.set_hexpand(True)
        config_grid.attach(self.rate_combo, 1, 0, 1, 1)

        # Buffer Size
        buffer_label = Gtk.Label(label="Buffer Size:")
        buffer_label.set_halign(Gtk.Align.END)
        config_grid.attach(buffer_label, 0, 1, 1, 1)

        self.buffer_combo = Gtk.ComboBoxText()
        for size in self.BUFFER_SIZES:
            self.buffer_combo.append_text(f"{size} frames")
        self.buffer_combo.set_active(self.BUFFER_SIZES.index(256))  # Default 256
        self.buffer_combo.connect("changed", self.on_config_changed)
        self.buffer_combo.set_hexpand(True)
        config_grid.attach(self.buffer_combo, 1, 1, 1, 1)

        # Periods
        periods_label = Gtk.Label(label="Periods:")
        periods_label.set_halign(Gtk.Align.END)
        config_grid.attach(periods_label, 0, 2, 1, 1)

        periods_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        adjustment = Gtk.Adjustment(
            value=3,
            lower=self.MIN_PERIODS,
            upper=self.MAX_PERIODS,
            step_increment=1,
            page_increment=1,
            page_size=0,
        )
        self.periods_spin = Gtk.SpinButton()
        self.periods_spin.set_adjustment(adjustment)
        self.periods_spin.set_numeric(True)
        self.periods_spin.set_value(3)  # Default 3
        self.periods_spin.connect("value-changed", self.on_config_changed)
        periods_box.pack_start(self.periods_spin, False, False, 0)
        config_grid.attach(periods_box, 1, 2, 1, 1)

        # Separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        config_box.pack_start(separator, False, False, 5)

        # Latency display
        latency_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        latency_box.set_halign(Gtk.Align.CENTER)
        config_box.pack_start(latency_box, False, False, 0)

        latency_title = Gtk.Label()
        latency_title.set_markup("<b>Buffer Latency / Round-Trip Latency:</b>")
        latency_box.pack_start(latency_title, False, False, 0)

        self.latency_label = Gtk.Label()
        self.latency_label.set_markup(
            f"<span size='large' foreground='{self.color_success}'>~2.7 ms</span>  /  "
            f"<span size='large' foreground='{self.color_success}'>~5.3 ms</span>"
        )
        latency_box.pack_start(self.latency_label, False, False, 0)

        # Latency warning
        self.latency_warning = Gtk.Label()
        self.latency_warning.set_markup(
            f"<span foreground='{self.color_warning}' size='small'>Warning: Very low latency may cause audio glitches</span>"
        )
        self.latency_warning.set_no_show_all(True)
        config_box.pack_start(self.latency_warning, False, False, 0)

        # Presets frame
        presets_frame = Gtk.Frame(label=" Quick Presets ")
        presets_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        presets_box.set_border_width(10)
        presets_box.set_halign(Gtk.Align.CENTER)
        presets_frame.add(presets_box)
        main_box.pack_start(presets_frame, False, False, 0)

        # Preset buttons (dynamically generated from PRESETS)
        self.preset_buttons = {}

        for preset_key, preset_data in self.PRESETS.items():
            _, roundtrip = self._calculate_preset_latency(preset_data)
            btn = Gtk.Button(label=f"{preset_data['name']} (~{roundtrip}ms)")
            btn.set_tooltip_text(
                f"{preset_data['rate']}Hz, {preset_data['period']} frames, "
                f"{preset_data['nperiods']} periods"
            )
            btn.connect("clicked", self.on_preset_clicked, preset_key)
            presets_box.pack_start(btn, True, True, 0)
            self.preset_buttons[preset_key] = btn

        # Options frame
        options_frame = Gtk.Frame(label=" Options ")
        options_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        options_box.set_border_width(10)
        options_frame.add(options_box)
        main_box.pack_start(options_frame, False, False, 0)

        # A2J MIDI Bridge checkbox
        a2j_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.a2j_check = Gtk.CheckButton(
            label="Enable ALSA-to-JACK MIDI Bridge (a2jmidid)"
        )
        self.a2j_check.set_active(False)
        self.a2j_check.set_tooltip_text(
            "Enable for hardware MIDI controllers in JACK.\n"
            "Disable for modern DAWs like Bitwig/Reaper to avoid 'device busy' errors."
        )
        a2j_box.pack_start(self.a2j_check, False, False, 0)

        # A2J status indicator
        self.a2j_status_label = Gtk.Label()
        self.a2j_status_label.set_markup("<small>(stopped)</small>")
        a2j_box.pack_start(self.a2j_status_label, False, False, 0)
        options_box.pack_start(a2j_box, False, False, 0)

        # Checkbox for automatic restart
        self.restart_check = Gtk.CheckButton(
            label="Automatically restart JACK after changes"
        )
        self.restart_check.set_active(True)
        options_box.pack_start(self.restart_check, False, False, 0)

        # Button box
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_halign(Gtk.Align.END)
        main_box.pack_start(button_box, False, False, 5)

        # Apply button
        self.apply_button = Gtk.Button(label="Apply")
        self.apply_button.get_style_context().add_class("suggested-action")
        self.apply_button.connect("clicked", self.on_apply_clicked)
        button_box.pack_start(self.apply_button, False, False, 0)

        # Close button
        close_button = Gtk.Button(label="Close")
        close_button.connect("clicked", Gtk.main_quit)
        button_box.pack_start(close_button, False, False, 0)

        # Spinner for loading animation
        self.spinner = Gtk.Spinner()
        button_box.pack_start(self.spinner, False, False, 0)

        # Status bar
        self.statusbar = Gtk.Label()
        self.statusbar.set_halign(Gtk.Align.START)
        main_box.pack_start(self.statusbar, False, False, 0)

        # Detect audio devices
        self.refresh_audio_devices()

        # Load initial status and configuration
        self.refresh_status()
        self.load_current_config()
        self.update_latency_display()

        # Start automatic status refresh (every 5 seconds)
        self.start_status_timer()

        # Show window
        self.connect("destroy", self.on_destroy)
        self.show_all()
        self.spinner.hide()
        self.latency_warning.hide()

    def _init_theme_colors(self):
        """Initialize colors from system theme or use sensible defaults"""
        # Try to get colors from GTK theme
        style_context = Gtk.StyleContext()

        # Create a temporary widget to get theme colors
        temp_widget = Gtk.Label()
        style_context = temp_widget.get_style_context()

        # Default colors (GNOME/Adwaita-like, work well on most themes)
        self.color_success = "#26a269"  # Green
        self.color_error = "#c01c28"  # Red
        self.color_warning = "#e5a50a"  # Orange/Yellow
        self.color_accent = "#3584e4"  # Blue
        self.color_muted = "#888888"  # Gray for disabled/inactive states

        # Try to detect dark theme and adjust colors for better visibility
        settings = Gtk.Settings.get_default()
        if settings:
            prefer_dark = settings.get_property("gtk-application-prefer-dark-theme")
            theme_name = settings.get_property("gtk-theme-name") or ""

            # Check if using a dark theme
            is_dark = prefer_dark or "dark" in theme_name.lower()

            if is_dark:
                # Brighter colors for dark themes
                self.color_success = "#33d17a"  # Brighter green
                self.color_error = "#f66151"  # Brighter red
                self.color_warning = "#f8e45c"  # Brighter yellow
                self.color_accent = "#62a0ea"  # Brighter blue
                self.color_muted = "#999999"  # Lighter gray for dark themes

        # Try to get actual theme colors via CSS lookup
        try:
            # For GNOME/GTK themes that define these
            rgba_success = Gdk.RGBA()
            rgba_error = Gdk.RGBA()

            if style_context.lookup_color("success_color", rgba_success)[0]:
                self.color_success = self._rgba_to_hex(rgba_success)
                logger.debug("Using theme success color: %s", self.color_success)
            if style_context.lookup_color("error_color", rgba_error)[0]:
                self.color_error = self._rgba_to_hex(rgba_error)
                logger.debug("Using theme error color: %s", self.color_error)
        except AttributeError as e:
            logger.warning(
                "GTK theme color lookup failed (missing attributes): %s", str(e)
            )
        except TypeError as e:
            logger.warning("GTK theme color lookup failed (type error): %s", str(e))
        except Exception as e:
            logger.warning(
                "Unexpected error looking up theme colors: %s", type(e).__name__
            )

    def _rgba_to_hex(self, rgba):
        """Convert Gdk.RGBA to hex color string"""
        return "#{:02x}{:02x}{:02x}".format(
            int(rgba.red * 255), int(rgba.green * 255), int(rgba.blue * 255)
        )

    def on_destroy(self, widget):
        """Handler for window close - stop timer and quit"""
        self.stop_status_timer()
        Gtk.main_quit()

    def start_status_timer(self):
        """Starts the automatic status refresh timer"""
        if self.status_timer_id is None:
            self.status_timer_id = GLib.timeout_add(5000, self.on_status_timer)

    def stop_status_timer(self):
        """Stops the automatic status refresh timer"""
        if self.status_timer_id is not None:
            GLib.source_remove(self.status_timer_id)
            self.status_timer_id = None

    def on_status_timer(self):
        """Timer callback for automatic status refresh"""
        self.update_status_display()
        return True

    # Patterns to filter out internal/onboard audio devices
    INTERNAL_DEVICE_PATTERNS = [
        "HDA NVidia",
        "HDA Intel",
        "HDA ATI",
        "HDA AMD",
        "HDMI",
        "sof-",  # Intel SOF (Sound Open Firmware)
        "PCH",  # Intel Platform Controller Hub
    ]

    def is_internal_device(self, card_name, card_id):
        """Check if device is an internal/onboard audio device"""
        check_str = f"{card_name} {card_id}".upper()
        for pattern in self.INTERNAL_DEVICE_PATTERNS:
            if pattern.upper() in check_str:
                return True
        return False

    def refresh_audio_devices(self):
        """Detect and populate audio devices from aplay -l (filters internal devices)"""
        # Remember currently selected device to restore after refresh
        previously_selected = self.get_selected_device()

        self.detected_devices = []
        self.device_combo.remove_all()

        try:
            # Force English output by setting LC_ALL=C
            env = os.environ.copy()
            env["LC_ALL"] = "C"
            result = subprocess.run(
                ["aplay", "-l"], capture_output=True, text=True, timeout=5, env=env
            )

            # Parse aplay output
            # Example: "card 0: M4 [MOTU M4], device 0: USB Audio [USB Audio]"
            pattern = r"card (\d+): (\w+) \[([^\]]+)\], device (\d+):"

            for line in result.stdout.splitlines():
                match = re.search(pattern, line)
                if match:
                    card_num = match.group(1)
                    card_id = match.group(2)
                    card_name = match.group(3)
                    device_num = match.group(4)

                    # Skip internal/onboard devices
                    if self.is_internal_device(card_name, card_id):
                        logger.debug(
                            "Skipping internal device: %s [%s]", card_name, card_id
                        )
                        continue

                    device_id = f"hw:{card_id},{device_num}"
                    display_name = f"{card_name} ({device_id})"

                    self.detected_devices.append(
                        {
                            "id": device_id,
                            "name": card_name,
                            "card_id": card_id,
                            "display": display_name,
                        }
                    )
                    self.device_combo.append_text(display_name)

            # Restore previous selection if still available, otherwise select first
            if self.detected_devices:
                self.updating_ui = True
                restored = False
                if previously_selected:
                    for i, dev in enumerate(self.detected_devices):
                        if dev["id"] == previously_selected:
                            self.device_combo.set_active(i)
                            restored = True
                            break
                if not restored:
                    self.device_combo.set_active(0)
                self.updating_ui = False

            logger.info("Detected %d audio devices", len(self.detected_devices))

        except subprocess.TimeoutExpired:
            logger.error("aplay -l timed out")
        except FileNotFoundError:
            logger.error("aplay command not found")
        except Exception as e:
            logger.exception("Error detecting audio devices: %s", type(e).__name__)

    def on_refresh_devices_clicked(self, button):
        """Handler for refresh devices button"""
        self.refresh_audio_devices()
        # refresh_audio_devices() already selects first device and updates pattern
        self.set_status("Audio devices refreshed")

    def on_device_changed(self, combo):
        """Handler for device selection change"""
        if self.updating_ui:
            return
        # Pattern is independent - user can set it manually if needed
        # The init script auto-detects anyway

    def get_selected_device(self):
        """Returns the selected ALSA device identifier"""
        idx = self.device_combo.get_active()
        if idx >= 0 and idx < len(self.detected_devices):
            return self.detected_devices[idx]["id"]
        # Fallback to default
        return "hw:0,0"

    def select_device_in_combo(self, device_id):
        """Selects the given device in the combo box"""
        self.updating_ui = True
        for i, dev in enumerate(self.detected_devices):
            if dev["id"] == device_id:
                self.device_combo.set_active(i)
                logger.info("Auto-selected device: %s", device_id)
                break
        self.updating_ui = False

    def get_selected_rate(self):
        """Returns the selected sample rate"""
        idx = self.rate_combo.get_active()
        if idx >= 0:
            return self.SAMPLE_RATES[idx]
        return 48000

    def get_selected_buffer(self):
        """Returns the selected buffer size"""
        idx = self.buffer_combo.get_active()
        if idx >= 0:
            return self.BUFFER_SIZES[idx]
        return 256

    def get_selected_periods(self):
        """Returns the selected number of periods"""
        return int(self.periods_spin.get_value())

    def _calculate_preset_latency(self, preset):
        """Calculate latency for a preset dict - used during __init__"""
        rate = preset["rate"]
        period = preset["period"]
        nperiods = preset["nperiods"]
        buffer_latency = period / rate * 1000
        roundtrip_latency = (period * nperiods) / rate * 1000
        return round(buffer_latency, 1), round(roundtrip_latency, 1)

    def calculate_latency(self, rate=None, buffer=None, periods=None):
        """Calculates latency in milliseconds - returns (buffer_latency, roundtrip_latency)"""
        if rate is None:
            rate = self.get_selected_rate()
        if buffer is None:
            buffer = self.get_selected_buffer()
        if periods is None:
            periods = self.get_selected_periods()

        buffer_latency = buffer / rate * 1000
        roundtrip_latency = (buffer * periods) / rate * 1000
        return round(buffer_latency, 1), round(roundtrip_latency, 1)

    def update_latency_display(self):
        """Updates the latency display"""
        buffer_latency, roundtrip_latency = self.calculate_latency()

        # Color based on roundtrip latency (using theme-aware colors)
        if roundtrip_latency < 3:
            color = self.color_error  # Red - very low
            self.latency_warning.show()
        elif roundtrip_latency < 5:
            color = self.color_warning  # Orange - low
            self.latency_warning.hide()
        elif roundtrip_latency < 10:
            color = self.color_success  # Green - good
            self.latency_warning.hide()
        else:
            color = self.color_accent  # Blue - safe
            self.latency_warning.hide()

        self.latency_label.set_markup(
            f"<span size='large' foreground='{color}'><b>~{buffer_latency} ms</b></span>  /  "
            f"<span size='large' foreground='{color}'><b>~{roundtrip_latency} ms</b></span>"
        )

    def on_config_changed(self, widget):
        """Handler for configuration changes"""
        if not self.updating_ui:
            self.update_latency_display()

    def on_preset_clicked(self, button, preset_name):
        """Handler for preset button clicks"""
        preset = self.PRESETS.get(preset_name)
        if preset:
            self.updating_ui = True

            # Set rate
            if preset["rate"] in self.SAMPLE_RATES:
                self.rate_combo.set_active(self.SAMPLE_RATES.index(preset["rate"]))

            # Set buffer
            if preset["period"] in self.BUFFER_SIZES:
                self.buffer_combo.set_active(self.BUFFER_SIZES.index(preset["period"]))

            # Set periods
            self.periods_spin.set_value(preset["nperiods"])

            self.updating_ui = False
            self.update_latency_display()
            self.set_status(f"Preset '{preset['name']}' selected")

    def update_status_display(self):
        """Updates only the status labels"""
        # JACK Status
        jack_running = self.check_jack_status()
        if jack_running:
            self.jack_status_label.set_markup(
                f"JACK Server: <span foreground='{self.color_success}'><b>Running</b></span>"
            )
        else:
            self.jack_status_label.set_markup(
                f"JACK Server: <span foreground='{self.color_error}'><b>Stopped</b></span>"
            )

        # Refresh device list to see what's currently connected
        self.refresh_audio_devices()

        self.previous_hardware_found = bool(self.detected_devices)

        # Current config display - read from config file
        config = self.read_current_config()
        config_device = config.get("audio_device", "")

        # Show the configured device and its connection status
        if config_device:
            # Check if configured device is available
            device_available = any(
                dev["id"] == config_device for dev in self.detected_devices
            )
            if device_available:
                # Find device name for display
                device_name = config_device
                for dev in self.detected_devices:
                    if dev["id"] == config_device:
                        device_name = dev.get("name", config_device)
                        break
                self.hardware_status_label.set_markup(
                    f"Audio Device: <span foreground='{self.color_success}'><b>{device_name}</b></span> ({config_device})"
                )
            else:
                self.hardware_status_label.set_markup(
                    f"Audio Device: <span foreground='{self.color_error}'><b>Not connected</b></span> ({config_device})"
                )
        elif self.detected_devices:
            # No specific device configured, show first available
            connected_device = self.detected_devices[0]
            self.hardware_status_label.set_markup(
                f"Audio Device: <span foreground='{self.color_success}'><b>{connected_device['name']}</b></span> ({connected_device['id']})"
            )
        else:
            self.hardware_status_label.set_markup(
                f"Audio Device: <span foreground='{self.color_error}'><b>Not found</b></span>"
            )

        # A2J Status indicator - only check if a2j is enabled in config
        # to prevent unwanted D-Bus activation of a2jmidid
        if config.get("a2j_enable", False):
            a2j_running = self.check_a2j_status()
            if a2j_running:
                self.a2j_status_label.set_markup(
                    f"<small><span foreground='{self.color_success}'>(running)</span></small>"
                )
            else:
                self.a2j_status_label.set_markup(
                    f"<small><span foreground='{self.color_error}'>(stopped)</span></small>"
                )
        else:
            self.a2j_status_label.set_markup(
                f"<small><span foreground='{self.color_muted}'>(disabled)</span></small>"
            )
        rate = config.get("rate", 48000)
        period = config.get("period", 256)
        nperiods = config.get("nperiods", 3)
        buffer_latency, roundtrip_latency = self.calculate_latency(
            rate, period, nperiods
        )

        self.current_config_label.set_markup(
            f"Active: <b>{rate:,} Hz</b> | <b>{period}</b> frames | "
            f"<b>{nperiods}</b> periods | <b>~{roundtrip_latency} ms</b>".replace(
                ",", "."
            )
        )

    def read_current_config(self):
        """Reads the current configuration from config files"""
        config = {
            "audio_device": "hw:0,0",
            "device_pattern": "",
            "rate": 48000,
            "period": 256,
            "nperiods": 3,
            "a2j_enable": False,
        }

        # Try user config first, then system config
        for config_file in [self.USER_CONFIG_FILE, self.SYSTEM_CONFIG_FILE]:
            if os.path.exists(config_file):
                try:
                    with open(config_file, "r") as f:
                        content = f.read()
                        logger.info("Reading configuration from: %s", config_file)

                        # Parse config file
                        for line in content.splitlines():
                            try:
                                if line.startswith("AUDIO_DEVICE="):
                                    config["audio_device"] = line.split("=")[1].strip()
                                elif line.startswith("DEVICE_PATTERN="):
                                    config["device_pattern"] = line.split("=")[
                                        1
                                    ].strip()
                                elif line.startswith("JACK_RATE="):
                                    config["rate"] = int(line.split("=")[1].strip())
                                elif line.startswith("JACK_PERIOD="):
                                    config["period"] = int(line.split("=")[1].strip())
                                elif line.startswith("JACK_NPERIODS="):
                                    config["nperiods"] = int(line.split("=")[1].strip())
                                elif line.startswith("A2J_ENABLE="):
                                    value = line.split("=")[1].strip().lower()
                                    config["a2j_enable"] = value in (
                                        "true",
                                        "yes",
                                        "1",
                                        "on",
                                    )
                                elif line.startswith("JACK_SETTING="):
                                    # Legacy v1.x format
                                    setting = int(line.split("=")[1].strip())
                                    if setting in self.LEGACY_PRESETS:
                                        preset = self.LEGACY_PRESETS[setting]
                                        config["rate"] = preset["rate"]
                                        config["period"] = preset["period"]
                                        config["nperiods"] = preset["nperiods"]
                            except ValueError as e:
                                logger.warning(
                                    "Failed to parse config line '%s': %s", line, str(e)
                                )
                                continue
                        break  # Use first found config
                except FileNotFoundError:
                    logger.warning("Config file not found: %s", config_file)
                except PermissionError:
                    logger.error(
                        "Permission denied reading config file: %s", config_file
                    )
                except IOError as e:
                    logger.error(
                        "I/O error reading config file %s: %s", config_file, str(e)
                    )
                except Exception as e:
                    logger.exception(
                        "Unexpected error reading config from %s: %s",
                        config_file,
                        type(e).__name__,
                    )

        return config

    def load_current_config(self):
        """Loads current config into UI controls"""
        config = self.read_current_config()

        self.updating_ui = True

        # Select device from config if available, otherwise first device
        if self.detected_devices:
            selected = False
            config_device = config.get("audio_device", "")
            if config_device:
                for i, dev in enumerate(self.detected_devices):
                    if dev["id"] == config_device:
                        self.device_combo.set_active(i)
                        selected = True
                        break
            if not selected:
                self.device_combo.set_active(0)

        # Set rate
        if config["rate"] in self.SAMPLE_RATES:
            self.rate_combo.set_active(self.SAMPLE_RATES.index(config["rate"]))

        # Set buffer
        if config["period"] in self.BUFFER_SIZES:
            self.buffer_combo.set_active(self.BUFFER_SIZES.index(config["period"]))

        # Set periods
        self.periods_spin.set_value(config["nperiods"])

        # Set A2J checkbox
        self.a2j_check.set_active(config["a2j_enable"])

        self.updating_ui = False

    def check_a2j_status(self):
        """Checks if a2jmidid bridge is actually active"""
        try:
            result = subprocess.run(
                ["a2j_control", "--status"], capture_output=True, text=True, timeout=5
            )
            # Check for DBus errors (can happen at early boot)
            if "dbus" in result.stderr.lower() or "autolaunch" in result.stderr.lower():
                logger.warning("DBus error in a2j_control: %s", result.stderr.strip())
                return False
            # Check for "Bridging enabled" (not "bridge is running")
            return "bridging enabled" in result.stdout.lower()
        except subprocess.TimeoutExpired:
            logger.error("a2j_control --status timed out after 5 seconds")
            return False
        except FileNotFoundError:
            logger.error(
                "a2j_control command not found - a2jmidid may not be installed"
            )
            return False
        except subprocess.CalledProcessError as e:
            logger.error(
                "a2j_control failed with return code %d: %s", e.returncode, e.stderr
            )
            return False
        except Exception as e:
            logger.exception(
                "Unexpected error checking a2j status: %s", type(e).__name__
            )
            return False

    def check_jack_status(self):
        """Checks if JACK is running"""
        try:
            result = subprocess.run(
                ["jack_control", "status"], capture_output=True, text=True, timeout=5
            )
            # Check for DBus errors (can happen at early boot)
            if "dbus" in result.stderr.lower() or "autolaunch" in result.stderr.lower():
                logger.warning("DBus error in jack_control: %s", result.stderr.strip())
                return False
            return "started" in result.stdout.lower()
        except subprocess.TimeoutExpired:
            logger.error("jack_control status timed out after 5 seconds")
            return False
        except FileNotFoundError:
            logger.error("jack_control command not found - JACK may not be installed")
            return False
        except subprocess.CalledProcessError as e:
            logger.error(
                "jack_control failed with return code %d: %s", e.returncode, e.stderr
            )
            return False
        except Exception as e:
            logger.exception(
                "Unexpected error checking JACK status: %s", type(e).__name__
            )
            return False

    def check_hardware(self, pattern="", device=""):
        """Checks if audio interface is connected"""
        try:
            # Force English output by setting LC_ALL=C (fixes locale issues)
            env = os.environ.copy()
            env["LC_ALL"] = "C"
            result = subprocess.run(
                ["aplay", "-l"], capture_output=True, text=True, timeout=5, env=env
            )
            if pattern:
                return pattern in result.stdout
            # If no pattern but device is set, extract card name from device (e.g., "M4" from "hw:M4,0")
            if device:
                match = re.match(r"hw:(\w+),", device)
                if match:
                    card_name = match.group(1)
                    # Check if this specific card exists in aplay output
                    return (
                        f"card {card_name}" in result.stdout
                        or f": {card_name} [" in result.stdout
                    )
            # Fallback: check if any sound card exists
            return "card" in result.stdout.lower()
        except subprocess.TimeoutExpired:
            logger.error("aplay -l timed out after 5 seconds")
            return False
        except FileNotFoundError:
            logger.error("aplay command not found - ALSA may not be installed")
            return False
        except subprocess.CalledProcessError as e:
            logger.error("aplay failed with return code %d: %s", e.returncode, e.stderr)
            return False
        except Exception as e:
            logger.exception("Unexpected error checking hardware: %s", type(e).__name__)
            return False

    def refresh_status(self):
        """Updates all status displays"""
        self.update_status_display()
        self.set_status("Status updated")

    def set_status(self, message):
        """Sets the status bar message"""
        self.statusbar.set_markup(f"<small>{message}</small>")

    def on_apply_clicked(self, button):
        """Handler for apply button"""
        device = self.get_selected_device()
        rate = self.get_selected_rate()
        period = self.get_selected_buffer()
        nperiods = self.get_selected_periods()
        a2j_enable = self.a2j_check.get_active()
        restart = self.restart_check.get_active()

        latency = self.calculate_latency(rate, period, nperiods)

        # Disable UI during application
        self.apply_button.set_sensitive(False)
        self.spinner.show()
        self.spinner.start()
        self.set_status(f"Applying: {device}, {rate}Hz, {period} frames...")

        # Run in separate thread
        thread = threading.Thread(
            target=self.apply_setting,
            args=(device, rate, period, nperiods, a2j_enable, restart),
        )
        thread.daemon = True
        thread.start()

    def apply_setting(self, device, rate, period, nperiods, a2j_enable, restart):
        """Applies the setting (runs in separate thread)"""
        try:
            # Extract card_id from device for pattern (e.g., "M4" from "hw:M4,0")
            pattern = re.match(r"hw:([^,]+)", device)
            pattern = pattern.group(1) if pattern else ""

            # Build command with v3.0 syntax
            a2j_value = "true" if a2j_enable else "false"
            cmd = [
                "pkexec",
                self.SETTING_SCRIPT,
                f"--device={device}",
                f"--pattern={pattern}",
                f"--rate={rate}",
                f"--period={period}",
                f"--nperiods={nperiods}",
                f"--a2j={a2j_value}",
            ]
            if restart:
                cmd.append("--restart")

            logger.info(
                "Applying settings: device=%s, rate=%d, period=%d, nperiods=%d, a2j=%s, restart=%s",
                device,
                rate,
                period,
                nperiods,
                a2j_value,
                restart,
            )

            # Execute script
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            success = result.returncode == 0

            if success:
                logger.info("Settings applied successfully")
            else:
                logger.warning("Settings application failed: %s", result.stderr.strip())

            # UI update in main thread
            GLib.idle_add(
                self.on_apply_complete, success, result.stderr if not success else ""
            )

        except subprocess.TimeoutExpired:
            error_msg = "Settings application timed out after 60 seconds"
            logger.error(error_msg)
            GLib.idle_add(self.on_apply_complete, False, error_msg)
        except FileNotFoundError:
            error_msg = f"Setting script not found: {self.SETTING_SCRIPT}"
            logger.error(error_msg)
            GLib.idle_add(self.on_apply_complete, False, error_msg)
        except subprocess.CalledProcessError as e:
            error_msg = (
                f"pkexec authorization failed or script error (code {e.returncode})"
            )
            logger.error("Settings application failed: %s - %s", error_msg, e.stderr)
            GLib.idle_add(self.on_apply_complete, False, error_msg)
        except PermissionError:
            error_msg = "Permission denied - unable to execute settings script"
            logger.error(error_msg)
            GLib.idle_add(self.on_apply_complete, False, error_msg)
        except Exception as e:
            error_msg = (
                f"Unexpected error applying settings: {type(e).__name__}: {str(e)}"
            )
            logger.exception(error_msg)
            GLib.idle_add(self.on_apply_complete, False, error_msg)

    def on_apply_complete(self, success, error_msg):
        """Callback after setting application completes"""
        self.spinner.stop()
        self.spinner.hide()
        self.apply_button.set_sensitive(True)

        if success:
            latency = self.calculate_latency()
            self.set_status(f"Settings applied successfully (~{latency[1]}ms latency)")
            self.refresh_status()
        else:
            self.set_status(f"Error: {error_msg[:50]}")

            # Show error dialog
            dialog = Gtk.MessageDialog(
                transient_for=self,
                flags=0,
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text="Error applying settings",
            )
            dialog.format_secondary_text(error_msg or "Unknown error")
            dialog.run()
            dialog.destroy()

        return False


def main():
    """Main entry point"""
    # Minimal CSS - let system theme handle most styling
    # This respects KDE/GNOME/XFCE themes automatically
    css_provider = Gtk.CssProvider()
    css = b"""
    /* Minimal styling - respect system theme */
    frame {
        border-radius: 5px;
    }
    spinbutton {
        min-width: 80px;
    }
    combobox {
        min-width: 150px;
    }
    """
    css_provider.load_from_data(css)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        css_provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    app = AudioInterfaceJackGUI()
    Gtk.main()


if __name__ == "__main__":
    main()

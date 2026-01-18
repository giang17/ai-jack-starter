#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MOTU M4 JACK Settings GUI - v2.0
A GTK3 GUI for flexible JACK audio configuration
for the MOTU M4 audio interface.

Features:
- Flexible sample rate selection (22050 - 192000 Hz)
- Flexible buffer size selection (16 - 4096 frames)
- Adjustable periods (2-8)
- Live latency calculation
- Quick presets for common configurations

Copyright (C) 2025
License: GPL-3.0-or-later
"""

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
import os
import subprocess
import threading

from gi.repository import Gdk, GLib, Gtk


class MotuM4JackGUI(Gtk.Window):
    """Main window for MOTU M4 JACK Settings GUI"""

    # Paths
    SYSTEM_CONFIG_FILE = "/etc/motu-m4/jack-setting.conf"
    USER_CONFIG_FILE = os.path.expanduser("~/.config/motu-m4/jack-setting.conf")
    SETTING_SCRIPT = "/usr/local/bin/motu-m4-jack-setting-system.sh"

    # Valid values
    SAMPLE_RATES = [22050, 44100, 48000, 88200, 96000, 176400, 192000]
    BUFFER_SIZES = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
    MIN_PERIODS = 2
    MAX_PERIODS = 8

    # Presets (for quick selection)
    PRESETS = {
        "low": {"name": "Low Latency", "rate": 48000, "period": 128, "nperiods": 2},
        "medium": {
            "name": "Medium Latency",
            "rate": 48000,
            "period": 256,
            "nperiods": 2,
        },
        "ultra": {"name": "Ultra-Low", "rate": 48000, "period": 64, "nperiods": 2},
    }

    # Legacy preset mapping (for backward compatibility)
    LEGACY_PRESETS = {
        1: {"rate": 48000, "period": 128, "nperiods": 2},
        2: {"rate": 48000, "period": 256, "nperiods": 2},
        3: {"rate": 48000, "period": 64, "nperiods": 2},
    }

    # Icon path
    ICON_PATH = "/usr/share/icons/hicolor/scalable/apps/motu-m4-jack-settings.svg"

    def __init__(self):
        super().__init__(title="MOTU M4 JACK Settings")
        self.set_border_width(15)
        self.set_default_size(420, 520)
        self.set_resizable(False)

        # Timer ID for automatic status refresh
        self.status_timer_id = None

        # Flag to prevent recursive updates
        self.updating_ui = False

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
        title_label.set_markup("<b><big>MOTU M4 JACK Settings</big></b>")
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
        latency_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        latency_box.set_halign(Gtk.Align.CENTER)
        config_box.pack_start(latency_box, False, False, 0)

        latency_title = Gtk.Label()
        latency_title.set_markup("<b>Calculated Latency:</b>")
        latency_box.pack_start(latency_title, False, False, 0)

        self.latency_label = Gtk.Label()
        self.latency_label.set_markup(
            "<span size='large' foreground='#2e7d32'>~5.3 ms</span>"
        )
        latency_box.pack_start(self.latency_label, False, False, 0)

        # Latency warning
        self.latency_warning = Gtk.Label()
        self.latency_warning.set_markup(
            "<span foreground='#ff6f00' size='small'>⚠ Very low latency may cause audio glitches</span>"
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

        # Preset buttons
        self.preset_buttons = {}

        low_btn = Gtk.Button(label="Low (~5ms)")
        low_btn.set_tooltip_text("48kHz, 128 frames, 2 periods")
        low_btn.connect("clicked", self.on_preset_clicked, "low")
        presets_box.pack_start(low_btn, True, True, 0)
        self.preset_buttons["low"] = low_btn

        medium_btn = Gtk.Button(label="Medium (~11ms)")
        medium_btn.set_tooltip_text("48kHz, 256 frames, 2 periods")
        medium_btn.connect("clicked", self.on_preset_clicked, "medium")
        presets_box.pack_start(medium_btn, True, True, 0)
        self.preset_buttons["medium"] = medium_btn

        ultra_btn = Gtk.Button(label="Ultra (~3ms)")
        ultra_btn.set_tooltip_text("48kHz, 64 frames, 2 periods")
        ultra_btn.connect("clicked", self.on_preset_clicked, "ultra")
        presets_box.pack_start(ultra_btn, True, True, 0)
        self.preset_buttons["ultra"] = ultra_btn

        # Checkbox for automatic restart
        self.restart_check = Gtk.CheckButton(
            label="Automatically restart JACK after changes"
        )
        self.restart_check.set_active(True)
        main_box.pack_start(self.restart_check, False, False, 0)

        # Button box
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        button_box.set_halign(Gtk.Align.END)
        main_box.pack_start(button_box, False, False, 5)

        # Refresh button
        refresh_button = Gtk.Button(label="Refresh")
        refresh_button.connect("clicked", self.on_refresh_clicked)
        button_box.pack_start(refresh_button, False, False, 0)

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

    def calculate_latency(self, rate=None, buffer=None, periods=None):
        """Calculates latency in milliseconds"""
        if rate is None:
            rate = self.get_selected_rate()
        if buffer is None:
            buffer = self.get_selected_buffer()
        if periods is None:
            periods = self.get_selected_periods()

        latency = (buffer * periods) / rate * 1000
        return round(latency, 1)

    def update_latency_display(self):
        """Updates the latency display"""
        latency = self.calculate_latency()

        # Color based on latency
        if latency < 3:
            color = "#d32f2f"  # Red - very low
            self.latency_warning.show()
        elif latency < 5:
            color = "#ff6f00"  # Orange - low
            self.latency_warning.hide()
        elif latency < 10:
            color = "#2e7d32"  # Green - good
            self.latency_warning.hide()
        else:
            color = "#1565c0"  # Blue - safe
            self.latency_warning.hide()

        self.latency_label.set_markup(
            f"<span size='large' foreground='{color}'><b>~{latency} ms</b></span>"
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
                "JACK Server: <span foreground='#2e7d32'><b>● Running</b></span>"
            )
        else:
            self.jack_status_label.set_markup(
                "JACK Server: <span foreground='#d32f2f'><b>○ Stopped</b></span>"
            )

        # Hardware Status
        hardware_found = self.check_hardware()
        if hardware_found:
            self.hardware_status_label.set_markup(
                "MOTU M4: <span foreground='#2e7d32'><b>● Connected</b></span>"
            )
        else:
            self.hardware_status_label.set_markup(
                "MOTU M4: <span foreground='#d32f2f'><b>○ Not found</b></span>"
            )

        # Current config display
        config = self.read_current_config()
        rate = config.get("rate", 48000)
        period = config.get("period", 256)
        nperiods = config.get("nperiods", 3)
        latency = self.calculate_latency(rate, period, nperiods)

        self.current_config_label.set_markup(
            f"Active: <b>{rate:,} Hz</b> | <b>{period}</b> frames | "
            f"<b>{nperiods}</b> periods | <b>~{latency} ms</b>".replace(",", ".")
        )

    def read_current_config(self):
        """Reads the current configuration from config files"""
        config = {"rate": 48000, "period": 256, "nperiods": 3}

        # Try user config first, then system config
        for config_file in [self.USER_CONFIG_FILE, self.SYSTEM_CONFIG_FILE]:
            if os.path.exists(config_file):
                try:
                    with open(config_file, "r") as f:
                        content = f.read()

                        # Check for v2.0 format
                        for line in content.splitlines():
                            if line.startswith("JACK_RATE="):
                                config["rate"] = int(line.split("=")[1].strip())
                            elif line.startswith("JACK_PERIOD="):
                                config["period"] = int(line.split("=")[1].strip())
                            elif line.startswith("JACK_NPERIODS="):
                                config["nperiods"] = int(line.split("=")[1].strip())
                            elif line.startswith("JACK_SETTING="):
                                # Legacy v1.x format
                                setting = int(line.split("=")[1].strip())
                                if setting in self.LEGACY_PRESETS:
                                    preset = self.LEGACY_PRESETS[setting]
                                    config["rate"] = preset["rate"]
                                    config["period"] = preset["period"]
                                    config["nperiods"] = preset["nperiods"]
                        break  # Use first found config
                except Exception:
                    pass

        return config

    def load_current_config(self):
        """Loads current config into UI controls"""
        config = self.read_current_config()

        self.updating_ui = True

        # Set rate
        if config["rate"] in self.SAMPLE_RATES:
            self.rate_combo.set_active(self.SAMPLE_RATES.index(config["rate"]))

        # Set buffer
        if config["period"] in self.BUFFER_SIZES:
            self.buffer_combo.set_active(self.BUFFER_SIZES.index(config["period"]))

        # Set periods
        self.periods_spin.set_value(config["nperiods"])

        self.updating_ui = False

    def check_jack_status(self):
        """Checks if JACK is running"""
        try:
            result = subprocess.run(
                ["jack_control", "status"], capture_output=True, text=True, timeout=5
            )
            return "started" in result.stdout.lower()
        except Exception:
            return False

    def check_hardware(self):
        """Checks if MOTU M4 is connected"""
        try:
            result = subprocess.run(
                ["aplay", "-l"], capture_output=True, text=True, timeout=5
            )
            return "M4" in result.stdout
        except Exception:
            return False

    def refresh_status(self):
        """Updates all status displays"""
        self.update_status_display()
        self.set_status("Status updated")

    def set_status(self, message):
        """Sets the status bar message"""
        self.statusbar.set_markup(f"<small>{message}</small>")

    def on_refresh_clicked(self, button):
        """Handler for refresh button"""
        self.refresh_status()
        self.load_current_config()
        self.update_latency_display()

    def on_apply_clicked(self, button):
        """Handler for apply button"""
        rate = self.get_selected_rate()
        period = self.get_selected_buffer()
        nperiods = self.get_selected_periods()
        restart = self.restart_check.get_active()

        latency = self.calculate_latency(rate, period, nperiods)

        # Disable UI during application
        self.apply_button.set_sensitive(False)
        self.spinner.show()
        self.spinner.start()
        self.set_status(f"Applying: {rate}Hz, {period} frames, {nperiods} periods...")

        # Run in separate thread
        thread = threading.Thread(
            target=self.apply_setting, args=(rate, period, nperiods, restart)
        )
        thread.daemon = True
        thread.start()

    def apply_setting(self, rate, period, nperiods, restart):
        """Applies the setting (runs in separate thread)"""
        try:
            # Build command with new v2.0 syntax
            cmd = [
                "pkexec",
                self.SETTING_SCRIPT,
                f"--rate={rate}",
                f"--period={period}",
                f"--nperiods={nperiods}",
            ]
            if restart:
                cmd.append("--restart")

            # Execute script
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            success = result.returncode == 0

            # UI update in main thread
            GLib.idle_add(
                self.on_apply_complete, success, result.stderr if not success else ""
            )

        except subprocess.TimeoutExpired:
            GLib.idle_add(self.on_apply_complete, False, "Timeout")
        except Exception as e:
            GLib.idle_add(self.on_apply_complete, False, str(e))

    def on_apply_complete(self, success, error_msg):
        """Callback after setting application completes"""
        self.spinner.stop()
        self.spinner.hide()
        self.apply_button.set_sensitive(True)

        if success:
            latency = self.calculate_latency()
            self.set_status(f"✓ Settings applied successfully (~{latency}ms latency)")
            self.refresh_status()
        else:
            self.set_status(f"✗ Error: {error_msg[:50]}")

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
    # CSS for better appearance
    css_provider = Gtk.CssProvider()
    css = b"""
    window {
        background-color: #f5f5f5;
    }
    frame {
        background-color: white;
        border-radius: 5px;
    }
    .suggested-action {
        background-color: #3584e4;
        color: white;
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

    app = MotuM4JackGUI()
    Gtk.main()


if __name__ == "__main__":
    main()

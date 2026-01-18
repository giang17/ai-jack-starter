#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MOTU M4 JACK Settings GUI
A minimalistic GTK3 GUI for controlling JACK settings
for the MOTU M4 audio interface.

Copyright (C) 2026
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
    """Hauptfenster der MOTU M4 JACK Settings GUI"""

    # Pfade
    SYSTEM_CONFIG_FILE = "/etc/motu-m4/jack-setting.conf"
    SETTING_SCRIPT = "/usr/local/bin/motu-m4-jack-setting-system.sh"

    # Setting definitions
    # Latency calculation: (period / rate) * 1000 = ms
    SETTINGS = {
        1: {
            "name": "Low Latency",
            "rate": "48,000 Hz",
            "periods": "3",
            "period": "256 frames",
            "latency": "~5.3 ms",  # 256/48000*1000 = 5.33ms
        },
        2: {
            "name": "Medium Latency",
            "rate": "48,000 Hz",
            "periods": "2",
            "period": "512 frames",
            "latency": "~10.7 ms",  # 512/48000*1000 = 10.67ms
        },
        3: {
            "name": "Ultra-Low Latency",
            "rate": "96,000 Hz",
            "periods": "3",
            "period": "128 frames",
            "latency": "~1.3 ms",  # 128/96000*1000 = 1.33ms
        },
    }

    # Icon path
    ICON_PATH = "/usr/share/icons/hicolor/scalable/apps/motu-m4-jack-settings.svg"

    def __init__(self):
        super().__init__(title="MOTU M4 JACK Settings")
        self.set_border_width(15)
        self.set_default_size(400, 450)
        self.set_resizable(False)

        # Set icon
        if os.path.exists(self.ICON_PATH):
            self.set_icon_from_file(self.ICON_PATH)
        else:
            # Fallback: Default icon
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

        self.current_setting_label = Gtk.Label()
        self.current_setting_label.set_halign(Gtk.Align.START)
        status_box.pack_start(self.current_setting_label, False, False, 0)

        self.hardware_status_label = Gtk.Label()
        self.hardware_status_label.set_halign(Gtk.Align.START)
        status_box.pack_start(self.hardware_status_label, False, False, 0)

        # Settings frame
        settings_frame = Gtk.Frame(label=" Select Setting ")
        settings_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        settings_box.set_border_width(10)
        settings_frame.add(settings_box)
        main_box.pack_start(settings_frame, True, True, 0)

        # Radio buttons for settings
        self.setting_buttons = {}
        first_button = None

        for setting_num in [1, 2, 3]:
            setting = self.SETTINGS[setting_num]

            if first_button is None:
                radio = Gtk.RadioButton.new_with_label_from_widget(None, "")
                first_button = radio
            else:
                radio = Gtk.RadioButton.new_with_label_from_widget(first_button, "")

            # Custom label with details
            label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)

            name_label = Gtk.Label()
            name_label.set_markup(f"<b>Setting {setting_num}: {setting['name']}</b>")
            name_label.set_halign(Gtk.Align.START)
            label_box.pack_start(name_label, False, False, 0)

            details_label = Gtk.Label()
            details_label.set_markup(
                f"<small>{setting['rate']} | {setting['periods']} Periods | "
                f"{setting['period']} | Latency: {setting['latency']}</small>"
            )
            details_label.set_halign(Gtk.Align.START)
            details_label.modify_fg(Gtk.StateFlags.NORMAL, None)
            label_box.pack_start(details_label, False, False, 0)

            radio.remove(radio.get_child())
            radio.add(label_box)

            self.setting_buttons[setting_num] = radio
            settings_box.pack_start(radio, False, False, 4)

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

        # Load initial status
        self.refresh_status()

        # Show window
        self.connect("destroy", Gtk.main_quit)
        self.show_all()
        self.spinner.hide()

    def get_current_setting(self):
        """Reads the current setting from the configuration file"""
        try:
            if os.path.exists(self.SYSTEM_CONFIG_FILE):
                with open(self.SYSTEM_CONFIG_FILE, "r") as f:
                    for line in f:
                        if line.startswith("JACK_SETTING="):
                            return int(line.strip().split("=")[1])
            return 1  # Default
        except Exception:
            return 1

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
        # JACK Status
        jack_running = self.check_jack_status()
        if jack_running:
            self.jack_status_label.set_markup(
                "JACK Server: <span foreground='green'><b>● Running</b></span>"
            )
        else:
            self.jack_status_label.set_markup(
                "JACK Server: <span foreground='red'><b>○ Stopped</b></span>"
            )

        # Hardware Status
        hardware_found = self.check_hardware()
        if hardware_found:
            self.hardware_status_label.set_markup(
                "MOTU M4: <span foreground='green'><b>● Connected</b></span>"
            )
        else:
            self.hardware_status_label.set_markup(
                "MOTU M4: <span foreground='red'><b>○ Not found</b></span>"
            )

        # Current Setting
        current = self.get_current_setting()
        setting_info = self.SETTINGS.get(current, self.SETTINGS[1])
        self.current_setting_label.set_markup(
            f"Active Setting: <b>{current} - {setting_info['name']}</b>"
        )

        # Set radio button accordingly
        if current in self.setting_buttons:
            self.setting_buttons[current].set_active(True)

        self.set_status("Status updated")

    def get_selected_setting(self):
        """Returns the selected setting"""
        for num, button in self.setting_buttons.items():
            if button.get_active():
                return num
        return 1

    def set_status(self, message):
        """Sets the status bar message"""
        self.statusbar.set_markup(f"<small>{message}</small>")

    def on_refresh_clicked(self, button):
        """Handler for refresh button"""
        self.refresh_status()

    def on_apply_clicked(self, button):
        """Handler for apply button"""
        selected = self.get_selected_setting()
        restart = self.restart_check.get_active()

        # Disable UI during application
        self.apply_button.set_sensitive(False)
        self.spinner.show()
        self.spinner.start()
        self.set_status(f"Applying Setting {selected}...")

        # Run in separate thread
        thread = threading.Thread(target=self.apply_setting, args=(selected, restart))
        thread.daemon = True
        thread.start()

    def apply_setting(self, setting, restart):
        """Applies the setting (runs in separate thread)"""
        try:
            # Build command
            cmd = ["pkexec", self.SETTING_SCRIPT, str(setting)]
            if restart:
                cmd.append("--restart")

            # Execute script
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

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
            self.set_status("✓ Settings applied successfully")
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

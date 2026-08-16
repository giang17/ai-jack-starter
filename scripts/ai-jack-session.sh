#!/bin/bash

# =============================================================================
# Audio Interface JACK Session Detection Library - v1.0
# =============================================================================
# Display-server agnostic detection of the active graphical session.
#
# Replaces the legacy `who | grep "(:"` approach, which only ever matched X11:
# under Wayland the utmp database carries no "(:0)" display entry, so the old
# check reported "no user logged in" even while the user was sitting in front
# of a running desktop. logind knows about both, so we ask logind.
#
# Usage:
#   source /usr/local/bin/ai-jack-session.sh
#   user=$(get_active_session_user)
#   display=$(get_active_session_display "$user")
#   is_user_logged_in "$user" && echo "logged in"
#
# All functions are safe to call as root (UDEV context) and as the user.
#
# Copyright (C) 2025
# License: GPL-3.0-or-later
# =============================================================================

# =============================================================================
# Internal Helpers
# =============================================================================

# List all session IDs known to logind
_ai_session_ids() {
    loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'
}

# Read a single property of a session
# Usage: _ai_session_prop <session-id> <property>
_ai_session_prop() {
    loginctl show-session "$1" -p "$2" --value 2>/dev/null
}

# Check whether logind is usable at all
_ai_has_logind() {
    command -v loginctl >/dev/null 2>&1 && loginctl list-sessions --no-legend >/dev/null 2>&1
}

# =============================================================================
# Session User Detection
# =============================================================================

# Return the ID of the active local graphical session (empty if none).
# Greeter sessions (SDDM/GDM) are skipped via Class=user, otherwise JACK would
# be started for the display manager's own account.
get_active_session_id() {
    local sid class active type remote
    local fallback_sid=""

    for sid in $(_ai_session_ids); do
        [ -n "$sid" ] || continue

        class=$(_ai_session_prop "$sid" Class)
        [ "$class" = "user" ] || continue

        remote=$(_ai_session_prop "$sid" Remote)
        [ "$remote" = "yes" ] && continue

        active=$(_ai_session_prop "$sid" Active)
        [ "$active" = "yes" ] || continue

        type=$(_ai_session_prop "$sid" Type)
        case "$type" in
            wayland|x11|mir)
                echo "$sid"
                return 0
                ;;
            *)
                # Remember non-graphical session as last resort
                [ -z "$fallback_sid" ] && fallback_sid="$sid"
                ;;
        esac
    done

    if [ -n "$fallback_sid" ]; then
        echo "$fallback_sid"
        return 0
    fi

    return 1
}

# Return the username owning the active local graphical session.
# Falls back to the legacy who-based lookup when logind is unavailable.
get_active_session_user() {
    local sid user

    if _ai_has_logind; then
        sid=$(get_active_session_id) && {
            user=$(_ai_session_prop "$sid" Name)
            if [ -n "$user" ]; then
                echo "$user"
                return 0
            fi
        }
    fi

    # Legacy fallback: X11 display entry, then any local login
    user=$(who 2>/dev/null | grep "(:" | head -n1 | awk '{print $1}')
    [ -z "$user" ] && user=$(who 2>/dev/null | head -n1 | awk '{print $1}')

    [ -n "$user" ] && echo "$user"
    [ -n "$user" ]
}

# Return the session type: wayland, x11, tty, ... (empty if undetermined)
get_active_session_type() {
    local sid
    sid=$(get_active_session_id) || return 1
    _ai_session_prop "$sid" Type
}

# Check whether the given user (default: active session user) is logged in.
# Usage: is_user_logged_in [username]
is_user_logged_in() {
    local want="$1"
    local sid user

    if [ -z "$want" ]; then
        [ -n "$(get_active_session_user)" ]
        return $?
    fi

    if _ai_has_logind; then
        for sid in $(_ai_session_ids); do
            [ "$(_ai_session_prop "$sid" Class)" = "user" ] || continue
            user=$(_ai_session_prop "$sid" Name)
            if [ "$user" = "$want" ]; then
                return 0
            fi
        done
        return 1
    fi

    who 2>/dev/null | grep -q "^$want "
}

# =============================================================================
# Display Detection
# =============================================================================

# Candidate processes whose environment usually carries a usable DISPLAY.
# Ordered from most to least desktop-specific.
_AI_DISPLAY_PROC_CANDIDATES="plasmashell gnome-shell xfce4-session mate-session cinnamon-session lxqt-session kwin_x11 kwin_wayland Xwayland xfwm4"

# Read DISPLAY from the environment of a running process of the user.
# Works for X11 as well as Wayland (where it yields the Xwayland display).
_ai_display_from_proc() {
    local user="$1"
    local proc pid value

    for proc in $_AI_DISPLAY_PROC_CANDIDATES; do
        for pid in $(pgrep -u "$user" -x "$proc" 2>/dev/null); do
            # /proc/<pid>/environ is unreadable for some hardened processes
            value=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
                    | grep -m1 '^DISPLAY=' | cut -d= -f2-)
            if [ -n "$value" ]; then
                echo "$value"
                return 0
            fi
        done
    done

    return 1
}

# Return the X display for the given user (default: active session user).
# Under Wayland this resolves to the Xwayland display, which is what GUI
# helpers need; JACK itself only requires DBUS_SESSION_BUS_ADDRESS.
# Usage: get_active_session_display [username]
get_active_session_display() {
    local user="${1:-}"
    local sid display

    [ -z "$user" ] && user=$(get_active_session_user)

    # 1. logind knows the display for X11 sessions
    if _ai_has_logind; then
        sid=$(get_active_session_id) && {
            display=$(_ai_session_prop "$sid" Display)
            if [ -n "$display" ]; then
                echo "$display"
                return 0
            fi
        }
    fi

    # 2. Environment of a running desktop process (covers Xwayland)
    if [ -n "$user" ]; then
        display=$(_ai_display_from_proc "$user") && {
            echo "$display"
            return 0
        }
    fi

    # 3. Any X11 socket present on the system
    if [ -d /tmp/.X11-unix ]; then
        display=$(find /tmp/.X11-unix/ -maxdepth 1 -name 'X[0-9]*' -printf '%f\n' 2>/dev/null \
                  | head -n1 | sed 's/^X/:/')
        if [ -n "$display" ]; then
            echo "$display"
            return 0
        fi
    fi

    # 4. Give up and assume the conventional default
    echo ":0"
    return 1
}

# =============================================================================
# Convenience
# =============================================================================

# Return the numeric UID of the active session user (empty on failure)
get_active_session_uid() {
    local user="${1:-}"
    [ -z "$user" ] && user=$(get_active_session_user)
    [ -n "$user" ] || return 1
    id -u "$user" 2>/dev/null
}

# Return the D-Bus session bus socket path for the active session user
get_active_session_dbus_socket() {
    local uid
    uid=$(get_active_session_uid "$1") || return 1
    [ -n "$uid" ] || return 1
    echo "/run/user/$uid/bus"
}

#!/bin/bash

# =============================================================================
# MOTU M4 JACK Display Detection Helper
# =============================================================================
# Erkennt automatisch das aktive X11 DISPLAY für JACK-Operationen

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion zur Erkennung des aktiven DISPLAY
detect_display() {
    local user="$1"
    local display=""

    # Methode 1: Aus who-Befehl extrahieren
    local who_display
    who_display=$(who | grep "($user)" | grep "(:" | head -n1 | sed 's/.*(\(:[0-9]*\)).*/\1/' | grep -o ':[0-9]*')
    if [ -n "$who_display" ]; then
        display="$who_display"
        echo "$display"
        return 0
    fi

    # Methode 2: Aus who-Befehl ohne Username-Filter
    local who_display_alt
    who_display_alt=$(who | grep "(:" | head -n1 | sed 's/.*(\(:[0-9]*\)).*/\1/' | grep -o ':[0-9]*')
    if [ -n "$who_display_alt" ]; then
        display="$who_display_alt"
        echo "$display"
        return 0
    fi

    # Methode 3: Prozess-basierte Erkennung
    if [ -n "$user" ]; then
        local proc_display
        proc_display=$(ps -u "$user" -o args | grep -E 'Xorg|X11' | grep -o -- '-display [^ ]*' | head -n1 | awk '{print $2}')
        if [ -n "$proc_display" ]; then
            display="$proc_display"
            echo "$display"
            return 0
        fi

        # Alternative Prozess-Erkennung
        local proc_display_alt
        proc_display_alt=$(ps -u "$user" -o args | grep -E '/usr/lib/xorg/Xorg' | grep -o -- ':[0-9]*' | head -n1)
        if [ -n "$proc_display_alt" ]; then
            display="$proc_display_alt"
            echo "$display"
            return 0
        fi
    fi

    # Methode 4: /tmp/.X11-unix Verzeichnis prüfen
    if [ -d "/tmp/.X11-unix" ]; then
        local x11_socket
        x11_socket=$(find /tmp/.X11-unix/ -maxdepth 1 -name 'X[0-9]*' -printf '%f\n' | head -n1 | sed 's/X//')
        if [ -n "$x11_socket" ]; then
            display=":$x11_socket"
            echo "$display"
            return 0
        fi
    fi

    # Methode 5: DISPLAY Umgebungsvariable des Users
    if [ -n "$user" ]; then
        local user_display
        user_display=$(su - "$user" -c 'echo $DISPLAY' 2>/dev/null | grep -o ':[0-9]*')
        if [ -n "$user_display" ]; then
            display="$user_display"
            echo "$display"
            return 0
        fi
    fi

    # Fallback: Standard-Display
    echo ":0"
    return 1
}

# Funktion für ausführliche Display-Analyse
analyze_display() {
    local user="$1"

    echo -e "${BLUE}=== Display-Analyse für User: ${user:-'current'} ===${NC}"
    echo ""

    echo -e "${BLUE}1. who-Befehl Ausgabe:${NC}"
    who | while read -r line; do
        echo "   $line"
    done
    echo ""

    echo -e "${BLUE}2. X11-Sockets in /tmp/.X11-unix:${NC}"
    if [ -d "/tmp/.X11-unix" ]; then
        find /tmp/.X11-unix/ -maxdepth 1 -ls | while read -r line; do
            echo "   $line"
        done
    else
        echo "   Verzeichnis nicht vorhanden"
    fi
    echo ""

    if [ -n "$user" ]; then
        echo -e "${BLUE}3. X11-Prozesse für User $user:${NC}"
        ps -u "$user" -o pid,args | grep -E 'Xorg|X11|xinit' | while read -r line; do
            echo "   $line"
        done
        echo ""

        echo -e "${BLUE}4. DISPLAY Umgebungsvariable von $user:${NC}"
        local user_display
        user_display=$(su - "$user" -c 'echo $DISPLAY' 2>/dev/null)
        echo "   $user_display"
        echo ""
    fi

    echo -e "${BLUE}5. Erkanntes DISPLAY:${NC}"
    local detected
    detected=$(detect_display "$user")
    echo -e "${GREEN}   $detected${NC}"
    echo ""

    # Test ob DISPLAY funktioniert
    if [ -n "$user" ] && [ -n "$detected" ]; then
        echo -e "${BLUE}6. DISPLAY-Test:${NC}"
        if su - "$user" -c "DISPLAY=$detected xdpyinfo >/dev/null 2>&1"; then
            echo -e "${GREEN}   ✅ DISPLAY $detected funktioniert${NC}"
        else
            echo -e "${RED}   ❌ DISPLAY $detected funktioniert nicht${NC}"
        fi
    fi
}

# Hauptlogik falls als eigenständiges Script ausgeführt
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "$1" in
        "analyze"|"debug")
            analyze_display "$2"
            ;;
        "detect")
            detect_display "$2"
            ;;
        "help"|"-h"|"--help")
            echo -e "${BLUE}MOTU M4 JACK Display Detection Helper${NC}"
            echo ""
            echo "Verwendung:"
            echo "  $0 detect [username]    - Erkenne DISPLAY für User"
            echo "  $0 analyze [username]   - Ausführliche Display-Analyse"
            echo "  $0 help                 - Diese Hilfe anzeigen"
            echo ""
            echo "Beispiele:"
            echo "  $0 detect               # Erkenne DISPLAY für aktuellen User"
            echo "  $0 detect username      # Erkenne DISPLAY für User 'username'"
            echo "  $0 analyze username     # Vollständige Analyse für User 'username'"
            echo ""
            echo "Als Include in anderen Scripts:"
            echo "  source detect-display.sh"
            echo "  DISPLAY=\$(detect_display \"username\")"
            ;;
        "")
            # Ohne Parameter: Erkenne für aktuellen aktiven User
            active_user=$(who | grep "(:" | head -n1 | awk '{print $1}')
            if [ -n "$active_user" ]; then
                detect_display "$active_user"
            else
                echo ":0"  # Fallback
            fi
            ;;
        *)
            echo -e "${RED}Fehler:${NC} Unbekannte Option '$1'"
            echo "Verwende '$0 help' für weitere Informationen."
            exit 1
            ;;
    esac
fi

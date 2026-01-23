#!/bin/bash

# =============================================================================
# MOTU M4 JACK Configuration Debug Script
# =============================================================================
# Analysiert die Konfigurationspriorität und zeigt alle Quellen an

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MOTU M4 JACK Konfiguration Debug ===${NC}"
echo ""

# 1. Umgebungsvariable prüfen
echo -e "${BLUE}1. Umgebungsvariable JACK_SETTING:${NC}"
if [ -n "${JACK_SETTING:-}" ]; then
    echo -e "${GREEN}   Gesetzt: JACK_SETTING=$JACK_SETTING${NC}"
    echo -e "${YELLOW}   Priorität: HÖCHSTE (überschreibt alle anderen)${NC}"
else
    echo -e "${YELLOW}   Nicht gesetzt${NC}"
fi
echo ""

# 2. User-Konfigurationsdatei prüfen
echo -e "${BLUE}2. User-Konfigurationsdatei:${NC}"
USER_CONFIG_FILE="$HOME/.config/motu-m4/jack-setting.conf"
if [ -f "$USER_CONFIG_FILE" ]; then
    echo -e "${GREEN}   Vorhanden: $USER_CONFIG_FILE${NC}"
    echo -e "${GREEN}   Inhalt:${NC}"
    while read -r line; do
        echo "      $line"
    done < "$USER_CONFIG_FILE"
    USER_SETTING=$(grep "^JACK_SETTING=" "$USER_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$USER_SETTING" ]; then
        echo -e "${GREEN}   Wert: JACK_SETTING=$USER_SETTING${NC}"
    else
        echo -e "${RED}   Kein JACK_SETTING gefunden${NC}"
    fi
else
    echo -e "${YELLOW}   Nicht vorhanden: $USER_CONFIG_FILE${NC}"
fi
echo ""

# 3. System-Konfigurationsdatei prüfen
echo -e "${BLUE}3. System-Konfigurationsdatei:${NC}"
SYSTEM_CONFIG_FILE="/etc/motu-m4/jack-setting.conf"
if [ -f "$SYSTEM_CONFIG_FILE" ]; then
    echo -e "${GREEN}   Vorhanden: $SYSTEM_CONFIG_FILE${NC}"
    echo -e "${GREEN}   Inhalt:${NC}"
    while read -r line; do
        echo "      $line"
    done < "$SYSTEM_CONFIG_FILE"
    SYSTEM_SETTING=$(grep "^JACK_SETTING=" "$SYSTEM_CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$SYSTEM_SETTING" ]; then
        echo -e "${GREEN}   Wert: JACK_SETTING=$SYSTEM_SETTING${NC}"
    else
        echo -e "${RED}   Kein JACK_SETTING gefunden${NC}"
    fi
else
    echo -e "${YELLOW}   Nicht vorhanden: $SYSTEM_CONFIG_FILE${NC}"
fi
echo ""

# 4. Prioritätsauflösung simulieren
echo -e "${BLUE}4. Prioritätsauflösung (wie im motu-m4-jack-init.sh):${NC}"

# Funktion zum Lesen der Konfigurationsdatei (kopiert aus init script)
read_config_file() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        local setting
        setting=$(grep "^JACK_SETTING=" "$config_file" | cut -d'=' -f2 | tr -d ' ')
        if [ -n "$setting" ]; then
            echo "$setting"
            return 0
        fi
    fi
    return 1
}

# Setting-Auswahl mit Fallback-Mechanismus (kopiert aus init script)
RESOLVED_JACK_SETTING=${JACK_SETTING:-}
RESOLUTION_SOURCE="Standard (Fallback)"

if [ -n "$RESOLVED_JACK_SETTING" ]; then
    RESOLUTION_SOURCE="Umgebungsvariable"
    echo -e "${GREEN}   Verwendet Umgebungsvariable: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
else
    # Versuche User-Config-Datei zu lesen
    RESOLVED_JACK_SETTING=$(read_config_file "$USER_CONFIG_FILE")
    if [ -n "$RESOLVED_JACK_SETTING" ]; then
        RESOLUTION_SOURCE="User-Konfigurationsdatei"
        echo -e "${GREEN}   Verwendet User-Config: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
    else
        # Versuche System-Config-Datei zu lesen
        RESOLVED_JACK_SETTING=$(read_config_file "$SYSTEM_CONFIG_FILE")
        if [ -n "$RESOLVED_JACK_SETTING" ]; then
            RESOLUTION_SOURCE="System-Konfigurationsdatei"
            echo -e "${GREEN}   Verwendet System-Config: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
        else
            # Fallback auf Standard-Setting
            RESOLVED_JACK_SETTING=1
            echo -e "${YELLOW}   Verwendet Standard-Setting: JACK_SETTING=$RESOLVED_JACK_SETTING${NC}"
        fi
    fi
fi

echo ""

# 5. Endgültiges Setting anzeigen
echo -e "${BLUE}5. Endgültiges Setting:${NC}"
echo -e "${GREEN}   JACK_SETTING = $RESOLVED_JACK_SETTING${NC}"
echo -e "${GREEN}   Quelle: $RESOLUTION_SOURCE${NC}"

if [ "$RESOLVED_JACK_SETTING" = "2" ]; then
    echo -e "${GREEN}   Beschreibung: Höhere Latenz (44.1kHz, 2x512)${NC}"
elif [ "$RESOLVED_JACK_SETTING" = "3" ]; then
    echo -e "${GREEN}   Beschreibung: Ultra-niedrige Latenz (96kHz, 3x128)${NC}"
else
    echo -e "${GREEN}   Beschreibung: Niedrige Latenz (48kHz, 2x256)${NC}"
fi
echo ""

# 6. Aktuelle JACK-Parameter anzeigen (falls JACK läuft)
echo -e "${BLUE}6. Aktuelle JACK-Parameter:${NC}"
if command -v jack_control >/dev/null 2>&1; then
    if jack_control status 2>/dev/null | grep -q started; then
        echo -e "${GREEN}   JACK läuft. Aktuelle Parameter:${NC}"

        # Device
        DEVICE=$(jack_control dp 2>/dev/null | grep "device" | awk '{print $NF}')
        echo "      Device: $DEVICE"

        # Sample Rate
        RATE=$(jack_control dp 2>/dev/null | grep "rate" | awk '{print $NF}')
        echo "      Sample Rate: $RATE Hz"

        # Period Size
        PERIOD=$(jack_control dp 2>/dev/null | grep "period" | awk '{print $NF}')
        echo "      Period Size: $PERIOD frames"

        # Number of Periods
        NPERIODS=$(jack_control dp 2>/dev/null | grep "nperiods" | awk '{print $NF}')
        echo "      Number of Periods: $NPERIODS"

    else
        echo -e "${YELLOW}   JACK läuft nicht${NC}"
    fi
else
    echo -e "${RED}   jack_control nicht verfügbar${NC}"
fi
echo ""

# 7. Empfehlungen
echo -e "${BLUE}7. Empfehlungen:${NC}"
if [ -n "${JACK_SETTING:-}" ]; then
    echo -e "${YELLOW}   Problem: Umgebungsvariable JACK_SETTING ist gesetzt!${NC}"
    echo -e "${YELLOW}   Lösung: 'unset JACK_SETTING' ausführen${NC}"
    echo ""
fi

echo -e "${GREEN}   Zum Testen:${NC}"
echo "   1. unset JACK_SETTING"
echo "   2. bash motu-m4-jack-setting.sh current"
echo "   3. bash motu-m4-jack-setting.sh 2"
echo "   4. bash motu-m4-jack-setting.sh current"
echo ""
echo -e "${GREEN}   Verfügbare Settings:${NC}"
echo "   Setting 1: Niedrige Latenz (48kHz, 2x256)"
echo "   Setting 2: Höhere Latenz (44.1kHz, 2x512)"
echo "   Setting 3: Ultra-niedrige Latenz (96kHz, 3x128)"
echo ""

echo -e "${BLUE}=== Debug-Analyse abgeschlossen ===${NC}"

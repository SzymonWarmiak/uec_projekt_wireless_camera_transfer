#!/bin/bash
#
# Trwale programuje pamiec QSPI Flash plytki Basys 3 wybranym bitstreamem,
# tak aby FPGA ladowala wsad samodzielnie po wlaczeniu zasilania.
#
# Uzycie:
#   ./tools/program_qspi_basys.sh <katalog_modulu> [NAZWA_LUB_ID_PLYTKI]
#
# Przyklady:
#   ./tools/program_qspi_basys.sh basys_cam basys15
#   ./tools/program_qspi_basys.sh basys_station basys16
#
# Skrypt:
#   1. Znajduje pierwszy .bit w <katalog_modulu>/results (lub generuje go w razie potreby).
#   2. Uruchamia tools/program_qspi_basys.tcl w trybie batch:
#        - tworzy <katalog_modulu>/results/<nazwa>.mcs z bitstreamu,
#        - kasuje, zapisuje i weryfikuje pamiec QSPI plytki.
#
# Uwaga: po skonczonym programowaniu FPGA jest jeszcze zaladowana tymczasowym bitstreamem
# programatora. Aby plytka ruszyla z wsadu we flashu, wcisnij PROG (lub wylacz+wlacz zasilanie).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/board_config.sh"
TCL_FILE="$SCRIPT_DIR/program_qspi_basys.tcl"

if [ -z "$1" ]; then
    echo "Uzycie: ./tools/program_qspi_basys.sh <katalog_modulu> [NAZWA_LUB_ID_PLYTKI]"
    echo "Przyklad: ./tools/program_qspi_basys.sh basys_cam basys15"
    exit 1
fi

PROJECT_DIR="$ROOT_DIR/$1"
INPUT_TARGET="$2"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Blad: Folder modulu '$1' nie istnieje w '$ROOT_DIR'."
    exit 1
fi

if [ ! -f "$TCL_FILE" ]; then
    echo "Blad: Brak pliku $TCL_FILE."
    exit 1
fi

if ! command -v vivado >/dev/null 2>&1; then
    echo "Blad: Nie znaleziono polecenia 'vivado' w PATH. Zaladuj srodowisko Vivado i uruchom skrypt ponownie."
    exit 1
fi

# Wczytanie aliasow plytek (jezeli istnieje plik konfiguracyjny)
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Rozwiazanie przyjaznej nazwy z board_config.sh na ID JTAG
TARGET_ID=""
if [ -n "$INPUT_TARGET" ]; then
    VAR_NAME="BOARD_${INPUT_TARGET}"
    if [ -n "${!VAR_NAME}" ]; then
        TARGET_ID="${!VAR_NAME}"
    else
        TARGET_ID="$INPUT_TARGET"
    fi
fi

# Lokalizacja pliku .bit (generujemy jezeli nie ma)
BITSTREAM=$(find "$PROJECT_DIR/results" -maxdepth 1 -name "*.bit" -print -quit 2>/dev/null || true)

if [ -z "$BITSTREAM" ]; then
    echo "Uwaga: Brak pliku .bit. Uruchamiam generowanie bitstreamu dla '$1'..."
    "$SCRIPT_DIR/generate_bitstream_basys.sh" "$1"
    BITSTREAM=$(find "$PROJECT_DIR/results" -maxdepth 1 -name "*.bit" -print -quit)
    if [ -z "$BITSTREAM" ]; then
        echo "Blad: Po wygenerowaniu nadal brak pliku .bit w '$PROJECT_DIR/results/'."
        exit 1
    fi
fi

BIT_BASENAME=$(basename "$BITSTREAM" .bit)
MCS_FILE="$PROJECT_DIR/results/${BIT_BASENAME}.mcs"

echo "Bitstream: $BITSTREAM"
echo "Plik MCS:  $MCS_FILE"
if [ -n "$TARGET_ID" ]; then
    echo "Plytka:    $INPUT_TARGET (JTAG ID: $TARGET_ID)"
else
    echo "Plytka:    pierwsza widoczna (brak filtra)"
fi

vivado -mode batch -notrace -source "$TCL_FILE" -tclargs "$BITSTREAM" "$MCS_FILE" "$TARGET_ID"

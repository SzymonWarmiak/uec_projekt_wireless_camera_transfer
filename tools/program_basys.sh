#!/bin/bash
#
# Wgrywa tymczasowo bitstream do RAM-u plytki Basys 3
#
# Uzycie: ./tools/program_basys.sh <folder_projektu> [NAZWA_LUB_ID_PLYTKI]
# Przyklad: ./tools/program_basys.sh basys_cam basys15

set -e

# Ustalenie absolutnej sciezki do folderu skryptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/board_config.sh"

if [ -z "$1" ]; then
    echo "Uzycie: ./tools/program_basys.sh <folder_projektu> [NAZWA_LUB_ID_PLYTKI]"
    echo "Przyklad: ./tools/program_basys.sh basys_cam basys15"
    exit 1
fi

PROJECT_DIR="$ROOT_DIR/$1"
INPUT_TARGET=$2

# Wczytanie konfiguracji plytek (jesli plik istnieje)
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Rozwiazywanie przyjaznej nazwy z pliku konfiguracyjnego na JTAG ID
TARGET_ID=""
if [ -n "$INPUT_TARGET" ]; then
    VAR_NAME="BOARD_${INPUT_TARGET}"
    if [ -n "${!VAR_NAME}" ]; then
        TARGET_ID="${!VAR_NAME}"
    else
        TARGET_ID="$INPUT_TARGET"
    fi
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Blad: Folder projektu '$1' nie istnieje!"
    exit 1
fi

if ! command -v vivado >/dev/null 2>&1; then
    echo "Blad: Nie znaleziono polecenia 'vivado' w PATH. Zaladuj srodowisko Vivado i uruchom skrypt ponownie."
    exit 1
fi

# Znajdz pierwszy plik .bit w folderze results danego projektu
BITSTREAM=$(find "$PROJECT_DIR/results" -maxdepth 1 -name "*.bit" -print -quit 2>/dev/null || true)

if [ -z "$BITSTREAM" ]; then
    echo "Uwaga: Nie znaleziono pliku .bit. Uruchamiam automatyczne generowanie bitstreamu dla $1..."
    
    cd "$PROJECT_DIR" || exit 1
    if [ -f "./tools/generate_bitstream.sh" ]; then
        ./tools/generate_bitstream.sh
    else
        echo "Blad: Nie znaleziono skryptu ./tools/generate_bitstream.sh wewnatrz folderu $1!"
        exit 1
    fi
    cd "$ROOT_DIR" || exit 1
    
    # Ponowna proba znalezienia pliku .bit po wygenerowaniu
    BITSTREAM=$(find "$PROJECT_DIR/results" -maxdepth 1 -name "*.bit" -print -quit)
    if [ -z "$BITSTREAM" ]; then
        echo "Blad: Generowanie bitstreamu nie powiodlo sie lub plik nie trafil do folderu results/!"
        exit 1
    fi
fi

echo "Znaleziono bitstream: $BITSTREAM"

if [ -n "$TARGET_ID" ]; then
    echo "Wgrywanie na plytke: $INPUT_TARGET (JTAG ID: $TARGET_ID) ..."
else
    echo "Wgrywanie na domyslna plytke (pierwsza znaleziona) ..."
fi

vivado -mode batch -source "$SCRIPT_DIR/program_fpga.tcl" -tclargs "$BITSTREAM" "$TARGET_ID" -notrace

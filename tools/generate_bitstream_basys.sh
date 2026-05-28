#!/bin/bash
#
# Opakowanie wewnętrznego ./tools/generate_bitstream.sh każdego modułu Basysa,
# tak aby z głównego katalogu projektu można było uruchomić jednym poleceniem:
#
#   ./tools/generate_bitstream_basys.sh <katalog_modulu>
#
# Skrypt:
#   1. Wchodzi do <katalog_modulu>.
#   2. Sourcuje env.sh (ustawia ROOT_DIR, PATH, kopiuje glbl.v jeśli trzeba).
#   3. Uruchamia ./tools/generate_bitstream.sh.
#   4. Wraca do katalogu wywołania, niezależnie od wyniku.
#
# Wynikowy bitstream trafia do <katalog_modulu>/results/, a podsumowanie
# warningów do <katalog_modulu>/results/warning_summary.log.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "$1" ]; then
    echo "Uzycie: ./tools/generate_bitstream_basys.sh <katalog_modulu>"
    echo "Przyklady:"
    echo "  ./tools/generate_bitstream_basys.sh basys_cam"
    echo "  ./tools/generate_bitstream_basys.sh basys_station"
    exit 1
fi

PROJECT_DIR="$ROOT_DIR/$1"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Blad: Folder modulu '$1' nie istnieje w '$ROOT_DIR'."
    exit 1
fi

if [ ! -f "$PROJECT_DIR/env.sh" ]; then
    echo "Blad: Brak pliku env.sh w '$PROJECT_DIR'."
    exit 1
fi

if [ ! -x "$PROJECT_DIR/tools/generate_bitstream.sh" ] && [ ! -f "$PROJECT_DIR/tools/generate_bitstream.sh" ]; then
    echo "Blad: Brak skryptu tools/generate_bitstream.sh w '$PROJECT_DIR'."
    exit 1
fi

if ! command -v vivado >/dev/null 2>&1; then
    echo "Blad: Nie znaleziono polecenia 'vivado' w PATH. Zaladuj srodowisko Vivado i uruchom skrypt ponownie."
    exit 1
fi

ORIGINAL_DIR="$(pwd)"
trap 'cd "$ORIGINAL_DIR"' EXIT

cd "$PROJECT_DIR"

echo "==> Inicjalizacja srodowiska modulu '$1' (source env.sh)"
# shellcheck source=/dev/null
. ./env.sh

echo "==> Generowanie bitstreamu modulu '$1'"
./tools/generate_bitstream.sh

echo "==> Sukces. Wynik w: $PROJECT_DIR/results/"
ls -1 "$PROJECT_DIR/results" || true

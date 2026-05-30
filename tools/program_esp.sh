#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ESP_DIR="$ROOT_DIR/uec_projekt_esp32"

TARGET_FILE=$1
UPLOAD_PORT=$2

if [ -z "$TARGET_FILE" ]; then
    echo "Blad: Podaj plik z kodem jako pierwszy argument!"
    echo "Przyklad: ./tools/program_esp.sh main_cam.cpp COM10"
    exit 1
fi

if [ ! -f "$ESP_DIR/src/$TARGET_FILE" ]; then
    echo "Blad: Plik $TARGET_FILE nie zostal znaleziony w folderze uec_projekt_esp32/src/!"
    exit 1
fi

PIO_CMD="pio"
if ! command -v pio &> /dev/null; then
    POSSIBLE_PATHS=(
        "$HOME/.platformio/penv/Scripts/pio.exe"
        "/c/Users/$USER/.platformio/penv/Scripts/pio.exe"
        "/c/Users/$USERNAME/.platformio/penv/Scripts/pio.exe"
        "/c/Users/szymo/.platformio/penv/Scripts/pio.exe"
    )
    for pio_path in "${POSSIBLE_PATHS[@]}"; do
        if [ -f "$pio_path" ]; then
            PIO_CMD="$pio_path"
            break
        fi
    done
    if [ "$PIO_CMD" = "pio" ]; then
        echo "Blad: Nie znaleziono polecenia pio."
        exit 1
    fi
fi

cd "$ESP_DIR" || exit 1

PIO_ENV="esp32-c3-devkitm-1"
export PLATFORMIO_BUILD_SRC_FILTER="+<*> -<main_*.cpp> +<$TARGET_FILE>"

if [ -z "$UPLOAD_PORT" ]; then
    "$PIO_CMD" run -e "$PIO_ENV" --target upload
else
    "$PIO_CMD" run -e "$PIO_ENV" --target upload --upload-port "$UPLOAD_PORT"
fi

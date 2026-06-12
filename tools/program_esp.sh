#!/bin/bash
# Copyright (C) 2026 Szymon Warmiak, Grzegorz Twardosz
# MTM UEC2
# Author: Szymon Warmiak, Grzegorz Twardosz
#
# Description:
# 

# Ustalenie absolutnej sciezki do folderu skryptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ESP_DIR="$ROOT_DIR/uec_projekt_esp32"

TARGET_NAME=$1
UPLOAD_PORT=$2

if [ -z "$TARGET_NAME" ]; then
    echo "Blad: Podaj cel ESP jako pierwszy argument!"
    echo "Cele: esp_cam, esp_station, esp_ps3, esp_cam_servo"
    echo "Przyklad kamera:  ./tools/program_esp.sh esp_cam COM12"
    echo "Przyklad stacja:  ./tools/program_esp.sh esp_station COM14"
    echo "Przyklad pad PS3: ./tools/program_esp.sh esp_ps3 COM16"
    echo "Przyklad serwo:   ./tools/program_esp.sh esp_cam_servo COM10"
    exit 1
fi

case "$TARGET_NAME" in
    esp_cam)
        TARGET_ENV="esp_cam"
        TARGET_FILE="main_esp_cam.cpp"
        ;;
    esp_station)
        TARGET_ENV="esp_station"
        TARGET_FILE="main_esp_station.cpp"
        ;;
    esp_ps3)
        TARGET_ENV="esp_ps3"
        TARGET_FILE="main_esp_ps3.cpp"
        ;;
    esp_cam_servo)
        TARGET_ENV="esp_cam_servo"
        TARGET_FILE="main_esp_cam_servo.cpp"
        ;;
    *.cpp)
        TARGET_ENV=""
        TARGET_FILE="$TARGET_NAME"
        ;;
    *)
        echo "Blad: Nieznany cel ESP '$TARGET_NAME'."
        echo "Uzyj: esp_cam, esp_station, esp_ps3 albo esp_cam_servo."
        exit 1
        ;;
esac

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
        echo "Blad: Nie znaleziono polecenia pio w domyslnych lokalizacjach."
        echo "Zainstaluj narzedzia CLI w VSCode (PlatformIO -> Core CLI) lub sprawdz sciezke instalacji."
        exit 1
    fi
fi

cd "$ESP_DIR" || exit 1
echo "Program ESP: $TARGET_NAME -> src/$TARGET_FILE"
if [ -n "$TARGET_ENV" ]; then
    if [ -z "$UPLOAD_PORT" ]; then
        "$PIO_CMD" run -e "$TARGET_ENV" --target upload
    else
        "$PIO_CMD" run -e "$TARGET_ENV" --target upload --upload-port "$UPLOAD_PORT"
    fi
else
    export PLATFORMIO_BUILD_SRC_FILTER="+<*> -<main_*.cpp> +<$TARGET_FILE>"
    if [ -z "$UPLOAD_PORT" ]; then
        "$PIO_CMD" run --target upload
    else
        "$PIO_CMD" run --target upload --upload-port "$UPLOAD_PORT"
    fi
fi

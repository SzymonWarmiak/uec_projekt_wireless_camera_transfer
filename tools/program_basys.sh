#!/bin/bash

# Ustalenie absolutnej sciezki do folderu skryptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/board_config.sh"
CFGMEM_PARTS=(
    "s25fl032p-spi-x1_x2_x4"
    "mx25l3273f-spi-x1_x2_x4"
    "mx25l3233f-spi-x1_x2_x4"
)

file_timestamp() {
    date -r "$1" "+%Y-%m-%d %H:%M:%S"
}

if [ -z "$1" ]; then
    echo "Uzycie: ./tools/program_basys.sh <folder_projektu> [NAZWA_LUB_ID_PLYTKI]"
    echo "Foldery projektu: basys_cam, basys_station"
    echo "Przyklad kamera:  ./tools/program_basys.sh basys_cam basys15"
    echo "Przyklad stacja:  ./tools/program_basys.sh basys_station basys16"
    exit 1
fi

PROJECT_DIR="$ROOT_DIR/$1"
INPUT_TARGET=$2
RESULTS_DIR="$PROJECT_DIR/results"

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

find_bitstream() {
    if [ -d "$RESULTS_DIR" ]; then
        find "$RESULTS_DIR" -maxdepth 1 -name "*.bit" -print -quit
    fi
}

generate_project_bitstream() {
    echo "Uruchamiam generowanie bitstreamu dla $1..."

    cd "$PROJECT_DIR" || exit 1
    if [ -f "./tools/generate_bitstream.sh" ]; then
        ./tools/generate_bitstream.sh
    else
        echo "Blad: Nie znaleziono skryptu ./tools/generate_bitstream.sh wewnatrz folderu $1!"
        exit 1
    fi
    cd "$ROOT_DIR" || exit 1
}

# Znajdz pierwszy plik .bit w folderze results danego projektu
BITSTREAM=$(find_bitstream)

if [ -z "$BITSTREAM" ]; then
    echo "Uwaga: Nie znaleziono pliku .bit. Uruchamiam automatyczne generowanie bitstreamu dla $1..."

    generate_project_bitstream "$1"

    # Ponowna proba znalezienia pliku .bit po wygenerowaniu
    BITSTREAM=$(find_bitstream)
    if [ -z "$BITSTREAM" ]; then
        echo "Blad: Generowanie bitstreamu nie powiodlo sie lub plik nie trafil do folderu results/!"
        exit 1
    fi
fi

echo "Znaleziono bitstream: $BITSTREAM"
echo "Data wygenerowania bitstreamu: $(file_timestamp "$BITSTREAM")"

BIN_FILE="${BITSTREAM%.bit}.bin"
QSPI_PROGRAM_TCL=$(mktemp "${TMPDIR:-/tmp}/basys_qspi_program.XXXXXX.tcl")
trap 'rm -f "$QSPI_PROGRAM_TCL"' EXIT

if [ ! -f "$BIN_FILE" ] || [ "$BITSTREAM" -nt "$BIN_FILE" ]; then
    echo "Uwaga: Brak aktualnego pliku QSPI dla bitstreamu. Generuje ponownie bitstream i QSPI..."
    generate_project_bitstream "$1"

    BITSTREAM=$(find_bitstream)
    if [ -z "$BITSTREAM" ]; then
        echo "Blad: Generowanie bitstreamu nie powiodlo sie lub plik nie trafil do folderu results/!"
        exit 1
    fi

    BIN_FILE="${BITSTREAM%.bit}.bin"
    if [ ! -f "$BIN_FILE" ]; then
        echo "Blad: Nie znaleziono pliku QSPI po generowaniu: $BIN_FILE"
        exit 1
    fi
fi

echo "Znaleziono plik QSPI: $BIN_FILE"
echo "Data wygenerowania pliku QSPI: $(file_timestamp "$BIN_FILE")"

if [ -n "$TARGET_ID" ]; then
    echo "Wgrywanie na plytke: $INPUT_TARGET (JTAG ID: $TARGET_ID) ..."
else
    echo "Wgrywanie na domyslna plytke (pierwsza znaleziona) ..."
fi

vivado -mode batch -source "$SCRIPT_DIR/program_fpga.tcl" -tclargs "$BITSTREAM" "$TARGET_ID" -notrace
if [ $? -ne 0 ]; then
    echo "Blad: Wgrywanie bitstreamu do FPGA nie powiodlo sie."
    exit 1
fi

echo "Zapisywanie konfiguracji do pamieci QSPI. Po zapisie ustaw JP1 w pozycje QSPI, zeby FPGA startowalo z pamieci po wlaczeniu zasilania."

CFG_PART_ARGS=("${CFGMEM_PARTS[@]}")
cat > "$QSPI_PROGRAM_TCL" <<'TCL'
if { $argc < 3 } {
    puts "Blad: Brak argumentow: <plik_bin> <target_id> <cfgmem_part...>"
    exit 1
}

set bin_file [lindex $argv 0]
set target_id [lindex $argv 1]
set cfgmem_part_names [lrange $argv 2 end]

open_hw_manager
connect_hw_server -allow_non_jtag

set targets [get_hw_targets]
set selected_target ""

if { $target_id != "" } {
    foreach target $targets {
        if { [string match "*$target_id*" $target] } {
            set selected_target $target
            break
        }
    }
    if { $selected_target == "" } {
        puts "Blad: Nie znaleziono podlaczonego urzadzenia z ID: $target_id"
        close_hw_manager
        exit 1
    }
} else {
    set selected_target [lindex $targets 0]
}

puts "\nLacznie z urzadzeniem: $selected_target"
current_hw_target $selected_target
open_hw_target

set device [lindex [get_hw_devices] 0]
current_hw_device $device

set programmed 0
foreach cfgmem_part_name $cfgmem_part_names {
    if { [catch {set cfgmem_parts [get_cfgmem_parts $cfgmem_part_name]} err] } {
        puts "Pominieto nieznany typ pamieci: $cfgmem_part_name"
        puts $err
        continue
    }

    if { [llength $cfgmem_parts] == 0 } {
        puts "Pominieto nieznany typ pamieci: $cfgmem_part_name"
        continue
    }

    puts "Proba zapisu pamieci QSPI: $cfgmem_part_name"
    set cfgmem_part [lindex $cfgmem_parts 0]

    catch {delete_hw_cfgmem [get_property PROGRAM.HW_CFGMEM $device]} delete_result
    create_hw_cfgmem -hw_device $device $cfgmem_part
    set cfgmem [get_property PROGRAM.HW_CFGMEM $device]

    set_property PROGRAM.ADDRESS_RANGE {use_file} $cfgmem
    set_property PROGRAM.FILES [list $bin_file] $cfgmem
    set_property PROGRAM.PRM_FILE {} $cfgmem
    set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $cfgmem
    set_property PROGRAM.BLANK_CHECK 0 $cfgmem
    set_property PROGRAM.ERASE 1 $cfgmem
    set_property PROGRAM.CFG_PROGRAM 1 $cfgmem
    set_property PROGRAM.VERIFY 1 $cfgmem
    set_property PROGRAM.CHECKSUM 0 $cfgmem

    if { [catch {
        startgroup
        set cfgmem_mem_type [get_property MEM_TYPE [get_property CFGMEM_PART $cfgmem]]
        if { ![string equal [get_property PROGRAM.HW_CFGMEM_TYPE $device] $cfgmem_mem_type] } {
            create_hw_bitstream -hw_device $device [get_property PROGRAM.HW_CFGMEM_BITFILE $device]
            program_hw_devices $device
            refresh_hw_device $device
        }
        program_hw_cfgmem -hw_cfgmem $cfgmem
        endgroup
    } err] } {
        catch {endgroup}
        puts "Nie udalo sie zaprogramowac $cfgmem_part_name:"
        puts $err
    } else {
        puts "Pamiec QSPI zaprogramowana poprawnie: $cfgmem_part_name"
        set programmed 1
        break
    }
}

close_hw_target
close_hw_manager

if { !$programmed } {
    puts "Blad: Nie udalo sie zaprogramowac zadnej obslugiwanej pamieci QSPI."
    exit 1
}
TCL

vivado -mode batch -nojournal -nolog -notrace -source "$QSPI_PROGRAM_TCL" -tclargs "$BIN_FILE" "$TARGET_ID" "${CFG_PART_ARGS[@]}"

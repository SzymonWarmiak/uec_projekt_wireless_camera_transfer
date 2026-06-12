#!/bin/bash
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
# Modified by: Szymon Warmiak, Grzegorz Twardosz
#
# Description:
# This script runs Vivado in tcl mode and sources an apropriate tcl file to run
# all the steps to generate bitstream. When finished, the bitsream is copied to
# the result directory. Additionally, all the warnings and errors logged during
# synthesis and implementation are also copied to results/warning_summary.log
# To work properly, a git repository in the project directory is required.
# Run from the project root directory.

# Remove untracked files
git clean -fXd fpga
mkdir -p results

# Run Vivado and generate bitstream
cd fpga
vivado -mode tcl -source scripts/generate_bitstream.tcl
cd ..

# Copy bitstream to results
find fpga/build -name "*.bit" -exec cp {} results/ \;

# Generate QSPI configuration file next to each bitstream
CFG_GEN_TCL=$(mktemp "${TMPDIR:-/tmp}/basys_cfgmem_gen.XXXXXX.tcl")
trap 'rm -f "$CFG_GEN_TCL"' EXIT

cat > "$CFG_GEN_TCL" <<'TCL'
set bitstream_file [lindex $argv 0]
set bin_file [lindex $argv 1]
set generated 0

foreach interface {spix4 spix1} {
    puts "Proba generowania pliku cfgmem dla interfejsu $interface"
    if { [catch {
        write_cfgmem -force -format bin -interface $interface -size 32 -loadbit "up 0x0 $bitstream_file" $bin_file
    } err] } {
        puts "Nie udalo sie wygenerowac cfgmem dla $interface:"
        puts $err
    } else {
        puts "Plik cfgmem wygenerowany dla interfejsu $interface"
        set generated 1
        break
    }
}

if { !$generated } {
    puts "Blad: Nie udalo sie wygenerowac pliku cfgmem ani dla spix4, ani dla spix1."
    exit 1
}
TCL

for BITSTREAM in results/*.bit; do
    [ -e "$BITSTREAM" ] || continue
    BIN_FILE="${BITSTREAM%.bit}.bin"
    echo "Generowanie pliku konfiguracji QSPI: $BIN_FILE"
    vivado -mode batch -nojournal -nolog -notrace -source "$CFG_GEN_TCL" -tclargs "$BITSTREAM" "$BIN_FILE"
done

# Copy warnings and errors to a single log file in results
./tools/warning_summary.sh

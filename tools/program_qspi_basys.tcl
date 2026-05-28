# Skrypt TCL programujacy pamiec QSPI Flash plytki Basys 3 (Spansion S25FL032P, 32 Mb)
# tak, aby bitstream byl ladowany do FPGA przy kazdym wlaczeniu zasilania.
#
# Argumenty (z linii polecen Vivado):
#   argv[0] - sciezka do pliku .bit
#   argv[1] - sciezka do pliku .mcs (zostanie utworzony / nadpisany)
#   argv[2] - (opcjonalnie) fragment ID urzadzenia JTAG (jak w board_config.sh).
#             Jezeli pusty, brana jest pierwsza widoczna plytka.
#
# Uwaga: uzywamy interfejsu spix1 - dziala bez dodatkowych
#   set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# w pliku XDC. Przy przejsciu na spix4 trzeba dolozyc te property w xdc i tu zmienic
# parametr -interface.

if { $argc < 2 } {
    puts "Blad: Uzycie: program_qspi_basys.tcl <plik.bit> <plik.mcs> \[ID_PLYTKI\]"
    exit 1
}

set bit_file  [file normalize [lindex $argv 0]]
set mcs_file  [file normalize [lindex $argv 1]]
set target_id [lindex $argv 2]

if { ![file exists $bit_file] } {
    puts "Blad: Plik bitstream nie istnieje: $bit_file"
    exit 1
}

# 1. Wygeneruj plik .mcs z .bit (Spansion S25FL032P = 32 Mb = 4 MB; -size 16 ustawia
#    wielkosc kontenera MCS na 16 MB, co bezpiecznie miesci bitstream Basysa).
puts "==> Generowanie pliku MCS: $mcs_file"
write_cfgmem -force -format mcs -interface spix1 -size 16 \
    -loadbit "up 0x00000000 $bit_file" \
    -file $mcs_file

if { ![file exists $mcs_file] } {
    puts "Blad: Vivado nie wygenerowal pliku MCS."
    exit 1
}

# 2. Polacz sie z hardware managerem.
open_hw_manager
connect_hw_server -allow_non_jtag

set targets [get_hw_targets]
if { [llength $targets] == 0 } {
    puts "Blad: Brak widocznych targetow JTAG."
    close_hw_manager
    exit 1
}

set selected_target ""
if { $target_id != "" } {
    foreach t $targets {
        if { [string match "*$target_id*" $t] } {
            set selected_target $t
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

puts "==> Lacznie z urzadzeniem: $selected_target"
current_hw_target $selected_target
open_hw_target

set device [lindex [get_hw_devices] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device

# 3. Dolacz konfigurowalna pamiec QSPI typowa dla plytki Basys 3.
set mem_part [lindex [get_cfgmem_parts {s25fl032p-spi-x1_x2_x4}] 0]
if { $mem_part == "" } {
    puts "Blad: Vivado nie zna czesci 's25fl032p-spi-x1_x2_x4'. Sprawdz wersje narzedzia."
    close_hw_target
    close_hw_manager
    exit 1
}

create_hw_cfgmem -hw_device $device -mem_dev $mem_part
set cfgmem [get_property PROGRAM.HW_CFGMEM $device]

set_property PROGRAM.FILES                  [list $mcs_file] $cfgmem
set_property PROGRAM.PRM_FILE               {}               $cfgmem
set_property PROGRAM.ADDRESS_RANGE          {use_file}       $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none}      $cfgmem
set_property PROGRAM.BLANK_CHECK            0                $cfgmem
set_property PROGRAM.ERASE                  1                $cfgmem
set_property PROGRAM.CFG_PROGRAM            1                $cfgmem
set_property PROGRAM.VERIFY                 1                $cfgmem
set_property PROGRAM.CHECKSUM               0                $cfgmem

# 4. Vivado wymaga, by tymczasowy bitstream programatora byl zaladowany do FPGA,
#    ktora pozniej kasuje i programuje flash w imieniu uzytkownika.
puts "==> Tworzenie tymczasowego bitstreamu programatora..."
create_hw_bitstream -hw_device $device [get_property PROGRAM.HW_CFGMEM_BITFILE $device]
program_hw_devices $device
refresh_hw_device $device

puts "==> Programowanie pamieci QSPI plikiem: $mcs_file"
program_hw_cfgmem -hw_cfgmem $cfgmem

puts "\n==> Programowanie QSPI zakonczone sukcesem."
puts "    Wcisnij przycisk PROG na plytce (lub wylacz i wlacz zasilanie),"
puts "    zeby FPGA pobrala wsad z flasha."

close_hw_target
close_hw_manager

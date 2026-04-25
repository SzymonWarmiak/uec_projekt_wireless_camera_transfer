# Skrypt TCL do wgrywania bitstreamu na konkretna plytke

if { $argc < 1 } {
    puts "Blad: Brak sciezki do pliku bitstream!"
    exit 1
}

set bitstream_file [lindex $argv 0]
set target_id [lindex $argv 1]

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

set_property PROGRAM.FILE $bitstream_file $device
puts "Wgrywanie pliku: $bitstream_file..."
program_hw_devices $device

puts "Operacja zakonczona sukcesem!"
close_hw_target
close_hw_manager
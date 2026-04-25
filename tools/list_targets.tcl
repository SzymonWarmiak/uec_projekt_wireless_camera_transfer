open_hw_manager
connect_hw_server -allow_non_jtag

set targets [get_hw_targets]
foreach target $targets {
    puts $target
}

close_hw_manager
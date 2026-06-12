# Copyright (C) 2026 Szymon Warmiak, Grzegorz Twardosz
# MTM UEC2
# Author: Szymon Warmiak, Grzegorz Twardosz
#
# Description:
# 
open_hw_manager
connect_hw_server -allow_non_jtag

set targets [get_hw_targets]
foreach target $targets {
    puts $target
}

close_hw_manager
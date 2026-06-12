#!/bin/bash
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
# Modified by: Szymon Warmiak, Grzegorz Twardosz
#
# Description:
# Load a bitstream to a Xilinx FPGA using Vivado in tcl mode
# Run from the project root directory.


bitstream_file=$(find results -name "*.bit")

vivado -mode tcl -source fpga/scripts/program_fpga.tcl -tclargs "${bitstream_file}"

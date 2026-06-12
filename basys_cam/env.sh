#!/bin/bash -e
#
# Copyright (C) 2025  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
# Modified by: Szymon Warmiak, Grzegorz Twardosz
#
# Description:
# Initialize enviorment for working with the project.

export ROOT_DIR=$(pwd)
export PATH=tools:${PATH}
export VIVADO_DIR=$(which vivado | sed "s/bin\/vivado//")

mkdir -p results

# Copy glbl.v from Vivado instalation dir - required for IP simulation
if [[ ! -e sim/common/glbl.v ]]; then
    mkdir -p sim/common
    cp ${VIVADO_DIR}/data/verilog/src/glbl.v sim/common/glbl.v
fi

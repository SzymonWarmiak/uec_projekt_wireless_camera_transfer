#!/bin/bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR
export PATH="$ROOT_DIR/tools:${PATH}"

echo "Project tools added to PATH:"
echo "  $ROOT_DIR/tools"
echo
echo "Commands:"
echo "  program_basys basys_cam basys15"
echo "  program_basys basys_station basys16"
echo "  program_esp main_cam.cpp COM10"
echo "  generate_bitstream_basys basys_cam"

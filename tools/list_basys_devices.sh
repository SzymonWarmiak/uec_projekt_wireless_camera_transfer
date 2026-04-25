#!/bin/bash

# Ustalenie absolutnej sciezki do folderu skryptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Uruchamiamy Vivado w trybie batch, bez zbednego interfejsu graficznego i wczytujemy plik tcl
vivado -mode batch -source "$SCRIPT_DIR/list_targets.tcl" -notrace
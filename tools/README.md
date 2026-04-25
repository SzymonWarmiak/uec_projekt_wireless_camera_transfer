# Narzędzia projektowe (Tools)

Ten folder zawiera uniwersalne skrypty wspierające pracę z wieloma układami w projekcie (w tym automatyzację wgrywania kodu na konkretne płytki FPGA).

## 1. Wgrywanie Bitstreamu na FPGA (`program_basys.sh`)

Skrypt `program_basys.sh` pozwala na wgranie wygenerowanego strumienia bitów (`.bit`) na docelową płytkę Basys 3. Skrypt został zintegrowany z plikiem konfiguracyjnym, dzięki czemu nie trzeba pamiętać długich sprzętowych numerów JTAG.

### Jak tego używać?
Będąc w **głównym katalogu** projektu wpisz komendę z dwoma argumentami:
1. Nazwę folderu modułu (np. `basys_1` lub `basys_2`).
2. Przyjazną nazwę płytki zdefiniowaną w pliku `board_config.sh` (np. `basys15`).

```bash
./tools/program_basys.sh basys_1 basys15
```
*Powyższa komenda odnajdzie plik `.bit` w `basys_1/results/` i zaprogramuje nim płytkę "basys15".*

### Co jeśli mam tylko jedną płytkę?
Jeśli masz podłączoną tylko jedną płytkę, możesz pominąć drugi argument. Vivado wgra projekt na pierwsze urządzenie, jakie znajdzie:
```bash
./tools/program_basys.sh basys_2
```

---

## 2. Zarządzanie przypisaniami (`board_config.sh`)

W pliku `board_config.sh` znajduje się mapa przyjaznych nazw przypisana do identyfikatorów JTAG (Target ID). 
Jeśli w przyszłości otrzymasz inną płytkę z laboratorium, wystarczy odczytać jej numer i zaktualizować ten plik.

Format wpisów to `BOARD_<twoja_nazwa>="<jtag_id>"`.

---

## 3. Listowanie podłączonych układów FPGA (`list_basys_devices.sh`)

Jeśli potrzebujesz sprawdzić sprzętowe numery JTAG aktualnie podłączonych urządzeń, użyj komendy:
```bash
./tools/list_basys_devices.sh
```
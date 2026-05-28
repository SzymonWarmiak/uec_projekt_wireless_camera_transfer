# Narzędzia projektowe (Tools)

Ten folder zawiera uniwersalne skrypty wspierające pracę z wieloma układami w projekcie (w tym automatyzację generowania bitstreamu, wgrywania na konkretne płytki FPGA i programowania pamięci QSPI).

Każdy skrypt uruchamiamy **z głównego katalogu projektu** (tam gdzie ten plik leży o jeden poziom wyżej), w terminalu obsługującym Bash (np. Git Bash).

## 1. Generowanie bitstreamu (`generate_bitstream_basys.sh`)

Skrypt opakowuje wewnętrzny `tools/generate_bitstream.sh` modułu Basysa tak, aby nie trzeba było ręcznie wchodzić do folderu i sourcować `env.sh`. Sam wchodzi do podanego katalogu, inicjalizuje środowisko i uruchamia syntezę + implementację w Vivado.

```bash
./tools/generate_bitstream_basys.sh basys_cam
./tools/generate_bitstream_basys.sh basys_station
```

Plik `.bit` ląduje w `<katalog_modulu>/results/`, a podsumowanie warningów w `<katalog_modulu>/results/warning_summary.log`.

---

## 2. Wgrywanie Bitstreamu na FPGA (`program_basys.sh`)

Skrypt `program_basys.sh` wgrywa wygenerowany strumień bitów (`.bit`) na docelową płytkę Basys 3 **do pamięci RAM FPGA** — po wyłączeniu zasilania bitstream znika. Jeżeli `.bit` nie istnieje, skrypt sam zawoła `generate_bitstream_basys.sh`. Skrypt jest zintegrowany z plikiem konfiguracyjnym, dzięki czemu nie trzeba pamiętać długich numerów JTAG.

### Jak tego używać?
Będąc w **głównym katalogu** projektu wpisz komendę z dwoma argumentami:
1. Nazwę folderu modułu (np. `basys_cam` lub `basys_station`).
2. Przyjazną nazwę płytki zdefiniowaną w pliku `board_config.sh` (np. `basys15`).

```bash
./tools/program_basys.sh basys_cam basys15
```
*Powyższa komenda odnajdzie plik `.bit` w `basys_cam/results/` i zaprogramuje nim płytkę "basys15".*

### Co jeśli mam tylko jedną płytkę?
Jeśli masz podłączoną tylko jedną płytkę, możesz pominąć drugi argument. Vivado wgra projekt na pierwsze urządzenie, jakie znajdzie:
```bash
./tools/program_basys.sh basys_station
```

---

## 3. Trwałe zaprogramowanie pamięci QSPI (`program_qspi_basys.sh`)

Skrypt programuje pamięć **QSPI Flash** płytki Basys 3 (Spansion S25FL032P, 32 Mb) tak, żeby bitstream pozostał w urządzeniu po odłączeniu zasilania. Tworzy plik `.mcs` z `.bit` w `<katalog_modulu>/results/`, a następnie kasuje, zapisuje i weryfikuje flash przez Vivado. Po zakończeniu wciśnij `PROG` na płytce (albo wyłącz i włącz zasilanie), żeby FPGA załadowała wsad z flasha.

```bash
./tools/program_qspi_basys.sh basys_cam basys15
./tools/program_qspi_basys.sh basys_station basys16
```

Pierwsze programowanie trwa zauważalnie dłużej niż wgrywanie do RAM (typowo 1–2 min). Argumenty są identyczne jak w `program_basys.sh`.

---

## 4. Zarządzanie przypisaniami (`board_config.sh`)

W pliku `board_config.sh` znajduje się mapa przyjaznych nazw przypisana do identyfikatorów JTAG (Target ID). Jeśli w przyszłości otrzymasz inną płytkę z laboratorium, wystarczy odczytać jej numer i zaktualizować ten plik.

Format wpisów to `BOARD_<twoja_nazwa>="<jtag_id>"`.

---

## 5. Listowanie podłączonych układów FPGA (`list_basys_devices.sh`)

Jeśli potrzebujesz sprawdzić sprzętowe numery JTAG aktualnie podłączonych urządzeń, użyj komendy:
```bash
./tools/list_basys_devices.sh
```

---

## 6. Wgrywanie kodu na ESP32 (`program_esp.sh`)

Skrypt pozwala wybrać który plik z `uec_projekt_esp32/src/main_*.cpp` ma być skompilowany i wgrany na podłączony mikrokontroler:

```bash
./tools/program_esp.sh main_cam.cpp COM12
./tools/program_esp.sh main_station.cpp COM14
```
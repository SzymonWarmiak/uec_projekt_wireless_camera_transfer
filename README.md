# Bezprzewodowy system transmisji wideo (Basys 3 + ESP32)

Projekt AGH / UEC2: obraz z kamery **OV7670** trafia przez **FPGA Basys 3** i most **Wi‑Fi (ESP32)** na drugą płytkę Basys z wyjściem **VGA**. Na stronie kamery można dodatkowo sterować napędem (**L298N**) pada z PC lub komendami UDP.

## Co jest w repozytorium

| Katalog | Rola |
|---------|------|
| [`basys_cam/`](basys_cam/) | Nadajnik: kamera, bufor ramki, **SPI master** ↔ ESP, sterowanie po **SPI MISO**, wyjścia **JXADC 7–10** → L298N, lokalny podgląd VGA |
| [`basys_station/`](basys_station/) | Odbiornik: **SPI slave** ← ESP, podwójne buforowanie, VGA na monitor |
| [`uec_projekt_esp32/`](uec_projekt_esp32/) | Firmware **PlatformIO** (`main_cam.cpp`, `main_station.cpp`) — UDP, SPI DMA |
| [`cam_control_gui/`](cam_control_gui/) | Aplikacja na PC: sterowanie i konfiguracja Wi-Fi (Python + tkinter) |
| [`tools/`](tools/) | Skrypty: Vivado, programowanie Basys/ESP, `cam_control.py` |
| [`basys_cam/docs/MOTOR_L298N.md`](basys_cam/docs/MOTOR_L298N.md) | Okablowanie L298N i mapowanie **JXADC** |

## Architektura

```mermaid
flowchart LR
  subgraph cam [basys_cam]
    OV7670[OV7670]
    FPGA_C[Artix-7]
    OV7670 --> FPGA_C
    FPGA_C <-->|SPI| ESP_C
    FPGA_C -->|VGA preview|
    FPGA_C -->|JXADC 7-10| L298N[L298N]
  end
  subgraph wifi [Wi-Fi]
    ESP_C[ESP32-C3 AP]
    ESP_S[ESP32 station]
    ESP_C -->|UDP 1234| ESP_S
  end
  subgraph st [basys_station]
    FPGA_S[Artix-7]
    ESP_S -->|SPI| FPGA_S
    FPGA_S --> VGA[VGA]
  end
  PC[PC / cam_control_gui] -->|Wi-Fi| ESP_C
```

1. **basys_cam** — przechwytuje klatkę (320×240), wysyła ~76 800 B przez SPI do ESP, opcjonalnie pokazuje obraz na lokalnym VGA.
2. **ESP cam** (`main_cam.cpp`) — tryb **STA** w skonfigurowanej sieci Wi-Fi, odbiór SPI, wysyłka klatek **UDP** (75 pakietów × 1024 B + nagłówek), sterowanie do FPGA po **SPI MISO**. Gdy brak konfiguracji Wi-Fi, łączy się jako klient z `ROBOT_SETUP`.
3. **ESP station** (`main_station.cpp`) — **STA** w tej samej sieci, broadcast `start`, składanie UDP → SPI do FPGA. Gdy brak konfiguracji Wi-Fi, uruchamia AP `ROBOT_SETUP`.
4. **basys_station** — odbiór SPI, framebuffer, **VGA** 1024×768.

## Wymagania

- **Xilinx Vivado** (w `PATH`) — synteza Basys 3 (`xc7a35tcpg236-1`)
- **PlatformIO** (`pio`) — firmware ESP32-C3 (cam) i ESP32 (station, według używanego modułu)
- **Git Bash** (Windows) lub Linux — skrypty `tools/*.sh`
- **Python 3** — `cam_control_gui`, `tools/cam_control.py`
- Sprzęt: 2× Basys 3, 2× ESP32 (u nas **ESP32-C3 DevKitM-1** przy kamerze), moduł OV7670, opcjonalnie **L298N** + 2 silniki DC

## Szybki start (kolejność)

Wszystkie polecenia z **katalogu głównego** repozytorium.

Najpierw w Git Bash załaduj krótkie komendy:

```bash
source env.sh
```

Po tym można pisać np. `program_basys ...` i `program_esp ...` bez prefiksu `tools/`.

### 1. Konfiguracja JTAG (jednorazowo / przy nowych płytkach)

```bash
list_basys_devices
# wpisz numery seryjne w tools/board_config.sh jako BOARD_basys15=...
```

### 2. FPGA — kamera

```bash
generate_bitstream_basys basys_cam
program_basys basys_cam basys15
```

### 3. FPGA — stacja

```bash
generate_bitstream_basys basys_station
program_basys basys_station basys16
```

### 4. ESP

```bash
program_esp main_cam.cpp COM10
program_esp main_station.cpp COM14
```

Porty `COM*` dopasuj w Menedżerze urządzeń.

### 5. Wideo

1. Zasilaj **Basys** i **ESP** osobno (np. dwa porty USB na PC — **nie** zasilaj ESP z USB Basysa).
2. Wspólna **masa (GND)** między Basys a ESP przy połączeniach sygnałowych.
3. Przy pierwszym uruchomieniu skonfiguruj Wi-Fi przez aplikację Flutter: połącz telefon z `ROBOT_SETUP` / `robotsetup`, wpisz SSID i hasło sieci, wyślij konfigurację do ESP station. ESP station rozgłasza konfigurację do ESP cam i oba ESP restartują się do wybranej sieci.
4. Włącz obie płytki — oba ESP łączą się z tą samą siecią i stacja sama negocjuje strumień (`start` broadcast).
5. Obraz na **VGA** stacji; na ESP cam dioda miga przy aktywnym streamie.

### 6. Sterowanie silnikami (pad na PC)

1. PC/telefon łączy się z tą samą siecią Wi-Fi, do której podłączone jest ESP cam.
2. Uruchom:

```bash
python cam_control_gui/cam_control_gui.py
```

Przytrzymaj **▲▼◄►** = jazda; puszczenie = stop. Szczegóły: [`cam_control_gui/README.md`](cam_control_gui/README.md).

Alternatywa (CLI):

```bash
python tools/cam_control.py start
python tools/cam_control.py stop
# test kierunku (nibble pada, dekodowany w FPGA):
python tools/cam_control.py led 0
```

## Połączenia sprzętowe (skrót)

### basys_cam ↔ ESP32-C3 (SPI-only)

| Sygnał | Basys | ESP (typowo) |
|--------|-------|----------------|
| SPI SCK | JA4 | GPIO4 |
| SPI MOSI | JA2 | GPIO6 |
| SPI MISO | JA3 | GPIO5 |
| SPI CS | JA1 | GPIO7 |
| GND | GND | GND |

SPI: Basys jest masterem. Obraz idzie po **MOSI** do ESP, a aktualny nibble sterowania wraca po **MISO** do Basysa.

### L298N ↔ basys_cam (JXADC)

| JXADC | FPGA | L298N |
|-------|------|-------|
| 1 | wolny | — |
| **7** | IN1 | silnik 1 |
| **8** | IN2 | silnik 1 |
| **9** | IN3 | silnik 2 |
| **10** | IN4 | silnik 2 |

**ENA / ENB** na module L298N — podłącz według dokumentacji modułu (często do +5 V dla stałej prędkości). Pełny opis: [`basys_cam/docs/MOTOR_L298N.md`](basys_cam/docs/MOTOR_L298N.md).

### Logika jazdy (FPGA `motor_l298n_decode.v`)

Pada wysyła **nibble kierunku** (bit0=góra, bit1=prawo, bit2=dół, bit3=lewo). FPGA ustawia pary IN jak w Arduino:

| Kierunek | IN1, IN2 (silnik 1) | IN3, IN4 (silnik 2) |
|----------|---------------------|---------------------|
| Przód | H, L | H, L |
| Tył | L, H | L, H |
| Lewo | L, H | H, L |
| Prawo | H, L | L, H |
| Stop | L, L | L, L |

> **Uwaga:** w zależności od okablowania mostka H mostek może jechać „do tyłu” — wtedy zamień przewody IN1↔IN2 lub IN3↔IN4 na jednym silniku. Dostrojenie kierunków jest w toku.

LD0–LD3 na **basys_cam** pokazują aktualny **nibble z pada** (podgląd), nie stan L298N.

## Protokół UDP (wideo)

- Port: **1234**
- Normalna praca: ESP cam i ESP station są klientami tej samej sieci Wi-Fi.
- Tryb konfiguracji: ESP station tworzy AP **`ROBOT_SETUP`** / **`robotsetup`**, IP **192.168.4.1**, HTTP `POST /config` (`ssid`, `pass`). ESP cam łączy się z tym AP i odbiera konfigurację rozgłoszeniem UDP.
- Start: tekst `start` → cam zapamiętuje IP stacji i wysyła klatki
- Klatka: **75** datagramów po **1027** B (seq 2 B + chunk_id 1 B + 1024 B danych)
- Sterowanie: **1 bajt** = nibble pada; `led <liczba>`; stacja może wysłać `0xC0` + nibble (2 B)

## Narzędzia (`tools/`)

| Skrypt | Opis |
|--------|------|
| `generate_bitstream_basys <basys_cam\|basys_station>` | Synteza + implementacja Vivado → `*/results/*.bit` |
| `program_basys <moduł> [nazwa_płytki]` | Wgranie bitstreamu do RAM (JTAG) |
| `program_qspi_basys.sh <moduł> [nazwa_płytki]` | Trwały zapis do flash QSPI |
| `program_esp <main_*.cpp> <COM>` | Build + upload PlatformIO (jeden plik `main` na build) |
| `list_basys_devices` | Lista numerów JTAG |
| `board_config.sh` | Mapowanie `basys15` → serial |
| `cam_control.py` | UDP: `start` / `stop` / `led <maska>` |

Przykłady:

```bash
source env.sh
generate_bitstream_basys basys_cam
program_basys basys_cam basys15
program_esp main_cam.cpp COM10
python cam_control_gui/cam_control_gui.py
```

## Firmware ESP (PlatformIO)

- Środowisko: [`uec_projekt_esp32/platformio.ini`](uec_projekt_esp32/platformio.ini) — `esp32-c3-devkitm-1` dla kamery
- Cam: `main_cam.cpp` + `spi_slave.cpp`
- Station: `main_station.cpp`
- **Bez Dabble / BLE** — sterowanie przez UDP i pad GUI

## Znane ograniczenia

- Kierunki jazdy mogą wymagać **korekty kabli lub RTL** (mapowanie lewo/przód/tył w trakcie testów).
- Brak PWM na **ENA/ENB** w FPGA — prędkość silników stała (mostek L298N).
- Duże obciążenie Wi‑Fi + SPI — ESP cam i stacja powinny być blisko i na wspólnej sieci AP.

## Autorzy / kontekst

Projekt laboratoryjny UEC2 (AGH), rozszerzenia: most Wi‑Fi ESP32, sterowanie L298N, aplikacja `cam_control_gui`.

Bazowy szkielet FPGA/Vivado: materiały ćwiczeń (m.in. VGA, OV7670).

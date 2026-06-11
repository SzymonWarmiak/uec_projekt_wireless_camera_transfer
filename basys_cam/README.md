# basys_cam — Moduł Nadajnika i Sterowania Robota (FPGA)

Moduł `basys_cam` jest częścią projektu bezprzewodowej transmisji obrazu, działającą bezpośrednio na robocie (płytka **Basys 3**). Odpowiada za akwizycję obrazu z kamery OV7670, lokalny podgląd VGA, przesyłanie strumienia wideo przez SPI do modułu ESP32 oraz odbiór komend sterujących silnikami.

## Funkcje modułu
- **Akwizycja wideo**: Przechwytywanie klatek z kamery **OV7670** w rozdzielczości **640x480** (VGA), a następnie ich downsampling (2x) do rozdzielczości **320x240** (QVGA) w skali szarości (8 bitów na piksel).
- **Lokalny podgląd VGA**: Wyświetlanie obrazu na monitorze VGA podłączonym bezpośrednio do płytki nadajnika (rozdzielczość ekranu 1024x768).
- **Most SPI Master**: Wysyłanie danych klatki (76 800 bajtów) do ESP32 (MOSI) oraz jednoczesny odbiór 4-bitowego kodu sterującego (MISO) w celu kontroli jazdy.
- **Sterowanie napędem (L298N)**: Dekodowanie odebranych 4 bitów kierunku na sygnały wejściowe mostka H L298N (IN1..IN4) wyprowadzone na złącze **JXADC** (piny 7..10).

## Struktura plików
```text
├── fpga
│   ├── constraints
│   │   └── top_basys3.xdc      - Mapowanie pinów (JA: SPI, JB/JC: Kamera, JXADC: Silniki, VGA) + poprawki taktowania
│   ├── rtl
│   │   └── top_basys3.sv       - Główny plik nadrzędny FPGA (zarządzanie zegarami MMCM, safe_start i resetem)
│   └── scripts
│       └── project_details.tcl - Pliki projektu i moduły dla Vivado
├── rtl
│   ├── motor_l298n_decode.sv   - Dekodowanie 4-bitowych komend ruchu na sygnały mostka H
│   ├── ov7670_capture.sv       - Przechwytywanie obrazu z kamery, konwersja na grayscale i downsampling 2x
│   ├── ov7670_configurator.sv  - Konfiguracja rejestrów kamery przez interfejs SCCB (I2C)
│   ├── spi_stream_master.sv    - Kontroler SPI master (taktowanie SPI zsynchronizowane z zegarem systemowym)
│   ├── top.sv                  - Logika nadrzędna projektu (FSM przesyłania klatek i sterowania silnikami)
│   ├── top_vga.sv              - Integracja bufora ramki i kontrolera VGA
│   ├── vga_frame_renderer.sv   - Skalowanie i wyświetlanie obrazu z bufora na monitorze VGA
│   ├── vga_pkg.sv              - Stałe czasowe dla rozdzielczości VGA (XGA 1024x768)
│   ├── vga_timing.sv           - Generator sygnałów synchronizacji VGA (HS/VS)
│   └── video_framebuffer.sv    - Dwumiejscowy bufor ramki w pamięci blokowej (BRAM)
└── sim                         - Testbenche dla modułów timingowych i pomocniczych
```

## Połączenia sprzętowe (Piny Basys 3)

### 1. Kamera OV7670 ↔ Basys 3 (Złącza Pmod JB i JC)
* **Szyna danych (JB)**: JB1..JB4, JB7..JB10 → `ov7670_data[0..7]`
* **Sterowanie (JC)**:
  * JC1 (SCL) → `ov7670_sioc`
  * JC2 (SDA) → `ov7670_siod`
  * JC3 (VSYNC) → `ov7670_vsync`
  * JC4 (HREF) → `ov7670_href`
  * JC7 (PCLK) → `ov7670_pclk` (Zdefiniowany jako zegar nie-dedykowany w `.xdc`)
  * JC8 (XCLK) → `ov7670_xclk` (Sygnał zegara taktującego kamerę wygenerowany z FPGA - 25 MHz)

### 2. ESP32 ↔ Basys 3 (Złącze Pmod JA)
* JA1 → SPI CS (`spi_cs_n`)
* JA2 → SPI MOSI (`spi_mosi` - wysyłanie klatek wideo do ESP32)
* JA3 → SPI MISO (`spi_miso` - odbieranie komend z pada Wi-Fi)
* JA4 → SPI SCK (`spi_sck`)

### 3. Mostek L298N (Silniki) ↔ Basys 3 (Złącze JXADC)
* JXADC 7 → `motor_in[0]` (IN1)
* JXADC 8 → `motor_in[1]` (IN2)
* JXADC 9 → `motor_in[2]` (IN3)
* JXADC 10 → `motor_in[3]` (IN4)

## Budowanie i wgrywanie
Aby wygenerować bitstream i zaprogramować układ, wykonaj w terminalu (np. Git Bash) w głównym katalogu projektu:
```bash
source env.sh
generate_bitstream_basys basys_cam
program_basys basys_cam basys15
```
*(gdzie `basys15` to zdefiniowana nazwa seryjna Twojej płytki nadawczej w pliku `tools/board_config.sh`)*.

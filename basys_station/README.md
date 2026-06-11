# basys_station — Moduł Odbiornika i Wyświetlania VGA (FPGA)

Moduł `basys_station` stanowi stację odbiorczą w projekcie bezprzewodowej transmisji wideo. Działa na stacjonarnej płytce **Basys 3** i odpowiada za odbiór klatek obrazu z modułu ESP32 (odbiornika Wi-Fi) za pomocą interfejsu SPI, zapis do bufora ramki oraz wyświetlanie obrazu na monitorze za pomocą portu VGA.

## Funkcje modułu
- **Odbiór SPI Slave**: Pracuje jako interfejs SPI slave podłączony do ESP32. Dane wideo przychodzą strumieniowo i są zapisywane bezpośrednio do wewnętrznej pamięci.
- **Bufor Ramki (BRAM)**: Przechowywanie klatek wideo o rozdzielczości **320x240** (QVGA) w skali szarości (8 bitów na piksel, co odpowiada buforowi o rozmiarze 76 800 bajtów).
- **Wyświetlanie VGA**: Generator obrazu VGA w standardzie XGA (**1024x768 @ 60Hz** przy zegarze 65 MHz).
- **Skalowanie i centrowanie obrazu**: Renderowanie obrazu 320x240 na ekranie 1024x768 poprzez centrowanie i interpolację pikseli na obszarze wyświetlania o rozmiarze 512x682 (uwzględniając obrót obrazu kamery zamontowanej pionowo/bocznie na robocie).

## Struktura plików
```text
├── fpga
│   ├── constraints
│   │   └── top_basys3.xdc      - Mapowanie pinów (JA: SPI, VGA, przyciski i diody) + poprawki taktowania
│   ├── rtl
│   │   └── top_basys3.sv       - Plik nadrzędny FPGA (zarządzanie zegarami MMCM, safe_start, debounce przycisków)
│   └── scripts
│       └── project_details.tcl - Pliki projektu i moduły stacji dla Vivado
├── rtl
│   ├── debounce.sv             - Moduł filtracji drgań styków dla przycisków kierunkowych
│   ├── spi_stream_rx.sv        - Odbiornik SPI slave (obsługa odbioru pikseli oraz przesyłania przycisków w kanale zwrotnym MISO)
│   ├── top.sv                  - Logika nadrzędna stacji (zarządzanie adresowaniem zapisu klatek do bufora)
│   ├── top_vga.sv              - Integracja bufora ramki i kontrolera VGA
│   ├── vga_frame_renderer.sv   - Skalowanie, obrót i centrowanie obrazu z bufora na monitorze VGA
│   ├── vga_pkg.sv              - Parametry czasowe dla rozdzielczości VGA (XGA 1024x768)
│   ├── vga_timing.sv           - Generator sygnałów synchronizacji VGA (HS/VS)
│   └── video_framebuffer.sv    - Dwumiejscowy bufor ramki w pamięci blokowej (BRAM)
└── sim                         - Środowisko testowe dla symulacji odbioru SPI i VGA
```

## Połączenia sprzętowe (Piny Basys 3)

### 1. ESP32 ↔ Basys 3 (Złącze Pmod JA)
* JA1 → SPI CS (`spi_cs_n`)
* JA2 → SPI MOSI (`spi_mosi` - odbieranie strumienia wideo z ESP32)
* JA3 → SPI MISO (`spi_miso` - wysyłanie stanu przycisków sterujących z Basysa do ESP32)
* JA4 → SPI SCK (`spi_sck`)

### 2. Wyjście VGA ↔ Monitor
Standardowe złącze D-SUB (VGA) na płytce Basys 3:
* Sygnały kolorów: `vgaRed[0..3]`, `vgaGreen[0..3]`, `vgaBlue[0..3]`
* Synchronizacja: `Hsync` (HS), `Vsync` (VS)

### 3. Przyciski sterujące (Jazda robotem z płytki stacji)
Możesz sterować robotem bezpośrednio przyciskami kierunkowymi na stacji odbiorczej:
* **btnU** (Góra) -> Jazda do przodu
* **btnD** (Dół) -> Jazda do tyłu
* **btnL** (Lewo) -> Skręt w lewo
* **btnR** (Prawo) -> Skręt w prawo

## Budowanie i wgrywanie
Aby wygenerować bitstream i zaprogramować układ, wykonaj w terminalu w głównym katalogu projektu:
```bash
source env.sh
generate_bitstream_basys basys_station
program_basys basys_station basys16
```
*(gdzie `basys16` to zdefiniowana nazwa seryjna Twojej stacji odbiorczej w pliku `tools/board_config.sh`)*.

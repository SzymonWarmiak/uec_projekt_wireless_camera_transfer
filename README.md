# Bezprzewodowy System Transmisji Wideo i Sterowania (Basys 3 + ESP32)

<p align="center">
  <img src="robot_app/photos/jezdzik_title.png" alt="Jeździk Banner" width="600px" style="border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.2);"/>
</p>

Projekt akademicki realizowany w ramach przedmiotu **MTM UEC2** na **AGH**. Jest to rozproszony układ sprzętowo-programowy implementujący bezprzewodową transmisję obrazu z ruchomej platformy na stację bazową z interfejsem VGA. System wykorzystuje mikrokontrolery ESP32 jako most radiowy pracujący w architekturze UDP.

---

## 📸 Galeria Konstrukcji
Poniżej przedstawiono zdjęcia zmontowanego robota mobilnego ("Jeździka") z różnych perspektyw:

| Przód (Kamera OV7670 & sensory) | Tył (Napęd i zasilanie) |
|:---:|:---:|
| <img src="robot_app/photos/robot_przod.png" width="300px" style="border-radius: 6px;"/> | <img src="robot_app/photos/robot_tyl.png" width="300px" style="border-radius: 6px;"/> |
| **Profil Lewy** | **Profil Prawy** |
| <img src="robot_app/photos/robot_lewo.png" width="300px" style="border-radius: 6px;"/> | <img src="robot_app/photos/robot_prawo.png" width="300px" style="border-radius: 6px;"/> |
| **Lewy Przód** | **Prawy Przód** |
| <img src="robot_app/photos/robot_lewo_przod.png" width="300px" style="border-radius: 6px;"/> | <img src="robot_app/photos/robot_prawo_przod.png" width="300px" style="border-radius: 6px;"/> |
| **Lewy Tył** | **Prawy Tył** |
| <img src="robot_app/photos/robot_lewo_tyl.png" width="300px" style="border-radius: 6px;"/> | <img src="robot_app/photos/robot_prawo_tyl.png" width="300px" style="border-radius: 6px;"/> |

---

## 1. Architektura Systemu

System zbudowany jest z dwóch niezależnych platform deweloperskich Digilent Basys 3 połączonych radiowo z wykorzystaniem ESP32-C3 / ESP32, działających w topologii punkt-punkt (ESP-NOW / UDP).

```mermaid
flowchart RL
  subgraph Robot [NADAJNIK: Jeździk Mobilny]
    direction RL
    OV7670[Kamera OV7670] -->|Piksele| FPGA_C[Basys 3: basys_cam]
    FPGA_C -->|Sygnał wideo SPI 20 MHz| ESP_C[ESP32-C3]
    ESP_C -->|Kierunek SPI MISO| FPGA_C
    FPGA_C -->|PWM| L298N[Mostek L298N]
    L298N -->|Moc| Motors[Silniki DC 12V]
  end

  subgraph Radio [Interfejs Radiowy]
    direction RL
    ESP_C <-->|Pakiety UDP / ESP-NOW| ESP_S[ESP32 Stacja]
  end

  subgraph Station [ODBIORNIK: Stacja Bazowa]
    direction RL
    ESP_S -->|Sygnał wideo SPI 10 MHz| FPGA_S[Basys 3: basys_station]
    FPGA_S -->|Sygnał wideo VGA 65 MHz| VGA[Monitor 1024x768]
  end
```

### Specyfikacja podzespołów sprzętowych:
1. **Moduł Kamery (`basys_cam`)**: Pobiera dane wejściowe w rozdzielczości 640x480 (PCLK: 10 MHz). Logika FPGA wykonuje downsampling do rozmiaru 320x240 w 8-bitowej skali szarości. Integracja domen zegarowych (CDC) ze środowiska kamery do domeny systemowej (40 MHz) odbywa się asynchronicznie poprzez instancję Xilinx XPM FIFO. Gotowe dane przesyłane są magistralą SPI. 
2. **Most Radiowy (`uec_projekt_esp32`)**: Kod bazujący na FreeRTOS z obsługą DMA dla SPI. Implementuje sprzętowe kolejkowanie i dzieli strukturę wejściową klatek wideo na mniejsze pakiety protokołu UDP, przesyłając je drogą bezprzewodową, a w locie powrotnym odsyła komendy mechanizmu napędowego układu jezdnego.
3. **Moduł Stacji (`basys_station`)**: Działa jako SPI Master z taktowaniem magistrali 10 MHz. Odpytuje ESP32 stacji za pomocą sekwencji synchronizującej `0xCAFE`. Odczytane paczki wideo trafiają pod adresację bufora Dual-Port BRAM z oddzielnym zegarem odczytu `65 MHz`. Moduł synchronizacji obrazu realizuje w locie stałą rotację tekstury o 90 stopni i sprzętowe skalowanie x2.13 dopasowując sygnał pod standard XGA 1024x768 60 Hz.

---

## 2. Mapa Repozytorium

| Katalog | Opis zawartości |
|:---|:---|
| [`basys_cam/`](basys_cam/) | Kod źródłowy (RTL) modułu wysyłającego obraz i układu FSM SPI. |
| [`basys_station/`](basys_station/) | Kod źródłowy (RTL) modułu odbiorczego, BRAM, i syntezy VGA. |
| [`uec_projekt_esp32/`](uec_projekt_esp32/) | Oprogramowanie C++ mikrokontrolerów pod PlatformIO. |
| [`cam_control_gui/`](cam_control_gui/) | Oprogramowanie klienckie Python do kontroli ruchu PC. |
| [`doc/`](doc/) | Dokumentacja końcowa, raport, checklisty MTM. |
| [`tools/`](tools/) | Skrypty powłoki automatyzujące tworzenie i wgrywanie bitstreamu. |

---

## 3. Parametry Interfejsu Sprzętowego
Poniżej zestawienie głównych linii transmisyjnych interfejsu Pmod (Złącza JA).

### Magistrala SPI
| Basys 3 Pin | Rola sygnałowa | Konfiguracja I/O | Przepustowość |
|:---:|:---|:---:|:---:|
| **JA1** | Chip Select (CS_N) | Active Low | - |
| **JA2** | MOSI (Master Out) | Odtwarzanie wideo / Tx | - |
| **JA3** | MISO (Master In) | Dane wejściowe przycisków / Rx | - |
| **JA4** | Zegar SCK | Typ. 10 - 20 MHz | do ~25 FPS |
| **GND** | Wspólna Masa | Konieczne domknięcie obwodu! | - |

*(W celu uzyskania informacji dotyczących sterownika mocy DC L298N przypiętego pod złącze `JXADC`, zapoznaj się z odpowiednią sekcją dokumentacji układu [doc/raport_modulow.md](doc/raport_modulow.md).)*

---

## 4. Budowa i Kompilacja (Build System)

System wspiera pełną automatyzację przez zbiór skryptów `.sh` wywołujących Vivado w trybie CLI (TCL Batch Mode). W celu uruchomienia syntezy wejdź do katalogu głównego w środowisku Bash.

**Krok 1. Ładowanie środowiska**
Wymagane do dołączenia ścieżek globalnych i lokalnego katalogu `tools`:
```bash
source env.sh
```

**Krok 2. Synteza / Implementacja FPGA**
Generuje konfigurację bitstream:
```bash
./tools/generate_bitstream_basys.sh basys_cam
./tools/generate_bitstream_basys.sh basys_station
```

**Krok 3. Wgrywanie układu testowego**
Ładuje projekt bezpośrednio do pamięci ulotnej (RAM) FPGA. Jako drugi argument wymagane jest ID JTAG przypisane do danego programatora USB, skonfigurowane uprzednio w `tools/board_config.sh`:
```bash
./tools/program_basys.sh basys_cam basys15
./tools/program_basys.sh basys_station basys16
```

**Krok 4. Programowanie Trwałe QSPI Flash (Opcjonalnie)**
Pozwala na utrwalenie bitstreamu `.bin` do pamięci stałej płyty i samoczynny zapłon układów po ponownym uruchomieniu zasilania bez wsparcia PC:
```bash
./tools/program_qspi_basys.sh basys_cam basys15
./tools/program_qspi_basys.sh basys_station basys16
```

---

## 5. Parowanie Sieci Wi-Fi i Szybki Start

Proces łączenia środowiska, sprzęgnięcia modułów i odpalania aplikacji przebiega następująco:
1. Po włączeniu zasilania, układ mikrokontrolera generuje tymczasowy punkt dostępowy o SSID: **`Robot_jezdzik`** (Z widocznym hasłem autoryzującym).
2. Podłącz się komputerem (lub telefonem) pod wygenerowaną sieć `Robot_jezdzik`. Od tego momentu wszystko działa w zamkniętym ekosystemie AP.
3. Jeśli chcesz przepiąć robota do swojej sieci domowej/hotspota: z poziomu Aplikacji mobilnej wejdź w ustawienia (ikona 3 strzałek w prawym górnym rogu), wpisz nazwę swojej sieci docelowej (SSID) oraz hasło docelowe, pozostawiając pole IP bez zmian, i wyślij konfigurację do układów ESP32.
4. Oba procesory chwilę się restartują (zobaczysz proces na migających diodach). 
5. Odczytaj przyznane IP w panelu swojego hotspota/routera Windows. 
6. Wróć do okienka sieci w aplikacji, wbij nowe docelowe IP urządzenia, wciśnij akceptację - adres IP w pasku aplikacji odświeży się. Wszystko "załapie", zyskujesz pełną wideo-obsługę i sterowanie po nowej sieci z pominięciem własnego AP.

---

## 6. Sterowanie i Aplikacje Klienckie

Platforma obsługuje zdalne sterowanie dedykowanymi programami:
1. **Platforma Mobilna / Windows**: Skompilowane instalatory (pakiety `.apk` dla Android i `.zip` na platformę Windows) dostępne są w katalogu głównym `Jezdzik_do_pobrania/`. Z poziomu ekranu urządzenia sterujesz kierunkiem modułu L298N. Wideo ładuje się wbudowanym interfejsem.
2. **Gotowe skrypty Python**: W katalogu `cam_control_gui/cam_control_gui.py` znajduje się referencyjny program do kierowania z użyciem klawiszy WASD lub strzałek, łącząc po standardowym Socket UDP.


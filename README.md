# Bezprzewodowy System Transmisji Wideo

Projekt realizujacy bezprzewodowa transmisje obrazu wideo z kamery OV7670 do wyswietlacza VGA. System wykorzystuje uklady FPGA Basys 3 do przetwarzania i buforowania obrazu oraz mikrokontrolery ESP32 jako szybki most Wi-Fi komunikujacy sie za pomoca protokolu UDP.

## Architektura Systemu

1. Nadajnik (basys_cam): Odbiera strumien z kamery OV7670, buforuje ramke w pamieci BRAM i przesyla ja przez interfejs SPI do mikrokontrolera nadajacego.
2. Most Wi-Fi (ESP32 strona kamery, main_cam.cpp): Dziala w trybie Access Point. Odbiera klatki przez interfejs SPI (DMA) i przesyla je bezprzewodowo pakietami UDP do odbiornika.
3. Most Wi-Fi (ESP32 strona stacji, main_station.cpp): Dziala w trybie Station. Laczy sie z siecia nadajnika, odbiera pakiety UDP, odbudowuje strukture klatki i udostepnia ja przez interfejs SPI.
4. Odbiornik (basys_station): Pobiera strumien pikseli przez SPI, realizuje podwojne buforowanie w pamieci BRAM i generuje odpowiednie sygnaly synchronizujace dla interfejsu VGA.

## Struktura Katalogow

* /basys_cam         - Projekt Vivado/SystemVerilog dla nadajnika (obsluga kamery OV7670, SPI Master, lokalny preview VGA do debugowania).
* /basys_station     - Projekt Vivado/SystemVerilog dla odbiornika (odbiornik SPI, podwojne buforowanie, kontroler VGA).
* /uec_projekt_esp32 - Projekt PlatformIO zawierajacy kody zrodlowe w jezyku C++ dla obu mikrokontrolerow ESP32 (main_cam.cpp, main_station.cpp).
* /tools             - Zestaw autorskich skryptow powloki automatyzujacych proces kompilacji i programowania urzadzen.

## Obsluga Skryptow Narzedziowych (Tools)

Wszystkie skrypty automatyzujace nalezy uruchamiac z poziomu glownego katalogu projektu, korzystajac z terminala obslugujacego powloke Bash (np. Git Bash). Przed rozpoczeciem pracy nalezy upewnic sie, ze srodowisko Vivado jest dostepne w `PATH`.

### 1. Generowanie bitstreamu (generate_bitstream_basys.sh)

Skrypt opakowuje wewnetrzny `./tools/generate_bitstream.sh` modulu Basysa tak, by mozna bylo go uruchomic z glownego katalogu projektu bez recznego `cd` i `source env.sh`. Sam wchodzi do wskazanego folderu, inicjalizuje srodowisko (`env.sh`) i odpala syntezy + implementacji w Vivado, a wynik trafia do `<folder>/results/`.

Sposob uzycia:
./tools/generate_bitstream_basys.sh <katalog_modulu>

Przyklady:
./tools/generate_bitstream_basys.sh basys_cam
./tools/generate_bitstream_basys.sh basys_station

### 2. Wgrywanie bitstreamu do RAM FPGA (program_basys.sh)

Skrypt automatycznie weryfikuje obecnosc wygenerowanego pliku bitstream w odpowiednim podkatalogu. W przypadku jego braku, samodzielnie uruchamia proces syntezy i implementacji w Vivado. Gotowy wsad wgrywany jest na wlasciwa plytke na podstawie zdefiniowanej nazwy. Po wylaczeniu zasilania bitstream znika z FPGA - jezeli chcesz go zapisac na stale, uzyj `program_qspi_basys.sh`.

Sposob uzycia:
./tools/program_basys.sh <katalog_modulu> [NAZWA_PLYTKI]

Przyklady:
./tools/program_basys.sh basys_cam basys15
./tools/program_basys.sh basys_station basys16

Nazwy plytek zdefiniowane w pliku board_config.sh.

### 3. Trwale zaprogramowanie pamieci QSPI (program_qspi_basys.sh)

Skrypt programuje pamiec QSPI Flash plytki Basys 3 (Spansion S25FL032P) tak, aby bitstream pozostal w urzadzeniu po wylaczeniu zasilania. Tworzy plik `.mcs` z bitstreamu (do `<folder>/results/`), po czym kasuje, zapisuje i weryfikuje flash przez Vivado. Po zakonczeniu plytke trzeba zresetowac (`PROG` na plytce lub przelacznik zasilania), zeby FPGA zaladowala wsad z flasha.

Sposob uzycia:
./tools/program_qspi_basys.sh <katalog_modulu> [NAZWA_PLYTKI]

Przyklady:
./tools/program_qspi_basys.sh basys_cam basys15
./tools/program_qspi_basys.sh basys_station basys16

### 4. Wgrywanie kodu na ESP32 (program_esp.sh)

Skrypt zastepuje koniecznosc recznego modyfikowania pliku konfiguracyjnego PlatformIO. Kompiluje i wgrywa wskazany plik zrodlowy C++ na mikrokontroler podlaczony pod podany port szeregowy.

Sposob uzycia:
./tools/program_esp.sh <nazwa_pliku.cpp> <PORT_COM>

Przyklady:
./tools/program_esp.sh main_cam.cpp COM12
./tools/program_esp.sh main_station.cpp COM14

### 5. Identyfikacja urzadzen FPGA (list_basys_devices.sh)

Skrypt komunikuje sie z serwerem sprzetowym Vivado i zwraca czysta liste numerow seryjnych JTAG dla wszystkich aktualnie podlaczonych urzadzen.

Sposob uzycia:
./tools/list_basys_devices.sh

### 6. Konfiguracja sprzetu (board_config.sh)

Plik przechowujacy mapowanie latwych do zapamietania nazw plytek (np. numery inwentarzowe / z naklejek) na fizyczne identyfikatory JTAG. Nalezy go zaktualizowac po wykryciu urzadzen skryptem `list_basys_devices.sh`, aby umozliwic bezkolizyjne programowanie wielu ukladow jednoczesnie.

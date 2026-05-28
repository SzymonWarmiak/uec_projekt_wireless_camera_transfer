# Bezprzewodowy System Transmisji Wideo

Projekt realizujacy bezprzewodowa transmisje obrazu wideo z kamery OV7670 do wyswietlacza VGA. System wykorzystuje uklady FPGA Basys 3 do przetwarzania i buforowania obrazu oraz mikrokontrolery ESP32 jako szybki most Wi-Fi komunikujacy sie za pomoca protokolu UDP.

## Architektura Systemu

1. Nadajnik (Basys 1): Odbiera strumien z kamery OV7670, buforuje ramke w pamieci BRAM i przesyla ja przez interfejs SPI do mikrokontrolera nadajacego.
2. Most Wi-Fi (ESP32 Nadajnik): Dziala w trybie Access Point. Odbiera klatki przez interfejs SPI (DMA) i przesyla je bezprzewodowo pakietami UDP do odbiornika.
3. Most Wi-Fi (ESP32 Odbiornik): Dziala w trybie Station. Laczy sie z siecia nadajnika, odbiera pakiety UDP, odbudowuje strukture klatki i udostepnia ja przez interfejs SPI.
4. Odbiornik (Basys 2): Pobiera strumien pikseli przez SPI, realizuje podwojne buforowanie w pamieci BRAM i generuje odpowiednie sygnaly synchronizujace dla interfejsu VGA.

## Struktura Katalogow

* /basys_cam         - Projekt Vivado/SystemVerilog dla nadajnika (obsluga kamery OV7670, SPI Master).
* /basys_station     - Projekt Vivado/SystemVerilog dla odbiornika (odbiornik SPI, podwojne buforowanie, kontroler VGA).
* /uec_projekt_esp32 - Projekt PlatformIO zawierajacy kody zrodlowe w jezyku C++ dla obu mikrokontrolerow ESP32.
* /tools             - Zestaw autorskich skryptow powloki automatyzujacych proces kompilacji i programowania urzadzen.

## Obsluga Skryptow Narzedziowych (Tools)

Wszystkie skrypty automatyzujace nalezy uruchamiac z poziomu glownego katalogu projektu, korzystajac z terminala obslugujacego powloke Bash (np. Git Bash). Przed rozpoczeciem pracy nalezy upewnic sie, ze srodowisko Vivado jest zaladowane (. env.sh).

### 1. Wgrywanie kodu na FPGA (program_basys.sh)

Skrypt automatycznie weryfikuje obecnosc wygenerowanego pliku bitstream w odpowiednim podkatalogu. W przypadku jego braku, samodzielnie uruchamia proces syntezy i implementacji w Vivado. Gotowy wsad wgrywany jest na wlasciwa plytke na podstawie zdefiniowanej nazwy. W razie problemow nalezy recznie wygenerowac bitstream przechodzac do konkretnego folderu docelowego.

Sposob uzycia:
./tools/program_basys.sh <katalog_modulu> [NAZWA_PLYTKI]

Przyklady:
./tools/program_basys.sh basys_cam basys15
./tools/program_basys.sh basys_station basys16

Nazwy plytek zdefiniowane w pliku board_config.sh.

### 2. Wgrywanie kodu na ESP32 (program_esp.sh)

Skrypt zastepuje koniecznosc recznego modyfikowania pliku konfiguracyjnego PlatformIO. Kompiluje i wgrywa wskazany plik zrodlowy C++ na mikrokontroler podlaczony pod podany port szeregowy.

Sposob uzycia:
./tools/program_esp.sh <esp_cam|esp_station> <PORT_COM>

Przyklady:
./tools/program_esp.sh esp_cam COM12
./tools/program_esp.sh esp_station COM14

### 3. Identyfikacja urzadzen FPGA (list_basys_devices.sh)

Skrypt komunikuje sie z serwerem sprzetowym Vivado i zwraca czysta liste numerow seryjnych JTAG dla wszystkich aktualnie podlaczonych urzadzen.

Sposob uzycia:
./tools/list_basys_devices.sh

### 4. Konfiguracja sprzetu (board_config.sh)

Plik przechowujacy mapowanie latwych do zapamietania nazw plytek (np. numery inwentarzowe / z naklejek) na fizyczne identyfikatory JTAG. Nalezy go zaktualizowac po wykryciu urzadzen skryptem `list_basys_devices.sh`, aby umozliwic bezkolizyjne programowanie wielu ukladow jednoczesnie.

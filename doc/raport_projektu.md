# RAPORT Z PROJEKTU: Bezprzewodowy System Transmisji Wideo

**Przedmiot:** Układy Elektroniki Cyfrowej 2 (UEC2)  
**Kierunek:** MTM, AGH University of Science and Technology  
**Autorzy:** Szymon Warmiak, Grzegorz Twardosz  
**Data:** Czerwiec 2026

---

## 1. Cel i koncepcja projektu
Celem projektu było zaprojektowanie, zaimplementowanie i przetestowanie zaawansowanego sprzętowo-programowego systemu transmisji wideo zrealizowanego w oparciu o dwie oddzielne platformy uruchomieniowe Basys3 (Multiplayer/Multi-board). Projekt pozwala na asynchroniczne odczytywanie klatek z matrycy OV7670 na jednej płytce (układ Kamery), transmisję pełnego obrazu po magistrali SPI w kierunku procesora ESP32 pracującego jako most radiowy Wi-Fi (UDP/ESP-NOW), a następnie odbiór sygnału, jego buforowanie i sprzętowe wyrenderowanie na monitorze podłączonym złączem VGA do drugiej płytki docelowej (układ Stacji Bazowej). Dodatkowo zaimplementowano interfejs użytkownika w postaci przycisków kierunkowych stacji bazowej sterujących zdalnie układem napędowym po stronie kamery (w układzie Full-Duplex).

---

## 2. Spełnienie Wymagań Projektowych
Projekt w pełni spełnia założenia specyfikacji wytycznej:
1. **Dwie Płytki Basys 3:** Zaimplementowano osobne logiki sprzętowe (`basys_cam` i `basys_station`).
2. **Interfejs Użytkownika:** Wciskane przyciski na pierwszej płytce (stacji) formują się w paczki danych transmitowanych falami radiowymi na drugą płytkę, napędzając dedykowany moduł sterownika silników (`motor_l298n_decode`).
3. **Ekran VGA 1024x768:** Płytka odbiorcza z sukcesem generuje interfejs wyświetlacza standardu XGA (65 MHz) i maluje zbuforowaną macierz na żywo, implementując unikalne 90-stopniowe obrócenie klatki i sprzętowe skalowanie (×2.13).
4. **Style Kodowania i Architektura (SystemVerilog):** System w pełni zaimplementowany jako FSM z rygorystycznym korzystaniem z poprawnych mechanizmów izolacji przekraczania domen zegarowych `CDC` przy użyciu wzorcowych bibliotek `Xilinx XPM`.
5. **Reset Asynchroniczny:** Moduły pamięciowe kasowane są asynchronicznie reagując na negację zbocza centralnego przycisku `BTNC`.

---

## 3. Architektura Systemu i Główne Moduły

### 3.1 Zegary i Zasilanie
- **Zegary Główne:** Wewnętrzne generatory PLL Vivado (moduł `MMCME2_BASE`) zasilane pokładowym rezonatorem 100MHz produkują czyste fali 65 MHz (domena renderingu VGA) oraz 40 MHz (domena zarządzania rdzeniem SPI i buforów logicznych).
- W układzie działa dedykowany mechanizm obwodu typu `Safe Start`, zamykający kluczowe bufory `BUFGCE` aż do momentu pełnego zapięcia się pętli fazowej oscylatora (PLL LOCK) aby uniknąć metastabilności po resecie.

### 3.2 Tor Transmisji Obrazu (Basys_Cam -> Basys_Station)
Zastosowano format strumieniowy stylizowany na standard sprzętowy **AXI-Stream** (porty `tdata`, `tvalid`, `tlast`, `tuser`), co gwarantuje łatwość kaskadowego powielania sygnału.
1. `ov7670_capture.sv` obiera z sensora obraz po własnym zegarze `pclk`, poddaje ekstrakcji na pasmo odcieni szarości i wrzuca do asynchronicznej buforowanej pamięci z niezależnymi zegarami `xpm_fifo_axis`.
2. Zbuforowane piksele porywa pełnodupleksowy moduł `spi_stream_master.sv` operujący na zegarze 20 MHz wpuszczający zrzut przez styki zewnętrzne (MISO/MOSI).
3. Ramki zbiera w powietrzu mikrokontroler z serii **ESP32** oprogramowany w C++ korzystający z wielozadaniowego mechanizmu sprzętowego `FreeRTOS` do bezstratnego pchania pakietów protokołem ESP-NOW.
4. Układ stacji bazowej odbierając pakiety nieustannie stymuluje swój własny port `spi_stream_rx.sv` wysyłając sygnały identyfikacyjne zapytania `0xCAFE`. Odpowiedź trafia z pominięciem procesorów bezpośrednio do układowej, 2-portowej szybkiej macierzy Block RAM na układzie FPGA (`video_framebuffer.sv`).
5. Przebudowana jednostka dekodująca z opóźnieniem o dwa takty zegara (`vga_frame_renderer.sv`) wyciąga zawartość by obrócić matrycę wymiarową obrazu matematycznie do formatu portretowego wyświetlanego z odświeżaniem na 1024x768 / 60 Hz.

---

## 4. Analiza Implementacji
* Projekt cechuje **0 błędów** i **0 ostrzeżeń krytycznych** zgłoszonych w środowisku Vivado 2024.2. Występujące zwykłe, spodziewane komunikaty "warnings" wynikają z celowego zostawienia portów w standardach XPM Xilinxa i w architekturze modułu rendera pod planowaną obudowę na przyszłe usprawnienia gry w tym wirtualne wskaźniki (HUD).
* Wszelkie zasoby fizyczne tablic układu Artix-7 (LUT, BRAM, DSP) zostały skrupulatnie rozplanowane pod unikanie latencji z zachowaniem dużej marży przestrzeni dla dwukanałowej pamięci `Double Buffering`. Analiza Timingu zgłasza brak zderzeń czasowych ułożenia zegarów (CLEAR).

## 5. Użytkowanie kontroli wersji
Całkowity cykl życia projektu operowany za pomocą zwinnego sytemu kontroli rewizji GIT, zabezpieczającego poprawność pliku `.gitignore` pomijającego tysiące nadmiarowych logów systemowych oraz z wykorzystaniem pre-konfigurowalnych skryptów wdrożeniowych (`generate_bitstream.sh`, `program_basys.sh`), całkowicie automatyzujących wdrożenie oprogramowania. Zadbano również o zapis trwałej powłoki bitowej (format `.bin`/`.mcs`) dla pokładowej szyny QSPI FLASH obydwu obwodów płytkowych.

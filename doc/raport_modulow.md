# Podsumowanie Modułów Projektowych

Niniejszy dokument stanowi zwięzłe podsumowanie struktury i działania modułów w projekcie bezprzewodowej transmisji wideo, przygotowane na potrzeby raportu końcowego. Wszystkie moduły sekwencyjne wykorzystują asynchroniczny reset (`rst_n`), wymuszony wciskaniem fizycznego przycisku `btnC` na płytce Basys3, a same logiki bazują na zestawie dobrych wzorców takich jak maszyny stanów FSM oraz potoki (pipelines) i sygnały protokołu zbliżonego do AXI-Stream.

## 1. Kamera (Basys_Cam)

### 1.1 `top_basys3.sv`
* **Rola:** Główny plik sprzętowy (wrapper). Konfiguruje PLL (MMCME2_BASE) do wygenerowania głównych domen zegarowych `40 MHz` (system/SPI) oraz `65 MHz` (VGA) z wejściowego sygnału 100 MHz. Bezpiecznie włącza sygnały zegarowe (`safe_start`) do wnętrza po ustabilizowaniu pętli PLL.
* **Resety/Zegary:** Wymusza reset asynchroniczny dla modułu podrzędnego z fizycznego przycisku.
* **Z czym się łączy:** Bezpośrednie porty XDC -> wejście `top.sv`.

### 1.2 `top.sv`
* **Rola:** Serce logiki płytki kamery. Instancjuje poszczególne pakiety, synchronizuje pobieranie strumienia obrazu, zapis do wewnętrznej pamięci VGA oraz przesyła dane z kolejki do szyny SPI. Oparty na 3-stanowej maszynie FSM (`WAIT_FRAME`, `SEND_PIXELS`, `SEND_CTRL`). 
* **Z czym się łączy:** Obsługuje `ov7670_capture`, `xpm_fifo_axis` do przekraczania domen zegarowych (CDC), oraz `spi_stream_master`.

### 1.3 `ov7670_capture.sv`
* **Rola:** Obniża rozdzielczość i wyłuskuje piksele (reagując na `vsync` i `href` z samej fizycznej kamery). Na bieżąco wyciąga przybliżoną jasność szarości (luminancję) wykorzystując piny odpowiedzialne za kolor zielony w formacie RGB565.
* **Resety/Zegary:** Cała logika działa na zegarze dostarczonym od kamery (`pclk` 10 MHz), asynchroniczny reset.

### 1.4 `ov7670_configurator.sv`
* **Rola:** Inicjalizuje rejestry matrycy OV7670 przy starcie poprzez protokół I²C/SCCB, ustawiając odświeżanie, ekspozycję i format piksela.
* **Resety/Zegary:** Używa dzielonego zegara ok. `10 MHz`, asynchroniczny reset na start.

### 1.5 `spi_stream_master.sv`
* **Rola:** Moduł SPI Full-Duplex. Przesyła 8-bitowe ramki do modułu ESP32 i w tym samym czasie odbiera odpowiedzi z bufora ESP32, co pozwala na jednoczesny przesył obrazu w przód i zaciąganie komend sterujących jazdą w tył.
* **Z czym się łączy:** ESP32 (MOSI, MISO, SCK, CS_N).
* **Resety/Zegary:** 40 MHz zegar systemowy. Dzielnik na SPI `20 MHz`. Async reset.

### 1.6 `motor_l298n_decode.sv`
* **Rola:** Dekoduje 4-bitowe komendy sterujące odebrane magistralą ze stacji na poprawne wysterowanie mostka H w module DC L298N (np. jazda w przód, obrót). Logika całkowicie kombinacyjna (nie wymaga resetów).

---

## 2. Stacja Bazowa (Basys_Station)

### 2.1 `top_basys3.sv` i `top.sv`
* **Rola:** Analogicznie jak w systemie kamery - dostarczają domen zegarowych 40 MHz i 65 MHz, ale ich serce (`top.sv`) pełni nieco odwrotną funkcję. Zamiast nadawać z modułów układu, nieprzerwanie pytają po SPI własne ESP32 o nowe piksele z powietrza, a przyciski odbite podsyłają jako flagi do sterowania robotem.
* **Resety:** Asynchroniczny z przycisku.

### 2.2 `spi_stream_rx.sv`
* **Rola:** Wyjątkowy układ nadrzędny SPI, który jest w ciągłym stanie odpytywania. FSM ładuje "magic number" `0xCAFE` i 16-bitowe wciśnięte klawisze joysticka w kierunku kontrolera ESP32, natychmiastowo nasłuchując napływu aż do 76800 bajtów kolejnej klatki.
* **Resety/Zegary:** Zegar systemowy 40 MHz. Zegar SPI 10 MHz. Async reset.

### 2.3 `debounce.sv`
* **Rola:** Standardowy filtr drgań styków dla fizycznych przycisków przed wpakowaniem ich na interfejs SPI. Opóźnienie na liczniku n-bitowym eliminuje metastabilność. Async reset.

---

## 3. Współdzielone Moduły Wyświetlania VGA (Wspólne)
Obie płytki używają poniższych modułów w identyczny sposób by umożliwić niezależny podgląd z kamer.

* **`top_vga.sv`** - Wrapper łączący rurę logiki ze sobą.
* **`video_framebuffer.sv`** - Pamięć Dual-Port BRAM pozwalająca na niezależny bezpieczny zapis pikseli przez SPI przy prędkości 40MHz, z niezależnym wyciąganiem ich i malowaniem na ekran monitora zegarem 65MHz. Podatne na rozbudowę o mechanikę double-buffering. Async reset portu czytania.
* **`vga_timing.sv`** - Kręgosłup wyświetlacza. Moduł generuje impulsy pionowe i poziome (H-Sync i V-Sync) specjalnie uszyte dla rozdzielczości standardu 1024x768 / 60Hz. Async reset.
* **`vga_frame_renderer.sv`** - Moduł operacji na teksturze. Zamienia pojedyncze rzędy pobrane z banku pamięci i przesuwa na sztywno ich adresację o 90 stopni żeby ustawić obraz w orientacji portretowej oraz skaluje tak, by naturalnie dopasować do ram monitora zachowując proporcje matrycy.

---

## 4. Mikroprocesory ESP32 (C++)

### 4.1 `main_cam.cpp` (Transmiter Radiowy)
* **Rola:** Mikroprocesor służy tu jako gigantyczna szyna radiowa sprzężona ze sprzętowym buforem DMA SPI ESP32. Skrypt zajmuje się wycinaniem mniejszych, zgodnych ze standardem pakietów po ok 1024 bity i wypluwaniem po WiFi / ESP-NOW. Przepycha też aktualne polecenia napędu odebrane od stacji z powrotem pod lufę układu FPGA po SPI.
* **Sygnały:** Przerwania hardware'owe, SPI Rx/Tx, Event Loop FreeRTOS'a.

### 4.2 `main_station.cpp` (Odbiornik Radiowy)
* **Rola:** Stacja bazowa ESP czuwa na stałym nasłuchu na otwartej sieci UDP na wybranym porcie (lub w sieci ad-hoc ESP-NOW). Odebrane ramki zlepia i synchronizuje numerami w wielkim wirtualnym ramie w układzie. Gdy na piny uderzy rozkaz "pytający" po SPI (`0xCAFE`), DMA zrzuca zebrany ram do fizycznego przewodu SPI prosto w szpony bufora VGA na płytce Basys.

### 4.3 `spi_slave.cpp` (Konfigurator API ESP-IDF)
* **Rola:** Narzędzie operacyjne pomagające podmieniać w locie bufory i re-inicjalizować ukryte głęboko transakcje szyny sprzętowej (korzysta z potężnych struktur C z driverów firmy Espressif dla wyciskania cykli poza rdzeniem CPU).

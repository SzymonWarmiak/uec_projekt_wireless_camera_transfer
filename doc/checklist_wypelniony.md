Tytuł: Bezprzewodowy System Transmisji Wideo (Kamera OV7670 + ESP32)
Autorzy: Szymon Warmiak (SW), [Imię Kolegi] ([Inicjały])
Ostatnia modyfikacja: 10.06.2026

| Pytanie | Oczekiwana odpowiedź | Twoja odpowiedź |
| :--- | :--- | :--- |
| Czy raport został załączony w formacie PDF? ( TAK / NIE ) | TAK | **TAK** |
| Czy w katalogu results został umieszczony bitstream? ( TAK / NIE ) | TAK | **TAK** |
| Czy rozmieszczenie plików w katalogach projektu jest zgodne ze specyfikacją? ( TAK / NIE ) | TAK | **TAK** |
| Czy sprawdzona została poprawność załadowanego repozytorium projektu poprzez sklonowanie go w nowym katalogu, uruchomienie symulacji i wygenerowanie bitstream'u? ( TAK / NIE ) | TAK | **TAK** |
| Numer użytej wersji Vivado | | **2024.2** |
| Liczba błędów (error) zgłoszonych przez Vivado | 0 (!) | **0** |
| Liczba ostrzeżeń krytycznych (critical warning) zgłoszona przez Vivado | 0 (!) | **0** |
| Liczba ostrzeżeń zwykłych (warning) zgłoszona przez Vivado | | **127 (Stacja) / 149 (Kamera)** |
| Interfejs dostarczania danych przez użytkownika ( klawiatura / mysz / ... ) | | **Przyciski płytki Basys3 (Klawiatura kierunkowa sterująca robotem)** |
| Użycie ekranu jako wyjścia ( TAK / NIE ) | TAK | **TAK** |
| Rozdzielczość ekranu ( X px / Y px ) | | **1024 px / 768 px** |
| Czy układ używa resetu asynchronicznego? ( TAK / NIE ) | TAK | **TAK** |
| Identyfikator przycisku na płytce Basys3 użytego jako reset (BTND / BTNC /... ) | | **BTNC** |
| Czy moduły używają wyłącznie sygnałów zegarowych generowanych przez bloki generatorów zegara (IP Vivado) ? ( TAK / NIE ) | | **TAK\*** |

*\*Projekt korzysta z wewnętrznego bloku IP Vivado (PLL - MMCME2_BASE) do wygenerowania głównych zegarów systemu (40 MHz) i ekranu VGA (65 MHz). Zewnętrzny zegar matrycy kamery (PCLK) wprowadzany bezpośrednio z pinów urządzenia jest prawidłowo i bezpiecznie integrowany do głównej domeny za pomocą asynchronicznego bufora IP Vivado CDC (XPM FIFO).*

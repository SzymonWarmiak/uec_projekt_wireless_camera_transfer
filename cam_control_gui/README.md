# Cam Control GUI

Aplikacja na PC (Python + `tkinter`) do sterowania Jeździkiem przez UDP. Działa tak samo jak aplikacja Flutter: wysyła kierunki jazdy do `ESP_station`, pozwala wpisać nowe Wi-Fi i zrobić reset do sieci `Robot_jezdzik`.

## Wymagania

- Python 3.8+
- PC w tej samej sieci Wi-Fi co ESP
- Wgrane firmware ESP z obsługą `Robot_jezdzik`, `CFG` i `RESET_SETUP`

## Uruchomienie

Z katalogu głównego repozytorium:

```bash
python cam_control_gui/cam_control_gui.py
```

Windows:

```powershell
py cam_control_gui\cam_control_gui.py
```

Możesz też uruchomić:

```powershell
cam_control_gui\run_cam_control.bat
```

## Sterowanie

| UI / klawisz | Maska | Efekt |
|--------------|-------|-------|
| ▲ / `W` / `↑` / `1` | `0001` | Przód |
| ▼ / `S` / `↓` / `2` | `0010` | Tył |
| ◄ / `A` / `←` / `4` | `0100` | Lewo |
| ► / `D` / `→` / `8` | `1000` | Prawo |
| ● / spacja | `0000` | Stop |

Przytrzymanie przycisku oznacza jazdę, puszczenie wysyła stop.

## Wi-Fi

Domyślnie wpisane jest:

- IP ESP_station: `192.168.4.1`
- port: `1234`

To jest adres ESP_station w sieci `Robot_jezdzik`.

Żeby przełączyć ESP na inną sieć:

1. Połącz komputer z aktualną siecią ESP.
2. Wpisz aktualne IP `ESP_station`.
3. Wpisz nazwę Wi-Fi i hasło.
4. Kliknij `Zapisz Wi-Fi w ESP`.
5. Po przełączeniu wpisz nowe IP `ESP_station` w polu u góry.

Przycisk `Reset do Robot_jezdzik` wysyła komendę `RESET_SETUP` i ustawia w aplikacji IP `192.168.4.1`.

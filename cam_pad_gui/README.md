# Cam Pad GUI

Aplikacja na PC (Python + **tkinter**, bez dodatkowych pakietów) — imitacja pada sterująca jazdą przez **Wi‑Fi → ESP cam → SPI MISO → FPGA → L298N**.

## Wymagania

- Python 3.8+
- PC w tej samej sieci Wi-Fi co ESP cam
- Wgrane: `main_cam.cpp` na ESP przy kamerze + bitstream `basys_cam` z `motor_l298n_decode.v`

## Uruchomienie

Z katalogu głównego repozytorium:

```bash
python cam_pad_gui/pad_gui.py
```

Windows:

```powershell
py cam_pad_gui\pad_gui.py
```

Lub: `cam_pad_gui/run_pad.bat`

## Sterowanie

| UI / klawisz | Efekt (po dekodowaniu w FPGA) |
|--------------|-------------------------------|
| ▲ / ↑ / `1` | **Przód** — oba silniki do przodu |
| ▼ / ↓ / `4` | **Tył** |
| ◄ / ← / `8` | **Lewo** — skręt (różnicowy) |
| ► / → / `2` | **Prawo** |
| Spacja / „Stop IN” | **Stop** |
| Start / Stop wideo | UDP `start` / `stop` |

**Przytrzymaj** kierunek = jazda; **puszczasz** = stop (wysyłany nibble `0`).

Host ustaw na adres IP ESP cam w skonfigurowanej sieci Wi-Fi, port **1234**.

## Co wysyła aplikacja

Jeden bajt UDP: bity `0x01` góra, `0x02` prawo, `0x04` dół, `0x08` lewo. FPGA zamienia to na sygnały **IN1–IN4** (patrz główny README i `basys_cam/docs/MOTOR_L298N.md`).

# Cam Pad GUI

Aplikacja na PC (Python + **tkinter**, bez dodatkowych pakietów) — imitacja pada sterująca jazdą przez **Wi‑Fi → ESP cam → UART → FPGA → L298N**.

## Wymagania

- Python 3.8+
- PC w sieci **`ESP_VIDEO_TX`** / hasło **`video_stream`**
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

Domyślnie: host **192.168.4.1**, port **1234** (pola w oknie).

## Co wysyła aplikacja

Jeden bajt UDP: bity `0x01` góra, `0x02` prawo, `0x04` dół, `0x08` lewo. FPGA zamienia to na sygnały **IN1–IN4** (patrz główny README i `basys_cam/docs/MOTOR_L298N.md`).

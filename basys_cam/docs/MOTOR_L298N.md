# L298N — złącze **JXADC** (piny 7–10)

Mapowanie wg [Basys 3 Reference Manual](https://digilent.com/reference/programmable-logic/basys-3/reference-manual) (tabela Pmod).

## Złącze JXADC (widok standardowego Pmod 2×6)

```
  [1] XA1_P (J3)  UART RX z ESP     [2] XA2_P (L3)
  [3] XA3_P (M2)                    [4] XA4_P (N2)
  [7] XA1_N (K3)  IN1              [8] XA2_N (M3)  IN2
  [9] XA3_N (M1)  IN3             [10] XA4_N (N1)  IN4
```

| JXADC pin | Sygnał FPGA | `motor_in` | Bit pada | L298N |
|-----------|-------------|------------|----------|-------|
| **1** | XA1_P (J3) | — | — | UART z ESP (nie L298N) |
| **7** | XA1_N (K3) | `[0]` | — | **IN1** (silnik 1) |
| **8** | XA2_N (M3) | `[1]` | — | **IN2** (silnik 1) |
| **9** | XA3_N (M1) | `[2]` | — | **IN3** (silnik 2) |
| **10** | XA4_N (N1) | `[3]` | — | **IN4** (silnik 2) |

## Pada → jazda (jak Arduino L298N)

UART wysyła **nibble kierunku** (nie bezpośrednio IN1..IN4). FPGA (`motor_l298n_decode.v`) mapuje:

| Pada | IN1 | IN2 | IN3 | IN4 | Efekt |
|------|-----|-----|-----|-----|--------|
| ▲ przód | H | L | H | L | oba silniki do przodu |
| ▼ tył | L | H | L | H | oba do tyłu |
| ◄ lewo | L | H | H | L | skręt w lewo (różnicowy) |
| ► prawo | H | L | L | H | skręt w prawo |
| puszczony / sprzeczne | L | L | L | L | stop |

**ENA/ENB** (PWM prędkości) — podłącz na module L298N do +5 V lub osobnego PWM; w FPGA nie ma jeszcze PWM.

Piny **2–6** (XA2_P … XA2_N) są wolne w tym projekcie.

## Okablowanie

- Przewody **IN1…IN4** → **JXADC 7, 8, 9, 10** (dolny rząd na kablu Pmod).
- **GND** L298N ↔ **GND** Basys (obowiązkowo).
- Zasilanie silników osobno; **ENA/ENB** na module L298N podłącz według dokumentacji modułu.

## Po zmianie constrainów

```bash
./tools/generate_bitstream_basys.sh basys_cam
./tools/program_basys.sh basys_cam basys15
```

Sterowanie: `python cam_pad_gui/pad_gui.py` (bez zmiany ESP).

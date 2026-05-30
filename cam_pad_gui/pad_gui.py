#!/usr/bin/env python3
"""
Prosty „pad” na PC → UDP → ESP → UART → L298N (2 silniki, JXADC 7–10).

Wi-Fi: ESP_VIDEO_TX / video_stream. Przytrzymaj kierunek = jazda; puszczenie = stop.
"""
from __future__ import annotations

import socket
import tkinter as tk
from tkinter import ttk, messagebox

DEFAULT_HOST = "192.168.4.1"
DEFAULT_PORT = 1234

# UDP[3:0] = kierunek pada; FPGA zamienia na IN1..IN4 (L298N)
BIT_UP = 0x01
BIT_RIGHT = 0x02
BIT_DOWN = 0x04
BIT_LEFT = 0x08
BIT_A = 0x01
BIT_B = 0x02
BIT_X = 0x04
BIT_Y = 0x08


class UdpCam:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def close(self) -> None:
        self._sock.close()

    def send_led(self, mask: int) -> None:
        self._sock.sendto(bytes([mask & 0x0F]), (self.host, self.port))

    def send_text(self, text: str) -> None:
        self._sock.sendto(text.encode("ascii"), (self.host, self.port))


class PadGui(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Basys Cam — pad (UDP)")
        self.resizable(False, False)

        self._pressed: set[int] = set()
        self._cam: UdpCam | None = None

        self._host_var = tk.StringVar(value=DEFAULT_HOST)
        self._port_var = tk.StringVar(value=str(DEFAULT_PORT))
        self._status_var = tk.StringVar(value="Nie połączono (tylko wysyłka UDP)")

        self._build_ui()
        self._bind_keys()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self) -> None:
        top = ttk.Frame(self, padding=8)
        top.pack(fill=tk.X)

        ttk.Label(top, text="Host ESP:").grid(row=0, column=0, sticky=tk.W)
        ttk.Entry(top, textvariable=self._host_var, width=14).grid(row=0, column=1, padx=4)
        ttk.Label(top, text="Port:").grid(row=0, column=2, sticky=tk.W)
        ttk.Entry(top, textvariable=self._port_var, width=6).grid(row=0, column=3, padx=4)

        ttk.Label(top, textvariable=self._status_var, foreground="#333").grid(
            row=1, column=0, columnspan=4, sticky=tk.W, pady=(6, 0)
        )

        stream = ttk.Frame(self, padding=(8, 0))
        stream.pack()
        ttk.Button(stream, text="Start wideo (UDP)", command=self._cmd_start).pack(
            side=tk.LEFT, padx=4
        )
        ttk.Button(stream, text="Stop wideo", command=self._cmd_stop).pack(side=tk.LEFT, padx=4)
        ttk.Button(stream, text="Stop IN (0)", command=lambda: self._set_mask(0)).pack(
            side=tk.LEFT, padx=4
        )

        main = ttk.Frame(self, padding=12)
        main.pack()

        dpad = ttk.LabelFrame(main, text="D-pad — jazda (przód/tył/lewo/prawo)", padding=8)
        dpad.grid(row=0, column=0, padx=8)

        self._add_pad_btn(dpad, "▲\nprzód", BIT_UP, 0, 1)
        self._add_pad_btn(dpad, "◄\nlewo", BIT_LEFT, 1, 0)
        self._add_pad_btn(dpad, "●", 0, 1, 1, is_center=True)
        self._add_pad_btn(dpad, "►\nprawo", BIT_RIGHT, 1, 2)
        self._add_pad_btn(dpad, "▼\ntył", BIT_DOWN, 2, 1)

        face = ttk.LabelFrame(main, text="Przyciski (te same bity)", padding=8)
        face.grid(row=0, column=1, padx=8)

        self._add_pad_btn(face, "A / △\nIN1", BIT_A, 0, 1, width=8)
        self._add_pad_btn(face, "B / ○\nIN2", BIT_B, 1, 0, width=8)
        self._add_pad_btn(face, "X / □\nIN4", BIT_X, 1, 2, width=8)
        self._add_pad_btn(face, "Y / ✕\nIN3", BIT_Y, 2, 1, width=8)

        hint = ttk.Label(
            self,
            text="Przytrzymaj kierunek = jazda; puszczenie = stop. Strzałki / 1·2·4·8, Spacja=stop.",
            padding=8,
            wraplength=420,
            justify=tk.CENTER,
        )
        hint.pack()

        self._mask_label = ttk.Label(self, text="Maska: 0x0", font=("Consolas", 11))
        self._mask_label.pack(pady=(0, 8))

    def _add_pad_btn(
        self,
        parent: ttk.Widget,
        text: str,
        bit: int,
        row: int,
        col: int,
        *,
        width: int = 6,
        is_center: bool = False,
    ) -> None:
        if is_center:
            lbl = ttk.Label(parent, text=text, anchor=tk.CENTER)
            lbl.grid(row=row, column=col, padx=2, pady=2)
            return
        btn = tk.Button(
            parent,
            text=text,
            width=width,
            height=2,
            relief=tk.RAISED,
            bg="#e8e8e8",
            activebackground="#cce5ff",
        )
        btn.grid(row=row, column=col, padx=2, pady=2)
        if bit:
            btn.bind("<ButtonPress-1>", lambda e, b=bit: self._press(b))
            btn.bind("<ButtonRelease-1>", lambda e, b=bit: self._release(b))
            btn.bind("<Leave>", lambda e, b=bit: self._release(b))

    def _bind_keys(self) -> None:
        key_map = {
            "Up": BIT_UP,
            "Down": BIT_DOWN,
            "Left": BIT_LEFT,
            "Right": BIT_RIGHT,
            "1": BIT_UP,
            "2": BIT_RIGHT,
            "4": BIT_DOWN,
            "8": BIT_LEFT,
            "z": BIT_A,
            "x": BIT_B,
            "c": BIT_Y,
            "v": BIT_X,
        }
        for key, bit in key_map.items():
            self.bind(f"<KeyPress-{key}>", lambda e, b=bit: self._press(b))
            self.bind(f"<KeyRelease-{key}>", lambda e, b=bit: self._release(b))
        self.bind("<space>", lambda e: self._set_mask(0))

    def _ensure_cam(self) -> UdpCam | None:
        try:
            port = int(self._port_var.get().strip())
            host = self._host_var.get().strip()
        except ValueError:
            messagebox.showerror("Błąd", "Port musi być liczbą.")
            return None
        if self._cam is None or self._cam.host != host or self._cam.port != port:
            if self._cam is not None:
                self._cam.close()
            self._cam = UdpCam(host, port)
        return self._cam

    def _current_mask(self) -> int:
        m = 0
        for b in self._pressed:
            m |= b
        return m & 0x0F

    def _send_mask(self, mask: int) -> None:
        cam = self._ensure_cam()
        if cam is None:
            return
        try:
            cam.send_led(mask)
            self._status_var.set(f"UDP → {cam.host}:{cam.port}  maska=0x{mask:X}")
            self._mask_label.config(text=f"Maska: 0x{mask:X}  ({mask:04b})")
        except OSError as exc:
            self._status_var.set(f"Błąd UDP: {exc}")
            messagebox.showwarning(
                "UDP",
                f"Nie wysłano pakietu.\nCzy jesteś w sieci ESP_VIDEO_TX?\n\n{exc}",
            )

    def _press(self, bit: int) -> None:
        if bit:
            self._pressed.add(bit)
        self._send_mask(self._current_mask())

    def _release(self, bit: int) -> None:
        self._pressed.discard(bit)
        self._send_mask(self._current_mask())

    def _set_mask(self, mask: int) -> None:
        self._pressed.clear()
        for bit in (BIT_UP, BIT_RIGHT, BIT_DOWN, BIT_LEFT):
            if mask & bit:
                self._pressed.add(bit)
        self._send_mask(mask)

    def _cmd_start(self) -> None:
        cam = self._ensure_cam()
        if cam:
            try:
                cam.send_text("start")
                self._status_var.set("Wysłano: start (wideo)")
            except OSError as exc:
                messagebox.showwarning("UDP", str(exc))

    def _cmd_stop(self) -> None:
        cam = self._ensure_cam()
        if cam:
            try:
                cam.send_text("stop")
                self._status_var.set("Wysłano: stop")
            except OSError as exc:
                messagebox.showwarning("UDP", str(exc))

    def _on_close(self) -> None:
        if self._cam is not None:
            self._cam.close()
        self.destroy()


def main() -> None:
    app = PadGui()
    app.mainloop()


if __name__ == "__main__":
    main()

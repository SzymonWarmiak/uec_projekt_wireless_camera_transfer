#!/usr/bin/env python3

from __future__ import annotations

import socket
import tkinter as tk
from tkinter import messagebox, ttk

DEFAULT_HOST = "192.168.4.1"
DEFAULT_PORT = 1234

BIT_UP = 0x01
BIT_DOWN = 0x02
BIT_LEFT = 0x04
BIT_RIGHT = 0x08


class UdpClient:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

    def close(self) -> None:
        self._sock.close()

    def send_mask(self, mask: int) -> None:
        self._sock.sendto(bytes([mask & 0x0F]), (self.host, self.port))

    def send_text_to(self, text: str, host: str) -> None:
        self._sock.sendto(text.encode("utf-8"), (host, self.port))


class CamControlGui(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Jezdzik")
        self.resizable(False, False)
        self.configure(bg="#0b1018")

        self._pressed: set[int] = set()
        self._client: UdpClient | None = None

        self._host_var = tk.StringVar(value=DEFAULT_HOST)
        self._port_var = tk.StringVar(value=str(DEFAULT_PORT))
        self._ssid_var = tk.StringVar()
        self._password_var = tk.StringVar()
        self._status_var = tk.StringVar(value="Gotowe")
        self._mask_var = tk.StringVar(value="Maska: 0x0 (0000)")

        self._style = ttk.Style(self)
        self._style.theme_use("clam")
        self._style.configure("Dark.TFrame", background="#0b1018")
        self._style.configure("Panel.TLabelframe", background="#111827", foreground="#e2e8f0")
        self._style.configure("Panel.TLabelframe.Label", background="#111827", foreground="#e2e8f0")
        self._style.configure("Dark.TLabel", background="#0b1018", foreground="#e2e8f0")
        self._style.configure("Panel.TLabel", background="#111827", foreground="#e2e8f0")
        self._style.configure("Dark.TButton", padding=8)

        self._build_ui()
        self._bind_keys()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self) -> None:
        root = ttk.Frame(self, padding=14, style="Dark.TFrame")
        root.pack(fill=tk.BOTH, expand=True)

        ttk.Label(root, text="Jezdzik", font=("Segoe UI", 20, "bold"), style="Dark.TLabel").grid(
            row=0, column=0, columnspan=2, pady=(0, 12)
        )

        connection = ttk.LabelFrame(root, text="ESP_station", padding=10, style="Panel.TLabelframe")
        connection.grid(row=1, column=0, columnspan=2, sticky=tk.EW, pady=(0, 12))
        ttk.Label(connection, text="IP ESP_station", style="Panel.TLabel").grid(row=0, column=0, sticky=tk.W)
        tk.Entry(connection, textvariable=self._host_var, width=18, bg="#111827", fg="#e2e8f0",
                 insertbackground="#e2e8f0").grid(row=0, column=1, padx=(8, 14))
        ttk.Label(connection, text="Port", style="Panel.TLabel").grid(row=0, column=2, sticky=tk.W)
        tk.Entry(connection, textvariable=self._port_var, width=7, bg="#111827", fg="#e2e8f0",
                 insertbackground="#e2e8f0").grid(row=0, column=3, padx=(8, 0))

        dpad = ttk.LabelFrame(root, text="Sterowanie", padding=12, style="Panel.TLabelframe")
        dpad.grid(row=2, column=0, padx=(0, 12), sticky=tk.N)
        self._add_pad_button(dpad, "▲", BIT_UP, 0, 1)
        self._add_pad_button(dpad, "◄", BIT_LEFT, 1, 0)
        self._add_stop_button(dpad, 1, 1)
        self._add_pad_button(dpad, "►", BIT_RIGHT, 1, 2)
        self._add_pad_button(dpad, "▼", BIT_DOWN, 2, 1)

        wifi = ttk.LabelFrame(root, text="Wi-Fi", padding=10, style="Panel.TLabelframe")
        wifi.grid(row=2, column=1, sticky=tk.N)
        ttk.Label(wifi, text="Nazwa Wi-Fi", style="Panel.TLabel").grid(row=0, column=0, sticky=tk.W)
        tk.Entry(wifi, textvariable=self._ssid_var, width=24, bg="#111827", fg="#e2e8f0",
                 insertbackground="#e2e8f0").grid(row=1, column=0, sticky=tk.EW, pady=(2, 8))
        ttk.Label(wifi, text="Haslo Wi-Fi", style="Panel.TLabel").grid(row=2, column=0, sticky=tk.W)
        tk.Entry(wifi, textvariable=self._password_var, width=24, show="*", bg="#111827", fg="#e2e8f0",
                 insertbackground="#e2e8f0").grid(row=3, column=0, sticky=tk.EW, pady=(2, 10))
        ttk.Button(wifi, text="Zapisz Wi-Fi w ESP", command=self._send_wifi_config,
                   style="Dark.TButton").grid(row=4, column=0, sticky=tk.EW, pady=(0, 8))
        ttk.Button(wifi, text="Reset do Robot_jezdzik", command=self._reset_setup,
                   style="Dark.TButton").grid(row=5, column=0, sticky=tk.EW)

        ttk.Label(root, textvariable=self._mask_var, font=("Consolas", 11), style="Dark.TLabel").grid(
            row=3, column=0, columnspan=2, pady=(12, 2)
        )
        ttk.Label(root, textvariable=self._status_var, wraplength=480, style="Dark.TLabel").grid(
            row=4, column=0, columnspan=2
        )

    def _add_pad_button(self, parent: ttk.Widget, text: str, bit: int, row: int, col: int) -> None:
        button = tk.Button(
            parent,
            text=text,
            width=6,
            height=3,
            font=("Segoe UI", 18, "bold"),
            bg="#243044",
            fg="#e2e8f0",
            activebackground="#2563eb",
            activeforeground="white",
            relief=tk.RAISED,
        )
        button.grid(row=row, column=col, padx=5, pady=5)
        button.bind("<ButtonPress-1>", lambda _event, b=bit: self._press(b))
        button.bind("<ButtonRelease-1>", lambda _event, b=bit: self._release(b))
        button.bind("<Leave>", lambda _event, b=bit: self._release(b))

    def _add_stop_button(self, parent: ttk.Widget, row: int, col: int) -> None:
        button = tk.Button(
            parent,
            text="●",
            width=6,
            height=3,
            font=("Segoe UI", 18, "bold"),
            bg="#243044",
            fg="white",
            activebackground="#dc2626",
            activeforeground="white",
            relief=tk.RAISED,
            command=self._stop,
        )
        button.grid(row=row, column=col, padx=5, pady=5)

    def _bind_keys(self) -> None:
        key_map = {
            "Up": BIT_UP, "w": BIT_UP, "W": BIT_UP, "1": BIT_UP,
            "Down": BIT_DOWN, "s": BIT_DOWN, "S": BIT_DOWN, "2": BIT_DOWN,
            "Left": BIT_LEFT, "a": BIT_LEFT, "A": BIT_LEFT, "4": BIT_LEFT,
            "Right": BIT_RIGHT, "d": BIT_RIGHT, "D": BIT_RIGHT, "8": BIT_RIGHT,
        }
        for key, bit in key_map.items():
            self.bind(f"<KeyPress-{key}>", lambda _event, b=bit: self._press(b))
            self.bind(f"<KeyRelease-{key}>", lambda _event, b=bit: self._release(b))
        self.bind("<space>", lambda _event: self._stop())

    def _get_port(self) -> int | None:
        try:
            return int(self._port_var.get().strip())
        except ValueError:
            messagebox.showerror("Blad", "Port musi byc liczba.")
            return None

    def _ensure_client(self) -> UdpClient | None:
        host = self._host_var.get().strip()
        port = self._get_port()
        if not host or port is None:
            messagebox.showerror("Blad", "Wpisz IP ESP_station i port.")
            return None
        if self._client is None or self._client.host != host or self._client.port != port:
            if self._client is not None:
                self._client.close()
            self._client = UdpClient(host, port)
        return self._client

    def _subnet_broadcast_for(self, host: str) -> str | None:
        parts = host.split(".")
        if len(parts) != 4:
            return None
        try:
            numbers = [int(part) for part in parts]
        except ValueError:
            return None
        if any(number < 0 or number > 255 for number in numbers):
            return None
        return f"{numbers[0]}.{numbers[1]}.{numbers[2]}.255"

    def _current_mask(self) -> int:
        mask = 0
        for bit in self._pressed:
            mask |= bit
        return mask & 0x0F

    def _send_mask(self, mask: int) -> None:
        client = self._ensure_client()
        if client is None:
            return
        try:
            client.send_mask(mask)
            self._mask_var.set(f"Maska: 0x{mask:X} ({mask:04b})")
            self._status_var.set(f"Wyslano do {client.host}:{client.port}")
        except OSError as exc:
            self._status_var.set(f"Blad UDP: {exc}")

    def _press(self, bit: int) -> None:
        self._pressed.add(bit)
        self._send_mask(self._current_mask())

    def _release(self, bit: int) -> None:
        self._pressed.discard(bit)
        self._send_mask(self._current_mask())

    def _stop(self) -> None:
        self._pressed.clear()
        self._send_mask(0)

    def _send_wifi_config(self) -> None:
        host = self._host_var.get().strip()
        ssid = self._ssid_var.get().strip()
        password = self._password_var.get()
        port = self._get_port()
        if not host or not ssid or port is None:
            messagebox.showerror("Blad", "Wpisz IP ESP_station oraz nazwe Wi-Fi.")
            return

        command = f"CFG\n{ssid}\n{password}\nAUTO\n"
        targets = {host, "255.255.255.255"}
        subnet = self._subnet_broadcast_for(host)
        if subnet is not None:
            targets.add(subnet)

        client = UdpClient(host, port)
        try:
            for _ in range(6):
                for target in targets:
                    client.send_text_to(command, target)
            self._status_var.set("Wyslano Wi-Fi. Potem wpisz nowe IP ESP_station w polu u gory.")
        except OSError as exc:
            self._status_var.set(f"Nie udalo sie wyslac konfiguracji: {exc}")
        finally:
            client.close()

    def _reset_setup(self) -> None:
        client = self._ensure_client()
        if client is not None:
            try:
                client.send_text_to("RESET_SETUP", client.host)
            except OSError:
                pass
        self._pressed.clear()
        self._host_var.set(DEFAULT_HOST)
        self._ssid_var.set("")
        self._password_var.set("")
        self._status_var.set("Ustawiono Robot_jezdzik i IP 192.168.4.1.")

    def _on_close(self) -> None:
        if self._client is not None:
            self._client.close()
        self.destroy()


def main() -> None:
    app = CamControlGui()
    app.mainloop()


if __name__ == "__main__":
    main()

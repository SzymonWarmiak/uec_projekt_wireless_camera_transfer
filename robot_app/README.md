# Jeździk - aplikacja Flutter

Aplikacja sterująca robotem z Androida i Windowsa.

## Funkcje

- sterowanie kierunkami przez UDP,
- klawiatura na Windows: `W`, `S`, `A`, `D`, spacja jako stop,
- domyślne IP `ESP_station`: `192.168.4.1`,
- konfiguracja Wi-Fi ESP,
- reset do sieci `Robot_jezdzik`.

## Protokół

- port UDP: `1234`,
- sterowanie: 1 bajt z nibblem kierunku:
  - `0x01` przód,
  - `0x02` tył,
  - `0x04` lewo,
  - `0x08` prawo,
  - `0x00` stop,
- konfiguracja Wi-Fi:

```text
CFG
ssid
password
AUTO
```

## Uruchomienie

```bash
cd robot_app
flutter run
```

Budowanie APK:

```bash
cd robot_app
flutter build apk
```

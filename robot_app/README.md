# Basys Cam Pad

Minimalna aplikacja Flutter do sterowania `basys_cam` tak samo jak
`cam_pad_gui`.

## Protokol

- Domyslny host: `192.168.4.1`
- Domyslny port UDP: `1234`
- `Start wideo` wysyla tekst `start`
- `Stop wideo` wysyla tekst `stop`
- Sterowanie jazda wysyla jeden bajt UDP:
  - `0x01` przod
  - `0x02` prawo
  - `0x04` tyl
  - `0x08` lewo
  - `0x00` stop

Telefon musi byc polaczony z Wi-Fi `ESP_VIDEO_TX` / `video_stream`.
Aplikacja nie uzywa Firebase, Bluetooth ani HTTP.

## Uruchomienie

```powershell
cd robot_app
flutter run
```

Budowanie APK:

```powershell
cd robot_app
flutter build apk
```

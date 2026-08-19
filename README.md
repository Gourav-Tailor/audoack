# Audoack Flutter Mobile App

Flutter client for the Audoack backend.

## Existing features

- Username/password login
- Persistent username
- Device list
- Latest analysis per device
- Configurable analysis polling

## New live recording feature

The app can now:

- Store a recording-device token using Android secure storage.
- Record exactly 5 seconds per audio chunk.
- Upload each WAV chunk to:
  - `POST /api/v1/sessions/`
  - `POST /api/v1/sessions/<batch_id>/chunks/`
- Select the recording interval from a dropdown.
- Supported intervals: 5, 10, 15, 20, 25, 30, 60, 120, 300 seconds.
- Stop the recording session and call the backend finalize endpoint.

The interval is a start-to-start interval.

Example:

```text
5 seconds:
record 5s -> upload -> record

10 seconds:
record 5s -> wait 5s -> record

30 seconds:
record 5s -> wait 25s -> record
```

### Token authentication

The live recording API uses:

```text
Authorization: Token <device-token>
```

This is separate from the existing logged-in mobile user's Bearer token.

### Backend endpoints

```text
POST /api/v1/sessions/
POST /api/v1/sessions/<batch_id>/chunks/
POST /api/v1/sessions/<batch_id>/finalize/
```

The backend already supports token-authenticated device sessions and chunk uploads.

## Install

```powershell
flutter pub get
flutter analyze
flutter run -d emulator-5554
```

## Android permissions

The project now declares:

- `RECORD_AUDIO`
- `INTERNET`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MICROPHONE`

The current implementation records while the Flutter application is active. Foreground-service execution is prepared at the manifest level, but a dedicated Android foreground-service implementation is still required for guaranteed screen-off/background recording.

## HTTP development

The configured backend is:

```text
http://34.148.248.202
```

Cleartext HTTP is enabled for development. Use HTTPS before production deployment.

## Troubleshooting

If Android installation fails, verify ADB:

```powershell
$SDK="$env:LOCALAPPDATA\Android\Sdk"
$ADB="$SDK\platform-tools\adb.exe"

Test-Path $ADB
& $ADB kill-server
& $ADB start-server
& $ADB devices
```

Then:

```powershell
flutter clean
flutter pub get
flutter run -d emulator-5554
```

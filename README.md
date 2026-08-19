# Audoack Flutter Mobile App

A Flutter mobile client for the Audoack backend.

The app currently provides:

- Username/password login
- Persistent login username
- User device list
- Device-specific latest analysis
- Manual refresh
- Configurable polling: 5, 10, 15, 30, or 60 seconds
- Android HTTP development support for the current backend

## Backend

The starter configuration uses:

`http://34.148.248.202/`

Expected API endpoints:

- `POST /api/login`
- `GET /api/devices?user={username}`
- `GET /api/analysis?user={username}&device={deviceId}`

Expected login request:

```json
{
  "username": "your_username",
  "password": "your_password"
}
```

Expected login response:

```json
{
  "success": true,
  "token": "optional-token"
}
```

Expected devices response:

```json
{
  "devices": [
    {
      "id": 1,
      "name": "Device 1"
    }
  ]
}
```

Expected analysis response:

```json
{
  "latestAnalysis": {
    "result": "Analysis result",
    "timestamp": "2026-08-18T12:00:00Z"
  }
}
```

If your Django API uses trailing slashes, authentication tokens, different field names, or different response structures, update `lib/services/api_service.dart`.

## Requirements

Install:

1. Flutter SDK
2. Android Studio
3. Android SDK
4. Android emulator or a physical Android phone

Verify Flutter:

```bash
flutter doctor
```

Check available devices:

```bash
flutter devices
```

## Getting the app running

### 1. Extract the ZIP

Extract `audoack.zip`.

Open a terminal in the extracted project directory:

```bash
cd audoack
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Check the project

```bash
flutter analyze
```

### 4. Start an Android emulator

Open Android Studio:

`Device Manager -> Start an emulator`

Or connect an Android phone with USB debugging enabled.

Verify:

```bash
flutter devices
```

### 5. Run the app

```bash
flutter run
```

Or select a specific device:

```bash
flutter run -d <device-id>
```

## Android HTTP development configuration

The current backend uses HTTP:

`http://34.148.248.202/`

Android blocks cleartext HTTP by default. The included Android manifest enables cleartext traffic for development.

This is suitable for development/testing only.

For production, use HTTPS, for example:

`https://api.example.com/`

and remove the cleartext HTTP permission.

## Project structure

```text
audoack/
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── AndroidManifest.xml
├── ios/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── analysis.dart
│   │   └── device.dart
│   ├── screens/
│   │   ├── analysis_screen.dart
│   │   ├── devices_screen.dart
│   │   └── login_screen.dart
│   └── services/
│       └── api_service.dart
├── pubspec.yaml
└── README.md
```

## Build Android APK

Debug APK:

```bash
flutter build apk --debug
```

Release APK:

```bash
flutter build apk --release
```

The release APK will be:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Build Play Store AAB

```bash
flutter build appbundle --release
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Before publishing, configure an Android release signing key.

## API authentication

The starter implementation supports an optional Bearer token returned by login:

```json
{
  "success": true,
  "token": "..."
}
```

The token is attached as:

```text
Authorization: Bearer <token>
```

The current sample does not persist the token across application restarts. For production, use secure storage and implement refresh-token handling if the backend supports it.

## Important production recommendation

Do not rely on:

```text
GET /api/devices?user=username
```

as the security boundary.

The backend should authenticate the user and derive the user identity from the access token/session.

A better API design is:

```text
POST /api/auth/login/
GET  /api/devices/
GET  /api/devices/{device_id}/latest-analysis/
GET  /api/devices/{device_id}/analysis-history/
```

## Polling behavior

When a device analysis screen opens:

1. The latest analysis is fetched immediately.
2. Automatic polling starts.
3. The selected interval controls subsequent requests.
4. Changing the interval restarts the timer.
5. Leaving the screen cancels the timer.

Supported intervals:

- 5 seconds
- 10 seconds
- 15 seconds
- 30 seconds
- 60 seconds

## Troubleshooting

### `flutter` command not found

Install Flutter and add its `bin` directory to your PATH.

Then reopen the terminal and run:

```bash
flutter doctor
```

### No Android device found

Run:

```bash
flutter devices
```

If using an emulator, start it from Android Studio Device Manager.

If using a physical phone:

- Enable Developer Options.
- Enable USB debugging.
- Connect the phone.
- Accept the debugging authorization prompt.

### HTTP connection fails

Confirm the backend is reachable:

```bash
curl http://34.148.248.202/
```

Also confirm the Android manifest contains:

```xml
android:usesCleartextTraffic="true"
```

### Login returns 404

Your backend probably uses a different URL or trailing slash.

For example:

```text
/api/login/
```

instead of:

```text
/api/login
```

Update `lib/services/api_service.dart`.

### Login returns 401/403

Check the backend authentication requirements. The sample API service currently assumes a JSON username/password login.

### Devices are empty

Check the actual JSON returned by the backend and make sure it contains:

```json
{
  "devices": []
}
```

If your API uses another field, update `getDevices()`.

## Development workflow

After changing Dart code:

```bash
flutter run
```

Flutter hot reload is available while the app is running.

Before committing:

```bash
flutter analyze
flutter test
```

## Current scope

This ZIP is a frontend starter designed around the API contract above. It does not modify the Django backend.

For production integration, align `api_service.dart` with the actual Django URLs, authentication mechanism, serializers, and response JSON.

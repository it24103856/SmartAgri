# agriculture_flutter

## Backend configuration

The default `API_BASE_URL` is `https://smartagri-api-5mkz.onrender.com/api`.
The committed `config/*.json` files contain public API URLs only. Endpoint paths
already omit `/api`; keep it exactly once in the base URL. Relative media paths
resolve against the backend origin, and absolute Supabase image URLs are retained.

Run against the hosted API from this directory:

```powershell
flutter pub get
flutter run --dart-define-from-file=config/hosted.json
```

To select Chrome explicitly:

```powershell
flutter run -d chrome --dart-define-from-file=config/hosted.json
```

Explicit local development (API on port 5000):

```powershell
# Android emulator accesses the development machine through 10.0.2.2.
flutter run --dart-define-from-file=config/local-android.json

# Chrome/desktop on the development machine.
flutter run -d chrome --dart-define-from-file=config/local-desktop.json
```

A physical phone requires the computer's reachable LAN address instead:
`flutter run --dart-define=API_BASE_URL=http://<LAN_ADDRESS>:5000/api`.
URL definitions apply at build time; restart/rebuild to change environments.
Do not put JWT signing secrets, Supabase service-role keys or agent credentials
into Dart definitions. Existing login/session validation is preserved; sign out
and back in after switching backends if a previous token is no longer valid.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

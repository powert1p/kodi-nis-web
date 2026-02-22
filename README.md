# kodi-nis-web

Flutter Web application for NIS Math platform.

## Structure

```
packages/kodi_core/   — Shared models + API client
apps/kodi_web/        — Flutter Web app
```

## Setup

```bash
# Install deps
cd packages/kodi_core && flutter pub get
cd apps/kodi_web && flutter pub get

# Run dev
cd apps/kodi_web
flutter run -d chrome

# Build
flutter build web --release
```

## API

Backend: `kodi-nis-bot` (FastAPI, Railway)
Configure `API_BASE_URL` environment variable or edit `lib/app/config.dart`.

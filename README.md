# Aurex

Aurex is a premium cross-platform Flutter music app with:

- live music browsing powered by `https://elitejiosaavn-api.vercel.app`
- Supabase-backed authentication, profiles, realtime rooms, and chat
- a premium audio player with lyrics, queue management, and offline downloads
- Android-first delivery with web-ready architecture and optional Windows support

## Stack

- Flutter 3.41.4 / Dart 3.11.1
- `flutter_riverpod` for state and dependency injection
- `go_router` for navigation
- `dio` for HTTP + download transport
- `supabase_flutter` for auth/realtime/database
- `just_audio` + `just_audio_background` for playback
- `sembast` for lightweight local persistence
- `shared_preferences` for settings/session-adjacent app prefs

## Setup

1. Copy `.env.example` to `.env`.
2. Fill in your Supabase URL and anon key.
3. Add your custom redirect URL to Supabase Auth settings.
4. Run:

```powershell
C:\Users\strad\develop\flutter\bin\flutter.bat pub get
C:\Users\strad\develop\flutter\bin\flutter.bat analyze
```

## Supabase

SQL migrations for the realtime room system live in [supabase/migrations](/c:/Users/strad/OneDrive/Documents/shortcuts/Downloads/Aurex/supabase/migrations).

## Verification

Local verification depends on:

- valid Supabase credentials in `.env`
- Google auth provider configuration in Supabase
- platform-specific OAuth redirect setup
- available Android/web/windows toolchains

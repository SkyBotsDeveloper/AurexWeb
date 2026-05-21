# Aurex

Aurex is a premium cross-platform Flutter music app with:

- live music browsing through same-origin `/music-api` with Aurex fallback
  playback through `/aurex-api`
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

1. Copy `.env.example` to `.env` for local values.
2. Fill in your Supabase URL and publishable key.
3. Add your custom redirect URL to Supabase Auth settings.
4. Pass local values at build/run time with `--dart-define-from-file=.env`.
5. Run:

```powershell
C:\Users\strad\develop\flutter\bin\flutter.bat pub get
C:\Users\strad\develop\flutter\bin\flutter.bat run --dart-define-from-file=.env
C:\Users\strad\develop\flutter\bin\flutter.bat build apk --release --dart-define-from-file=.env
C:\Users\strad\develop\flutter\bin\flutter.bat analyze
```

For Vercel, the music, artwork, and Aurex API calls default to same-origin
rewrites in `vercel.json`: `/music-api`, `/artwork-api`, and `/aurex-api`.
Only set `JIOSAAVN_BASE_URL`, `AUREX_API_BASE_URL`, or
`CLEAN_ARTWORK_API_BASE_URL` when a custom deployment needs different routes.
For local Flutter web without Vercel rewrites or for mobile builds, set those
API variables to reachable absolute API origins in your private `.env`.
Keep Supabase values in project environment variables instead of committing or
shipping `.env`: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
`AUTH_REDIRECT_SCHEME`, and `AUTH_REDIRECT_HOST`.

## Aurex API fallback

The app keeps the existing music catalog/API as the primary source. Search first
queries the existing source and renders those results without calling Aurex API.
If the primary result is empty, the Search screen shows a small online loading
state and calls:

```text
GET {AUREX_API_BASE_URL}/api/search?q=<query>&limit=10
```

When primary results exist, users can still click `Search online too` to fetch
fallback results in a separate `Online results` section.

Online results are metadata-only and cached in memory for a short time. Stream
URLs are never persisted. A stream is resolved only after the user selects an
online result:

```text
GET {AUREX_API_BASE_URL}/api/resolve?videoId=<videoId>&format=mp3
```

Playback uses `audio.streamLink` first, then `audio.directLink`. The clicked
online row shows its own loading state while resolving so the rest of the app
stays interactive.

## Supabase

SQL migrations for the realtime room system live in [supabase/migrations](/c:/Users/strad/OneDrive/Documents/shortcuts/Downloads/Aurex/supabase/migrations).

## Verification

Local verification depends on:

- valid Supabase credentials passed with `--dart-define-from-file=.env`
- Google auth provider configuration in Supabase
- platform-specific OAuth redirect setup
- available Android/web/windows toolchains

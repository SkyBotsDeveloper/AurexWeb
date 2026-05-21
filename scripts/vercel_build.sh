#!/usr/bin/env bash
set -euo pipefail

FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"

if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

if [ -n "${VERCEL:-}" ] || [ -n "${VERCEL_ENV:-}" ]; then
  music_api_base="${JIOSAAVN_WEB_BASE_URL:-/music-api}"
  aurex_api_base="${AUREX_WEB_BASE_URL:-/aurex-api}"
  clean_artwork_api_base="${CLEAN_ARTWORK_WEB_BASE_URL:-/artwork-api}"
else
  music_api_base="${JIOSAAVN_BASE_URL:-/music-api}"
  aurex_api_base="${AUREX_API_BASE_URL:-/aurex-api}"
  clean_artwork_api_base="${CLEAN_ARTWORK_API_BASE_URL:-/artwork-api}"
fi

dart_defines=(
  "--dart-define=JIOSAAVN_BASE_URL=${music_api_base}"
  "--dart-define=AUREX_API_BASE_URL=${aurex_api_base}"
  "--dart-define=CLEAN_ARTWORK_API_BASE_URL=${clean_artwork_api_base}"
  "--dart-define=SUPABASE_URL=${SUPABASE_URL:-}"
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_ANON_KEY:-}}"
  "--dart-define=AUTH_REDIRECT_SCHEME=${AUTH_REDIRECT_SCHEME:-aurex}"
  "--dart-define=AUTH_REDIRECT_HOST=${AUTH_REDIRECT_HOST:-auth-callback}"
)

flutter --disable-analytics
flutter config --enable-web
flutter pub get
flutter build web --release "${dart_defines[@]}"

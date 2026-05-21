#!/usr/bin/env bash
set -euo pipefail

FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"

if [ ! -d "$FLUTTER_ROOT" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"

dart_defines=(
  "--dart-define=JIOSAAVN_BASE_URL=${JIOSAAVN_BASE_URL:-/music-api}"
  "--dart-define=AUREX_API_BASE_URL=${AUREX_API_BASE_URL:-/aurex-api}"
  "--dart-define=CLEAN_ARTWORK_API_BASE_URL=${CLEAN_ARTWORK_API_BASE_URL:-/artwork-api}"
  "--dart-define=SUPABASE_URL=${SUPABASE_URL:-}"
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_ANON_KEY:-}}"
  "--dart-define=AUTH_REDIRECT_SCHEME=${AUTH_REDIRECT_SCHEME:-aurex}"
  "--dart-define=AUTH_REDIRECT_HOST=${AUTH_REDIRECT_HOST:-auth-callback}"
)

flutter --disable-analytics
flutter config --enable-web
flutter pub get
flutter build web --release "${dart_defines[@]}"

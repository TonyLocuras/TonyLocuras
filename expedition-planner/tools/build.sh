#!/usr/bin/env bash
# Runs tests + analysis, then builds the target given as $1 (default: apk).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
flutter test
flutter analyze --no-fatal-infos
case "${1:-apk}" in
  apk)     flutter build apk --release ;;
  windows) flutter build windows --release ;;
  linux)   flutter build linux --release ;;
  web)     flutter build web --release ;;
  *) echo "Uso: tools/build.sh [apk|windows|linux|web]"; exit 1 ;;
esac

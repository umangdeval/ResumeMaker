#!/usr/bin/env bash
set -euo pipefail

PROJECT="ResumeForge.xcodeproj"
SCHEME="ResumeForge"
CONFIGURATION="Release"
DESTINATION="platform=macOS"
VOLUME_NAME="ResumeForge"
OUTPUT_DMG="dist/ResumeForge-Test.dmg"
SKIP_BUILD=0

usage() {
  cat <<'EOF'
Usage: scripts/make-dmg.sh [options]

Creates a test-installable DMG for the macOS app.

Options:
  --project <path>         Xcode project path (default: ResumeForge.xcodeproj)
  --scheme <name>          Xcode scheme (default: ResumeForge)
  --configuration <name>   Build configuration (default: Release)
  --destination <value>    xcodebuild destination (default: platform=macOS)
  --volume-name <name>     DMG volume name (default: ResumeForge)
  --output <path>          Output DMG path (default: dist/ResumeForge-Test.dmg)
  --skip-build             Skip xcodebuild and use latest built app
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --destination)
      DESTINATION="$2"
      shift 2
      ;;
    --volume-name)
      VOLUME_NAME="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DMG="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ $SKIP_BUILD -eq 0 ]]; then
  echo "Building $SCHEME ($CONFIGURATION)..."
  xcodebuild clean build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION"
fi

DERIVED_PATTERN="$HOME/Library/Developer/Xcode/DerivedData/ResumeForge-*/Build/Products/$CONFIGURATION/ResumeForge.app"
APP_PATH="$(ls -td $DERIVED_PATTERN 2>/dev/null | head -n 1 || true)"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Could not find built app at pattern: $DERIVED_PATTERN" >&2
  echo "Try running without --skip-build, or check scheme/configuration." >&2
  exit 1
fi

echo "Using app: $APP_PATH"

STAGE_DIR="dist/dmg-root"
mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$OUTPUT_DMG"
echo "Creating DMG: $OUTPUT_DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov -format UDZO \
  "$OUTPUT_DMG"

echo "Done: $OUTPUT_DMG"

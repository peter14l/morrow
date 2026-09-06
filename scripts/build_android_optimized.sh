#!/usr/bin/env bash
set -e

# Oasis Optimized Android Release Build Script (Bash)
# Enforces standard Dart compilation flags (--obfuscate, --split-debug-info) and R8 optimizations.

BUNDLE=false
ANALYZE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --bundle) BUNDLE=true ;;
        --analyze-size) ANALYZE=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

SYMBOLS_DIR="build/app/outputs/symbols"
mkdir -p "$SYMBOLS_DIR"

CMD="apk"
if [ "$BUNDLE" = true ]; then
    CMD="appbundle"
fi

ARGS=("build" "$CMD" "--release" "--obfuscate" "--split-debug-info=$SYMBOLS_DIR" "--tree-shake-icons")

if [ "$ANALYZE" = true ]; then
    ARGS+=("--analyze-size" "--target-platform" "android-arm64")
fi

echo "===================================================="
echo " Building Oasis for Android (Optimized Production) "
echo " Flags: ${ARGS[*]}"
echo "===================================================="

flutter "${ARGS[@]}"

echo ""
echo "Build completed successfully!"
echo "Debug symbols stored at: $SYMBOLS_DIR"

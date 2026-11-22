#!/usr/bin/env bash
# ==============================================================================
# TelsoWorld Auto-Build Script for Google Play Store (.aab)
# Automatically bumps the version and builds an optimized release App Bundle
# ==============================================================================

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "========================================================"
echo "🚀 TelsoWorld - Building Release App Bundle (.aab)"
echo "========================================================"

# Run Flutter build appbundle with release flag
flutter build appbundle --release

AAB_PATH="$DIR/build/app/outputs/bundle/release/app-release.aab"

if [ -f "$AAB_PATH" ]; then
    SIZE=$(ls -lh "$AAB_PATH" | awk '{print $5}')
    echo ""
    echo "========================================================"
    echo "✅ Release .aab successfully generated!"
    echo "📦 File: $AAB_PATH"
    echo "⚖️  Size: $SIZE"
    echo "========================================================"
else
    echo "❌ Error: AAB file not found at $AAB_PATH"
    exit 1
fi

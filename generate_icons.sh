#!/bin/bash

# Script to generate macOS app icons from a 1024x1024 source image
# Usage: ./generate_icons.sh path/to/your/1024x1024/image.png

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_1024x1024_image.png>"
    echo "Example: $0 ~/Desktop/my_icon.png"
    exit 1
fi

SOURCE_IMAGE="$1"
OUTPUT_DIR="Sources/Assets.xcassets/AppIcon.appiconset"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Error: Source image '$SOURCE_IMAGE' not found!"
    exit 1
fi

# Check if sips is available (macOS built-in tool)
if ! command -v sips &> /dev/null; then
    echo "Error: sips command not found. This script requires macOS."
    exit 1
fi

echo "Generating app icons from: $SOURCE_IMAGE"
echo "Output directory: $OUTPUT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Generate all required icon sizes
echo "Generating 16x16 (1x)..."
sips -z 16 16 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_16x16.png"

echo "Generating 16x16@2x (32x32)..."
sips -z 32 32 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_16x16@2x.png"

echo "Generating 32x32 (1x)..."
sips -z 32 32 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_32x32.png"

echo "Generating 32x32@2x (64x64)..."
sips -z 64 64 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_32x32@2x.png"

echo "Generating 128x128 (1x)..."
sips -z 128 128 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_128x128.png"

echo "Generating 128x128@2x (256x256)..."
sips -z 256 256 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_128x128@2x.png"

echo "Generating 256x256 (1x)..."
sips -z 256 256 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_256x256.png"

echo "Generating 256x256@2x (512x512)..."
sips -z 512 512 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_256x256@2x.png"

echo "Generating 512x512 (1x)..."
sips -z 512 512 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_512x512.png"

echo "Generating 512x512@2x (1024x1024)..."
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_512x512@2x.png"

echo ""
echo "✅ All app icons generated successfully!"
echo "📁 Icons saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Rebuild your app: xcodebuild build -scheme Pickle"
echo "2. The new icons will appear in your app"

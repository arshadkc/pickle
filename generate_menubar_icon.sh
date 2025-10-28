#!/bin/bash

# Script to generate monochrome menu bar icons from a 1024x1024 source image
# Usage: ./generate_menubar_icon.sh path/to/your/1024x1024/image.png

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_1024x1024_image.png>"
    echo "Example: $0 ~/Desktop/my_icon.png"
    exit 1
fi

SOURCE_IMAGE="$1"
OUTPUT_DIR="Sources/Assets.xcassets/MenuBarIcon.imageset"

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

echo "Generating menu bar icons from: $SOURCE_IMAGE"
echo "Output directory: $OUTPUT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Generate 16x16 (1x) - monochrome black
echo "Generating 16x16 (1x) - monochrome black..."
sips -z 16 16 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/menubar_16x16.png" --setProperty format png --setProperty formatOptions 0

# Generate 16x16 (2x) - monochrome black  
echo "Generating 16x16 (2x) - monochrome black..."
sips -z 32 32 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/menubar_16x16@2x.png" --setProperty format png --setProperty formatOptions 0

echo "Menu bar icons generated successfully in $OUTPUT_DIR"
echo ""
echo "Note: These icons are monochrome and will automatically adapt to light/dark mode."
echo "The system will invert the colors for dark mode automatically."

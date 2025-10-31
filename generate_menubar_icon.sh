#!/bin/bash

# Script to generate monochrome menu bar icons from a 1024x1024 source image
# Supports PNG, APNG (extracts first frame), and other formats
# Usage: ./generate_menubar_icon.sh path/to/your/1024x1024/image.png

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_1024x1024_image.png or .apng>"
    echo "Example: $0 ~/Desktop/my_icon.png"
    echo "Example: $0 ~/Desktop/my_icon.apng"
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

# Check if source is APNG and convert to static PNG if needed
WORKING_IMAGE="$SOURCE_IMAGE"
TEMP_STATIC_PNG=""

# Detect APNG by checking file extension or using file command
if [[ "$SOURCE_IMAGE" =~ \.(apng|APNG)$ ]] || file "$SOURCE_IMAGE" | grep -q "APNG"; then
    echo "Detected APNG format - extracting first frame to static PNG..."
    TEMP_STATIC_PNG="$(mktemp /tmp/menubar_icon_XXXXXX.png)"
    # sips will extract the first frame from APNG
    sips -s format png "$SOURCE_IMAGE" --out "$TEMP_STATIC_PNG" >/dev/null 2>&1
    if [ -f "$TEMP_STATIC_PNG" ]; then
        WORKING_IMAGE="$TEMP_STATIC_PNG"
        echo "Using extracted first frame from APNG"
    else
        echo "Warning: Failed to extract APNG frame, using original file"
    fi
fi

echo "Generating menu bar icons from: $SOURCE_IMAGE"
echo "Output directory: $OUTPUT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Generate 16x16 (1x) - monochrome black
echo "Generating 16x16 (1x) - monochrome black..."
sips -z 16 16 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_16x16.png" --setProperty format png --setProperty formatOptions 0 || { echo "Error: Failed to generate 16x16 (1x)"; exit 1; }

# Generate 16x16 (2x) - monochrome black  
echo "Generating 16x16 (2x/32x32) - monochrome black..."
sips -z 32 32 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_16x16@2x.png" --setProperty format png --setProperty formatOptions 0 || { echo "Error: Failed to generate 16x16 (2x)"; exit 1; }

# Generate 22x22 (1x) - monochrome black (modern macOS)
echo "Generating 22x22 (1x) - monochrome black..."
sips -z 22 22 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_22x22.png" --setProperty format png --setProperty formatOptions 0 || { echo "Error: Failed to generate 22x22 (1x)"; exit 1; }

# Generate 22x22 (2x/44x44) - monochrome black
echo "Generating 22x22 (2x/44x44) - monochrome black..."
sips -z 44 44 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_22x22@2x.png" --setProperty format png --setProperty formatOptions 0 || { echo "Error: Failed to generate 22x22 (2x)"; exit 1; }

# Generate SOLID (white) variants for active/highlighted state
echo "Generating solid (white) active variants..."
TMP_GRAY="$OUTPUT_DIR/tmp_gray.png"
TMP_16="$OUTPUT_DIR/tmp_16.png"
TMP_32="$OUTPUT_DIR/tmp_32.png"
TMP_22="$OUTPUT_DIR/tmp_22.png"
TMP_44="$OUTPUT_DIR/tmp_44.png"

# Prepare grayscale base (reduce hue variance so invert yields uniform white)
echo "Converting to grayscale..."
sips "$WORKING_IMAGE" --matchTo "/System/Library/ColorSync/Profiles/Generic Gray Profile.icc" --out "$TMP_GRAY" 2>/dev/null || {
    echo "Warning: Grayscale conversion failed, using original image"
    TMP_GRAY="$WORKING_IMAGE"
}

# 16pt solid (1x/2x)
echo "Generating solid 16x16 (1x)..."
sips -z 16 16 "$TMP_GRAY" --out "$TMP_16" 2>/dev/null
sips --invert "$TMP_16" --out "$OUTPUT_DIR/menubar_solid_16x16.png" 2>/dev/null || {
    # Fallback: create inverted version manually
    sips -z 16 16 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_solid_16x16.png" --setProperty format png 2>/dev/null
    echo "Created menubar_solid_16x16.png (fallback)"
}

echo "Generating solid 16x16 (2x/32x32)..."
sips -z 32 32 "$TMP_GRAY" --out "$TMP_32" 2>/dev/null
sips --invert "$TMP_32" --out "$OUTPUT_DIR/menubar_solid_16x16@2x.png" 2>/dev/null || {
    # Fallback: create inverted version manually
    sips -z 32 32 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_solid_16x16@2x.png" --setProperty format png 2>/dev/null
    echo "Created menubar_solid_16x16@2x.png (fallback)"
}

# 22pt solid (1x/2x) — commonly used by NSStatusBar on modern macOS
echo "Generating solid 22x22 (1x)..."
sips -z 22 22 "$TMP_GRAY" --out "$TMP_22" 2>/dev/null
sips --invert "$TMP_22" --out "$OUTPUT_DIR/menubar_solid_22x22.png" 2>/dev/null || {
    # Fallback: create inverted version manually
    sips -z 22 22 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_solid_22x22.png" --setProperty format png 2>/dev/null
    echo "Created menubar_solid_22x22.png (fallback)"
}

echo "Generating solid 22x22 (2x/44x44)..."
sips -z 44 44 "$TMP_GRAY" --out "$TMP_44" 2>/dev/null
sips --invert "$TMP_44" --out "$OUTPUT_DIR/menubar_solid_22x22@2x.png" 2>/dev/null || {
    # Fallback: create inverted version manually
    sips -z 44 44 "$WORKING_IMAGE" --out "$OUTPUT_DIR/menubar_solid_22x22@2x.png" --setProperty format png 2>/dev/null
    echo "Created menubar_solid_22x22@2x.png (fallback)"
}

# Clean up temp files
rm -f "$TMP_GRAY" "$TMP_16" "$TMP_32" "$TMP_22" "$TMP_44"
# Clean up temporary static PNG if we created one from APNG
if [ -n "$TEMP_STATIC_PNG" ] && [ -f "$TEMP_STATIC_PNG" ]; then
    rm -f "$TEMP_STATIC_PNG"
fi

echo "Solid icon variants generated."
echo ""
echo "========================================"
echo "Generated Files Summary:"
echo "========================================"
echo "Regular icons (black/monochrome):"
ls -1 "$OUTPUT_DIR"/menubar_*.png 2>/dev/null | grep -v solid | sed 's|.*/||' || echo "  (none found)"
echo ""
echo "Solid icons (white/highlighted):"
ls -1 "$OUTPUT_DIR"/menubar_solid_*.png 2>/dev/null | sed 's|.*/||' || echo "  (none found)"
echo "========================================"
echo ""
echo "Tips:"
echo " - Use menubar_*.png for the template image: statusItem.button?.image"
echo " - Use menubar_solid_*.png for the highlighted/alternate image:"
echo "     statusItem.button?.alternateImage = NSImage(named: \\\"menubar_solid_16x16\\\")"
echo " - Set template rendering for automatic tinting:"
echo "     statusItem.button?.image?.isTemplate = true"
echo "     statusItem.button?.alternateImage?.isTemplate = true"
echo ""
echo "Menu bar icons generated successfully in $OUTPUT_DIR"
echo ""
echo "Note: These icons are monochrome and will automatically adapt to light/dark mode."
echo "The system will invert the colors for dark mode automatically."

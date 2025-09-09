#!/bin/bash

# Generate App Icons Script
# This script creates beautiful app icons for the Roblox Account Manager

echo "🎨 Generating App Icons..."

# Create the icon directory if it doesn't exist
ICON_DIR="Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICON_DIR"

# Function to create an icon using SF Symbols
create_icon() {
    local size=$1
    local scale=$2
    local filename=$3
    local pixel_size=$((size * scale))
    
    # Create a simple Swift script to generate the icon
    cat > temp_icon_generator.swift << EOF
import Cocoa
import CoreGraphics

let size = CGSize(width: $pixel_size, height: $pixel_size)
let image = NSImage(size: size)

image.lockFocus()

// Background gradient
let gradient = NSGradient(colors: [
    NSColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),
    NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0)
])!

let rect = NSRect(origin: .zero, size: size)
gradient.draw(in: rect, angle: 45)

// Game controller icon
let iconSize = size.width * 0.6
let iconRect = NSRect(
    x: (size.width - iconSize) / 2,
    y: (size.height - iconSize) / 2,
    width: iconSize,
    height: iconSize
)

NSColor.white.setFill()

// Simple game controller shape
let controllerPath = NSBezierPath()
controllerPath.appendRoundedRect(iconRect, xRadius: iconSize * 0.2, yRadius: iconSize * 0.2)
controllerPath.fill()

// Add some details
NSColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1.0).setFill()
let buttonSize = iconSize * 0.1
let button1 = NSRect(x: iconRect.midX - buttonSize * 2, y: iconRect.midY - buttonSize/2, width: buttonSize, height: buttonSize)
let button2 = NSRect(x: iconRect.midX + buttonSize, y: iconRect.midY - buttonSize/2, width: buttonSize, height: buttonSize)

NSBezierPath(ovalIn: button1).fill()
NSBezierPath(ovalIn: button2).fill()

image.unlockFocus()

// Save the image
let data = image.tiffRepresentation!
let bitmap = NSBitmapImageRep(data: data)!
let pngData = bitmap.representation(using: .png, properties: [:])!

let url = URL(fileURLWithPath: "$ICON_DIR/$filename")
try! pngData.write(to: url)

print("Generated $filename")
EOF

    # Compile and run the Swift script
    if command -v swift &> /dev/null; then
        swift temp_icon_generator.swift
    else
        echo "⚠️  Swift not found in PATH, creating placeholder icon for $filename"
        # Create a simple placeholder
        touch "$ICON_DIR/$filename"
    fi
}

# Generate all required icon sizes
create_icon 16 1 "icon_16x16.png"
create_icon 16 2 "icon_16x16@2x.png"
create_icon 32 1 "icon_32x32.png"
create_icon 32 2 "icon_32x32@2x.png"
create_icon 128 1 "icon_128x128.png"
create_icon 128 2 "icon_128x128@2x.png"
create_icon 256 1 "icon_256x256.png"
create_icon 256 2 "icon_256x256@2x.png"
create_icon 512 1 "icon_512x512.png"
create_icon 512 2 "icon_512x512@2x.png"

# Clean up
rm -f temp_icon_generator.swift

echo "✅ App icons generated successfully!"
echo "📱 Icons saved to $ICON_DIR"
echo ""
echo "Note: If you want custom icons, you can replace these files with your own designs."
echo "The icons should be PNG format with the exact pixel dimensions specified."

#!/bin/bash

# Roblox Account Manager - Build Script
# This script helps build and run the project

set -e

echo "🚀 Roblox Account Manager Build Script"
echo "======================================"

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ XcodeGen is not installed. Please install it first:"
    echo "   brew install xcodegen"
    exit 1
fi

# Generate Xcode project
echo "⚙️  Generating Xcode project..."
xcodegen generate

# Check if project was created successfully
if [ -f "RobloxAccountManager.xcodeproj/project.pbxproj" ]; then
    echo "✅ Xcode project generated successfully!"
else
    echo "❌ Failed to generate Xcode project"
    exit 1
fi

# Open the project in Xcode
echo "📱 Opening project in Xcode..."
open RobloxAccountManager.xcodeproj

echo ""
echo "🎉 Setup complete! The project is now open in Xcode."
echo ""
echo "Next steps:"
echo "1. Wait for Xcode to index the project"
echo "2. Select your development team in project settings"
echo "3. Build and run the project (Cmd+R)"
echo ""
echo "Features included:"
echo "• 🔐 Secure account management with encryption"
echo "• 🎮 Advanced game browser with search"
echo "• 🚀 Multi-launcher for simultaneous accounts"
echo "• 🎨 Beautiful SwiftUI interface with themes"
echo "• 📊 Statistics and analytics dashboard"
echo "• ⚙️ Comprehensive settings menu"
echo ""
echo "Enjoy your new Roblox Account Manager! 🎮✨"

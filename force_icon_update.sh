#!/bin/bash

echo "🔧 Forcing app icon update..."

# Build the app first
echo "📱 Building app..."
xcodebuild -project RobloxAccountManager.xcodeproj -scheme RobloxAccountManager -configuration Debug build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the built app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "RobloxAccountManager.app" -type d 2>/dev/null | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "📂 Found app at: $APP_PATH"
        
        # Copy icon files directly to the app bundle
        echo "🎨 Installing custom icon..."
        cp Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128.png "$APP_PATH/Contents/Resources/" 2>/dev/null || true
        cp Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png "$APP_PATH/Contents/Resources/" 2>/dev/null || true
        cp Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png "$APP_PATH/Contents/Resources/" 2>/dev/null || true
        
        # Update the app's Info.plist to reference the icon
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
        
        # Force macOS to refresh the icon cache
        echo "🔄 Refreshing icon cache..."
        touch "$APP_PATH"
        /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_PATH"
        
        # Kill dock to refresh
        killall Dock 2>/dev/null || true
        
        echo "🎉 Icon update complete!"
        echo "💡 If icon still doesn't show, try:"
        echo "   1. Restart the app"
        echo "   2. Wait a few seconds for macOS to refresh"
        echo "   3. Check the dock and Applications folder"
        
        # Launch the app
        echo "🚀 Launching app..."
        open "$APP_PATH"
        
    else
        echo "❌ Could not find built app. Make sure build was successful."
    fi
else
    echo "❌ Build failed. Please fix any compilation errors first."
fi

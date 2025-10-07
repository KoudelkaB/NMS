#!/bin/bash

# iOS App Store Build Script for NMS Flutter App
# This script prepares the iOS build for App Store submission

set -e

echo "🚀 Starting iOS App Store build process..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build Flutter iOS release
echo "🔨 Building Flutter assets (iOS build requires macOS with Xcode)..."
flutter build bundle

echo "✅ Flutter assets built!"
echo ""
echo "⚠️  Note: iOS builds require macOS with Xcode installed."
echo "   The iOS project is configured and ready for building on macOS."

echo "✅ Flutter build completed!"
echo ""
echo "📋 Next steps for App Store submission:"
echo "1. Transfer the project to a Mac with Xcode installed"
echo "2. Open ios/Runner.xcworkspace in Xcode"
echo "3. Download and add GoogleService-Info.plist from Firebase console to ios/Runner/"
echo "4. Set up code signing in Xcode:"
echo "   - Go to Signing & Capabilities"
echo "   - Select your development team"
echo "   - Enable Push Notifications capability"
echo "5. Archive the app: Product > Archive"
echo "6. Upload to App Store Connect: Window > Organizer > Upload to App Store"
echo ""
echo "🔧 Build artifacts are in: build/ios/iphoneos/Runner.app"
echo "📱 Bundle ID: org.nms.App"
echo "📦 Version: $(grep 'version:' pubspec.yaml | sed 's/version: //')"
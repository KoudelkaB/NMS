# iOS App Store Build Configuration

This document outlines the steps to build and submit the NMS Flutter app to the Apple App Store.

## Prerequisites

- macOS with Xcode 15+ installed
- Apple Developer Program membership
- Firebase project with iOS app configured
- Flutter SDK installed

## Bundle Configuration

- **Bundle ID**: `org.nms.App`
- **Display Name**: NMS
- **Version**: 1.0.0 (configured in pubspec.yaml)
- **Build Number**: Auto-incremented via CI/CD

## Required Files

### GoogleService-Info.plist

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Project Settings > General > Your apps
4. Click "Add app" > iOS
5. Enter bundle ID: `org.nms.App`
6. Download `GoogleService-Info.plist`
7. Place it in `ios/Runner/GoogleService-Info.plist`

## Build Steps

### Automated Build (Recommended)

Run the provided build script:

```bash
./build_ios.sh
```

This will:
- Clean previous builds
- Get Flutter dependencies
- Build the iOS release version

### Manual Build

```bash
flutter clean
flutter pub get
flutter build ios --release --no-codesign
```

## Xcode Configuration

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project in the navigator
3. Go to "Signing & Capabilities" tab
4. Select your development team
5. Ensure "Push Notifications" capability is enabled
6. Verify bundle identifier is `org.nms.App`

## App Store Submission

### Archive the App

1. In Xcode: Product > Archive
2. Wait for the archive to complete
3. Select the archive in Organizer
4. Click "Distribute App"
5. Select "App Store Connect"
6. Choose "Upload"

### App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Create a new app or update existing one
3. Upload the build
4. Fill in app information, screenshots, etc.
5. Submit for review

## Code Signing

For production builds, ensure:
- Distribution certificate is installed
- App Store provisioning profile is configured
- Code signing identity is set to "iPhone Distribution"

## Testing

Test push notifications and Firebase features on physical devices before submission.

## Troubleshooting

- If build fails, check Xcode logs for specific errors
- Ensure all dependencies are properly configured
- Verify Firebase configuration matches the bundle ID
- Check that provisioning profiles are valid
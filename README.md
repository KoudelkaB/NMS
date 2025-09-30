# NMS Shared Prayer Calendar

Flutter application for coordinating shared half-hour prayer time-slots for a large community (up to 10&nbsp;000 users). The app integrates Firebase Authentication, Cloud Firestore, Cloud Messaging, and Cloud Functions to deliver multi-platform builds (Android, iOS, Web, Windows, Linux, macOS).

## Features

- **Authentication** with email/password, Google, and Apple providers.
- **Mandatory profile fields** during registration (Jméno, Příjmení, e-mail, telefon, bydliště, církev/společenství) with validation and email verification reminder.
- **Day view calendar** with 48 half-hour slots, live indicator of current time, and quick booking/cancellation via tap.
- **Weekly recurrence** option when reserving a slot (creates reservations for the next 12 weeks, capacity limited to 10 users per slot).
- **Slot occupancy preview** showing the first three participants with overflow counter and tooltip.
- **Profile page** where users can review/update their details and see upcoming reservations.
- **Admin announcements** screen to push information, reminders, or urgent notifications through Firebase Cloud Messaging.
- **Push notifications** handled via FCM topics and rendered in the foreground with `flutter_local_notifications`.

## Project structure

```
lib/
  main.dart            # Firebase bootstrap + notification setup
  app.dart             # MaterialApp + routing
  core/                # Theme, routing, shared widgets, notifications
  features/
    auth/              # Auth repository, controllers, UI
    calendar/          # Firestore models, providers, UI widgets
    profile/           # Profile page and summary
    admin/             # Admin push notification tooling
functions/             # Firebase Cloud Functions (TypeScript)
web/                   # Flutter web bootstrap files
```

## Getting started

1. **Install Flutter** (3.19 or newer) and the required platform tooling for Android/iOS/desktop.
2. Fetch dependencies:

   ```bash
   flutter pub get
   ```

3. **Generate platform folders** (if missing) and web icons:

   ```bash
   flutter create .
   ```

4. **Configure Firebase** with the FlutterFire CLI:

   ```bash
   flutterfire configure --project <your-project-id>
   ```

   Replace the contents of `lib/firebase_options.dart` with the generated file.

5. **Enable Firebase products** in the console:

   - Authentication providers: Email/Password, Google, Apple
   - Firestore (native mode)
   - Cloud Messaging (configure APNs for iOS)
   - Cloud Functions (deploy from the `functions` directory)

6. **Install Cloud Functions dependencies**:

   ```bash
   cd functions
   npm install
   npm run build
   firebase deploy --only functions
   ```

   Set the custom claim `isAdmin` to `true` for administrator accounts in Firebase Auth to allow push announcements.

7. **Run the app** on your desired platform:

   ```bash
   flutter run -d chrome   # Web
   flutter run -d windows  # Windows desktop
   flutter run -d linux    # Linux desktop
   flutter run -d macos    # macOS (if available)
   flutter run -d android  # Android
   flutter run -d ios      # iOS
   ```

## Firebase data model

- **Collection `users`** — stores extended profile fields, admin flag, notification metadata.
- **Collection `timeSlots`** — documents keyed by slot start timestamp (UTC ISO string) with participants (maps + `participantIds` array) and capacity.
- **Topic `announcements`** — FCM topic subscribed by all users; Cloud Function adds `type` (information/reminder/urgent) to payload data.

## Tests & quality

Run static analysis and tests:

```bash
flutter analyze
flutter test
```

## Deployment notes

- **Android/iOS**: configure app icons, splash, signing, and `google-services.json` / `GoogleService-Info.plist`.
- **Web**: upload `firebase-messaging-sw.js` and update FCM web configs per Firebase documentation.
- **Desktop**: enable Windows/Linux/macOS builds with `flutter config --enable-<platform>-desktop`.

## Next steps

- Implement dedicated admin dashboard (web) for slot moderation.
- Add localization support (e.g., English) using Flutter localization tooling.
- Extend recurring reservations with automatic cleanup when the series ends.
- Add integration tests covering the booking flow end-to-end.

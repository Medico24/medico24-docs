# Mobile Development Setup

This guide covers setting up the Medico24 mobile application (Flutter + Dart).

## Prerequisites

- Flutter SDK 3.x or higher
- Dart SDK (comes with Flutter)
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)
- VS Code or Android Studio

---

## Installation

### 1. Install Flutter

=== "Windows"
    ```powershell
    # Using Chocolatey
    choco install flutter

    # Or download from https://docs.flutter.dev/get-started/install/windows
    # Extract to C:\src\flutter and add to PATH
    ```

=== "macOS"
    ```bash
    # Using Homebrew
    brew install flutter

    # Or download from https://docs.flutter.dev/get-started/install/macos
    ```

=== "Linux"
    ```bash
    # Using snap
    sudo snap install flutter --classic

    # Or download from https://docs.flutter.dev/get-started/install/linux
    ```

### 2. Verify Installation

```bash
flutter doctor

# Should show:
# ✓ Flutter (Channel stable)
# ✓ Android toolchain
# ✓ Xcode (macOS only)
# ✓ VS Code
```

Fix any issues reported by `flutter doctor`.

### 3. Install IDE Extensions

=== "VS Code"
    - Flutter extension
    - Dart extension
    - Flutter Widget Snippets

=== "Android Studio"
    - Flutter plugin
    - Dart plugin

---

## Project Setup

### 1. Navigate to Application Directory

```bash
cd medico24-application
```

### 2. Get Dependencies

```bash
flutter pub get
```

### 3. Generate Code (if using code generation)

```bash
# Generate model files, JSON serialization, etc.
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Firebase Configuration

### Android Setup

1. Download `google-services.json` from [Firebase Console](https://console.firebase.google.com/)
2. Place in `android/app/google-services.json`

3. Verify `android/build.gradle.kts`:

```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.0")
    }
}
```

4. Verify `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.google.gms.google-services")
}

android {
    defaultConfig {
        applicationId = "com.medico24.app"
        minSdk = 21
        targetSdk = 34
    }
}
```

### iOS Setup

1. Download `GoogleService-Info.plist` from Firebase Console
2. Open `ios/Runner.xcworkspace` in Xcode
3. Drag `GoogleService-Info.plist` into the `Runner` folder in Xcode
4. Ensure it's added to the `Runner` target

5. Update `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
        </array>
    </dict>
</array>
```

---

## Environment Configuration

### Create Environment Files

Flutter doesn't have built-in `.env` support. Use one of these approaches:

#### Option 1: Dart Define (Recommended)

Create `lib/config/env.dart`:

```dart
class Environment {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',  // Android emulator
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'YOUR_API_KEY',
  );

  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );
}
```

Run with:

```bash
flutter run --dart-define=API_BASE_URL=https://api.medico24.com \
            --dart-define=GOOGLE_MAPS_API_KEY=AIzaSyD...
```

#### Option 2: flutter_dotenv Package

1. Add dependency in `pubspec.yaml`:

```yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

2. Create `.env` file:

```env
API_BASE_URL=http://10.0.2.2:8000/api/v1
GOOGLE_MAPS_API_KEY=AIzaSyD...your-key
```

3. Add to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - .env
```

4. Load in `main.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}
```

5. Use in code:

```dart
final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
```

---

## Google Maps Setup

### Android Configuration

1. Add API key to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
    </application>
</manifest>
```

2. Enable location permissions:

```xml
<manifest>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
```

### iOS Configuration

1. Add API key to `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

2. Enable location in `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to show nearby pharmacies</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to your location to provide better service</string>
```

---

## Running the Application

### Android Emulator

```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>

# Or use Android Studio AVD Manager
```

### iOS Simulator (macOS only)

```bash
# Open simulator
open -a Simulator

# Or
flutter run
# Flutter will launch simulator automatically
```

### Physical Device

#### Android

1. Enable Developer Options on device
2. Enable USB Debugging
3. Connect via USB
4. Verify: `flutter devices`

#### iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select your device
3. Click Run, or use `flutter run`

### Run Commands

```bash
# Run in debug mode
flutter run

# Run in release mode
flutter run --release

# Run with specific device
flutter run -d <device_id>

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R'
# Quit: Press 'q'
```

---

## Project Structure

```
medico24-application/
├── android/                 # Android-specific code
├── ios/                     # iOS-specific code
├── lib/
│   ├── main.dart           # App entry point
│   ├── core/
│   │   ├── config/         # App configuration
│   │   ├── constants/      # Constants and enums
│   │   ├── services/       # API services, storage
│   │   ├── models/         # Data models
│   │   └── utils/          # Utility functions
│   └── presentation/
│       ├── screens/        # App screens
│       │   ├── home/
│       │   ├── pharmacy/
│       │   ├── auth/
│       │   └── profile/
│       ├── widgets/        # Reusable widgets
│       └── providers/      # State management (Riverpod/Provider)
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
├── test/                    # Unit & widget tests
├── integration_test/        # Integration tests
├── pubspec.yaml            # Dependencies
└── analysis_options.yaml   # Linter rules
```

---

## Development Workflow

### Creating a New Screen

```dart
// lib/presentation/screens/pharmacy/pharmacy_list_screen.dart
import 'package:flutter/material.dart';

class PharmacyListScreen extends StatelessWidget {
  const PharmacyListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Pharmacies'),
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('Pharmacy $index'),
            subtitle: Text('Address $index'),
          );
        },
      ),
    );
  }
}
```

### API Integration

```dart
// lib/core/services/api_service.dart
import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio;

  ApiService({required String baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 3),
        ));

  Future<List<Pharmacy>> getPharmacies() async {
    try {
      final response = await _dio.get('/pharmacies');
      return (response.data as List)
          .map((json) => Pharmacy.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to load pharmacies: $e');
    }
  }
}
```

### State Management (Riverpod)

```dart
// lib/presentation/providers/pharmacy_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final pharmacyProvider = FutureProvider<List<Pharmacy>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getPharmacies();
});

// Usage in widget
class PharmacyListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmaciesAsync = ref.watch(pharmacyProvider);

    return pharmaciesAsync.when(
      data: (pharmacies) => ListView.builder(
        itemCount: pharmacies.length,
        itemBuilder: (context, index) {
          final pharmacy = pharmacies[index];
          return ListTile(title: Text(pharmacy.name));
        },
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Navigation

```dart
// Using Navigator 2.0 with go_router
import 'package:go_router/go_router.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/pharmacies',
      builder: (context, state) => const PharmacyListScreen(),
    ),
    GoRoute(
      path: '/pharmacy/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PharmacyDetailScreen(id: id);
      },
    ),
  ],
);

// Navigate
context.go('/pharmacies');
context.push('/pharmacy/123');
```

---

## Testing

### Unit Tests

```dart
// test/services/api_service_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiService', () {
    test('fetches pharmacies successfully', () async {
      final apiService = ApiService(baseUrl: 'https://api.test.com');
      final pharmacies = await apiService.getPharmacies();
      expect(pharmacies, isA<List<Pharmacy>>());
    });
  });
}
```

Run tests:

```bash
flutter test
```

### Widget Tests

```dart
// test/widgets/pharmacy_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PharmacyCard displays name', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyCard(
          pharmacy: Pharmacy(id: '1', name: 'Test Pharmacy'),
        ),
      ),
    );

    expect(find.text('Test Pharmacy'), findsOneWidget);
  });
}
```

### Integration Tests

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:medico24/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete user flow', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Test navigation
    await tester.tap(find.text('Find Pharmacies'));
    await tester.pumpAndSettle();

    expect(find.text('Nearby Pharmacies'), findsOneWidget);
  });
}
```

Run integration tests:

```bash
flutter test integration_test
```

---

## Code Quality

### Linting

```bash
# Analyze code
flutter analyze

# Fix auto-fixable issues
dart fix --apply
```

### Formatting

```bash
# Format all Dart files
dart format .

# Check formatting without modifying
dart format --set-exit-if-changed .
```

### Custom Lint Rules

Edit `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_literals_to_create_immutables
    - avoid_print
    - prefer_single_quotes
    - sort_constructors_first
```

---

## Debugging

### VS Code Launch Configuration

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter: Run",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart"
    },
    {
      "name": "Flutter: Attach to Device",
      "type": "dart",
      "request": "attach"
    }
  ]
}
```

### Flutter DevTools

```bash
# Open DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Or while app is running
flutter run
# Then press 'v' to open DevTools in browser
```

### Logging

```dart
import 'dart:developer' as developer;

developer.log('User logged in', name: 'auth');

// Or use logger package
import 'package:logger/logger.dart';

final logger = Logger();
logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

---

## Build & Release

### Android

#### Debug APK

```bash
flutter build apk --debug
```

#### Release APK

```bash
flutter build apk --release
```

#### App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

#### Signing Configuration

1. Generate keystore:

```bash
keytool -genkey -v -keystore ~/medico24-keystore.jks \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -alias medico24
```

2. Create `android/key.properties`:

```properties
storePassword=yourStorePassword
keyPassword=yourKeyPassword
keyAlias=medico24
storeFile=/path/to/medico24-keystore.jks
```

3. Reference in `android/app/build.gradle.kts`:

```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### iOS

#### Build

```bash
flutter build ios --release
```

#### Archive & Upload (Xcode required)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Product** → **Archive**
3. Upload to App Store Connect

---

## Performance Optimization

### Reduce App Size

```bash
# Build with size optimization
flutter build apk --split-per-abi --target-platform android-arm64

# Analyze app size
flutter build apk --analyze-size
```

### Image Optimization

- Use vector graphics (SVG) where possible
- Compress images before adding to assets
- Use cached_network_image for network images

### Code Optimization

- Use `const` constructors
- Avoid rebuilding widgets unnecessarily
- Use `ListView.builder` for long lists
- Lazy load data

---

## Troubleshooting

### Common Issues

??? question "Gradle build failed"
    ```bash
    # Clear Gradle cache
    cd android
    ./gradlew clean
    cd ..
    flutter clean
    flutter pub get
    ```

??? question "Pod install failed (iOS)"
    ```bash
    cd ios
    pod deintegrate
    pod install
    cd ..
    flutter clean
    ```

??? question "Google Maps not showing"
    - Verify API key is correct
    - Check API key restrictions
    - Ensure Maps SDK is enabled in Google Cloud Console

??? question "Firebase authentication not working"
    - Verify `google-services.json` / `GoogleService-Info.plist` are in correct locations
    - Check SHA-1 fingerprint is added to Firebase Console (Android)
    - Ensure bundle ID matches (iOS)

---

## Next Steps

1. Complete [External Services Setup](external-services.md)
2. Integrate with [Backend API](backend-setup.md)
3. Explore [Flutter Documentation](https://docs.flutter.dev/)
4. Read [Material Design Guidelines](https://m3.material.io/)

**Related Guides:**

- [Setup Overview](overview.md)
- [External Services](external-services.md)
- [Backend Setup](backend-setup.md)
- [Frontend Setup](frontend-setup.md)

# Mobile App Development Guide

This guide covers the development setup, architecture, and implementation details for the Medico24 Flutter mobile application.

## Overview

The Medico24 mobile app is built with Flutter, providing cross-platform support for iOS and Android. The app enables patients to manage appointments, find nearby pharmacies, view environmental health data, and access their healthcare information.

## Architecture

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── core/                     # Core functionality
│   ├── api/                  # API services and models
│   ├── config/               # App configuration
│   ├── constants/            # App constants
│   ├── services/             # Business logic services
│   ├── utils/                # Utility functions
│   └── theme/                # App theming
├── presentation/             # UI layer
│   ├── screens/              # Screen widgets
│   ├── widgets/              # Reusable widgets
│   └── providers/            # State management
├── data/                     # Data layer
│   ├── models/               # Data models
│   ├── repositories/         # Data repositories
│   └── datasources/          # Local/Remote data sources
└── assets/                   # Images, fonts, etc.
```

### Key Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP client
  dio: ^5.4.0
  
  # State management
  provider: ^6.1.0
  
  # Routing
  go_router: ^13.0.0
  
  # Authentication
  firebase_auth: ^4.16.0
  google_sign_in: ^6.2.1
  
  # Maps and location
  google_maps_flutter: ^2.5.0
  geolocator: ^10.1.0
  geocoding: ^2.1.1
  
  # Local storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  
  # Push notifications
  firebase_messaging: ^14.7.10
  flutter_local_notifications: ^16.3.0
  
  # UI components
  cupertino_icons: ^1.0.6
  flutter_svg: ^2.0.9
```

## Development Setup

### Prerequisites

1. **Flutter SDK**: Install Flutter 3.x
2. **Android Studio**: For Android development
3. **Xcode**: For iOS development (macOS only)
4. **Git**: Version control

### Environment Setup

```bash
# Clone repository
git clone https://github.com/medico24/medico24-application.git
cd medico24-application

# Install dependencies
flutter pub get

# Run code generation
flutter packages pub run build_runner build

# Check Flutter setup
flutter doctor
```

### Configuration

#### Firebase Setup

1. **Create Firebase Project**
   - Go to Firebase Console
   - Create new project "medico24-mobile"
   - Enable Authentication, FCM, Analytics

2. **Android Configuration**
   ```bash
   # Download google-services.json
   # Place in android/app/
   ```

3. **iOS Configuration**
   ```bash
   # Download GoogleService-Info.plist
   # Add to ios/Runner/ in Xcode
   ```

#### Environment Variables

```dart
// lib/core/config/app_config.dart
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
  
  static const bool isProduction = bool.fromEnvironment(
    'DART_DEFINES_IS_PRODUCTION',
    defaultValue: false,
  );
}
```

## Key Features Implementation

### Authentication

```dart
// lib/core/services/auth_service.dart
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiClient _apiClient;
  
  AuthService(this._apiClient);
  
  Future<User?> signInWithGoogle() async {
    try {
      // Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      // Firebase authentication
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential result = 
          await _firebaseAuth.signInWithCredential(credential);
      
      // Exchange Firebase token for JWT
      final idToken = await result.user?.getIdToken();
      if (idToken != null) {
        await _exchangeFirebaseToken(idToken);
      }
      
      return result.user;
    } catch (e) {
      throw AuthException('Google sign-in failed: $e');
    }
  }
  
  Future<void> _exchangeFirebaseToken(String idToken) async {
    final response = await _apiClient.post(
      '/auth/firebase/verify',
      data: {'id_token': idToken},
    );
    
    if (response.statusCode == 200) {
      final data = response.data;
      await _storeTokens(
        data['access_token'],
        data['refresh_token'],
      );
    }
  }
  
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'access_token', value: accessToken);
    await storage.write(key: 'refresh_token', value: refreshToken);
  }
}
```

### API Integration

```dart
// lib/core/api/api_client.dart
class ApiClient {
  late final Dio _dio;
  
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.baseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    
    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(LoggingInterceptor());
    _dio.interceptors.add(ErrorInterceptor());
  }
  
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }
  
  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }
  
  // ... other HTTP methods
}

// Auth Interceptor
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    const storage = FlutterSecureStorage();
    final accessToken = await storage.read(key: 'access_token');
    
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired, try refresh
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Retry original request
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      }
    }
    handler.next(err);
  }
  
  Future<bool> _refreshToken() async {
    try {
      const storage = FlutterSecureStorage();
      final refreshToken = await storage.read(key: 'refresh_token');
      
      if (refreshToken == null) return false;
      
      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      
      if (response.statusCode == 200) {
        await storage.write(
          key: 'access_token', 
          value: response.data['access_token'],
        );
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}
```

### Appointment Management

```dart
// lib/data/repositories/appointment_repository.dart
class AppointmentRepository {
  final ApiClient _apiClient;
  
  AppointmentRepository(this._apiClient);
  
  Future<List<Appointment>> getAppointments({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final response = await _apiClient.get('/appointments/', queryParameters: {
      'page': page,
      'page_size': pageSize,
      if (status != null) 'status': status,
    });
    
    final List<dynamic> items = response.data['items'];
    return items.map((json) => Appointment.fromJson(json)).toList();
  }
  
  Future<Appointment> createAppointment(CreateAppointmentRequest request) async {
    final response = await _apiClient.post('/appointments/', 
      data: request.toJson());
    return Appointment.fromJson(response.data);
  }
  
  Future<Appointment> updateAppointmentStatus(
    String appointmentId,
    String status, {
    String? notes,
  }) async {
    final response = await _apiClient.patch(
      '/appointments/$appointmentId/status',
      data: {
        'status': status,
        if (notes != null) 'notes': notes,
      },
    );
    return Appointment.fromJson(response.data);
  }
}
```

### Maps Integration

```dart
// lib/presentation/screens/pharmacy_map_screen.dart
class PharmacyMapScreen extends StatefulWidget {
  @override
  _PharmacyMapScreenState createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends State<PharmacyMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<Pharmacy> _nearbyPharmacies = [];
  Set<Marker> _markers = {};
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      
      await _searchNearbyPharmacies();
    } catch (e) {
      _showError('Location access denied');
    }
  }
  
  Future<void> _searchNearbyPharmacies() async {
    if (_currentPosition == null) return;
    
    try {
      final pharmacies = await context.read<PharmacyRepository>()
        .searchNearby(
          lat: _currentPosition!.latitude,
          lng: _currentPosition!.longitude,
          radiusKm: 10.0,
        );
      
      setState(() {
        _nearbyPharmacies = pharmacies;
        _updateMarkers();
      });
    } catch (e) {
      _showError('Failed to load pharmacies');
    }
  }
  
  void _updateMarkers() {
    _markers = _nearbyPharmacies.map((pharmacy) => Marker(
      markerId: MarkerId(pharmacy.id),
      position: LatLng(pharmacy.latitude, pharmacy.longitude),
      infoWindow: InfoWindow(
        title: pharmacy.name,
        snippet: '${pharmacy.distanceKm.toStringAsFixed(1)} km away',
      ),
      onTap: () => _showPharmacyDetails(pharmacy),
    )).toSet();
    
    // Add user location marker
    if (_currentPosition != null) {
      _markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueBlue,
        ),
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Pharmacies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _searchNearbyPharmacies,
          ),
        ],
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                zoom: 14.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
    );
  }
}
```

## State Management

### Provider Pattern

```dart
// lib/presentation/providers/appointment_provider.dart
class AppointmentProvider extends ChangeNotifier {
  final AppointmentRepository _repository;
  
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;
  
  AppointmentProvider(this._repository);
  
  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> loadAppointments() async {
    _setLoading(true);
    
    try {
      _appointments = await _repository.getAppointments();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> createAppointment(CreateAppointmentRequest request) async {
    try {
      final appointment = await _repository.createAppointment(request);
      _appointments.insert(0, appointment);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
```

## Testing

### Unit Tests

```dart
// test/core/services/auth_service_test.dart
void main() {
  group('AuthService', () {
    late AuthService authService;
    late MockApiClient mockApiClient;
    
    setUp(() {
      mockApiClient = MockApiClient();
      authService = AuthService(mockApiClient);
    });
    
    testWidgets('should exchange Firebase token for JWT', (tester) async {
      // Arrange
      const idToken = 'firebase_id_token';
      const accessToken = 'jwt_access_token';
      const refreshToken = 'jwt_refresh_token';
      
      when(mockApiClient.post('/auth/firebase/verify', data: anyNamed('data')))
          .thenAnswer((_) async => Response(
            data: {
              'access_token': accessToken,
              'refresh_token': refreshToken,
            },
            statusCode: 200,
          ));
      
      // Act
      await authService.exchangeFirebaseToken(idToken);
      
      // Assert
      verify(mockApiClient.post('/auth/firebase/verify', data: {
        'id_token': idToken,
      })).called(1);
    });
  });
}
```

### Widget Tests

```dart
// test/presentation/screens/appointment_list_screen_test.dart
void main() {
  group('AppointmentListScreen', () {
    testWidgets('should display appointments when loaded', (tester) async {
      // Arrange
      final mockProvider = MockAppointmentProvider();
      when(mockProvider.appointments).thenReturn([
        Appointment(
          id: '1',
          doctorName: 'Dr. Smith',
          clinicName: 'Test Clinic',
          appointmentAt: DateTime.now(),
          reason: 'Checkup',
          status: 'scheduled',
        ),
      ]);
      when(mockProvider.isLoading).thenReturn(false);
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppointmentProvider>(
            create: (_) => mockProvider,
            child: const AppointmentListScreen(),
          ),
        ),
      );
      
      // Assert
      expect(find.text('Dr. Smith'), findsOneWidget);
      expect(find.text('Test Clinic'), findsOneWidget);
      expect(find.text('Checkup'), findsOneWidget);
    });
  });
}
```

## Build and Deployment

### Android Build

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# App Bundle (recommended for Play Store)
flutter build appbundle --release
```

### iOS Build

```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release

# Archive for App Store
flutter build ipa --release
```

### CI/CD Pipeline

```yaml
# .github/workflows/mobile.yml
name: Mobile CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test
      
      - name: Check formatting
        run: dart format --set-exit-if-changed .
      
      - name: Analyze code
        run: flutter analyze
  
  build_android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      
      - name: Setup Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build APK
        run: flutter build apk --release
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

## Performance Optimization

### Image Optimization

```dart
// lib/core/widgets/optimized_image.dart
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  
  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => const ShimmerPlaceholder(),
      errorWidget: (context, url, error) => const Icon(Icons.error),
      memCacheWidth: width?.round(),
      memCacheHeight: height?.round(),
    );
  }
}
```

### List Performance

```dart
// Use ListView.builder for large lists
ListView.builder(
  itemCount: appointments.length,
  itemBuilder: (context, index) {
    return AppointmentCard(
      appointment: appointments[index],
      key: ValueKey(appointments[index].id),
    );
  },
)
```

## Related Documentation

- [API Documentation](../api/overview.md) - Backend API integration
- [System Architecture](../architecture/overview.md) - Overall system design
- [Testing Guide](testing.md) - Comprehensive testing strategies
- [Deployment Guide](deployment.md) - Deployment procedures
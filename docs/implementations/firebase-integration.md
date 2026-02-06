# Firebase Integration

This document explains how Medico24 uses Firebase for user authentication and push notifications across all platforms.

## Purpose

Firebase provides two critical services:
- **Authentication**: Secure user login with email/password and Google OAuth
- **Push Notifications**: Real-time FCM (Firebase Cloud Messaging) for appointment reminders and alerts

## How Authentication Works

### Registration Flow

1. User signs up on mobile/web app using Firebase SDK
2. Firebase creates user account and returns ID token
3. App sends ID token to Medico24 backend
4. Backend verifies token with Firebase Admin SDK
5. Backend creates user record in PostgreSQL with `firebase_uid`
6. User can now make authenticated API requests

### Login Flow

1. User logs in with email/password or Google account
2. Firebase SDK returns ID token
3. App includes token in API request headers: `Authorization: Bearer <token>`
4. Backend validates token using Firebase Admin SDK
5. Backend retrieves user from database using `firebase_uid`
6. Request proceeds with authenticated user context

### Token Verification

Every API request with authentication:
- Extracts bearer token from `Authorization` header
- Calls Firebase Admin SDK to verify token validity
- Checks token expiration and signature
- Returns decoded claims including `uid` and `email`
- Looks up user in local database

## How Push Notifications Work

### Device Registration

1. Mobile/web app initializes Firebase Messaging
2. App requests notification permissions from user
3. Firebase generates unique FCM device token
4. App sends token to backend via `/api/v1/auth/device-token`
5. Backend stores token in user's database record

### Sending Notifications

When sending an appointment reminder:
1. Backend retrieves user's FCM token from database
2. Creates notification message with title, body, and data payload
3. Sends to Firebase Cloud Messaging API
4. FCM delivers to user's device
5. If token is invalid (unregistered), backend removes it from database

### Notification Types

- **Appointment Reminders**: 1 hour before scheduled time
- **Appointment Confirmations**: When doctor confirms
- **Prescription Ready**: Pharmacy notifications
- **Health Alerts**: Critical health information

## Platform-Specific Implementation

### Backend (Python)

**Firebase Admin SDK** (`firebase-admin` package):
- Initializes with service account JSON
- Provides `verify_id_token()` for authentication
- Provides `send()` for push notifications
- Server-to-server communication only

**Key Components**:
- `FirebaseService`: Wrapper for Firebase operations
- Authentication middleware: Extracts and verifies tokens
- Notification service: Sends FCM messages to users

### Mobile App (Flutter)

**Required Packages**:
- `firebase_core`: Core Firebase initialization
- `firebase_auth`: Authentication SDK
- `firebase_messaging`: Push notifications
- `google_sign_in`: Google OAuth integration

**Configuration Files**:
- Android: `google-services.json` (in `android/app/`)
- iOS: `GoogleService-Info.plist` (in `ios/Runner/`)

**Initialization**: Apps call `Firebase.initializeApp()` at startup

### Web Dashboard (Next.js)

**Firebase Web SDK**:
- Uses JavaScript Firebase SDK (not Admin SDK)
- Client-side authentication
- Web push notifications (requires VAPID key)

**Configuration**: Firebase config object in environment variables

## Security Considerations

### Token Security

- Tokens expire after 1 hour (enforced by Firebase)
- Backend validates every token on every request
- Tokens are never stored, only verified
- HTTPS required for all communication

### API Key Protection

- **Backend**: Service account JSON kept in secure environment variable
- **Mobile**: API keys restricted by package name/bundle ID and SHA fingerprint
- **Web**: API key restricted to specific domains

### Best Practices

- Never expose service account JSON publicly
- Store sensitive config in `.env` files (git-ignored)
- Use Firebase security rules for additional protection
- Implement rate limiting on authentication endpoints

## Configuration Setup

### Backend Environment

```bash
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase-service-account.json
```

The service account JSON is downloaded from Firebase Console → Project Settings → Service Accounts.

### Mobile Configuration

**Android**: Add SHA-1 fingerprint to Firebase Console, download `google-services.json`

**iOS**: Register bundle ID in Firebase Console, download `GoogleService-Info.plist`

### Web Configuration

Set environment variables for Firebase config:
- API Key
- Auth Domain
- Project ID
- Messaging Sender ID
- App ID

## Common Use Cases

### Protecting API Endpoints

Use authentication middleware to require valid Firebase token:
```py
@router.get("/appointments")
async def get_appointments(current_user = Depends(get_current_user)):
    # current_user automatically populated from Firebase token
    return user's appointments
```

### Bulk Notifications

Send to multiple users (e.g., appointment reminders for the day):
- Fetch all users needing reminders
- Collect their FCM tokens
- Use `send_multicast()` for batch sending
- Handle failed tokens (remove from database)

### Google Sign-In

- User taps "Sign in with Google" button
- Flutter/Web SDK handles OAuth flow
- Returns Google credential
- Sign in to Firebase with credential
- Get ID token and send to backend

## Performance & Costs

### Authentication
- Token verification: < 100ms
- Cached in request context (no repeated verification per request)
- Free tier: Unlimited authentications

### Push Notifications
- FCM delivery: 1-3 seconds typical
- Free tier: Unlimited notifications
- Multicast: Up to 500 tokens per batch

## Troubleshooting

**Common Issues**:

1. **Token verification fails**: Check service account JSON is valid and Firebase project matches
2. **Notifications not delivered**: Verify FCM token is current and permissions granted
3. **Google Sign-In fails**: Check SHA-1 fingerprint (Android) or bundle ID (iOS) configured correctly
4. **CORS errors (web)**: Add domain to Firebase authorized domains list

## Related Documentation

- [Google Maps Integration](./google-maps-integration.md) - Location services integration
- [Environment API Implementation](./environment-api.md) - Environmental data integration
- [Mobile Setup Guide](../guides/setup/mobile-setup.md) - Step-by-step Firebase setup for Flutter
- [Frontend Setup Guide](../guides/setup/frontend-setup.md) - Firebase configuration for Next.js
- [Backend Setup Guide](../guides/setup/backend-setup.md) - Firebase Admin SDK integration

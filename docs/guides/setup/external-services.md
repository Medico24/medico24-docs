# External Services Setup

This guide provides detailed instructions for obtaining and configuring all external services required by Medico24.

## Overview

Medico24 requires the following external services:

| Service | Purpose | Cost | Required |
|---------|---------|------|----------|
| **Google Maps** | Location services | Free tier ($200/month credit) | Yes |
| **Firebase** | Auth & notifications | Free tier | Yes |
| **Neon PostgreSQL** | Database | Free tier (300h/month) | Yes |
| **Redis Cloud** | Caching & sessions | Free tier (30MB) | Yes |
| **Weather API** | Environmental data | Free tier (1000 calls/day) | Optional |

---

## Google Maps API Key

Google Maps is used for pharmacy location services and distance calculations.

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **Select a project** → **New Project**
3. Enter project name: `medico24-dev` (or your preferred name)
4. Click **Create**

### Step 2: Enable Required APIs

1. In the Cloud Console, go to **APIs & Services** → **Library**
2. Search for and enable the following APIs:
   - **Maps JavaScript API**
   - **Places API**
   - **Geocoding API**
   - **Geolocation API**
   - **Directions API** (optional, for route planning)
   - **Distance Matrix API** (for calculating distances)

### Step 3: Create API Key

1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **API Key**
3. Copy the generated API key
4. Click on the API key to configure restrictions (recommended)

### Step 4: Configure API Key Restrictions

!!! warning "Security Recommendation"
    Always restrict your API keys to prevent unauthorized use and unexpected charges.

=== "Development"
    1. **Application restrictions**: None (for testing)
    2. **API restrictions**: Select **Restrict key**
       - Check all the Maps APIs you enabled
    3. Click **Save**

=== "Production"
    1. **Application restrictions**: 
       - For web: **HTTP referrers** → Add `https://yourdomain.com/*`
       - For mobile: **Android apps** or **iOS apps** → Add your app's bundle ID
    2. **API restrictions**: Select **Restrict key**
    3. Click **Save**

### Step 5: Add to Environment Variables

```env
# Backend (.env)
GOOGLE_MAPS_API_KEY=AIzaSyD...your-api-key-here

# Frontend (.env.local)
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIzaSyD...your-api-key-here
```

### Billing & Pricing

- Google Maps offers **$200 free credit per month**
- Set up billing alerts to avoid unexpected charges
- For development, free tier is usually sufficient
- [Pricing Calculator](https://mapsplatform.google.com/pricing/)

---

## Firebase Setup

Firebase is used for authentication (Google OAuth), push notifications, and cloud storage.

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **Add Project**
3. Enter project name: `medico24` (or your preferred name)
4. Enable Google Analytics (recommended) or skip
5. Click **Create Project**

### Step 2: Add Web App

1. In Firebase Console, click the **Web icon** (code symbol `<` `/` `>`)
2. Register app nickname: `medico24-web`
3. Check **"Also set up Firebase Hosting"** (optional)
4. Click **Register app**
5. Copy the Firebase configuration object:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSyD...",
  authDomain: "medico24.firebaseapp.com",
  projectId: "medico24",
  storageBucket: "medico24.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123",
  measurementId: "G-XXXXXXXXXX"
};
```

6. Add to your web app's `.env.local`:

```env
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyD...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=medico24.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=medico24
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=medico24.appspot.com
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=123456789
NEXT_PUBLIC_FIREBASE_APP_ID=1:123456789:web:abc123
NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX
```

### Step 3: Add Android App

1. In Firebase Console, click the **Android icon**
2. Enter Android package name: `com.medico24.app` (match your Flutter app)
3. Download `google-services.json`
4. Place it in `medico24-application/android/app/google-services.json`
5. Follow the Firebase setup instructions for Android

### Step 4: Add iOS App

1. In Firebase Console, click the **iOS icon**
2. Enter iOS bundle ID: `com.medico24.app` (match your Flutter app)
3. Download `GoogleService-Info.plist`
4. Place it in `medico24-application/ios/Runner/GoogleService-Info.plist`
5. Follow the Firebase setup instructions for iOS

### Step 5: Enable Authentication Methods

1. Go to **Authentication** → **Sign-in method**
2. Enable **Email/Password**:
   - Click **Email/Password**
   - Toggle **Enable**
   - Click **Save**
3. Enable **Google**:
   - Click **Google**
   - Toggle **Enable**
   - Set project support email
   - Click **Save**

### Step 6: Configure OAuth Consent Screen

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Go to **APIs & Services** → **OAuth consent screen**
4. Choose **External** for user type (or Internal if you have Google Workspace)
5. Fill in required information:
   - App name: `Medico24`
   - User support email: your email
   - Developer contact: your email
6. Add scopes (optional for basic auth):
   - `openid`
   - `email`
   - `profile`
7. Add test users (for testing before verification)
8. Click **Save and Continue**

### Step 7: Create OAuth Client ID (for Backend)

1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Choose **Web application**
4. Name: `Medico24 Backend`
5. Add **Authorized redirect URIs**:
   - Development: `http://localhost:8000/api/v1/auth/google/callback`
   - Production: `https://api.yourdomain.com/api/v1/auth/google/callback`
6. Click **Create**
7. Copy **Client ID** and **Client Secret**
8. Add to backend `.env`:

```env
GOOGLE_CLIENT_ID=123456789-abc123.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abc123def456
GOOGLE_REDIRECT_URI=http://localhost:8000/api/v1/auth/google/callback
```

### Step 8: Generate Firebase Admin SDK Service Account

!!! danger "Security Alert"
    The service account key file contains sensitive credentials. Never commit it to version control!

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Go to **Service Accounts** tab
3. Click **Generate New Private Key**
4. Confirm by clicking **Generate Key**
5. A JSON file will download: `medico24-firebase-adminsdk-xxxxx.json`
6. Rename to `firebase-service-account.json`
7. Place in `medico24-backend/firebase-service-account.json`
8. Add path to `.env`:

```env
FIREBASE_CREDENTIALS_PATH=firebase-service-account.json
```

9. Add to `.gitignore`:

```
firebase-service-account.json
*-firebase-adminsdk-*.json
```

### Step 9: Enable Cloud Messaging

1. In Firebase Console, go to **Cloud Messaging**
2. No additional setup required for FCM
3. For iOS, you'll need to upload APNs certificates:
   - Go to **Project Settings** → **Cloud Messaging** → **iOS app configuration**
   - Upload APNs authentication key or certificate
   - [APNs Setup Guide](https://firebase.google.com/docs/cloud-messaging/ios/client)

### Verification & Testing

Test Firebase authentication:

```python
# scripts/test_firebase.py
import firebase_admin
from firebase_admin import credentials, auth

# Initialize Firebase
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)

# Test: List users
try:
    users = auth.list_users()
    print(f"✓ Firebase Admin SDK working! Found {len(users.users)} users")
except Exception as e:
    print(f"✗ Error: {e}")
```

---

## PostgreSQL Database (Neon Cloud)

Neon provides serverless PostgreSQL with generous free tier.

### Step 1: Create Neon Account

1. Go to [Neon Console](https://console.neon.tech/)
2. Sign up with GitHub or email
3. Verify your email

### Step 2: Create a Project

1. Click **Create Project**
2. Enter project name: `medico24-production`
3. Select region: **Asia Pacific (Singapore)** or closest to your users
4. Select PostgreSQL version: **15** or latest
5. Click **Create Project**

### Step 3: Get Connection String

1. After creation, you'll see the connection string
2. Copy the **Pooled connection** string (recommended for serverless)
3. Format: `postgresql://user:password@host/database?sslmode=require`

### Step 4: Create Development Branch

!!! tip "Database Branching"
    Neon supports database branching - perfect for separate dev/test environments!

1. In your project, go to **Branches**
2. Click **Create Branch**
3. Branch from: `main`
4. Branch name: `development`
5. Click **Create**
6. Copy the connection string for the dev branch

### Step 5: Add to Environment Variables

```env
# Production database (.env.production)
DATABASE_URL=postgresql://user:password@ep-xxxx.aws.neon.tech/medico24?sslmode=require

# Development database (.env)
DATABASE_URL=postgresql://user:password@ep-yyyy.aws.neon.tech/medico24?sslmode=require

# Test database (create another branch called 'test')
TEST_DATABASE_URL=postgresql://user:password@ep-zzzz.aws.neon.tech/medico24?sslmode=require
```

### Step 6: Enable PostGIS Extension

For location-based features:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
```

Or via command line:

```bash
psql "$DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
```

### Step 7: Run Migrations

```bash
cd medico24-backend
alembic upgrade head
```

### Free Tier Limits

- **Compute**: 300 hours/month (sufficient for development)
- **Storage**: 0.5 GB (generous for most apps)
- **Branches**: Multiple branches included
- Automatically pauses when inactive (saves compute hours)

---

## Redis (Redis Cloud)

Redis is used for caching, sessions, and rate limiting.

### Step 1: Create Redis Cloud Account

1. Go to [Redis Cloud](https://redis.com/try-free/)
2. Sign up with email or Google
3. Verify your email

### Step 2: Create a Database

1. Click **Create Database** or **New Subscription**
2. Choose **Free** plan (30MB storage, sufficient for development)
3. Select cloud provider: **AWS**
4. Select region: **ap-south-1** (Mumbai) or closest
5. Database name: `medico24-cache`
6. Click **Create Database**

### Step 3: Get Connection Details

1. After creation, click on your database
2. Copy connection details:
   - **Endpoint**: `redis-xxxxx.c264.ap-south-1-1.ec2.cloud.redislabs.com`
   - **Port**: `xxxxx`
   - **Password**: Click **Show** to reveal

### Step 4: Configure Connection

```env
REDIS_HOST=redis-xxxxx.c264.ap-south-1-1.ec2.cloud.redislabs.com
REDIS_PORT=xxxxx
REDIS_PASSWORD=your-password-here
REDIS_USERNAME=default
REDIS_DECODE_RESPONSES=true

# Or use Redis URL format
REDIS_URL=redis://default:password@redis-xxxxx.c264.ap-south-1-1.ec2.cloud.redislabs.com:xxxxx/0
```

### Step 5: Test Connection

```bash
# Using redis-cli
redis-cli -h redis-xxxxx.c264.ap-south-1-1.ec2.cloud.redislabs.com \
          -p xxxxx \
          -a your-password \
          PING
# Should return: PONG
```

---

## Environment Data APIs

### OpenWeatherMap API

1. Go to [OpenWeatherMap](https://openweathermap.org/api)
2. Sign up for a free account
3. Go to **API keys** section
4. Copy your API key
5. Add to `.env`:

```env
OPENWEATHER_API_KEY=your-api-key-here
```

**Free Tier**: 1,000 calls/day

### Alternative: Visual Crossing

1. Go to [Visual Crossing](https://www.visualcrossing.com/)
2. Sign up for free account
3. Copy API key from dashboard
4. Add to `.env`:

```env
VISUAL_CROSSING_API_KEY=your-api-key-here
```

**Free Tier**: 1,000 records/day

---

## JWT Secret Keys

Generate secure secret keys for JWT tokens:

=== "Using OpenSSL"
    ```bash
    # Generate JWT secret key
    openssl rand -hex 32

    # Generate JWT refresh secret key
    openssl rand -hex 32

    # Generate admin notification secret
    openssl rand -hex 32
    ```

=== "Using Python"
    ```python
    import secrets

    # Generate 32-byte random keys
    jwt_secret = secrets.token_urlsafe(32)
    refresh_secret = secrets.token_urlsafe(32)
    admin_secret = secrets.token_urlsafe(32)

    print(f"JWT_SECRET_KEY={jwt_secret}")
    print(f"JWT_REFRESH_SECRET_KEY={refresh_secret}")
    print(f"ADMIN_NOTIFICATION_SECRET={admin_secret}")
    ```

Add to `.env`:

```env
JWT_SECRET_KEY=generated-secret-key-here
JWT_REFRESH_SECRET_KEY=generated-refresh-secret-here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

ADMIN_NOTIFICATION_SECRET=generated-admin-secret-here
```

!!! warning "Security"
    - Use different keys for production and development
    - Never commit secret keys to Git
    - Rotate keys periodically in production

---

## Complete Environment Configuration

See the [Backend Setup Guide](backend-setup.md#environment-configuration) for a complete `.env` file example with all services configured.

---

## Security Best Practices

### 1. Environment Files Security

```bash
# Add to .gitignore
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore
echo ".env.production" >> .gitignore
echo "firebase-service-account.json" >> .gitignore

# Verify not tracked by Git
git status --ignored
```

### 2. Separate Environments

Always use different credentials for:
- **Development**: Local testing
- **Staging**: Pre-production testing
- **Production**: Live application

### 3. Secret Management

For production, use secret management services:
- **AWS Secrets Manager**
- **Google Secret Manager**
- **HashiCorp Vault**
- **Azure Key Vault**

### 4. API Key Restrictions

- Restrict API keys to specific domains/IPs
- Use separate keys for different environments
- Rotate keys periodically
- Monitor API usage

---

## Troubleshooting

### Firebase Issues

**Permission denied errors:**  
Check if service account has correct permissions. Regenerate service account key if needed.

**OAuth redirect mismatch:**  
Ensure redirect URI in Google Console matches exactly, including `http://` or `https://` and trailing paths.

### Google Maps Issues

**This API key is not authorized:**  
1. Check API key restrictions in Google Cloud Console  
2. Ensure Maps JavaScript API is enabled  
3. Wait up to 5 minutes for changes to propagate

### Database Connection Issues

**Connection refused:**  
- Check if IP is whitelisted (Neon allows all by default)  
- Verify connection string format  
- Ensure `sslmode=require` is included

**Too many connections:**  
- Use connection pooling (SQLAlchemy handles this)  
- For Neon: Use pooled connection string

### Redis Connection Issues

**Connection timeout:**  
1. Verify Redis host and port  
2. Check firewall rules  
3. Ensure password is correct  
4. Try connecting via redis-cli first

---

## Cost Management

### Free Tier Summary

| Service | Free Tier | What's Included |
|---------|-----------|-----------------|
| **Neon PostgreSQL** | 300 compute hours/month | 0.5GB storage, multiple branches |
| **Redis Cloud** | Forever free | 30MB storage |
| **Firebase** | Spark Plan | Authentication Unlimited, FCM Unlimited, Storage 5GB |
| **Google Maps** | $200 credit/month | ~28,000 map loads/month |
| **OpenWeatherMap** | 1,000 calls/day | Weather & AQI data |

### Staying Within Free Tiers

1. **Neon**: Database auto-pauses after inactivity (saves compute hours)
2. **Redis**: 30MB is sufficient for sessions and cache
3. **Firebase**: Free tier generous for development
4. **Google Maps**: Use caching to reduce API calls
5. **Weather API**: Cache weather data (updates every 15 minutes)

### Monitoring Costs

- Set up billing alerts in each service
- Check usage dashboards regularly
- Use environment variables to switch to mock services in development

---

## Next Steps

Once you've configured all external services:

1. Continue with [Backend Setup](backend-setup.md)
2. Setup [Frontend Development](frontend-setup.md)
3. Setup [Mobile Development](mobile-setup.md)
4. Read [Development Best Practices](../development.md#best-practices)

**Related Guides:**

- [Setup Overview](overview.md)
- [Backend Setup](backend-setup.md)
- [Frontend Setup](frontend-setup.md)
- [Mobile Setup](mobile-setup.md)

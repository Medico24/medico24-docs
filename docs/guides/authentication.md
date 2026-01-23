# Authentication Guide

## Overview

This guide covers authentication and authorization mechanisms across all components of the Medico24 platform.

## Authentication Strategy

### JWT-Based Authentication

The platform uses JSON Web Tokens (JWT) for stateless authentication:

- **Access Tokens:** Short-lived (15 minutes) for API access
- **Refresh Tokens:** Long-lived (7 days) for token renewal
- **Secure Storage:** Tokens stored in secure storage on mobile, httpOnly cookies on web

### Multi-Factor Authentication (MFA)

Optional MFA support using:
- SMS-based OTP
- Time-based OTP (TOTP)
- Email verification

## Backend Authentication

### JWT Implementation

#### Token Structure

```python
# app/auth.py
import jwt
from datetime import datetime, timedelta
from typing import Optional

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_refresh_token(data: dict):
    """Create JWT refresh token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=7)
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(token: str):
    """Verify and decode JWT token."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

#### Authentication Endpoints

```python
# app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

router = APIRouter(prefix="/auth")
security = HTTPBearer()

@router.post("/register")
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Register new user."""
    # Check if user exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Hash password
    hashed_password = get_password_hash(user_data.password)
    
    # Create user
    user = User(
        email=user_data.email,
        hashed_password=hashed_password,
        full_name=user_data.full_name
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    
    # Create tokens
    access_token = create_access_token({"sub": user.email, "user_id": user.id})
    refresh_token = create_refresh_token({"sub": user.email, "user_id": user.id})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": UserResponse.from_orm(user)
    }

@router.post("/login")
async def login(form_data: UserLogin, db: Session = Depends(get_db)):
    """Authenticate user and return tokens."""
    # Verify user credentials
    user = authenticate_user(db, form_data.email, form_data.password)
    if not user:
        raise HTTPException(
            status_code=401,
            detail="Incorrect email or password"
        )
    
    # Create tokens
    access_token = create_access_token({"sub": user.email, "user_id": user.id})
    refresh_token = create_refresh_token({"sub": user.email, "user_id": user.id})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": UserResponse.from_orm(user)
    }

@router.post("/refresh")
async def refresh_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Refresh access token using refresh token."""
    token = credentials.credentials
    payload = verify_token(token)
    
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid token type")
    
    # Create new access token
    access_token = create_access_token({
        "sub": payload.get("sub"),
        "user_id": payload.get("user_id")
    })
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

@router.post("/logout")
async def logout(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Logout user (add token to blacklist)."""
    token = credentials.credentials
    # Add token to blacklist (implement based on your needs)
    blacklist_token(token)
    return {"message": "Successfully logged out"}
```

#### Password Security

```python
# app/security.py
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """Hash password using bcrypt."""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash."""
    return pwd_context.verify(plain_password, hashed_password)

def authenticate_user(db: Session, email: str, password: str):
    """Authenticate user credentials."""
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user
```

#### Protected Routes

```python
# app/dependencies.py
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """Get current authenticated user."""
    token = credentials.credentials
    payload = verify_token(token)
    
    if payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid token type")
    
    user_id = payload.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    return user

async def get_current_active_user(
    current_user: User = Depends(get_current_user)
):
    """Get current active user."""
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# Usage in protected endpoints
@router.get("/profile")
async def get_profile(current_user: User = Depends(get_current_active_user)):
    """Get user profile."""
    return UserResponse.from_orm(current_user)
```

## Mobile App Authentication

### Flutter Implementation

#### Auth Service

```dart
// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'https://api.medico24.com';
  static const storage = FlutterSecureStorage();
  
  static Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Store tokens securely
        await storage.write(key: 'access_token', value: data['access_token']);
        await storage.write(key: 'refresh_token', value: data['refresh_token']);
        
        return AuthResult.success(
          user: User.fromJson(data['user']),
          token: data['access_token'],
        );
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      return AuthResult.error('Network error: $e');
    }
  }
  
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Store tokens securely
        await storage.write(key: 'access_token', value: data['access_token']);
        await storage.write(key: 'refresh_token', value: data['refresh_token']);
        
        return AuthResult.success(
          user: User.fromJson(data['user']),
          token: data['access_token'],
        );
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      return AuthResult.error('Network error: $e');
    }
  }
  
  static Future<void> logout() async {
    try {
      final token = await storage.read(key: 'access_token');
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      // Handle logout error
    } finally {
      // Always clear local tokens
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
    }
  }
  
  static Future<String?> getValidToken() async {
    final accessToken = await storage.read(key: 'access_token');
    if (accessToken == null) return null;
    
    // Check if token is expired
    if (isTokenExpired(accessToken)) {
      final refreshed = await refreshToken();
      return refreshed ? await storage.read(key: 'access_token') : null;
    }
    
    return accessToken;
  }
  
  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await storage.write(key: 'access_token', value: data['access_token']);
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      );
      final exp = payload['exp'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return currentTime >= exp;
    } catch (e) {
      return true;
    }
  }
}
```

#### HTTP Interceptor

```dart
// lib/services/http_interceptor.dart
import 'package:http_interceptor/http_interceptor.dart';
import 'auth_service.dart';

class AuthInterceptor implements InterceptorContract {
  @override
  Future<RequestData> interceptRequest({required RequestData data}) async {
    final token = await AuthService.getValidToken();
    if (token != null) {
      data.headers['Authorization'] = 'Bearer $token';
    }
    return data;
  }

  @override
  Future<ResponseData> interceptResponse({required ResponseData data}) async {
    // Handle 401 responses
    if (data.statusCode == 401) {
      // Token expired, try to refresh
      final refreshed = await AuthService.refreshToken();
      if (!refreshed) {
        // Redirect to login
        NavigationService.instance.pushReplacementNamed('/login');
      }
    }
    return data;
  }
}
```

### State Management

```dart
// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await AuthService.register(
      email: email,
      password: password,
      fullName: fullName,
    );

    if (result.isSuccess) {
      _user = result.user;
    } else {
      _error = result.error;
    }

    _setLoading(false);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    final result = await AuthService.login(
      email: email,
      password: password,
    );

    if (result.isSuccess) {
      _user = result.user;
    } else {
      _error = result.error;
    }

    _setLoading(false);
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
```

## Web Dashboard Authentication

### Next.js Implementation

#### Auth Context

```typescript
// contexts/AuthContext.tsx
import React, { createContext, useContext, useEffect, useState } from 'react';
import { User } from '../types/user';
import { authApi } from '../lib/api';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, fullName: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    try {
      const token = localStorage.getItem('access_token');
      if (token) {
        const user = await authApi.getProfile();
        setUser(user);
      }
    } catch (error) {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
    } finally {
      setLoading(false);
    }
  };

  const login = async (email: string, password: string) => {
    setLoading(true);
    setError(null);

    try {
      const response = await authApi.login(email, password);
      
      localStorage.setItem('access_token', response.access_token);
      localStorage.setItem('refresh_token', response.refresh_token);
      
      setUser(response.user);
    } catch (error) {
      setError('Login failed. Please check your credentials.');
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const register = async (email: string, password: string, fullName: string) => {
    setLoading(true);
    setError(null);

    try {
      const response = await authApi.register(email, password, fullName);
      
      localStorage.setItem('access_token', response.access_token);
      localStorage.setItem('refresh_token', response.refresh_token);
      
      setUser(response.user);
    } catch (error) {
      setError('Registration failed. Please try again.');
      throw error;
    } finally {
      setLoading(false);
    }
  };

  const logout = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{
      user,
      loading,
      error,
      login,
      register,
      logout,
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
```

#### API Client

```typescript
// lib/api.ts
import axios, { AxiosInstance } from 'axios';

class ApiClient {
  private api: AxiosInstance;

  constructor() {
    this.api = axios.create({
      baseURL: process.env.NEXT_PUBLIC_API_URL,
      timeout: 10000,
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor
    this.api.interceptors.request.use((config) => {
      const token = localStorage.getItem('access_token');
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    });

    // Response interceptor
    this.api.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          const refreshToken = localStorage.getItem('refresh_token');
          
          if (refreshToken) {
            try {
              const response = await this.api.post('/auth/refresh', {}, {
                headers: { Authorization: `Bearer ${refreshToken}` }
              });
              
              const newToken = response.data.access_token;
              localStorage.setItem('access_token', newToken);
              
              // Retry original request
              error.config.headers.Authorization = `Bearer ${newToken}`;
              return this.api.request(error.config);
            } catch (refreshError) {
              // Refresh failed, redirect to login
              localStorage.removeItem('access_token');
              localStorage.removeItem('refresh_token');
              window.location.href = '/login';
            }
          } else {
            // No refresh token, redirect to login
            window.location.href = '/login';
          }
        }
        
        throw error;
      }
    );
  }

  async login(email: string, password: string) {
    const response = await this.api.post('/auth/login', { email, password });
    return response.data;
  }

  async register(email: string, password: string, fullName: string) {
    const response = await this.api.post('/auth/register', {
      email,
      password,
      full_name: fullName,
    });
    return response.data;
  }

  async getProfile() {
    const response = await this.api.get('/auth/profile');
    return response.data;
  }
}

export const authApi = new ApiClient();
```

#### Protected Routes

```typescript
// components/ProtectedRoute.tsx
import { useAuth } from '../contexts/AuthContext';
import { useRouter } from 'next/router';
import { useEffect } from 'react';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRole?: string;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({
  children,
  requiredRole,
}) => {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading) {
      if (!user) {
        router.push('/login');
        return;
      }

      if (requiredRole && user.role !== requiredRole) {
        router.push('/unauthorized');
        return;
      }
    }
  }, [user, loading, requiredRole, router]);

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!user) {
    return null;
  }

  if (requiredRole && user.role !== requiredRole) {
    return null;
  }

  return <>{children}</>;
};
```

## Security Best Practices

### Token Security

1. **Access Token Expiration:**
   - Keep access tokens short-lived (15-30 minutes)
   - Use refresh tokens for longer sessions

2. **Secure Storage:**
   - Mobile: Use FlutterSecureStorage or Keychain
   - Web: Use httpOnly cookies for production
   - Never store tokens in plain localStorage in production

3. **Token Rotation:**
   - Implement refresh token rotation
   - Invalidate old refresh tokens

### Password Security

1. **Password Requirements:**
   ```typescript
   const passwordSchema = z.string()
     .min(8, 'Password must be at least 8 characters')
     .regex(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, 
       'Password must contain uppercase, lowercase, and number');
   ```

2. **Rate Limiting:**
   ```python
   from slowapi import Limiter, _rate_limit_exceeded_handler
   from slowapi.util import get_remote_address

   limiter = Limiter(key_func=get_remote_address)

   @app.post("/auth/login")
   @limiter.limit("5/minute")
   async def login(request: Request, form_data: UserLogin):
       # Login logic
   ```

3. **Account Lockout:**
   - Lock accounts after failed attempts
   - Implement exponential backoff

### CSRF Protection

```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';

export function middleware(request: NextRequest) {
  // CSRF token validation
  const csrfToken = request.headers.get('x-csrf-token');
  const sessionToken = request.cookies.get('session-token');
  
  if (!validateCSRFToken(csrfToken, sessionToken)) {
    return NextResponse.json({ error: 'Invalid CSRF token' }, { status: 403 });
  }
  
  return NextResponse.next();
}
```

## Multi-Factor Authentication

### TOTP Implementation

```python
# app/mfa.py
import pyotp
import qrcode
from io import BytesIO

def generate_totp_secret():
    """Generate TOTP secret for user."""
    return pyotp.random_base32()

def generate_qr_code(user_email: str, secret: str) -> str:
    """Generate QR code for TOTP setup."""
    totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
        name=user_email,
        issuer_name="Medico24"
    )
    
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(totp_uri)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = BytesIO()
    img.save(buffer, format="PNG")
    
    return base64.b64encode(buffer.getvalue()).decode()

def verify_totp(secret: str, token: str) -> bool:
    """Verify TOTP token."""
    totp = pyotp.TOTP(secret)
    return totp.verify(token, valid_window=1)
```

## Social Authentication

### Google OAuth

```python
# app/oauth.py
from authlib.integrations.starlette_client import OAuth

oauth = OAuth()

oauth.register(
    name='google',
    client_id=settings.GOOGLE_CLIENT_ID,
    client_secret=settings.GOOGLE_CLIENT_SECRET,
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={
        'scope': 'openid email profile'
    }
)

@router.get('/auth/google')
async def google_auth(request: Request):
    """Initiate Google OAuth flow."""
    redirect_uri = request.url_for('google_callback')
    return await oauth.google.authorize_redirect(request, redirect_uri)

@router.get('/auth/google/callback')
async def google_callback(request: Request, db: Session = Depends(get_db)):
    """Handle Google OAuth callback."""
    token = await oauth.google.authorize_access_token(request)
    user_info = token.get('userinfo')
    
    # Find or create user
    user = db.query(User).filter(User.email == user_info['email']).first()
    if not user:
        user = User(
            email=user_info['email'],
            full_name=user_info['name'],
            is_active=True,
            oauth_provider='google'
        )
        db.add(user)
        db.commit()
    
    # Create tokens
    access_token = create_access_token({"sub": user.email, "user_id": user.id})
    refresh_token = create_refresh_token({"sub": user.email, "user_id": user.id})
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": UserResponse.from_orm(user)
    }
```

## Resources

- [JWT Best Practices](https://auth0.com/blog/a-look-at-the-latest-draft-for-jwt-bcp/)
- [OAuth 2.0 Security](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [NextAuth.js](https://next-auth.js.org/)
- [OWASP Authentication](https://owasp.org/www-project-top-ten/2017/A2_2017-Broken_Authentication)
# API Overview

**Medico24** provides a comprehensive REST API built with FastAPI that enables healthcare appointment management, pharmacy search, and environmental data access.

## Base Information

- **Production URL**: `https://api.medico24.com/api/v1`
- **Development URL**: `http://localhost:8000/api/v1`
- **API Version**: 2.0
- **Authentication**: Bearer Token (JWT)
- **Format**: JSON
- **Protocol**: HTTPS (Production), HTTP (Development)

## Quick Start

### Authentication Flow

1. **Google Sign-In**: Users authenticate via Firebase Google OAuth
2. **Token Exchange**: Firebase ID token is exchanged for JWT tokens
3. **API Access**: Use access token in Authorization header
4. **Token Refresh**: Refresh tokens when access token expires

### Example Request

```bash
curl -H "Authorization: Bearer <access_token>" \
     https://api.medico24.com/api/v1/users/me
```

## Core Endpoints

### Authentication
- `POST /auth/firebase/verify` - Exchange Firebase token for JWT
- `POST /auth/refresh` - Refresh access token
- `POST /auth/logout` - Logout and revoke tokens

### Users
- `GET /users/me` - Get current user profile
- `PATCH /users/me` - Update user profile
- `POST /users/me/onboard` - Complete user onboarding

### Appointments
- `POST /appointments/` - Create new appointment
- `GET /appointments/` - List user appointments
- `GET /appointments/{id}` - Get appointment details
- `PUT /appointments/{id}` - Update appointment
- `PATCH /appointments/{id}/status` - Update appointment status

### Doctors
- `POST /doctors/` - Create doctor profile
- `GET /doctors/` - List doctors with filters
- `GET /doctors/search` - Search doctors
- `GET /doctors/{id}` - Get doctor details
- `GET /doctors/user/{user_id}` - Get doctor by user ID
- `PUT /doctors/{id}` - Update doctor profile
- `GET /doctors/nearby` - Search nearby doctors
- `POST /doctors/{id}/verify` - Verify doctor (Admin)
- `POST /doctors/{id}/unverify` - Unverify doctor (Admin)

### Clinics
- `POST /clinics/` - Create clinic (Admin)
- `GET /clinics/` - List clinics
- `GET /clinics/search` - Search clinics
- `GET /clinics/nearby` - Search nearby clinics
- `GET /clinics/{id}` - Get clinic details
- `GET /clinics/slug/{slug}` - Get clinic by slug
- `PUT /clinics/{id}` - Update clinic (Admin)
- `DELETE /clinics/{id}` - Delete clinic (Admin)
- `POST /clinics/{clinic_id}/doctors` - Add doctor to clinic (Admin)
- `GET /clinics/{clinic_id}/doctors` - List clinic's doctors
- `GET /clinics/doctors/{doctor_id}/clinics` - List doctor's clinics

### Pharmacies
- `GET /pharmacies` - List pharmacies
- `GET /pharmacies/search/nearby` - Search nearby pharmacies
- `GET /pharmacies/{id}` - Get pharmacy details

### Environmental Data
- `GET /environment/conditions` - Get real-time AQI and weather data

### Notifications
- `POST /notifications/register-token` - Register FCM device token
- `POST /notifications/send` - Send push notification
- `DELETE /notifications/deactivate-token` - Deactivate device token

### Admin (Admin Role Required)
- `GET /admin/users` - List all users
- `GET /admin/appointments` - List all appointments
- `GET /admin/metrics` - System metrics
- `POST /admin/notifications/broadcast` - Broadcast notifications

## Response Format

### Success Response
```json
{
  "status": "success",
  "data": { ... }
}
```

### Error Response
```json
{
  "detail": "Error message"
}
```

### Paginated Response
```json
{
  "items": [...],
  "page": 1,
  "page_size": 20,
  "total_items": 100,
  "total_pages": 5
}
```

## Status Codes

- `200 OK` - Request successful
- `201 Created` - Resource created
- `204 No Content` - Success with no response body
- `400 Bad Request` - Invalid request
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation error
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error
- `503 Service Unavailable` - Service temporarily down

## Rate Limiting

- **Authenticated Users**: 1000 requests per hour
- **Unauthenticated**: 100 requests per hour
- **Admin Operations**: 5000 requests per hour

Rate limit headers are included in all responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1643723400
```

## SDKs & Clients

### Official SDKs
- **Flutter**: Built-in Dio HTTP client
- **JavaScript**: Fetch API / Axios
- **Python**: httpx / requests

### Example Implementations

#### Flutter (Dart)
```dart
class ApiClient {
  final Dio _dio = Dio();
  
  Future<Response> get(String path, {String? token}) async {
    return await _dio.get(
      'https://api.medico24.com/api/v1$path',
      options: Options(headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      }),
    );
  }
}
```

#### JavaScript
```javascript
class ApiClient {
  constructor(baseURL = 'https://api.medico24.com/api/v1') {
    this.baseURL = baseURL;
  }
  
  async get(path, token) {
    const response = await fetch(`${this.baseURL}${path}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    return response.json();
  }
}
```

## Testing

### API Testing Tools
- **Postman Collection**: Available in repository
- **OpenAPI/Swagger**: `http://localhost:8000/docs`
- **pytest**: Comprehensive test suite

### Test Environments
- **Development**: `http://localhost:8000`
- **Staging**: `https://staging-api.medico24.com`
- **Production**: `https://api.medico24.com`

## API Categories

### Healthcare Management
- [Doctors](specifications.md#doctor-endpoints) - Complete doctor profile management
- [Clinics](specifications.md#clinic-endpoints) - Clinic management and doctor-clinic associations
- [Appointments](specifications.md#appointment-endpoints) - Appointment booking system

### Location Services
- [Pharmacies](specifications.md#pharmacy-endpoints) - Pharmacy search with geolocation
- [Environmental Data](specifications.md#environmental-endpoints) - AQI and weather data

### User & Admin
- [Authentication](specifications.md#authentication-endpoints) - Firebase JWT authentication
- [Users](specifications.md#user-endpoints) - User profile management
- [Admin](specifications.md#admin-endpoints) - Administrative operations

## Next Steps

- [API Specifications](specifications.md) - Detailed endpoint documentation
- [Authentication Guide](../guides/authentication.md) - Authentication implementation
- [Error Handling](../guides/error-handling.md) - Error handling best practices
- [Rate Limiting](../guides/rate-limiting.md) - Rate limiting details
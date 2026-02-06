# Medico24 - API Specifications

**Version:** 2.0  
**Base URL:** `https://api.medico24.com/api/v1` (Production)  
**Base URL:** `http://localhost:8000/api/v1` (Development)  
**Last Updated:** January 31, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Common Response Formats](#common-response-formats)
4. [Error Handling](#error-handling)
5. [API Endpoints](#api-endpoints)
   - [Health Check](#health-check)
   - [Authentication](#authentication-endpoints)
   - [Users](#user-endpoints)
   - [Doctors](#doctor-endpoints)
   - [Clinics](#clinic-endpoints)
   - [Appointments](#appointment-endpoints)
   - [Pharmacies](#pharmacy-endpoints)
   - [Environmental](#environmental-endpoints)
   - [Notifications](#notification-endpoints)
   - [Admin](#admin-endpoints)
6. [Data Models](#data-models)
7. [Rate Limiting](#rate-limiting)
8. [Versioning](#versioning)

---

## Overview

The Medico24 API is a RESTful API built with FastAPI that provides healthcare appointment management, pharmacy search, and environmental data functionality.

### Key Features

- Firebase-based authentication with JWT tokens
- JWT token management (access + refresh)
- Doctor profile management with verification system
- Clinic management with doctor associations
- Appointment CRUD operations
- Geographic search (doctors, clinics, pharmacies)
- Real-time environmental data (AQI, weather)
- Push notifications (FCM)
- Admin console and dashboard
- Admin notification broadcasting
- User and appointment management
- Pharmacy verification system
- Role-based access control (Patient/Doctor/Admin)
- Comprehensive error handling
- Request validation with Pydantic
- Comprehensive test coverage (pytest)

### API Characteristics

- **Protocol**: HTTPS (Production), HTTP (Development)
- **Format**: JSON
- **Authentication**: Bearer Token (JWT)
- **Encoding**: UTF-8
- **Datetime Format**: ISO 8601 (UTC)

---

## Authentication

### Authentication Flow

```
1. User authenticates with Google via Firebase
2. Flutter app receives Firebase ID Token
3. App sends ID Token to POST /auth/firebase/verify
4. Backend verifies token with Firebase Admin SDK
5. Backend returns JWT access token + refresh token
6. App includes access token in Authorization header
7. When access token expires, use refresh token
```

```
┌──────────┐                  ┌────────────┐              ┌──────────┐
│  Flutter │                  │  Firebase  │              │ Backend  │
│   App    │                  │   Auth     │              │  API     │
└────┬─────┘                  └─────┬──────┘              └────┬─────┘
     │                              │                          │
     │ 1. Google Sign-In            │                          │
     │─────────────────────────────>│                          │
     │                              │                          │
     │ 2. Firebase ID Token         │                          │
     │<─────────────────────────────│                          │
     │                              │                          │
     │ 3. POST /auth/firebase/verify                           │
     │    {id_token: "..."}                                    │
     │────────────────────────────────────────────────────────>│
     │                              │                          │
     │                              │  4. Verify Token         │
     │                              │<─────────────────────────│
     │                              │                          │
     │                              │  5. Token Valid          │
     │                              │─────────────────────────>│
     │                              │                          │
     │ 6. JWT Access + Refresh Token                           │
     │<────────────────────────────────────────────────────────│
     │                              │                          │
     │ 7. All API Requests with Bearer Token                   │
     │────────────────────────────────────────────────────────>│
     │                              │                          │
     │ 8. If 401, refresh Firebase token                       │
     │    Re-authenticate automatically                        │
     │────────────────────────────────────────────────────────>│
```

### Using Authentication

All authenticated endpoints require a Bearer token in the Authorization header:

```http
Authorization: Bearer <access_token>
```

### Token Expiry

- **Access Token**: 30 minutes
- **Refresh Token**: 7 days

### Token Refresh

When access token expires, call `POST /auth/refresh` with refresh token to get new tokens.

---

## Common Response Formats

### Success Response

```json
{
  "status": "success",
  "data": { ... }
}
```

### Paginated Response

```json
{
  "items": [ ... ],
  "total": 100,
  "page": 1,
  "page_size": 20,
  "total_pages": 5
}
```

---

## Error Handling

### Error Response Format

```json
{
  "detail": "Error message describing what went wrong"
}
```

### HTTP Status Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 200 | OK | Request successful |
| 201 | Created | Resource created successfully |
| 204 | No Content | Success with no response body |
| 400 | Bad Request | Invalid request data |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 422 | Unprocessable Entity | Validation error |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service temporarily down |

### Validation Errors

```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "invalid email format",
      "type": "value_error.email"
    }
  ]
}
```

---

## API Endpoints

## Health Check

### GET /health

Basic health check endpoint.

**Authentication**: Not required

**Response**: `200 OK`

```json
{
  "status": "healthy",
  "version": "0.1.0",
  "environment": "production"
}
```

---

### GET /health/detailed

Detailed health check with database and Redis status.

**Authentication**: Not required

**Response**: `200 OK`

```json
{
  "status": "healthy",
  "version": "0.1.0",
  "environment": "production",
  "database": "connected",
  "redis": "connected"
}
```

---

### GET /ping

Simple ping endpoint for uptime monitoring.

**Authentication**: Not required

**Response**: `200 OK`

```json
{
  "message": "pong"
}
```

---

## Authentication Endpoints

### POST /auth/firebase/verify

Verify Firebase ID token and get JWT tokens.

**Authentication**: Not required (but requires Firebase ID token)

**Request Body**:

```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6..."
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id_token | string | Yes | Firebase ID token from Google Sign-In |

**Response**: `200 OK`

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "email": "user@example.com",
    "name": "John Doe",
    "picture": "https://lh3.googleusercontent.com/...",
    "is_active": true
  }
}
```

**Errors**:
- `400 Bad Request`: Invalid or expired Firebase token
- `500 Internal Server Error`: Firebase verification failed

---

### POST /auth/refresh

Refresh access token using refresh token.

**Authentication**: Not required (but requires refresh token)

**Request Body**:

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response**: `200 OK`

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or expired refresh token

---

### POST /auth/logout

Logout and revoke refresh token.

**Authentication**: Not required (but requires refresh token)

**Request Body**:

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response**: `204 No Content`

---

## User Endpoints

### GET /users/me

Get current user's profile.

**Authentication**: Required

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "firebase_uid": "firebase_uid_here",
  "email": "user@example.com",
  "email_verified": true,
  "full_name": "John Doe",
  "given_name": "John",
  "family_name": "Doe",
  "photo_url": "https://lh3.googleusercontent.com/...",
  "phone": "+1234567890",
  "role": "patient",
  "is_active": true,
  "is_onboarded": true,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-20T14:45:00Z",
  "last_login_at": "2026-01-02T08:20:00Z"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: User not found

---

### PATCH /users/me

Update current user's profile.

**Authentication**: Required

**Request Body**:

```json
{
  "full_name": "John Smith",
  "phone": "+1234567890"
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| full_name | string | No | User's full name |
| phone | string | No | Phone number |
| given_name | string | No | First name |
| family_name | string | No | Last name |

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "email": "user@example.com",
  "full_name": "John Smith",
  "phone": "+1234567890",
  ...
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: User not found
- `422 Unprocessable Entity`: Validation error

---

### POST /users/me/onboard

Mark user as onboarded (completes initial setup).

**Authentication**: Required

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "email": "user@example.com",
  "is_onboarded": true,
  ...
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: User not found

---

### GET /users/{user_id}/profile

Get public profile of another user.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| user_id | UUID | User ID |

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "full_name": "Jane Doe",
  "photo_url": "https://lh3.googleusercontent.com/...",
  "role": "doctor"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: User not found or inactive

---

### DELETE /users/me

Deactivate current user's account (soft delete).

**Authentication**: Required

**Response**: `204 No Content`

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: User not found

---

## Appointment Endpoints

### POST /appointments/

Create a new appointment.

**Authentication**: Required

**Request Body**:

```json
{
  "doctor_name": "Dr. Sarah Johnson",
  "clinic_name": "City Medical Center",
  "appointment_at": "2026-01-15T14:00:00Z",
  "appointment_end_at": "2026-01-15T14:30:00Z",
  "reason": "Annual checkup",
  "contact_phone": "+1234567890",
  "notes": "Please bring previous medical records"
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| doctor_name | string | Yes | Doctor's name |
| clinic_name | string | No | Clinic name |
| appointment_at | datetime | Yes | Appointment start time (ISO 8601) |
| appointment_end_at | datetime | No | Appointment end time |
| reason | string | Yes | Reason for appointment |
| contact_phone | string | Yes | Contact phone number |
| notes | string | No | Additional notes |
| doctor_id | UUID | No | Doctor user ID (if known) |
| clinic_id | UUID | No | Clinic ID (if known) |

**Response**: `201 Created`

```json
{
  "id": "987e6543-e21b-12d3-a456-426614174000",
  "patient_id": "123e4567-e89b-12d3-a456-426614174000",
  "doctor_id": null,
  "clinic_id": null,
  "doctor_name": "Dr. Sarah Johnson",
  "clinic_name": "City Medical Center",
  "appointment_at": "2026-01-15T14:00:00Z",
  "appointment_end_at": "2026-01-15T14:30:00Z",
  "reason": "Annual checkup",
  "contact_phone": "+1234567890",
  "status": "scheduled",
  "notes": "Please bring previous medical records",
  "source": "patient_app",
  "created_at": "2026-01-02T10:00:00Z",
  "updated_at": "2026-01-02T10:00:00Z",
  "cancelled_at": null
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `422 Unprocessable Entity`: Validation error

---

### GET /appointments/

List appointments for the authenticated user.

**Authentication**: Required

**Query Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| status | string | No | - | Filter by status (scheduled, confirmed, cancelled, etc.) |
| doctor_id | UUID | No | - | Filter by doctor ID |
| clinic_id | UUID | No | - | Filter by clinic ID |
| from_date | datetime | No | - | Filter from date (ISO 8601) |
| to_date | datetime | No | - | Filter to date (ISO 8601) |
| page | integer | No | 1 | Page number (min: 1) |
| page_size | integer | No | 20 | Items per page (min: 1, max: 100) |

**Response**: `200 OK`

```json
{
  "items": [
    {
      "id": "987e6543-e21b-12d3-a456-426614174000",
      "doctor_name": "Dr. Sarah Johnson",
      "appointment_at": "2026-01-15T14:00:00Z",
      "status": "scheduled",
      ...
    }
  ],
  "total": 10,
  "page": 1,
  "page_size": 20,
  "total_pages": 1
}
```

**Valid Status Values**:
- `scheduled`
- `confirmed`
- `rescheduled`
- `cancelled`
- `completed`
- `no_show`

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `422 Unprocessable Entity`: Invalid query parameters

---

### GET /appointments/{appointment_id}

Get a specific appointment by ID.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| appointment_id | UUID | Appointment ID |

**Response**: `200 OK`

```json
{
  "id": "987e6543-e21b-12d3-a456-426614174000",
  "patient_id": "123e4567-e89b-12d3-a456-426614174000",
  "doctor_name": "Dr. Sarah Johnson",
  "clinic_name": "City Medical Center",
  "appointment_at": "2026-01-15T14:00:00Z",
  "status": "scheduled",
  ...
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to view this appointment
- `404 Not Found`: Appointment not found

---

### PUT /appointments/{appointment_id}

Update an existing appointment.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| appointment_id | UUID | Appointment ID |

**Request Body**:

```json
{
  "doctor_name": "Dr. Michael Brown",
  "appointment_at": "2026-01-16T15:00:00Z",
  "reason": "Follow-up consultation"
}
```

**Request Schema**: Same as POST /appointments/ but all fields are optional

**Response**: `200 OK`

```json
{
  "id": "987e6543-e21b-12d3-a456-426614174000",
  "doctor_name": "Dr. Michael Brown",
  "appointment_at": "2026-01-16T15:00:00Z",
  "reason": "Follow-up consultation",
  "updated_at": "2026-01-02T11:30:00Z",
  ...
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to update this appointment
- `404 Not Found`: Appointment not found
- `422 Unprocessable Entity`: Validation error

---

### PATCH /appointments/{appointment_id}/status

Update appointment status.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| appointment_id | UUID | Appointment ID |

**Request Body**:

```json
{
  "status": "cancelled",
  "notes": "Unable to make it, will reschedule"
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| status | string | Yes | New status (scheduled, confirmed, cancelled, completed, no_show) |
| notes | string | No | Additional notes |

**Response**: `200 OK`

```json
{
  "id": "987e6543-e21b-12d3-a456-426614174000",
  "status": "cancelled",
  "cancelled_at": "2026-01-02T12:00:00Z",
  "notes": "Unable to make it, will reschedule",
  ...
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to update this appointment
- `404 Not Found`: Appointment not found
- `422 Unprocessable Entity`: Invalid status

---

### DELETE /appointments/{appointment_id}

Delete (soft delete) an appointment.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| appointment_id | UUID | Appointment ID |

**Response**: `204 No Content`

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to delete this appointment
- `404 Not Found`: Appointment not found

---

## Doctor Endpoints

### POST /doctors/

Create a new doctor profile.

**Authentication**: Required

**Request Body**:

```json
{
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "license_number": "LIC-123456",
  "specialization": "Cardiology",
  "sub_specialization": "Interventional Cardiology",
  "qualification": "MBBS, MD (Cardiology), DM (Cardiology)",
  "experience_years": 10,
  "consultation_fee": 150.00,
  "consultation_duration_minutes": 30,
  "bio": "Experienced cardiologist...",
  "languages_spoken": ["English", "Spanish"],
  "medical_council_registration": "MCI123456"
}
```

**Response**: `201 Created`

```json
{
  "id": "987e6543-e21b-12d3-a456-426614174000",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "license_number": "LIC-123456",
  "specialization": "Cardiology",
  "is_verified": false,
  "rating": null,
  "created_at": "2026-02-07T10:30:00Z"
}
```

**Errors**:
- `400 Bad Request`: Duplicate license number or user already has doctor profile
- `401 Unauthorized`: Invalid or missing token

---

### GET /doctors/

List doctors with optional filters.

**Authentication**: Not required

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| skip | integer | 0 | Pagination offset |
| limit | integer | 20 | Results per page (max: 100) |
| specialization | string | - | Filter by specialization |
| min_experience | integer | - | Minimum years of experience |
| is_verified | boolean | - | Filter by verification status |
| min_rating | float | - | Minimum rating (0-5) |

**Response**: `200 OK`

```json
[
  {
    "id": "987e6543-e21b-12d3-a456-426614174000",
    "full_name": "Dr. John Smith",
    "specialization": "Cardiology",
    "experience_years": 10,
    "consultation_fee": 150.00,
    "is_verified": true,
    "rating": 4.5
  }
]
```

---

### GET /doctors/{doctor_id}

Get detailed doctor information.

**Authentication**: Not required

**Response**: `200 OK`

```json
{
  "id": "987e6543-e21b-12d3-a456-426614174000",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "license_number": "LIC-123456",
  "specialization": "Cardiology",
  "sub_specialization": "Interventional Cardiology",
  "qualification": "MBBS, MD, DM",
  "experience_years": 10,
  "consultation_fee": 150.00,
  "bio": "Experienced cardiologist...",
  "is_verified": true,
  "rating": 4.5,
  "rating_count": 25,
  "full_name": "Dr. John Smith",
  "email": "john@example.com",
  "clinics": [
    {
      "clinic_id": "abc12345-e89b-12d3-a456-426614174000",
      "clinic_name": "City Hospital",
      "is_primary": true,
      "consultation_fee": 150.00
    }
  ]
}
```

**Errors**:
- `404 Not Found`: Doctor not found

---

### PUT /doctors/{doctor_id}

Update doctor profile.

**Authentication**: Required (doctor owner or admin)

**Request Body** (all fields optional):

```json
{
  "specialization": "Cardiology",
  "experience_years": 12,
  "consultation_fee": 175.00,
  "bio": "Updated biography..."
}
```

**Response**: `200 OK`

Returns updated doctor profile.

**Errors**:
- `404 Not Found`: Doctor not found
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to update this doctor

---

### GET /doctors/nearby

Search for doctors near a location.

**Authentication**: Not required

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| latitude | float | Yes | Search center latitude (-90 to 90) |
| longitude | float | Yes | Search center longitude (-180 to 180) |
| radius_km | float | No | Search radius in km (default: 10, max: 100) |
| specialization | string | No | Filter by specialization |
| is_verified | boolean | No | Filter verified doctors (default: true) |
| min_rating | float | No | Minimum rating (0-5) |

**Response**: `200 OK`

```json
[
  {
    "id": "987e6543-e21b-12d3-a456-426614174000",
    "full_name": "Dr. John Smith",
    "specialization": "Cardiology",
    "rating": 4.5,
    "clinic_name": "City Hospital",
    "clinic_address": "123 Main St",
    "distance_km": 2.5
  }
]
```

---

### POST /doctors/{doctor_id}/verify

Verify a doctor's credentials (admin only).

**Authentication**: Required (Admin)

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| verified_by | UUID | Yes | Admin user ID |

**Request Body**:

```json
{
  "verification_documents": {
    "medical_license": "doc_id_123",
    "medical_degree": "doc_id_456"
  },
  "notes": "Verified all credentials"
}
```

**Response**: `200 OK`

```json
{
  "id": "987e6543-e21b-12d3-a456-426614174000",
  "is_verified": true,
  "verified_at": "2026-02-07T10:30:00Z",
  "verified_by": "admin-uuid"
}
```

**Errors**:
- `404 Not Found`: Doctor not found
- `403 Forbidden`: Not admin role

---

### POST /doctors/{doctor_id}/unverify

Remove doctor verification (admin only).

**Authentication**: Required (Admin)

**Response**: `200 OK`

Returns updated doctor with `is_verified: false`.

---

## Clinic Endpoints

### POST /clinics/

Create a new clinic.

**Authentication**: Required (Admin)

**Request Body**:

```json
{
  "name": "City Medical Center",
  "description": "24/7 multi-specialty clinic",
  "contacts": {
    "phone_primary": "+1234567890",
    "email": "info@citymedical.com"
  },
  "address": "123 Main St, New York, NY 10001",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "opening_hours": {
    "monday": {"open": "08:00", "close": "20:00"}
  },
  "services": ["Cardiology", "Pediatrics"]
}
```

**Response**: `201 Created`

```json
{
  "id": "abc12345-e89b-12d3-a456-426614174000",
  "name": "City Medical Center",
  "slug": "city-medical-center",
  "status": "active",
  "rating": null,
  "created_at": "2026-02-07T10:30:00Z"
}
```

**Errors**:
- `400 Bad Request`: Duplicate clinic name or slug
- `403 Forbidden`: Not admin role

---

### GET /clinics/

List clinics with optional filters.

**Authentication**: Not required

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| skip | integer | 0 | Pagination offset |
| limit | integer | 20 | Results per page (max: 100) |
| status | string | active | Filter by status |
| name | string | - | Search by name (partial match) |
| min_rating | float | - | Minimum rating (0-5) |

**Response**: `200 OK`

```json
[
  {
    "id": "abc12345-e89b-12d3-a456-426614174000",
    "name": "City Medical Center",
    "slug": "city-medical-center",
    "address": "123 Main St",
    "status": "active",
    "rating": 4.5,
    "total_doctors": 15
  }
]
```

---

### GET /clinics/{clinic_id}

Get detailed clinic information.

**Authentication**: Not required

**Response**: `200 OK`

```json
{
  "id": "abc12345-e89b-12d3-a456-426614174000",
  "name": "City Medical Center",
  "slug": "city-medical-center",
  "description": "24/7 multi-specialty clinic",
  "contacts": {
    "phone_primary": "+1234567890"
  },
  "address": "123 Main St",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "opening_hours": {},
  "services": ["Cardiology"],
  "status": "active",
  "rating": 4.5
}
```

**Errors**:
- `404 Not Found`: Clinic not found

---

### GET /clinics/slug/{slug}

Get clinic by URL-friendly slug.

**Authentication**: Not required

**Response**: `200 OK`

Same as GET /clinics/{clinic_id}

---

### PUT /clinics/{clinic_id}

Update clinic information.

**Authentication**: Required (Admin)

**Request Body** (all fields optional):

```json
{
  "name": "City Medical Center & Hospital",
  "description": "Updated description",
  "status": "active"
}
```

**Response**: `200 OK`

Returns updated clinic.

**Errors**:
- `404 Not Found`: Clinic not found
- `403 Forbidden`: Not admin role

---

### DELETE /clinics/{clinic_id}

Soft delete a clinic (sets status to permanently_closed).

**Authentication**: Required (Admin)

**Response**: `204 No Content`

**Errors**:
- `404 Not Found`: Clinic not found
- `403 Forbidden`: Not admin role

---

### GET /clinics/nearby

Search for clinics near a location.

**Authentication**: Not required

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| latitude | float | Yes | Search center latitude (-90 to 90) |
| longitude | float | Yes | Search center longitude (-180 to 180) |
| radius_km | float | No | Search radius in km (default: 10, max: 100) |
| status | string | No | Filter by status |
| min_rating | float | No | Minimum rating (0-5) |

**Response**: `200 OK`

```json
[
  {
    "id": "abc12345-e89b-12d3-a456-426614174000",
    "name": "City Medical Center",
    "address": "123 Main St",
    "distance_km": 2.5,
    "rating": 4.5
  }
]
```

---

### POST /clinics/{clinic_id}/doctors

Add a doctor to a clinic with clinic-specific settings.

**Authentication**: Required (Admin)

**Request Body**:

```json
{
  "doctor_id": "987e6543-e21b-12d3-a456-426614174000",
  "is_primary": true,
  "consultation_fee": 150.00,
  "department": "Cardiology",
  "designation": "Senior Consultant",
  "available_days": [1, 2, 3, 4, 5],
  "available_time_slots": {
    "monday": ["09:00-12:00", "14:00-18:00"]
  }
}
```

**Response**: `201 Created`

```json
{
  "id": "def45678-e89b-12d3-a456-426614174000",
  "doctor_id": "987e6543-e21b-12d3-a456-426614174000",
  "clinic_id": "abc12345-e89b-12d3-a456-426614174000",
  "is_primary": true,
  "status": "active",
  "consultation_fee": 150.00
}
```

**Errors**:
- `400 Bad Request`: Active association already exists
- `403 Forbidden`: Not admin role
- `404 Not Found`: Doctor or clinic not found

---

### GET /clinics/{clinic_id}/doctors

List all doctors at a clinic.

**Authentication**: Not required

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| active_only | boolean | true | Only show active associations |

**Response**: `200 OK`

```json
[
  {
    "doctor_id": "987e6543-e21b-12d3-a456-426614174000",
    "doctor_name": "Dr. John Smith",
    "specialization": "Cardiology",
    "department": "Cardiology",
    "consultation_fee": 150.00,
    "is_primary": true
  }
]
```

---

### GET /clinics/doctors/{doctor_id}/clinics

List all clinics for a doctor.

**Authentication**: Not required

**Response**: `200 OK`

```json
[
  {
    "clinic_id": "abc12345-e89b-12d3-a456-426614174000",
    "clinic_name": "City Medical Center",
    "clinic_address": "123 Main St",
    "is_primary": true,
    "consultation_fee": 150.00
  }
]
```

---

### DELETE /clinics/{clinic_id}/doctors/{doctor_id}

Remove a doctor from a clinic.

**Authentication**: Required (Admin)

**Response**: `204 No Content`

**Errors**:
- `404 Not Found`: Association not found
- `403 Forbidden`: Not admin role

---

## Pharmacy Endpoints

### POST /pharmacies

Create a new pharmacy (admin only).

**Authentication**: Required (Admin role)

**Request Body**:

```json
{
  "name": "HealthPlus Pharmacy",
  "description": "24/7 pharmacy with delivery service",
  "phone": "+1234567890",
  "email": "contact@healthplus.com",
  "supports_delivery": true,
  "supports_pickup": true,
  "location": {
    "address_line": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "country": "USA",
    "pincode": "10001",
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "hours": [
    {
      "day_of_week": 1,
      "open_time": "09:00:00",
      "close_time": "21:00:00",
      "is_closed": false
    }
  ]
}
```

**Response**: `201 Created`

```json
{
  "id": "456e7890-e12b-34d5-a678-901234567890",
  "name": "HealthPlus Pharmacy",
  "description": "24/7 pharmacy with delivery service",
  "phone": "+1234567890",
  "email": "contact@healthplus.com",
  "is_verified": false,
  "is_active": true,
  "rating": 0.0,
  "rating_count": 0,
  "supports_delivery": true,
  "supports_pickup": true,
  "created_at": "2026-01-02T10:00:00Z",
  "updated_at": "2026-01-02T10:00:00Z",
  "location": {
    "id": "789e0123-e45b-67d8-a901-234567890abc",
    "address_line": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "country": "USA",
    "pincode": "10001",
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "hours": [...]
}
```

---

### GET /pharmacies

List all pharmacies with optional filters.

**Authentication**: Not required (public endpoint)

**Query Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| skip | integer | No | 0 | Number of records to skip |
| limit | integer | No | 20 | Number of records to return (max: 100) |
| latitude | float | No | - | User's latitude for nearby search |
| longitude | float | No | - | User's longitude for nearby search |
| radius_km | float | No | 10.0 | Search radius in km (max: 100) |
| is_active | boolean | No | true | Filter by active status |
| is_verified | boolean | No | - | Filter by verified status |
| supports_delivery | boolean | No | - | Filter by delivery support |
| supports_pickup | boolean | No | - | Filter by pickup support |

**Response**: `200 OK`

```json
[
  {
    "id": "456e7890-e12b-34d5-a678-901234567890",
    "name": "HealthPlus Pharmacy",
    "phone": "+1234567890",
    "rating": 4.5,
    "rating_count": 120,
    "supports_delivery": true,
    "supports_pickup": true,
    "distance_km": 2.3,
    "location": {
      "address_line": "123 Main Street",
      "city": "New York",
      "latitude": 40.7128,
      "longitude": -74.0060
    }
  }
]
```

**Note**: If `latitude` and `longitude` are provided, results are sorted by distance and include `distance_km` field.

---

### GET /pharmacies/search/nearby

Search pharmacies within a specific radius (geographic search).

**Authentication**: Not required (public endpoint)

**Query Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| latitude | float | Yes | - | Search latitude |
| longitude | float | Yes | - | Search longitude |
| radius_km | float | No | 10.0 | Search radius in km (max: 100) |
| skip | integer | No | 0 | Number of records to skip |
| limit | integer | No | 20 | Number of records to return (max: 100) |
| is_active | boolean | No | true | Filter by active status |
| is_verified | boolean | No | - | Filter by verified status |
| supports_delivery | boolean | No | - | Filter by delivery support |
| supports_pickup | boolean | No | - | Filter by pickup support |

**Example Request**:

```
GET /api/v1/pharmacies/search/nearby?latitude=40.7128&longitude=-74.0060&radius_km=5
```

**Response**: `200 OK`

```json
[
  {
    "id": "456e7890-e12b-34d5-a678-901234567890",
    "name": "HealthPlus Pharmacy",
    "distance_km": 1.2,
    "rating": 4.5,
    "supports_delivery": true,
    "location": {
      "address_line": "123 Main Street",
      "city": "New York",
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    ...
  },
  {
    "id": "567e8901-e23c-45d6-a789-012345678901",
    "name": "MediCare Pharmacy",
    "distance_km": 3.5,
    "rating": 4.2,
    ...
  }
]
```

**Note**: Results are ordered by distance (closest first).

**Errors**:
- `422 Unprocessable Entity`: Invalid coordinates or parameters

---

### GET /pharmacies/{pharmacy_id}

Get detailed information about a specific pharmacy.

**Authentication**: Not required (public endpoint)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |

**Response**: `200 OK`

```json
{
  "id": "456e7890-e12b-34d5-a678-901234567890",
  "name": "HealthPlus Pharmacy",
  "description": "24/7 pharmacy with delivery service",
  "phone": "+1234567890",
  "email": "contact@healthplus.com",
  "is_verified": true,
  "is_active": true,
  "rating": 4.5,
  "rating_count": 120,
  "supports_delivery": true,
  "supports_pickup": true,
  "created_at": "2025-06-15T10:00:00Z",
  "updated_at": "2026-01-01T08:30:00Z",
  "location": {
    "id": "789e0123-e45b-67d8-a901-234567890abc",
    "address_line": "123 Main Street",
    "city": "New York",
    "state": "NY",
    "country": "USA",
    "pincode": "10001",
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "hours": [
    {
      "id": "890e1234-e56c-78d9-a012-345678901bcd",
      "day_of_week": 1,
      "open_time": "09:00:00",
      "close_time": "21:00:00",
      "is_closed": false
    },
    {
      "id": "901e2345-e67d-89e0-a123-456789012cde",
      "day_of_week": 2,
      "open_time": "09:00:00",
      "close_time": "21:00:00",
      "is_closed": false
    }
  ]
}
```

**Errors**:
- `404 Not Found`: Pharmacy not found

---

### PATCH /pharmacies/{pharmacy_id}

Update pharmacy information (admin only).

**Authentication**: Required (Admin role)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |

**Request Body**:

```json
{
  "name": "HealthPlus Pharmacy & Wellness",
  "description": "Updated description",
  "phone": "+1234567899",
  "supports_delivery": true
}
```

**Response**: `200 OK`

```json
{
  "id": "456e7890-e12b-34d5-a678-901234567890",
  "name": "HealthPlus Pharmacy & Wellness",
  "updated_at": "2026-01-02T14:30:00Z",
  ...
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Pharmacy not found

---

### DELETE /pharmacies/{pharmacy_id}

Delete a pharmacy (admin only).

**Authentication**: Required (Admin role)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |

**Response**: `204 No Content`

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Pharmacy not found

---

### PATCH /pharmacies/{pharmacy_id}/location

Update pharmacy location.

**Authentication**: Required (Admin role)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |

**Request Body**:

```json
{
  "address_line": "456 New Street",
  "city": "Brooklyn",
  "latitude": 40.6782,
  "longitude": -73.9442
}
```

**Response**: `200 OK`

```json
{
  "id": "456e7890-e12b-34d5-a678-901234567890",
  "name": "HealthPlus Pharmacy",
  "location": {
    "address_line": "456 New Street",
    "city": "Brooklyn",
    "latitude": 40.6782,
    "longitude": -73.9442
  },
  ...
}
```

---

### POST /pharmacies/{pharmacy_id}/hours

Add or update pharmacy hours for specific days.

**Authentication**: Required (Admin role)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |

**Request Body**:

```json
[
  {
    "day_of_week": 1,
    "open_time": "08:00:00",
    "close_time": "22:00:00",
    "is_closed": false
  },
  {
    "day_of_week": 7,
    "open_time": "10:00:00",
    "close_time": "18:00:00",
    "is_closed": false
  }
]
```

**Day of Week Values**:
- `1` = Monday
- `2` = Tuesday
- `3` = Wednesday
- `4` = Thursday
- `5` = Friday
- `6` = Saturday
- `7` = Sunday

**Response**: `200 OK`

```json
{
  "id": "456e7890-e12b-34d5-a678-901234567890",
  "hours": [
    {
      "id": "890e1234-e56c-78d9-a012-345678901bcd",
      "day_of_week": 1,
      "open_time": "08:00:00",
      "close_time": "22:00:00",
      "is_closed": false
    },
    ...
  ]
}
```

---

### GET /pharmacies/{pharmacy_id}/hours

Get pharmacy hours.

**Authentication**: Not required (public endpoint)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |

**Response**: `200 OK`

```json
[
  {
    "id": "890e1234-e56c-78d9-a012-345678901bcd",
    "day_of_week": 1,
    "open_time": "08:00:00",
    "close_time": "22:00:00",
    "is_closed": false
  },
  {
    "id": "901e2345-e67d-89e0-a123-456789012cde",
    "day_of_week": 2,
    "open_time": "08:00:00",
    "close_time": "22:00:00",
    "is_closed": false
  }
]
```

---

### DELETE /pharmacies/{pharmacy_id}/hours/{day_of_week}

Delete pharmacy hours for a specific day.

**Authentication**: Required (Admin role)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |
| day_of_week | integer | Day of week (1-7) |

**Response**: `204 No Content`

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Pharmacy or hours not found

---

## Environmental Endpoints

### GET /environment/conditions

Fetch real-time environmental conditions for a specific location.

**Authentication**: Not required (public endpoint)

**Query Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| lat | float | Yes | Latitude coordinate (-90 to 90) |
| lng | float | Yes | Longitude coordinate (-180 to 180) |

**Response**: `200 OK`

```json
{
  "aqi": 35,
  "aqi_category": "Good",
  "temperature": 21.3,
  "condition": "Clear sky"
}
```

**Errors**:
- `422 Unprocessable Entity`: Invalid coordinates
- `503 Service Unavailable`: Environmental data currently unavailable

---

## Notification Endpoints

### POST /notifications/register-token

Register or update a user's FCM device token for push notifications.

**Authentication**: Required

**Request Body**:

```json
{
  "fcm_token": "dXJlIGZpcmViYXNlIHRva2VuIGhlcmU...",
  "platform": "android"
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| fcm_token | string | Yes | Firebase Cloud Messaging device token |
| platform | string | Yes | Device platform (android, ios, web) |

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "789e0123-e45b-67d8-a901-234567890abc",
  "fcm_token": "dXJlIGZpcmViYXNlIHRva2VuIGhlcmU...",
  "platform": "android",
  "is_active": true,
  "created_at": "2026-01-02T10:00:00Z",
  "updated_at": "2026-01-02T10:00:00Z",
  "last_used_at": "2026-01-02T10:00:00Z"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `422 Unprocessable Entity`: Validation error

---

### DELETE /notifications/deactivate-token

Deactivate a specific FCM token.

**Authentication**: Required

**Request Body**:

```json
{
  "fcm_token": "dXJlIGZpcmViYXNlIHRva2VuIGhlcmU..."
}
```

**Response**: `200 OK`

```json
{
  "message": "Token deactivated successfully"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: Token not found

---

### DELETE /notifications/deactivate-all

Deactivate all FCM tokens for the current user.

**Authentication**: Required

**Response**: `200 OK`

```json
{
  "message": "All tokens deactivated",
  "count": 3
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token

---

### POST /notifications/send

Send a push notification to a specific user.

**Authentication**: Required

**Request Body**:

```json
{
  "user_id": "789e0123-e45b-67d8-a901-234567890abc",
  "title": "Appointment Reminder",
  "body": "You have an appointment with Dr. Smith at 2 PM tomorrow",
  "data": {
    "type": "appointment_reminder",
    "appointment_id": "456e7890-e12b-34d5-a678-901234567890"
  }
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| user_id | UUID | Yes | Target user's ID |
| title | string | Yes | Notification title (max: 100 chars) |
| body | string | Yes | Notification body (max: 500 chars) |
| data | object | No | Custom data payload (JSON) |

**Response**: `200 OK`

```json
{
  "success_count": 1,
  "failure_count": 0,
  "message": "Sent to 1 devices, 0 failed"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `404 Not Found`: User not found or has no registered devices
- `422 Unprocessable Entity`: Validation error

---

### POST /notifications/send-batch

Send push notifications to multiple users.

**Authentication**: Required

**Request Body**:

```json
{
  "user_ids": [
    "789e0123-e45b-67d8-a901-234567890abc",
    "987e6543-e21b-12d3-a456-426614174000"
  ],
  "title": "System Announcement",
  "body": "New features are now available in Medico24",
  "data": {
    "type": "announcement",
    "url": "https://medico24.com/updates"
  }
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| user_ids | array[UUID] | Yes | List of target user IDs (max: 500) |
| title | string | Yes | Notification title (max: 100 chars) |
| body | string | Yes | Notification body (max: 500 chars) |
| data | object | No | Custom data payload (JSON) |

**Response**: `200 OK`

```json
{
  "success_count": 2,
  "failure_count": 0,
  "message": "Sent to 2 devices, 0 failed"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `422 Unprocessable Entity`: Validation error (e.g., too many user_ids)

---

### POST /notifications/admin-send

Send push notification using admin secret key (for backend services).

**Authentication**: Admin Secret Key (via header)

---

## Admin Endpoints

All admin endpoints require authentication and the user must have the `admin` role. Unauthorized access returns `403 Forbidden`.

### GET /admin/users

List all users with pagination and filtering.

**Authentication**: Required (Admin role)

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number |
| page_size | integer | 20 | Items per page (max: 100) |
| role | string | null | Filter by role (patient, doctor, admin) |
| is_active | boolean | null | Filter by active status |

**Response**: `200 OK`

```json
{
  "items": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "firebase_uid": "firebase_uid_here",
      "email": "user@example.com",
      "full_name": "John Doe",
      "role": "patient",
      "is_active": true,
      "created_at": "2024-01-15T10:30:00Z",
      "last_login_at": "2026-01-02T08:20:00Z"
    }
  ],
  "total": 150,
  "page": 1,
  "page_size": 20,
  "total_pages": 8
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: User is not an admin

---

### GET /admin/appointments

List all appointments with pagination and filtering.

**Authentication**: Required (Admin role)

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number |
| page_size | integer | 20 | Items per page (max: 100) |
| status | string | null | Filter by status (scheduled, confirmed, cancelled, completed, no_show) |

**Response**: `200 OK`

```json
{
  "items": [
    {
      "id": "987e6543-e21b-12d3-a456-426614174000",
      "patient_id": "123e4567-e89b-12d3-a456-426614174000",
      "doctor_name": "Dr. Sarah Johnson",
      "clinic_name": "City Medical Center",
      "appointment_at": "2026-01-15T14:00:00Z",
      "status": "scheduled",
      "created_at": "2026-01-01T10:00:00Z"
    }
  ],
  "total": 500,
  "page": 1,
  "page_size": 20,
  "total_pages": 25
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: User is not an admin

---

### GET /admin/metrics

Get system-wide metrics and statistics.

**Authentication**: Required (Admin role)

**Response**: `200 OK`

```json
{
  "users": {
    "total": 1250,
    "active": 980,
    "by_role": {
      "patient": 1100,
      "doctor": 140,
      "admin": 10
    }
  },
  "appointments": {
    "total": 5430,
    "pending": 45,
    "confirmed": 120,
    "by_status": {
      "scheduled": 165,
      "confirmed": 120,
      "cancelled": 89,
      "completed": 4956,
      "no_show": 100
    }
  },
  "pharmacies": {
    "total": 89,
    "verified": 67,
    "active": 82
  },
  "notifications": {
    "sent_today": 234,
    "sent_this_week": 1567,
    "sent_this_month": 6789
  }
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: User is not an admin

---

### GET /admin/notifications/logs

Get notification logs with pagination.

**Authentication**: Required (Admin role)

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number |
| page_size | integer | 20 | Items per page (max: 100) |

**Response**: `200 OK`

```json
{
  "items": [
    {
      "id": "abc12345-e67f-89g0-h123-456789012def",
      "user_id": "123e4567-e89b-12d3-a456-426614174000",
      "title": "Appointment Reminder",
      "body": "You have an appointment tomorrow",
      "notification_type": "appointment_reminder",
      "is_read": false,
      "sent_at": "2026-01-02T10:00:00Z",
      "created_at": "2026-01-02T10:00:00Z"
    }
  ],
  "total": 10234,
  "page": 1,
  "page_size": 20,
  "total_pages": 512
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: User is not an admin

---

### POST /admin/notifications/broadcast

Broadcast notification to all users, patients, or pharmacies.

**Authentication**: Required (Admin role)

**Request Body**:

```json
{
  "target": "all",
  "title": "System Maintenance",
  "body": "Scheduled maintenance on Jan 5 from 2-4 AM",
  "data": {
    "type": "announcement",
    "priority": "high"
  }
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| target | string | Yes | Broadcast target: "all", "patients", "pharmacies" |
| title | string | Yes | Notification title (max: 100 chars) |
| body | string | Yes | Notification body (max: 500 chars) |
| data | object | No | Custom data payload (JSON) |

**Response**: `200 OK`

```json
{
  "success_count": 1234,
  "failure_count": 12,
  "total_users": 1246,
  "message": "Broadcast sent to 1234 users successfully"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: User is not an admin
- `422 Unprocessable Entity`: Invalid target or validation error

---

### PATCH /admin/pharmacies/{pharmacy_id}/verify

Toggle pharmacy verification status.

**Authentication**: Required (Admin role)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| pharmacy_id | UUID | Pharmacy ID |

**Response**: `200 OK`

```json
{
  "id": "456e7890-e12b-34d5-a678-901234567890",
  "name": "HealthPlus Pharmacy",
  "is_verified": true,
  "updated_at": "2026-01-02T15:30:00Z"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: User is not an admin
- `404 Not Found`: Pharmacy not found

**Headers**:

```http
X-Admin-Secret: your-admin-secret-key
Content-Type: application/json
```

**Request Body**:

```json
{
  "user_id": "789e0123-e45b-67d8-a901-234567890abc",
  "title": "Appointment Confirmed",
  "body": "Your appointment has been confirmed by the clinic",
  "data": {
    "type": "appointment_update",
    "appointment_id": "456e7890-e12b-34d5-a678-901234567890",
    "status": "confirmed"
  }
}
```

**Request Schema**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| user_id | UUID | Yes | Target user's ID |
| title | string | Yes | Notification title (max: 100 chars) |
| body | string | Yes | Notification body (max: 500 chars) |
| data | object | No | Custom data payload (JSON, all values must be strings) |

**Response**: `200 OK`

```json
{
  "success_count": 1,
  "failure_count": 0,
  "message": "Sent to 1 devices, 0 failed"
}
```

**Errors**:
- `401 Unauthorized`: Invalid admin secret key
- `404 Not Found`: User not found or has no registered devices
- `422 Unprocessable Entity`: Validation error (missing X-Admin-Secret header or invalid data)

**Note**: This endpoint is intended for server-to-server communication. The admin secret key is configured via the `ADMIN_NOTIFICATION_SECRET` environment variable.

---

### GET /notifications/history

Get notification history for the current user.

**Authentication**: Required

**Query Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| skip | integer | No | 0 | Number of records to skip |
| limit | integer | No | 20 | Number of records to return (max: 100) |
| is_read | boolean | No | - | Filter by read status |

**Response**: `200 OK`

```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "789e0123-e45b-67d8-a901-234567890abc",
    "title": "Appointment Reminder",
    "body": "You have an appointment with Dr. Smith at 2 PM tomorrow",
    "data": {
      "type": "appointment_reminder",
      "appointment_id": "456e7890-e12b-34d5-a678-901234567890"
    },
    "is_read": false,
    "sent_at": "2026-01-02T10:00:00Z",
    "read_at": null,
    "created_at": "2026-01-02T10:00:00Z"
  }
]
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token

---

### GET /notifications/history/{user_id}

Get notification history for a specific user (admin only).

**Authentication**: Required (Admin role)

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| user_id | UUID | User ID |

**Query Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| skip | integer | No | 0 | Number of records to skip |
| limit | integer | No | 20 | Number of records to return (max: 100) |

**Response**: `200 OK`

```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "user_id": "789e0123-e45b-67d8-a901-234567890abc",
    "title": "Appointment Reminder",
    "body": "You have an appointment with Dr. Smith at 2 PM tomorrow",
    "is_read": true,
    "sent_at": "2026-01-02T10:00:00Z",
    "read_at": "2026-01-02T11:30:00Z",
    "created_at": "2026-01-02T10:00:00Z"
  }
]
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: User not found

---

### GET /notifications/{notification_id}

Get a specific notification by ID.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|  
| notification_id | UUID | Notification ID |

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "789e0123-e45b-67d8-a901-234567890abc",
  "title": "Appointment Reminder",
  "body": "You have an appointment with Dr. Smith at 2 PM tomorrow",
  "data": {
    "type": "appointment_reminder",
    "appointment_id": "456e7890-e12b-34d5-a678-901234567890"
  },
  "is_read": false,
  "sent_at": "2026-01-02T10:00:00Z",
  "read_at": null,
  "created_at": "2026-01-02T10:00:00Z"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to view this notification
- `404 Not Found`: Notification not found

---

### PATCH /notifications/{notification_id}/read

Mark a notification as read.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| notification_id | UUID | Notification ID |

**Response**: `200 OK`

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "is_read": true,
  "read_at": "2026-01-02T12:00:00Z"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to update this notification
- `404 Not Found`: Notification not found

---

### DELETE /notifications/{notification_id}

Delete a notification.

**Authentication**: Required

**Path Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| notification_id | UUID | Notification ID |

**Response**: `204 No Content`

**Errors**:
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Not authorized to delete this notification
- `404 Not Found`: Notification not found

---

### GET /notifications/stats/summary

Get notification statistics for the current user.

**Authentication**: Required

**Response**: `200 OK`

```json
{
  "total_notifications": 50,
  "unread_count": 5,
  "read_count": 45,
  "last_notification_at": "2026-01-02T10:00:00Z"
}
```

**Errors**:
- `401 Unauthorized`: Invalid or missing token

---

## Data Models

### User

```typescript
{
  id: UUID,
  firebase_uid: string,
  email: string,
  email_verified: boolean,
  auth_provider: string,
  full_name: string | null,
  given_name: string | null,
  family_name: string | null,
  photo_url: string | null,
  phone: string | null,
  role: "patient" | "doctor" | "admin",
  is_active: boolean,
  is_onboarded: boolean,
  created_at: datetime,
  updated_at: datetime,
  last_login_at: datetime | null
}
```

### Appointment

```typescript
{
  id: UUID,
  patient_id: UUID,
  doctor_id: UUID | null,
  clinic_id: UUID | null,
  doctor_name: string,
  clinic_name: string | null,
  appointment_at: datetime,
  appointment_end_at: datetime | null,
  reason: string,
  contact_phone: string,
  status: "scheduled" | "confirmed" | "rescheduled" | "cancelled" | "completed" | "no_show",
  notes: string | null,
  source: string,
  created_at: datetime,
  updated_at: datetime,
  cancelled_at: datetime | null,
  deleted_at: datetime | null
}
```

### Pharmacy

```typescript
{
  id: UUID,
  name: string,
  description: string | null,
  phone: string | null,
  email: string | null,
  is_verified: boolean,
  is_active: boolean,
  rating: decimal(2,1) | null,
  rating_count: integer | null,
  supports_delivery: boolean,
  supports_pickup: boolean,
  created_at: datetime,
  updated_at: datetime,
  location: PharmacyLocation,
  hours: PharmacyHours[]
}
```

### PharmacyLocation

```typescript
{
  id: UUID,
  pharmacy_id: UUID,
  address_line: string,
  city: string,
  state: string | null,
  country: string,
  pincode: string | null,
  latitude: float,
  longitude: float,
  created_at: datetime
}
```

### PharmacyHours

```typescript
{
  id: UUID,
  pharmacy_id: UUID,
  day_of_week: integer (1-7),
  open_time: time,
  close_time: time,
  is_closed: boolean
}
```

### Notification

```typescript
{
  id: UUID,
  user_id: UUID,
  title: string,
  body: string,
  data: object | null,
  notification_type: string | null,
  is_read: boolean,
  sent_at: datetime,
  read_at: datetime | null,
  created_at: datetime
}
```

### FCMToken

```typescript
{
  id: UUID,
  user_id: UUID,
  fcm_token: string,
  platform: "android" | "ios" | "web",
  is_active: boolean,
  created_at: datetime,
  updated_at: datetime,
  last_used_at: datetime | null
}
```

---

## Rate Limiting

The API implements rate limiting to prevent abuse:

- **Default Limit**: 60 requests per minute per IP address
- **Response Header**: `X-RateLimit-Remaining` (number of requests left)
- **Rate Limit Response**: `429 Too Many Requests`

```json
{
  "detail": "Rate limit exceeded. Please try again later."
}
```

---

## Versioning

The API uses URL-based versioning:

- Current version: `/api/v1`
- Future versions: `/api/v2`, `/api/v3`, etc.

Breaking changes will be introduced in new API versions. The current version will be maintained for a deprecation period.

---

## Pagination

List endpoints support pagination with query parameters:

- `page`: Page number (starting from 1)
- `page_size`: Number of items per page (default: 20, max: 100)

Response includes:
- `items`: Array of results
- `total`: Total number of items
- `page`: Current page
- `page_size`: Items per page
- `total_pages`: Total number of pages

---

## Filtering

### Date Filtering

Use ISO 8601 format for date/time filters:

```
?from_date=2026-01-01T00:00:00Z&to_date=2026-01-31T23:59:59Z
```

### Boolean Filtering

Use `true` or `false` (lowercase):

```
?is_active=true&supports_delivery=true
```

---

## Best Practices

### Request Format

1. Always set `Content-Type: application/json`
2. Include `Authorization: Bearer <token>` for authenticated endpoints
3. Use ISO 8601 for all datetime values
4. Use UUIDs for all ID fields

### Error Handling

1. Always check HTTP status codes
2. Parse `detail` field for error messages
3. Handle validation errors from `422` responses
4. Implement token refresh logic for `401` errors

### Performance

1. Use pagination for large datasets
2. Filter data server-side when possible
3. Cache frequently accessed data (with appropriate TTL)
4. Implement exponential backoff for retries

---

## Support

For API support and questions:

- **Email**: api-support@medico24.com
- **Documentation**: https://docs.medico24.com
- **Status Page**: https://status.medico24.com

---

**API Documentation End**

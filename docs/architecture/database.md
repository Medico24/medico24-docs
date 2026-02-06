# Database Architecture

**Version:** 2.0  
**Last Updated:** February 7, 2026  
**DBMS:** PostgreSQL 16+ with PostGIS extension

---

## Overview

The Medico24 platform uses a PostgreSQL database with PostGIS for geospatial queries. The database architecture follows a normalized relational model with carefully designed relationships to ensure data integrity, scalability, and performance.

### Key Features

- ✅ Normalized relational schema
- ✅ Foreign key constraints with appropriate cascade rules
- ✅ Geospatial support via PostGIS
- ✅ Many-to-many relationships with rich junction tables
- ✅ Soft delete patterns
- ✅ Audit trails with timestamps
- ✅ Indexed columns for performance
- ✅ JSON/JSONB for flexible data structures

---

## Table of Contents

1. [Database Schema Overview](#database-schema-overview)
2. [Core Tables](#core-tables)
3. [Junction Tables](#junction-tables)
4. [Relationships & Constraints](#relationships--constraints)
5. [Indexes & Performance](#indexes--performance)
6. [Design Patterns](#design-patterns)
7. [Migrations](#migrations)
8. [ERD Diagrams](#erd-diagrams)

---

## Database Schema Overview

### Entity Relationship Summary

```
┌──────────┐
│  users   │◄────────┐
└────┬─────┘         │
     │               │
     │ 1:1           │ 1:1
     ▼               │
┌──────────┐    ┌────┴────┐
│ patients │    │ doctors │
└──────────┘    └────┬────┘
     │               │
     │ 1:N           │ M:N
     │               ▼
     │          ┌──────────────────┐
     │          │ doctor_clinics   │◄────┐
     │          │  (junction)      │     │
     │          └────┬─────────────┘     │ M:N
     │               │                   │
     │               │ M:1               │
     │               ▼              ┌────┴────┐
     │          ┌──────────┐        │ clinics │
     │          │ appointments      │         │
     │          │          │        └─────────┘
     │          └──────────┘
     │               ▲
     │ 1:N           │ M:1
     └───────────────┘
     
┌──────────────┐
│ pharmacies   │
└──────────────┘

┌──────────────┐
│ notifications│
└──────────────┘
```

### Table List

| Table | Purpose | Relationships |
|-------|---------|---------------|
| **users** | User accounts and authentication | Referenced by patients, doctors, admins |
| **patients** | Patient profiles | 1:1 with users, 1:N with appointments |
| **doctors** | Doctor profiles | 1:1 with users, M:N with clinics via doctor_clinics |
| **admins** | Admin profiles and permissions | 1:1 with users |
| **clinics** | Healthcare facility information | M:N with doctors via doctor_clinics |
| **doctor_clinics** | Doctor-clinic associations | Junction table for doctors ↔ clinics |
| **appointments** | Appointment bookings | References patients, doctors, doctor_clinics |
| **pharmacies** | Pharmacy information with geolocation | 1:N with pharmacy_staff |
| **pharmacy_staff** | Pharmacy staff members | References users, pharmacies |
| **push_tokens** | FCM device tokens for notifications | References users |
| **notifications** | Push notification logs | References users |
| **refresh_tokens** | JWT refresh token storage | References users |

---

## Core Tables

### users

Central table for all user authentication and profile information.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    full_name VARCHAR(255),
    given_name VARCHAR(100),
    family_name VARCHAR(100),
    photo_url TEXT,
    phone VARCHAR(20),
    role VARCHAR(20) NOT NULL DEFAULT 'patient',
    is_active BOOLEAN DEFAULT TRUE,
    is_onboarded BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP
);

CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
```

**Key Fields:**

- `firebase_uid`: Firebase authentication UID (unique identifier from Firebase)
- `role`: Enum values: 'patient', 'doctor', 'admin'
- `is_onboarded`: Tracks whether user completed onboarding flow

**Relationships:**

- 1:1 with `patients` (via `user_id`)
- 1:1 with `doctors` (via `user_id`)
- 1:N with `appointments`, `notifications`, `refresh_tokens`

---

### patients

Extended profile for users with patient role.

```sql
CREATE TABLE patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    date_of_birth DATE,
    gender VARCHAR(20),
    blood_group VARCHAR(5),
    allergies TEXT[],
    chronic_conditions TEXT[],
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(20),
    emergency_contact_relationship VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    insurance_provider VARCHAR(255),
    insurance_policy_number VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_patients_user_id ON patients(user_id);
```

**Key Features:**

- Medical history fields (allergies, chronic_conditions)
- Emergency contact information
- Insurance details
- Cascade delete on user removal

---

### doctors

Extended profile for users with doctor role.

```sql
CREATE TABLE doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(100) UNIQUE NOT NULL,
    specialization VARCHAR(200) NOT NULL,
    sub_specialization VARCHAR(200),
    qualification TEXT,
    experience_years INTEGER DEFAULT 0,
    consultation_fee DECIMAL(10, 2),
    consultation_duration_minutes INTEGER DEFAULT 30,
    bio TEXT,
    languages_spoken TEXT[],
    medical_council_registration VARCHAR(100),
    is_verified BOOLEAN DEFAULT FALSE,
    verification_documents JSONB,
    verified_at TIMESTAMP,
    verified_by UUID REFERENCES users(id),
    rating DECIMAL(3, 2) CHECK (rating >= 0 AND rating <= 5),
    rating_count INTEGER DEFAULT 0,
    total_patients_treated INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_doctors_user_id ON doctors(user_id);
CREATE INDEX idx_doctors_license_number ON doctors(license_number);
CREATE INDEX idx_doctors_specialization ON doctors(specialization);
```

**Key Features:**

- Verification system for credential validation
- Rating system for patient reviews
- Multiple language support
- JSONB for flexible document storage
- Self-referential FK for `verified_by`

**Constraints:**

- License number must be unique
- One doctor profile per user
- Rating must be between 0 and 5

---

### clinics

Healthcare facility information with geolocation support.

```sql
CREATE TABLE clinics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    contacts JSONB,
    address TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    opening_hours JSONB,
    services TEXT[],
    amenities TEXT[],
    insurance_accepted TEXT[],
    status VARCHAR(50) DEFAULT 'active',
    rating DECIMAL(3, 2) CHECK (rating >= 0 AND rating <= 5),
    rating_count INTEGER DEFAULT 0,
    total_doctors INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_clinics_slug ON clinics(slug);
CREATE INDEX idx_clinics_status ON clinics(status);
CREATE INDEX idx_clinics_location ON clinics(latitude, longitude);
```

**Key Features:**

- Slug for SEO-friendly URLs
- JSONB for contacts and opening_hours
- Array fields for services, amenities, insurance
- Geolocation with lat/lng for distance calculations
- Status enum: active, inactive, temporarily_closed, permanently_closed

**Design Note:**

Removed direct clinic fields from doctors table. Relationship now managed via `doctor_clinics` junction table for many-to-many support.

---

### pharmacies

Pharmacy information with PostGIS geospatial support.

```sql
CREATE TABLE pharmacies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE,
    description TEXT,
    location GEOGRAPHY(Point, 4326) NOT NULL,
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(255),
    website VARCHAR(255),
    opening_hours JSONB,
    services TEXT[],
    supports_delivery BOOLEAN DEFAULT FALSE,
    delivery_radius_km DECIMAL(5, 2),
    accepts_insurance BOOLEAN DEFAULT FALSE,
    insurance_providers TEXT[],
    rating DECIMAL(3, 2) CHECK (rating >= 0 AND rating <= 5),
    rating_count INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_pharmacies_location ON pharmacies USING GIST(location);
CREATE INDEX idx_pharmacies_slug ON pharmacies(slug);
CREATE INDEX idx_pharmacies_is_active ON pharmacies(is_active);
CREATE INDEX idx_pharmacies_is_verified ON pharmacies(is_verified);
```

**Key Features:**

- PostGIS GEOGRAPHY type for accurate distance calculations
- GIST index for spatial queries
- Delivery support with radius
- Verification system
- Rating system

---

### appointments

Appointment booking records linking patients, doctors, and clinics.

```sql
CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES doctors(id) ON DELETE SET NULL,
    doctor_clinic_id UUID REFERENCES doctor_clinics(id) ON DELETE SET NULL,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    duration_minutes INTEGER DEFAULT 30,
    status VARCHAR(50) DEFAULT 'scheduled',
    symptoms TEXT,
    notes TEXT,
    prescription TEXT,
    consultation_fee DECIMAL(10, 2),
    payment_status VARCHAR(50) DEFAULT 'pending',
    cancelled_at TIMESTAMP,
    cancelled_by UUID REFERENCES users(id),
    cancellation_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_appointments_patient_id ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor_id ON appointments(doctor_id);
CREATE INDEX idx_appointments_doctor_clinic_id ON appointments(doctor_clinic_id);
CREATE INDEX idx_appointments_appointment_date ON appointments(appointment_date);
CREATE INDEX idx_appointments_status ON appointments(status);
```

**Key Features:**

- References both doctor and specific clinic (via doctor_clinic_id)
- Status tracking: scheduled, confirmed, completed, cancelled, no_show
- Payment status tracking
- Cancellation audit trail
- Cascade delete on patient removal
- SET NULL on doctor/clinic removal (preserves history)

**Status Values:**

- `scheduled`: Initial booking
- `confirmed`: Confirmed by clinic/doctor
- `completed`: Appointment finished
- `cancelled`: Cancelled by patient/doctor
- `no_show`: Patient didn't attend

---

### notifications

Push notification logs for Firebase Cloud Messaging.

```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    device_token VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    notification_type VARCHAR(50),
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_device_token ON notifications(device_token);
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);
```

**Key Features:**

- FCM device token storage
- JSONB for custom notification data
- Read status tracking
- Notification type categorization

---

### refresh_tokens

JWT refresh token storage for authentication.

```sql
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
```

**Key Features:**

- Token revocation support
- Expiration tracking
- Cascade delete on user removal

---

### push_tokens

FCM device tokens for push notifications.

```sql
CREATE TABLE push_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform VARCHAR(10) NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    is_active BOOLEAN DEFAULT TRUE,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_push_tokens_user_id ON push_tokens(user_id);
CREATE INDEX idx_push_tokens_is_active ON push_tokens(is_active);
```

**Key Features:**

- Multiple tokens per user (multi-device support)
- Platform tracking (Android, iOS, Web)
- Active status for token management
- Last used tracking

---

### admins

Admin user profiles with permissions and access control.

```sql
CREATE TABLE admins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    department VARCHAR(100),
    access_level VARCHAR(50) DEFAULT 'standard',
    job_title VARCHAR(100),
    permissions JSONB,
    allowed_modules JSONB,
    last_login_ip VARCHAR(45),
    login_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_admins_user_id ON admins(user_id);
CREATE INDEX idx_admins_access_level ON admins(access_level);
```

**Key Features:**

- Granular permission system via JSONB
- Access level hierarchy
- Module-based access control
- Login tracking and audit trail

**Access Levels:**

- `super_admin`: Full system access
- `admin`: Standard administrative access
- `moderator`: Limited administrative access
- `support`: Support and read-only access

---

### pharmacy_staff

Staff members associated with pharmacies.

```sql
CREATE TABLE pharmacy_staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pharmacy_id UUID NOT NULL REFERENCES pharmacies(id) ON DELETE CASCADE,
    position VARCHAR(100),
    license_number VARCHAR(100),
    is_owner BOOLEAN DEFAULT FALSE,
    is_primary_contact BOOLEAN DEFAULT FALSE,
    employment_type VARCHAR(50),
    date_joined DATE,
    date_left DATE,
    permissions JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_pharmacy_staff_user_id ON pharmacy_staff(user_id);
CREATE INDEX idx_pharmacy_staff_pharmacy_id ON pharmacy_staff(pharmacy_id);
CREATE INDEX idx_pharmacy_staff_is_owner ON pharmacy_staff(is_owner);
```

**Key Features:**

- Links users to pharmacies they manage/work at
- Tracks employment details
- Ownership designation
- Position-based permissions via JSONB

**Positions:**

- `owner`: Pharmacy owner
- `pharmacist`: Licensed pharmacist
- `manager`: Pharmacy manager
- `staff`: General staff member

---

## Junction Tables

### doctor_clinics

Rich junction table managing many-to-many relationship between doctors and clinics.

```sql
CREATE TABLE doctor_clinics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    clinic_id UUID NOT NULL REFERENCES clinics(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,
    status VARCHAR(50) DEFAULT 'active',
    consultation_fee DECIMAL(10, 2),
    consultation_duration_minutes INTEGER DEFAULT 30,
    department VARCHAR(100),
    designation VARCHAR(100),
    available_days INTEGER[],
    available_time_slots JSONB,
    appointment_booking_enabled BOOLEAN DEFAULT TRUE,
    total_appointments INTEGER DEFAULT 0,
    completed_appointments INTEGER DEFAULT 0,
    average_rating DECIMAL(3, 2) CHECK (average_rating >= 0 AND average_rating <= 5),
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Unique constraint: one active association per doctor-clinic pair
CREATE UNIQUE INDEX idx_doctor_clinics_unique_active 
    ON doctor_clinics(doctor_id, clinic_id) 
    WHERE status = 'active';

CREATE INDEX idx_doctor_clinics_doctor_id ON doctor_clinics(doctor_id);
CREATE INDEX idx_doctor_clinics_clinic_id ON doctor_clinics(clinic_id);
CREATE INDEX idx_doctor_clinics_status ON doctor_clinics(status);
```

**Key Features:**

- Clinic-specific consultation fees and durations
- Department and designation per clinic
- Weekly availability schedule (available_days: 1=Mon...7=Sun)
- Time slot management via JSONB
- Primary clinic designation
- Appointment statistics tracking
- Soft delete with end_date
- Partial unique index prevents duplicate active associations

**Design Pattern:**

This is a **rich junction table** (also called an associative entity) that stores not just the relationship but also context-specific attributes. This pattern is essential for scenarios where the relationship itself has properties.

**Status Values:**

- `active`: Currently working at this clinic
- `on_leave`: Temporarily unavailable
- `ended`: No longer associated with this clinic

**Example available_time_slots JSONB:**

```json
{
  "monday": ["09:00-12:00", "14:00-18:00"],
  "tuesday": ["09:00-12:00", "14:00-18:00"],
  "wednesday": ["09:00-12:00"],
  "friday": ["09:00-12:00", "14:00-18:00"]
}
```

---

## Relationships & Constraints

### Foreign Key Constraints

#### CASCADE DELETE

Used when child records should be removed if parent is deleted:

```sql
-- User deletion should remove all associated data
patients.user_id → users.id (ON DELETE CASCADE)
doctors.user_id → users.id (ON DELETE CASCADE)
appointments.patient_id → patients.id (ON DELETE CASCADE)
notifications.user_id → users.id (ON DELETE CASCADE)
refresh_tokens.user_id → users.id (ON DELETE CASCADE)
doctor_clinics.doctor_id → doctors.id (ON DELETE CASCADE)
doctor_clinics.clinic_id → clinics.id (ON DELETE CASCADE)
```

**Rationale:** Patient/doctor profiles are meaningless without user accounts. All user data should be cleanly removed.

#### SET NULL

Used when child records should be preserved but reference removed:

```sql
-- Preserve appointment history even if doctor/clinic removed
appointments.doctor_id → doctors.id (ON DELETE SET NULL)
appointments.doctor_clinic_id → doctor_clinics.id (ON DELETE SET NULL)
```

**Rationale:** Appointments are historical records that should be preserved for legal/audit purposes even if the doctor or clinic is removed from the system.

#### RESTRICT (Implicit Default)

Used when parent records should not be deletable if children exist:

```sql
-- Doctor verification references
doctors.verified_by → users.id (Default RESTRICT)
```

**Rationale:** Prevents accidental deletion of admin users who verified doctors.

---

### Unique Constraints

```sql
-- User constraints
users.firebase_uid (UNIQUE)
users.email (UNIQUE)

-- Profile constraints
patients.user_id (UNIQUE) -- One patient profile per user
doctors.user_id (UNIQUE) -- One doctor profile per user
doctors.license_number (UNIQUE) -- One doctor per license

-- Clinic constraints
clinics.slug (UNIQUE) -- SEO-friendly URLs

-- Token constraints
refresh_tokens.token (UNIQUE)

-- Association constraints
doctor_clinics(doctor_id, clinic_id) WHERE status='active' (UNIQUE PARTIAL)
```

---

### Check Constraints

```sql
-- Rating constraints
doctors.rating CHECK (rating >= 0 AND rating <= 5)
clinics.rating CHECK (rating >= 0 AND rating <= 5)
pharmacies.rating CHECK (rating >= 0 AND rating <= 5)
doctor_clinics.average_rating CHECK (average_rating >= 0 AND average_rating <= 5)

-- Business logic constraints
doctors.experience_years >= 0
doctors.consultation_fee >= 0
```

---

## Indexes & Performance

### Primary Indexes

All tables have UUID primary keys with automatic indexes.

### Foreign Key Indexes

Foreign key columns are indexed for join performance:

```sql
-- User relationships
idx_patients_user_id
idx_doctors_user_id

-- Appointment relationships
idx_appointments_patient_id
idx_appointments_doctor_id
idx_appointments_doctor_clinic_id

-- Doctor-clinic relationships
idx_doctor_clinics_doctor_id
idx_doctor_clinics_clinic_id

-- Notification relationships
idx_notifications_user_id
```

### Lookup Indexes

Indexed columns used in WHERE clauses:

```sql
-- User lookups
idx_users_firebase_uid (for authentication)
idx_users_email (for user search)
idx_users_role (for role-based queries)

-- Doctor lookups
idx_doctors_license_number (for verification)
idx_doctors_specialization (for filtering)

-- Clinic lookups
idx_clinics_slug (for SEO URLs)
idx_clinics_status (for active clinic queries)

-- Appointment lookups
idx_appointments_appointment_date (for date-range queries)
idx_appointments_status (for status filtering)

-- Pharmacy lookups
idx_pharmacies_is_active
idx_pharmacies_is_verified
```

### Geospatial Indexes

```sql
-- PostGIS GIST index for spatial queries
idx_pharmacies_location ON pharmacies USING GIST(location)

-- Compound index for clinic location
idx_clinics_location ON clinics(latitude, longitude)
```

### Composite Indexes

```sql
-- Partial unique index for active associations
idx_doctor_clinics_unique_active 
    ON doctor_clinics(doctor_id, clinic_id) 
    WHERE status = 'active'
```

### Query Optimization Examples

**Find nearby pharmacies (uses GIST index):**

```sql
SELECT * FROM pharmacies
WHERE ST_DWithin(
    location,
    ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)::geography,
    5000  -- 5km radius
)
ORDER BY location <-> ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)::geography;
```

**Find doctor's active clinics (uses FK and status indexes):**

```sql
SELECT c.* 
FROM clinics c
JOIN doctor_clinics dc ON dc.clinic_id = c.id
WHERE dc.doctor_id = $1 AND dc.status = 'active'
ORDER BY dc.is_primary DESC, c.name;
```

---

## Design Patterns

### 1. Soft Delete Pattern

Used in `doctor_clinics` table with `end_date` and `status`:

```sql
-- Instead of deleting
DELETE FROM doctor_clinics WHERE id = $1;

-- We soft delete
UPDATE doctor_clinics 
SET status = 'ended', end_date = CURRENT_DATE 
WHERE id = $1;
```

**Benefits:**

- Preserves historical data
- Maintains referential integrity
- Enables audit trails
- Allows data recovery

**Used In:** doctor_clinics, clinics (via status field)

---

### 2. Rich Junction Table Pattern

`doctor_clinics` stores relationship-specific attributes:

```sql
-- Not just: (doctor_id, clinic_id)
-- But also: fees, schedules, departments, statistics
```

**Benefits:**

- Supports different settings per clinic
- Tracks context-specific metrics
- Enables complex business logic
- Maintains relationship history

---

### 3. Audit Trail Pattern

Timestamps on all tables:

```sql
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
```

Additional audit fields where needed:

```sql
-- Appointments
cancelled_at, cancelled_by, cancellation_reason

-- Doctors
verified_at, verified_by

-- Notifications
sent_at, read_at
```

**Benefits:**

- Track record creation and modifications
- Support compliance requirements
- Enable temporal queries
- Facilitate debugging

---

### 4. Verification Pattern

Used in `doctors` and `pharmacies`:

```sql
is_verified BOOLEAN DEFAULT FALSE
verified_at TIMESTAMP
verified_by UUID REFERENCES users(id)
verification_documents JSONB
```

**Benefits:**

- Tracks credential validation
- Records who verified and when
- Stores document references
- Supports compliance

---

### 5. JSONB for Flexible Data

Used for semi-structured data:

```sql
-- Contacts (varying fields per clinic)
clinics.contacts JSONB

-- Opening hours (variable weekly schedules)
clinics.opening_hours JSONB
pharmacies.opening_hours JSONB

-- Doctor availability (clinic-specific schedules)
doctor_clinics.available_time_slots JSONB

-- Verification documents (different per doctor)
doctors.verification_documents JSONB

-- Notification custom data
notifications.data JSONB
```

**Benefits:**

- Schema flexibility
- Efficient storage
- Indexable (GIN indexes)
- JSON query support

---

### 6. Array Fields for Lists

Used for multi-value attributes:

```sql
patients.allergies TEXT[]
patients.chronic_conditions TEXT[]
doctors.languages_spoken TEXT[]
clinics.services TEXT[]
clinics.amenities TEXT[]
clinics.insurance_accepted TEXT[]
pharmacies.services TEXT[]
doctor_clinics.available_days INTEGER[]
```

**Benefits:**

- Simple list storage
- Array query operators
- No junction table overhead
- Efficient for small lists

**Note:** Use junction tables when list items need their own attributes.

---

## Migrations

### Migration System

Using Alembic for database migrations:

```
medico24-backend/
├── alembic/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/
│       ├── 001_create_users_table.py
│       ├── 002_create_patients_table.py
│       ├── 003_create_doctors_table.py
│       ├── 009_create_clinics_table.py
│       ├── 010_create_doctor_clinics_table.py
│       ├── 011_update_doctors_remove_clinic_fields.py
│       └── 012_update_appointments_add_fks.py
└── alembic.ini
```

### Key Migrations

**009_create_clinics_table.py**
- Creates clinics table
- Simplified schema with JSONB contacts
- Status enum implementation

**010_create_doctor_clinics_table.py**
- Creates junction table
- Partial unique index for active associations
- Rich association fields

**011_update_doctors_remove_clinic_fields.py**
- Removes clinic-specific fields from doctors
- Data migration to doctor_clinics
- Maintains backward compatibility

**012_update_appointments_add_fks.py**
- Adds doctor_clinic_id foreign key
- Updates existing appointments
- Preserves appointment history

### Running Migrations

```bash
# Upgrade to latest
alembic upgrade head

# Downgrade one version
alembic downgrade -1

# View migration history
alembic history

# Create new migration
alembic revision -m "description"
```

---

## ERD Diagrams

### Core Entities

```
┌─────────────────────────────────────────┐
│              users                      │
├─────────────────────────────────────────┤
│ • id (PK, UUID)                         │
│ • firebase_uid (UNIQUE)                 │
│ • email (UNIQUE)                        │
│ • full_name                             │
│ • role (patient/doctor/admin)           │
│ • is_active                             │
│ • is_onboarded                          │
└───────────┬─────────────────────────────┘
            │
      ┌─────┴──────┐
      │            │
      ▼            ▼
┌──────────┐  ┌──────────┐
│ patients │  │ doctors  │
├──────────┤  ├──────────┤
│ • id (PK)│  │ • id (PK)│
│ • user_id│  │ • user_id│
│   (FK)   │  │   (FK)   │
│ • dob    │  │ • license│
│ • blood  │  │ • special│
│ • medical│  │ • rating │
└────┬─────┘  └────┬─────┘
     │             │
     │ 1:N         │ M:N
     │             ▼
     │     ┌────────────────┐
     │     │ doctor_clinics │
     │     ├────────────────┤
     │     │ • id (PK)      │
     │     │ • doctor_id(FK)│
     │     │ • clinic_id(FK)│
     │     │ • is_primary   │
     │     │ • fees         │
     │     │ • schedule     │
     │     └────┬───────────┘
     │          │
     │          │ M:1
     │          ▼
     │     ┌─────────┐
     │     │ clinics │
     │     ├─────────┤
     │     │ • id(PK)│
     │     │ • name  │
     │     │ • slug  │
     │     │ • lat   │
     │     │ • lng   │
     │     └─────────┘
     │
     │ 1:N
     ▼
┌──────────────┐
│ appointments │
├──────────────┤
│ • id (PK)    │
│ • patient_id │
│ • doctor_id  │
│ • clinic_id  │
│ • date       │
│ • status     │
└──────────────┘
```

### Appointment Relationships

```
appointments
├── patient_id → patients.id (CASCADE)
├── doctor_id → doctors.id (SET NULL)
└── doctor_clinic_id → doctor_clinics.id (SET NULL)
```

**Design Rationale:**

- Appointments CASCADE with patients (patient-centric)
- SET NULL for doctor/clinic (preserve history)
- References both doctor AND specific clinic

---

## Database Statistics

### Current Schema Metrics

| Metric | Value |
|--------|-------|
| Total Tables | 13 |
| Core Tables | 10 |
| Junction Tables | 1 (doctor_clinics) |
| Total Indexes | ~50 |
| Foreign Keys | 20+ |
| Check Constraints | 6 |
| Unique Constraints | 15 |
| JSONB Columns | 10 |
| Array Columns | 10 |
| Geospatial Columns | 1 (PostGIS) |

### Expected Data Volume

| Table | Estimated Rows | Growth Rate |
|-------|----------------|-------------|
| users | 100K | Medium |
| patients | 80K | Medium |
| doctors | 10K | Low |
| admins | 100 | Very Low |
| clinics | 5K | Low |
| doctor_clinics | 25K | Medium |
| appointments | 1M+ | High |
| pharmacies | 10K | Low |
| pharmacy_staff | 20K | Low |
| push_tokens | 150K | Medium |
| notifications | 5M+ | High |
| refresh_tokens | 100K | Medium |

---

## Performance Considerations

### Query Optimization

1. **Use indexes** for all foreign keys and lookup columns
2. **Avoid N+1 queries** with proper JOINs
3. **Use EXPLAIN ANALYZE** to verify query plans
4. **Denormalize** where appropriate (e.g., rating counts)
5. **Partition** large tables like appointments by date

### Connection Pooling

```python
# SQLAlchemy configuration
SQLALCHEMY_DATABASE_URI = "postgresql://..."
SQLALCHEMY_POOL_SIZE = 20
SQLALCHEMY_MAX_OVERFLOW = 40
SQLALCHEMY_POOL_TIMEOUT = 30
SQLALCHEMY_POOL_RECYCLE = 3600
```

### Caching Strategy

See [Application-Caching-Database Layers](layers.md) for details.

---

## Security Considerations

### Sensitive Data

- Passwords: NOT stored (Firebase handles auth)
- PHI (Protected Health Information): Encrypted at rest
- Payment data: Use external payment processor
- License numbers: Restricted access

### Access Control

- Row-level security for multi-tenant scenarios
- Application-level authorization via user roles
- Audit logging for sensitive operations

### Data Privacy

- HIPAA compliance for patient data
- GDPR compliance for EU users
- Data retention policies
- Right to deletion support

---

## Backup & Recovery

### Backup Strategy

```bash
# Daily full backups
pg_dump medico24_db > backup_$(date +%Y%m%d).sql

# Point-in-time recovery via WAL archiving
archive_mode = on
archive_command = 'cp %p /backup/archive/%f'
```

### Recovery Procedures

1. Restore from latest backup
2. Apply WAL files for point-in-time recovery
3. Verify data integrity
4. Update application configuration

---

## Related Documentation

- [Application-Caching-Database Layers](layers.md)
- [Caching Strategy & Implementation](caching.md) - Comprehensive caching guide with all cache keys and patterns
- [API Specifications](../api/specifications.md)
- [System Architecture](overview.md)

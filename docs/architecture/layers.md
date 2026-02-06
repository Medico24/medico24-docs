# Application-Caching-Database Layers

**Version:** 2.0  
**Last Updated:** February 7, 2026

---

## Overview

The Medico24 platform implements a robust three-tier architecture with an intelligent caching layer to optimize performance, reduce database load, and provide a scalable foundation for growth. This document explains how data flows through the application, the role of each layer, and the caching strategies employed.

### Architecture Goals

- ✅ Minimize database queries through intelligent caching
- ✅ Provide consistent response times under load
- ✅ Scale horizontally with stateless application servers
- ✅ Maintain data consistency across layers
- ✅ Support high availability and fault tolerance

---

## Table of Contents

1. [Layer Architecture Overview](#layer-architecture-overview)
2. [Application Layer](#application-layer)
3. [Caching Layer](#caching-layer)
4. [Database Layer](#database-layer)
5. [Data Flow Patterns](#data-flow-patterns)
6. [Caching Strategies](#caching-strategies)
7. [Cache Invalidation](#cache-invalidation)
8. [Performance Optimization](#performance-optimization)
9. [Monitoring & Observability](#monitoring--observability)

---

## Layer Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT LAYER                            │
│  ┌──────────────┐              ┌──────────────┐             │
│  │ Flutter App  │              │  Next.js Web │             │
│  └──────┬───────┘              └──────┬───────┘             │
│         │                             │                     │
│         └─────────────┬───────────────┘                     │
│                       │ HTTPS/REST                          │
└───────────────────────┼─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│              APPLICATION LAYER (FastAPI)                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐     │
│  │         API Endpoints (Router Layer)               │     │
│  │  • Request validation                              │     │
│  │  • Authentication/Authorization                    │     │
│  │  • Response formatting                             │     │
│  └────────────────┬───────────────────────────────────┘     │
│                   │                                         │
│  ┌────────────────▼───────────────────────────────────┐     │
│  │         Service Layer (Business Logic)             │     │
│  │  • DoctorService                                   │     │
│  │  • ClinicService                                   │     │
│  │  • AppointmentService                              │     │
│  │  • PharmacyService                                 │     │
│  │  • UserService                                     │     │
│  └────────────┬─────────────────────┬─────────────────┘     │
│               │                     │                       │
└───────────────┼─────────────────────┼───────────────────────┘
                │                     │
       ┌────────▼────────┐   ┌────────▼────────┐
       │  CACHING LAYER  │   │  DATABASE LAYER │
       │  (Redis Cloud)  │   │  (PostgreSQL)   │
       └─────────────────┘   └─────────────────┘
```

### Layer Responsibilities

| Layer | Purpose | Technologies | Stateless |
|-------|---------|--------------|-----------|
| **Application** | Business logic, API routing, validation | FastAPI, Pydantic, SQLAlchemy | Yes |
| **Caching** | Temporary data storage, session management | Redis (Redis Labs Cloud) | Yes |
| **Database** | Persistent data storage, ACID transactions | PostgreSQL + PostGIS (Neon Cloud) | No |

---

## Application Layer

### Components

#### 1. API Endpoints (Router Layer)

Located in `app/api/v1/endpoints/`:

```python
# app/api/v1/endpoints/doctors.py
from fastapi import APIRouter, Depends, HTTPException
from app.services.doctor_service import DoctorService

router = APIRouter()

@router.get("/doctors/{doctor_id}")
async def get_doctor(
    doctor_id: UUID,
    doctor_service: DoctorService = Depends(get_doctor_service)
):
    """
    Endpoint responsibilities:
    1. Validate request parameters
    2. Authenticate/authorize user
    3. Call service layer
    4. Format response
    5. Handle errors
    """
    doctor = await doctor_service.get_doctor_by_id(doctor_id)
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")
    return doctor
```

**Responsibilities:**

- Request validation with Pydantic
- Authentication/authorization checks
- Delegate business logic to service layer
- Format responses
- Handle HTTP errors

**Design Principle:** Thin controllers - minimal logic in endpoints.

---

#### 2. Service Layer (Business Logic)

Located in `app/services/`:

```python
# app/services/doctor_service.py
from app.core.cache import CacheManager
from app.models.doctors import Doctor
from sqlalchemy.orm import Session

class DoctorService:
    def __init__(self, cache: CacheManager):
        self.cache = cache
    
    async def get_doctor_by_id(self, db: Session, doctor_id: UUID) -> Doctor:
        """
        Service responsibilities:
        1. Check cache first
        2. Query database if cache miss
        3. Update cache on database hit
        4. Apply business logic
        5. Return data
        """
        # Try cache first
        cache_key = f"doctor:{doctor_id}"
        cached_doctor = await self.cache.get(cache_key)
        if cached_doctor:
            return cached_doctor
        
        # Cache miss - query database
        doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
        
        # Update cache
        if doctor:
            await self.cache.set(cache_key, doctor, ttl=900)  # 15 min
        
        return doctor
```

**Responsibilities:**

- Implement business logic
- Orchestrate cache and database operations
- Manage transactions
- Apply domain rules
- Cache management

**Design Principle:** Service layer is the heart of the application - all business logic lives here.

---

#### 3. Model Layer (ORM)

Located in `app/models/`:

```python
# app/models/doctors.py
from sqlalchemy import Column, String, Integer, Boolean, DECIMAL
from sqlalchemy.orm import relationship
from app.database import Base

class Doctor(Base):
    __tablename__ = "doctors"
    
    id = Column(UUID, primary_key=True)
    user_id = Column(UUID, ForeignKey("users.id"))
    license_number = Column(String(100), unique=True)
    specialization = Column(String(200))
    # ... other fields
    
    # Relationships
    user = relationship("User", back_populates="doctor")
    clinics = relationship("DoctorClinic", back_populates="doctor")
```

**Responsibilities:**

- Define database schema
- Manage relationships
- Provide ORM interface
- Validate data types

---

#### 4. Schema Layer (Data Transfer Objects)

Located in `app/schemas/`:

```python
# app/schemas/doctors.py
from pydantic import BaseModel, Field, validator

class DoctorCreate(BaseModel):
    user_id: UUID
    license_number: str = Field(..., max_length=100)
    specialization: str = Field(..., max_length=200)
    experience_years: int = Field(default=0, ge=0)
    
    @validator('license_number')
    def validate_license(cls, v):
        if not v.startswith('LIC-'):
            raise ValueError('License must start with LIC-')
        return v

class DoctorResponse(BaseModel):
    id: UUID
    full_name: str
    specialization: str
    rating: Optional[float]
    # ... other fields
    
    class Config:
        from_attributes = True  # Pydantic v2
```

**Responsibilities:**

- Define request/response schemas
- Validate input data
- Serialize/deserialize data
- Document API contracts

---

### Request Flow in Application Layer

```
1. HTTP Request
   ↓
2. Endpoint (Router)
   • Parse request
   • Validate with Pydantic schema
   • Authenticate user
   ↓
3. Service Layer
   • Check cache
   • Query database if needed
   • Apply business logic
   • Update cache
   ↓
4. Response
   • Serialize with Pydantic
   • Return to client
```

---

## Caching Layer

### Redis Configuration

**Provider:** Redis Labs Cloud (Managed)  
**Location:** Singapore region  
**Version:** Redis 7+  
**Connection:** TLS-enabled

```python
# app/core/config.py
REDIS_URL = "redis://default:password@redis-12345.cloud.redislabs.com:12345"
REDIS_MAX_CONNECTIONS = 50
REDIS_SOCKET_TIMEOUT = 5
```

### Cache Manager Implementation

```python
# app/core/cache.py
import redis
import json
import pickle
from typing import Any, Optional

class CacheManager:
    """
    Centralized cache management with Redis.
    Supports JSON and pickle serialization.
    """
    
    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
        self.default_ttl = 3600  # 1 hour
    
    async def get(self, key: str) -> Optional[Any]:
        """
        Retrieve value from cache.
        Auto-deserializes JSON or pickle.
        """
        try:
            value = self.redis.get(key)
            if value is None:
                return None
            
            # Try JSON first (faster)
            try:
                return json.loads(value)
            except (json.JSONDecodeError, TypeError):
                # Fallback to pickle for complex objects
                return pickle.loads(value)
        except Exception as e:
            logger.error(f"Cache get error for {key}: {e}")
            return None
    
    async def set(
        self,
        key: str,
        value: Any,
        ttl: Optional[int] = None
    ) -> bool:
        """
        Store value in cache with TTL.
        Auto-serializes to JSON or pickle.
        """
        try:
            # Prefer JSON for interoperability
            if isinstance(value, (dict, list, str, int, float, bool, type(None))):
                serialized = json.dumps(value)
            else:
                serialized = pickle.dumps(value)
            
            expire_time = ttl or self.default_ttl
            self.redis.setex(key, expire_time, serialized)
            return True
        except Exception as e:
            logger.error(f"Cache set error for {key}: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        """Delete key from cache."""
        try:
            return bool(self.redis.delete(key))
        except Exception as e:
            logger.error(f"Cache delete error for {key}: {e}")
            return False
    
    async def clear_pattern(self, pattern: str) -> int:
        """
        Clear all keys matching pattern.
        Example: clear_pattern("doctor:list:*")
        """
        try:
            keys = self.redis.keys(pattern)
            if keys:
                return self.redis.delete(*keys)
            return 0
        except Exception as e:
            logger.error(f"Cache clear pattern error for {pattern}: {e}")
            return 0
```

### Cache Key Naming Convention

```
# Format: {entity}:{identifier}[:{sub-key}]

# Individual records
doctor:{doctor_id}
clinic:{clinic_id}
pharmacy:{pharmacy_id}
user:{user_id}

# Lists with filters
doctor:list:{filter_hash}
clinic:list:active:{page}
pharmacy:list:verified

# Relationships
doctor:{doctor_id}:clinics
clinic:{clinic_id}:doctors

# Session data
session:{user_id}
token:{token_hash}
```

**Benefits:**

- Easy to understand
- Pattern-based invalidation
- Namespace isolation
- Collision prevention

---

## Database Layer

### PostgreSQL Configuration

**Provider:** Neon (Serverless PostgreSQL)  
**Location:** Singapore region  
**Version:** PostgreSQL 16 with PostGIS  
**Connection:** SSL-required

```python
# app/core/config.py
DATABASE_URL = "postgresql://user:pass@ep-xyz.ap-southeast-1.aws.neon.tech/medico24?sslmode=require"
SQLALCHEMY_POOL_SIZE = 20
SQLALCHEMY_MAX_OVERFLOW = 40
SQLALCHEMY_POOL_TIMEOUT = 30
SQLALCHEMY_POOL_RECYCLE = 3600
```

### Connection Pooling

```python
# app/database.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine(
    DATABASE_URL,
    pool_size=20,              # Base connections
    max_overflow=40,           # Additional connections under load
    pool_timeout=30,           # Wait time for connection
    pool_recycle=3600,         # Recycle connections every hour
    pool_pre_ping=True,        # Verify connections before use
    echo=False                 # Don't log SQL (production)
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
```

### Database Session Management

```python
# app/core/deps.py
from app.database import SessionLocal

def get_db():
    """
    Dependency for database sessions.
    Ensures proper cleanup with context manager.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Usage in endpoints
@router.get("/doctors/{doctor_id}")
async def get_doctor(
    doctor_id: UUID,
    db: Session = Depends(get_db)
):
    # db session automatically closed after request
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    return doctor
```

---

## Data Flow Patterns

### Pattern 1: Read-Through Cache (GET Requests)

```
┌────────┐     ┌─────────────┐     ┌───────┐     ┌──────────┐
│ Client │────▶│ Application │────▶│ Cache │     │ Database │
└────────┘     └─────────────┘     └───┬───┘     └────┬─────┘
                     ▲                  │              │
                     │                  │ Cache Miss   │
                     │                  ▼              │
                     │              Not Found          │
                     │                  │              │
                     │                  ├─────────────▶│
                     │                  │  Query       │
                     │                  │              │
                     │                  │◀─────────────┤
                     │                  │  Result      │
                     │                  │              │
                     │                  ├──────────────┘
                     │                  │ Update Cache
                     │                  │
                     │◀─────────────────┤
                     │   Return Data
                     │
```

**Implementation:**

```python
async def get_doctor_by_id(db: Session, doctor_id: UUID) -> Doctor:
    # 1. Check cache
    cache_key = f"doctor:{doctor_id}"
    cached = await cache.get(cache_key)
    if cached:
        return cached  # Cache hit - return immediately
    
    # 2. Cache miss - query database
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    
    # 3. Update cache for future requests
    if doctor:
        await cache.set(cache_key, doctor, ttl=900)
    
    return doctor
```

**Metrics:**

- Cache hit: ~5-10ms response time
- Cache miss: ~50-100ms response time
- Database query saved on cache hit

---

### Pattern 2: Write-Through Cache (CREATE/UPDATE Requests)

```
┌────────┐     ┌─────────────┐     ┌──────────┐
│ Client │────▶│ Application │────▶│ Database │
└────────┘     └─────────────┘     └────┬─────┘
                     ▲                   │
                     │                   │ Write
                     │                   ▼
                     │               Success
                     │                   │
                     │     ┌───────┐     │
                     │     │ Cache │◀────┤
                     │     └───┬───┘  Update
                     │         │
                     │         │ Invalidate
                     │         │ Old Keys
                     │         │
                     │◀────────┤
                     │  Return
                     │
```

**Implementation:**

```python
async def update_doctor(
    db: Session,
    doctor_id: UUID,
    doctor_data: DoctorUpdate
) -> Doctor:
    # 1. Update database
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    if not doctor:
        raise HTTPException(404, "Doctor not found")
    
    for field, value in doctor_data.dict(exclude_unset=True).items():
        setattr(doctor, field, value)
    
    db.commit()
    db.refresh(doctor)
    
    # 2. Invalidate cache (write-through)
    await cache.delete(f"doctor:{doctor_id}")
    await cache.clear_pattern("doctor:list:*")
    
    # 3. Optional: Update cache immediately (write-back)
    # await cache.set(f"doctor:{doctor_id}", doctor, ttl=900)
    
    return doctor
```

**Benefits:**

- Database is source of truth
- Cache invalidation prevents stale data
- Next read will repopulate cache

---

### Pattern 3: Cache-Aside (Manual Cache Management)

```python
# List operations often use cache-aside pattern
async def get_doctors(
    db: Session,
    skip: int = 0,
    limit: int = 20,
    filters: dict = None
) -> List[Doctor]:
    # 1. Generate cache key from filters
    filter_hash = hashlib.md5(
        json.dumps(filters, sort_keys=True).encode()
    ).hexdigest()
    cache_key = f"doctor:list:{filter_hash}:{skip}:{limit}"
    
    # 2. Check cache
    cached = await cache.get(cache_key)
    if cached:
        return cached
    
    # 3. Query database
    query = db.query(Doctor)
    if filters:
        # Apply filters
        pass
    doctors = query.offset(skip).limit(limit).all()
    
    # 4. Store in cache
    await cache.set(cache_key, doctors, ttl=300)  # 5 min for lists
    
    return doctors
```

---

## Caching Strategies

### TTL (Time-To-Live) Strategy

Different data types have different cache durations:

| Data Type | TTL | Rationale |
|-----------|-----|-----------|
| Individual records | 15 min (900s) | Moderate update frequency |
| List results | 5 min (300s) | Frequently changing |
| Static data | 1 hour (3600s) | Rarely changes |
| Session data | 24 hours | User session duration |
| Geographic queries | No cache | Location-dependent |
| Verification status | 1 hour | Admin operations |

### Cache Warming

Preload frequently accessed data:

```python
async def warm_cache():
    """
    Warm cache with frequently accessed data.
    Run on application startup or scheduled.
    """
    db = SessionLocal()
    try:
        # Warm top doctors
        top_doctors = db.query(Doctor)\
            .filter(Doctor.is_verified == True)\
            .order_by(Doctor.rating.desc())\
            .limit(50)\
            .all()
        
        for doctor in top_doctors:
            cache_key = f"doctor:{doctor.id}"
            await cache.set(cache_key, doctor, ttl=900)
        
        # Warm active clinics
        active_clinics = db.query(Clinic)\
            .filter(Clinic.status == 'active')\
            .limit(100)\
            .all()
        
        for clinic in active_clinics:
            cache_key = f"clinic:{clinic.id}"
            await cache.set(cache_key, clinic, ttl=900)
    finally:
        db.close()
```

### Cache Stampede Prevention

Prevent multiple requests from hitting database simultaneously:

```python
import asyncio
from functools import wraps

# Simple locking mechanism
_locks = {}

async def get_with_lock(cache_key: str, fetch_func):
    """
    Prevent cache stampede with async lock.
    Only one request fetches from DB, others wait.
    """
    # Check cache first
    cached = await cache.get(cache_key)
    if cached:
        return cached
    
    # Acquire lock for this key
    if cache_key not in _locks:
        _locks[cache_key] = asyncio.Lock()
    
    async with _locks[cache_key]:
        # Double-check cache (another request may have populated it)
        cached = await cache.get(cache_key)
        if cached:
            return cached
        
        # Fetch from database
        result = await fetch_func()
        
        # Update cache
        await cache.set(cache_key, result, ttl=900)
        
        return result
```

---

## Cache Invalidation

### Invalidation Strategies

#### 1. Direct Invalidation

Delete specific cache keys on updates:

```python
# Update doctor
await cache.delete(f"doctor:{doctor_id}")
```

#### 2. Pattern-Based Invalidation

Delete multiple related keys:

```python
# Update doctor - invalidate all list caches
await cache.clear_pattern("doctor:list:*")

# Delete clinic - invalidate clinic and related doctors
await cache.delete(f"clinic:{clinic_id}")
await cache.clear_pattern(f"clinic:{clinic_id}:*")
await cache.clear_pattern("clinic:list:*")
```

#### 3. Tag-Based Invalidation

Use tags to group related keys:

```python
# When creating cache entry, add to tag set
await cache.sadd(f"tag:doctor:{doctor_id}", cache_key)

# Invalidate all keys with tag
tag_keys = await cache.smembers(f"tag:doctor:{doctor_id}")
for key in tag_keys:
    await cache.delete(key)
```

### Invalidation Events

| Event | Invalidation Strategy |
|-------|----------------------|
| Create doctor | Clear `doctor:list:*` |
| Update doctor | Delete `doctor:{id}`, clear `doctor:list:*` |
| Verify doctor | Delete `doctor:{id}`, clear `doctor:list:*` |
| Create clinic | Clear `clinic:list:*` |
| Update clinic | Delete `clinic:{id}`, clear `clinic:list:*` |
| Add doctor to clinic | Delete `clinic:{id}:doctors`, `doctor:{id}:clinics` |
| Update appointment | Delete `appointment:{id}`, `patient:{id}:appointments` |

---

## Performance Optimization

### Query Optimization

```python
# Bad: N+1 query problem
doctors = db.query(Doctor).all()
for doctor in doctors:
    clinics = doctor.clinics  # Separate query for each doctor!

# Good: Eager loading
from sqlalchemy.orm import joinedload

doctors = db.query(Doctor)\
    .options(joinedload(Doctor.clinics))\
    .all()
# Single query with JOIN
```

### Pagination

```python
# Always paginate large result sets
def get_doctors(skip: int = 0, limit: int = 20):
    return db.query(Doctor)\
        .offset(skip)\
        .limit(min(limit, 100))  # Cap at 100
        .all()
```

### Database Indexes

Ensure indexed columns for common queries:

```sql
-- Frequently filtered columns
CREATE INDEX idx_doctors_specialization ON doctors(specialization);
CREATE INDEX idx_doctors_is_verified ON doctors(is_verified);
CREATE INDEX idx_clinics_status ON clinics(status);

-- Foreign keys (auto-indexed)
CREATE INDEX idx_appointments_patient_id ON appointments(patient_id);
CREATE INDEX idx_appointments_doctor_id ON appointments(doctor_id);
```

### Connection Pooling

```python
# Reuse database connections
engine = create_engine(
    DATABASE_URL,
    pool_size=20,           # Idle connections
    max_overflow=40,        # Additional under load
    pool_pre_ping=True,     # Verify before use
    pool_recycle=3600       # Recycle hourly
)
```

---

## Monitoring & Observability

### Cache Metrics

Track cache performance:

```python
# app/core/cache.py
class CacheManager:
    def __init__(self, redis_client):
        self.redis = redis_client
        self.hits = 0
        self.misses = 0
    
    async def get(self, key: str):
        value = self.redis.get(key)
        if value:
            self.hits += 1
        else:
            self.misses += 1
        return value
    
    def hit_rate(self) -> float:
        total = self.hits + self.misses
        return self.hits / total if total > 0 else 0.0
```

### Prometheus Metrics

```python
from prometheus_client import Counter, Histogram

# Cache metrics
cache_hits = Counter('cache_hits_total', 'Total cache hits')
cache_misses = Counter('cache_misses_total', 'Total cache misses')

# Database metrics
db_query_duration = Histogram('db_query_duration_seconds', 'DB query duration')

# Usage
@db_query_duration.time()
def query_database():
    return db.query(Doctor).all()
```

### Logging

```python
import logging

logger = logging.getLogger(__name__)

async def get_doctor_by_id(doctor_id: UUID):
    logger.info(f"Fetching doctor {doctor_id}")
    
    cached = await cache.get(f"doctor:{doctor_id}")
    if cached:
        logger.debug(f"Cache hit for doctor {doctor_id}")
        return cached
    
    logger.debug(f"Cache miss for doctor {doctor_id}, querying DB")
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    
    if doctor:
        await cache.set(f"doctor:{doctor_id}", doctor, ttl=900)
        logger.debug(f"Cached doctor {doctor_id}")
    
    return doctor
```

---

## Best Practices

### Application Layer

1. **Keep controllers thin** - Business logic belongs in services
2. **Use dependency injection** - Easier testing and flexibility
3. **Validate early** - Use Pydantic schemas at API boundary
4. **Handle errors gracefully** - Consistent error responses
5. **Log strategically** - Debug logs for development, info/error for production

### Caching Layer

1. **Cache hot data** - Focus on frequently accessed records
2. **Set appropriate TTLs** - Balance freshness and hit rate
3. **Invalidate proactively** - Don't wait for expiration on updates
4. **Monitor hit rates** - Target >80% for individual records
5. **Fail gracefully** - Application should work if cache is down

### Database Layer

1. **Use connection pooling** - Reuse connections efficiently
2. **Index wisely** - Index filtered and joined columns
3. **Avoid N+1 queries** - Use eager loading
4. **Paginate results** - Never return unbounded lists
5. **Use transactions** - Ensure data consistency

---

## Troubleshooting

### High Cache Miss Rate

**Symptoms:** Cache hit rate < 50%

**Possible Causes:**

- TTL too short
- Cache keys not consistent
- Cold cache after restart
- Data changes too frequently

**Solutions:**

- Increase TTL for stable data
- Implement cache warming
- Review invalidation logic

---

### Database Connection Pool Exhausted

**Symptoms:** `TimeoutError: QueuePool limit... exceeded`

**Possible Causes:**

- Too many concurrent requests
- Long-running queries
- Connections not closed properly

**Solutions:**

- Increase pool size
- Optimize slow queries
- Ensure session cleanup
- Add connection timeout

---

### Stale Cache Data

**Symptoms:** Users see outdated information

**Possible Causes:**

- Missing cache invalidation
- Invalidation pattern doesn't match
- Race condition in updates

**Solutions:**

- Review invalidation logic
- Use pattern-based invalidation
- Consider shorter TTLs
- Implement cache versioning

---

## Related Documentation

- [Database Architecture](database.md)
- [Caching Strategy & Implementation](caching.md) - Comprehensive caching guide with all cache keys, TTL strategies, and invalidation patterns
- [API Specifications](../api/specifications.md)
- [System Architecture](overview.md)

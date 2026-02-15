# Caching Strategy & Implementation

**Version:** 2.0  
**Last Updated:** February 7, 2026

---

## Overview

This document provides comprehensive documentation of the caching strategy implemented in the Medico24 platform using Redis Cloud. It covers cache keys, TTL strategies, invalidation patterns, and best practices.

### Caching Goals

- ✅ Reduce database load by 70-80%
- ✅ Achieve <10ms response time for cached data
- ✅ Maintain >85% cache hit rate for hot data
- ✅ Ensure data consistency across cache and database
- ✅ Scale horizontally without session affinity

---

## Table of Contents

1. [Redis Configuration](#redis-configuration)
2. [Cache Key Conventions](#cache-key-conventions)
3. [TTL Strategies](#ttl-strategies)
4. [Cache Keys Reference](#cache-keys-reference)
5. [Caching Patterns](#caching-patterns)
6. [Cache Invalidation](#cache-invalidation)
7. [Cache Warming](#cache-warming)
8. [Monitoring & Metrics](#monitoring--metrics)
9. [Best Practices](#best-practices)

---

## Redis Configuration

### Infrastructure

**Provider:** Redis Labs Cloud (Managed Service)  
**Region:** Singapore (ap-southeast-1)  
**Version:** Redis 7.2+  
**Connection:** TLS 1.2+ required  
**Persistence:** AOF + RDB snapshots

### Connection Settings

```python
# app/core/config.py
REDIS_URL = "rediss://default:password@redis-12345.cloud.redislabs.com:12345"
REDIS_MAX_CONNECTIONS = 50
REDIS_SOCKET_TIMEOUT = 5
REDIS_SOCKET_CONNECT_TIMEOUT = 5
REDIS_RETRY_ON_TIMEOUT = True
REDIS_HEALTH_CHECK_INTERVAL = 30
```

### Connection Pool

```python
# app/core/redis.py
import redis
from redis.connection import ConnectionPool

pool = ConnectionPool(
    connection_class=redis.SSLConnection,
    max_connections=50,
    socket_timeout=5,
    socket_connect_timeout=5,
    socket_keepalive=True,
    health_check_interval=30,
    decode_responses=False,  # Handle bytes for pickle
)

redis_client = redis.Redis(connection_pool=pool)
```

---

## Cache Key Conventions

### Naming Pattern

```
{entity}:{identifier}[:{sub-key}][:{filter-hash}]
```

### Key Components

1. **Entity**: Primary resource type (user, doctor, clinic, etc.)
2. **Identifier**: UUID or unique identifier
3. **Sub-key** (optional): Related resource or property
4. **Filter-hash** (optional): MD5 hash of filter parameters

### Examples

```python
# Individual records
"user:123e4567-e89b-12d3-a456-426614174000"
"doctor:987e6543-e21b-12d3-a456-426614174000"
"clinic:abc12345-e89b-12d3-a456-426614174000"

# Relationships
"doctor:987e6543:clinics"
"clinic:abc12345:doctors"
"patient:123e4567:appointments"

# Lists with filters
"doctor:list:5f4dcc3b5aa765d61d8327deb882cf99"
"clinic:list:active:1:20"
"pharmacy:list:verified:0:50"

# Session data
"session:user:123e4567"
"refresh_token:abc123def456"

# Verification data
"doctor:verify:987e6543"
"pharmacy:verify:xyz789"
```

---

## TTL Strategies

### TTL Guidelines by Data Type

| Data Type | TTL | Rationale |
|-----------|-----|-----------|
| **Individual Records** | | |
| User profile | 900s (15 min) | Moderate update frequency |
| Doctor profile | 900s (15 min) | Moderate update frequency |
| Clinic details | 900s (15 min) | Moderate update frequency |
| Pharmacy details | 1800s (30 min) | Low update frequency |
| Patient profile | 600s (10 min) | Higher update frequency |
| Appointment | 300s (5 min) | Frequently updated status |
| **List Results** | | |
| Doctor lists | 300s (5 min) | Frequently changing |
| Clinic lists | 300s (5 min) | Frequently changing |
| Pharmacy lists | 600s (10 min) | Less frequently changing |
| Appointment lists | 180s (3 min) | Highly dynamic |
| **Relationships** | | |
| Doctor-clinic associations | 600s (10 min) | Moderate changes |
| Clinic doctors | 600s (10 min) | Moderate changes |
| Patient appointments | 180s (3 min) | Frequently updated |
| **Session Data** | | |
| User sessions | 86400s (24 hours) | Session duration |
| Refresh tokens | 2592000s (30 days) | Token lifetime |
| **Verification Data** | | |
| Doctor verification | 3600s (1 hour) | Admin operation |
| Pharmacy verification | 3600s (1 hour) | Admin operation |
| **Static/Reference Data** | | |
| System configurations | 3600s (1 hour) | Rarely changes |
| Static content | 7200s (2 hours) | Very stable |

### Dynamic TTL

```python
def get_ttl_for_entity(entity_type: str, is_verified: bool = None) -> int:
    """
    Calculate TTL based on entity type and state.
    Verified/stable entities get longer TTL.
    """
    base_ttls = {
        "user": 900,
        "doctor": 900,
        "clinic": 900,
        "pharmacy": 1800,
        "appointment": 300,
    }
    
    ttl = base_ttls.get(entity_type, 600)
    
    # Extend TTL for verified entities
    if is_verified and entity_type in ["doctor", "pharmacy"]:
        ttl = int(ttl * 1.5)
    
    return ttl
```

---

## Cache Keys Reference

### User & Authentication Keys

```python
# User profiles
"user:{user_id}"                              # TTL: 900s
"user:email:{email_hash}"                     # TTL: 900s
"user:firebase:{firebase_uid}"                # TTL: 900s

# Sessions
"session:user:{user_id}"                      # TTL: 86400s
"session:token:{token_hash}"                  # TTL: 86400s

# Refresh tokens
"refresh_token:{token}"                       # TTL: 2592000s
"refresh_token:user:{user_id}"                # TTL: 2592000s

# Push tokens
"push_tokens:user:{user_id}"                  # TTL: 3600s
```

### Doctor Keys

```python
# Individual doctors
"doctor:{doctor_id}"                          # TTL: 900s
"doctor:email:{email_hash}"                   # TTL: 900s
"doctor:license:{license_number}"             # TTL: 900s

# Doctor lists
"doctor:list:{filter_hash}"                   # TTL: 300s
"doctor:list:verified"                        # TTL: 300s
"doctor:list:specialization:{spec}"           # TTL: 300s

# Doctor relationships
"doctor:{doctor_id}:clinics"                  # TTL: 600s
"doctor:{doctor_id}:appointments"             # TTL: 180s

# Nearby search (not cached - location dependent)
# "doctor:nearby:*" - Not cached

# Verification
"doctor:verify:{doctor_id}"                   # TTL: 3600s
```

### Clinic Keys

```python
# Individual clinics
"clinic:{clinic_id}"                          # TTL: 900s
"clinic:slug:{slug}"                          # TTL: 900s

# Clinic lists
"clinic:list:{filter_hash}"                   # TTL: 300s
"clinic:list:active"                          # TTL: 300s
"clinic:list:status:{status}"                 # TTL: 300s

# Clinic relationships
"clinic:{clinic_id}:doctors"                  # TTL: 600s
"clinic:{clinic_id}:appointments"             # TTL: 180s

# Doctor-clinic associations
"doctor_clinic:{association_id}"              # TTL: 600s
"doctor_clinic:{doctor_id}:{clinic_id}"       # TTL: 600s

# Nearby search (not cached)
# "clinic:nearby:*" - Not cached
```

### Pharmacy Keys

```python
# Individual pharmacies
"pharmacy:{pharmacy_id}"                      # TTL: 1800s
"pharmacy:slug:{slug}"                        # TTL: 1800s

# Pharmacy lists
"pharmacy:list:{filter_hash}"                 # TTL: 600s
"pharmacy:list:verified"                      # TTL: 600s
"pharmacy:list:delivery"                      # TTL: 600s

# Pharmacy staff
"pharmacy:{pharmacy_id}:staff"                # TTL: 1800s
"pharmacy_staff:{staff_id}"                   # TTL: 1800s
"pharmacy_staff:user:{user_id}"               # TTL: 1800s

# Nearby search (not cached)
# "pharmacy:nearby:*" - Not cached

# Verification
"pharmacy:verify:{pharmacy_id}"               # TTL: 3600s
```

### Appointment Keys

```python
# Individual appointments
"appointment:{appointment_id}"                # TTL: 300s

# Appointment lists
"appointment:patient:{patient_id}"            # TTL: 180s
"appointment:doctor:{doctor_id}"              # TTL: 180s
"appointment:clinic:{clinic_id}"              # TTL: 180s
"appointment:list:{filter_hash}"              # TTL: 180s

# Status-based lists
"appointment:upcoming:{user_id}"              # TTL: 180s
"appointment:past:{user_id}"                  # TTL: 600s
```

### Patient Keys

```python
# Individual patients
"patient:{patient_id}"                        # TTL: 600s
"patient:user:{user_id}"                      # TTL: 600s

# Medical records (sensitive - shorter TTL)
"patient:{patient_id}:medical_history"        # TTL: 300s
"patient:{patient_id}:appointments"           # TTL: 180s
```

### Admin Keys

```python
# Admin profiles
"admin:{admin_id}"                            # TTL: 1800s
"admin:user:{user_id}"                        # TTL: 1800s

# Admin permissions
"admin:{admin_id}:permissions"                # TTL: 3600s

# Admin metrics
"admin:metrics:dashboard"                     # TTL: 60s
"admin:metrics:appointments"                  # TTL: 60s
"admin:metrics:users"                         # TTL: 60s
```

### Notification Keys

```python
# Notification history
"notification:user:{user_id}"                 # TTL: 3600s
"notification:{notification_id}"              # TTL: 3600s

# Unread counts
"notification:unread:{user_id}"               # TTL: 300s
```

---

## Caching Patterns

### 1. Read-Through Cache

**Use Case:** Individual record retrieval

```python
async def get_doctor_by_id(db: Session, doctor_id: UUID) -> Doctor:
    cache_key = f"doctor:{doctor_id}"
    
    # Try cache first
    cached = await cache.get(cache_key)
    if cached:
        return cached
    
    # Cache miss - query database
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    
    # Store in cache
    if doctor:
        ttl = get_ttl_for_entity("doctor", doctor.is_verified)
        await cache.set(cache_key, doctor, ttl=ttl)
    
    return doctor
```

**Metrics:**
- Cache Hit: ~5-10ms
- Cache Miss: ~50-100ms
- Database queries saved: 85-90%

---

### 2. Write-Through Cache

**Use Case:** Create/Update operations

```python
async def update_doctor(
    db: Session,
    doctor_id: UUID,
    doctor_data: DoctorUpdate
) -> Doctor:
    # Update database
    doctor = db.query(Doctor).filter(Doctor.id == doctor_id).first()
    for field, value in doctor_data.dict(exclude_unset=True).items():
        setattr(doctor, field, value)
    
    db.commit()
    db.refresh(doctor)
    
    # Invalidate related caches
    await cache.delete(f"doctor:{doctor_id}")
    await cache.delete(f"doctor:email:{hash(doctor.email)}")
    await cache.clear_pattern("doctor:list:*")
    await cache.clear_pattern(f"doctor:{doctor_id}:*")
    
    return doctor
```

---

### 3. Cache-Aside with Filter Hashing

**Use Case:** Filtered list queries

```python
import hashlib
import json

async def get_doctors(
    db: Session,
    skip: int = 0,
    limit: int = 20,
    filters: dict = None
) -> List[Doctor]:
    # Generate cache key from filters
    filter_data = {
        "skip": skip,
        "limit": limit,
        **(filters or {})
    }
    filter_hash = hashlib.md5(
        json.dumps(filter_data, sort_keys=True).encode()
    ).hexdigest()
    
    cache_key = f"doctor:list:{filter_hash}"
    
    # Try cache
    cached = await cache.get(cache_key)
    if cached:
        return cached
    
    # Query database
    query = db.query(Doctor)
    
    # Apply filters
    if filters:
        if filters.get("specialization"):
            query = query.filter(Doctor.specialization == filters["specialization"])
        if filters.get("is_verified") is not None:
            query = query.filter(Doctor.is_verified == filters["is_verified"])
        # ... more filters
    
    doctors = query.offset(skip).limit(limit).all()
    
    # Cache result
    await cache.set(cache_key, doctors, ttl=300)
    
    return doctors
```

---

### 4. Cache Stampede Prevention

**Use Case:** High-concurrency scenarios

```python
import asyncio

_locks = {}

async def get_with_lock(cache_key: str, fetch_func, ttl: int = 900):
    """
    Prevent multiple simultaneous database queries for same key.
    """
    # Check cache first
    cached = await cache.get(cache_key)
    if cached:
        return cached
    
    # Create lock if doesn't exist
    if cache_key not in _locks:
        _locks[cache_key] = asyncio.Lock()
    
    # Acquire lock
    async with _locks[cache_key]:
        # Double-check cache
        cached = await cache.get(cache_key)
        if cached:
            return cached
        
        # Fetch data
        result = await fetch_func()
        
        # Cache it
        if result:
            await cache.set(cache_key, result, ttl=ttl)
        
        return result

# Usage
doctor = await get_with_lock(
    f"doctor:{doctor_id}",
    lambda: db.query(Doctor).filter(Doctor.id == doctor_id).first(),
    ttl=900
)
```

---

## Cache Invalidation

### Invalidation Strategies

#### 1. Direct Invalidation

Single key deletion for specific records:

```python
# Update doctor
await cache.delete(f"doctor:{doctor_id}")
await cache.delete(f"doctor:email:{email_hash}")
```

#### 2. Pattern-Based Invalidation

Delete multiple related keys:

```python
# Update doctor - invalidate all lists
await cache.clear_pattern("doctor:list:*")

# Update clinic - invalidate clinic and relationships
await cache.delete(f"clinic:{clinic_id}")
await cache.clear_pattern(f"clinic:{clinic_id}:*")
await cache.clear_pattern("clinic:list:*")
```

#### 3. Relationship Invalidation

Invalidate related entities:

```python
# Add doctor to clinic
await cache.delete(f"clinic:{clinic_id}:doctors")
await cache.delete(f"doctor:{doctor_id}:clinics")
await cache.clear_pattern("doctor:list:*")
await cache.clear_pattern("clinic:list:*")
```

### Invalidation Event Matrix

| Event | Keys to Invalidate |
|-------|-------------------|
| **User Operations** | |
| Create user | `user:email:{hash}`, `user:list:*` |
| Update user | `user:{id}`, `user:firebase:{uid}` |
| Delete user | `user:{id}`, `user:*:{id}`, all related entities |
| **Doctor Operations** | |
| Create doctor | `doctor:list:*`, `doctor:email:{email_hash}` |
| Update doctor | `doctor:{id}`, `doctor:email:{email_hash}`, `doctor:list:*` |
| Verify doctor | `doctor:{id}`, `doctor:verify:{id}`, `doctor:list:*` |
| Delete doctor | `doctor:{id}`, `doctor:*`, `doctor:list:*` |
| **Clinic Operations** | |
| Create clinic | `clinic:list:*` |
| Update clinic | `clinic:{id}`, `clinic:slug:{slug}`, `clinic:list:*` |
| Delete clinic | `clinic:{id}`, `clinic:*`, `clinic:list:*` |
| **Doctor-Clinic Associations** | |
| Add association | `doctor:{id}:clinics`, `clinic:{id}:doctors`, lists |
| Update association | `doctor_clinic:{id}`, doctor/clinic relationships |
| Remove association | `doctor:{id}:clinics`, `clinic:{id}:doctors`, lists |
| **Appointment Operations** | |
| Create appointment | `appointment:patient:{id}`, `appointment:doctor:{id}`, `appointment:upcoming:{id}` |
| Update appointment | `appointment:{id}`, all appointment lists |
| Cancel appointment | `appointment:{id}`, `appointment:upcoming:{id}`, lists |
| **Pharmacy Operations** | |
| Create pharmacy | `pharmacy:list:*` |
| Update pharmacy | `pharmacy:{id}`, `pharmacy:slug:{slug}`, `pharmacy:list:*` |
| Verify pharmacy | `pharmacy:{id}`, `pharmacy:verify:{id}`, `pharmacy:list:*` |

---

## Cache Warming

### Startup Warm-up

Pre-populate cache with frequently accessed data:

```python
async def warm_cache_on_startup():
    """
    Warm cache with hot data during application startup.
    """
    db = SessionLocal()
    try:
        # Warm verified doctors
        verified_doctors = db.query(Doctor)\
            .filter(Doctor.is_verified == True)\
            .order_by(Doctor.rating.desc())\
            .limit(100)\
            .all()
        
        for doctor in verified_doctors:
            cache_key = f"doctor:{doctor.id}"
            await cache.set(cache_key, doctor, ttl=900)
        
        # Warm active clinics
        active_clinics = db.query(Clinic)\
            .filter(Clinic.status == 'active')\
            .order_by(Clinic.rating.desc())\
            .limit(100)\
            .all()
        
        for clinic in active_clinics:
            cache_key = f"clinic:{clinic.id}"
            await cache.set(cache_key, clinic, ttl=900)
        
        # Warm verified pharmacies
        verified_pharmacies = db.query(Pharmacy)\
            .filter(Pharmacy.is_verified == True)\
            .limit(100)\
            .all()
        
        for pharmacy in verified_pharmacies:
            cache_key = f"pharmacy:{pharmacy.id}"
            await cache.set(cache_key, pharmacy, ttl=1800)
        
        logger.info("Cache warming completed successfully")
    
    except Exception as e:
        logger.error(f"Cache warming failed: {e}")
    finally:
        db.close()
```

### Scheduled Warm-up

Periodically refresh hot data:

```python
from apscheduler.schedulers.asyncio import AsyncIOScheduler

scheduler = AsyncIOScheduler()

@scheduler.scheduled_job('interval', hours=1)
async def refresh_hot_cache():
    """
    Refresh frequently accessed data every hour.
    """
    # Refresh top doctors list
    cache_key = "doctor:list:verified:top:50"
    top_doctors = await fetch_top_doctors(limit=50)
    await cache.set(cache_key, top_doctors, ttl=3600)
    
    # Refresh active clinics
    cache_key = "clinic:list:active:top:50"
    top_clinics = await fetch_top_clinics(limit=50)
    await cache.set(cache_key, top_clinics, ttl=3600)
```

---

## Monitoring & Metrics

### Cache Performance Metrics

```python
from prometheus_client import Counter, Histogram, Gauge

# Cache operations
cache_hits = Counter('cache_hits_total', 'Total cache hits', ['entity_type'])
cache_misses = Counter('cache_misses_total', 'Total cache misses', ['entity_type'])
cache_errors = Counter('cache_errors_total', 'Total cache errors', ['operation'])

# Cache latency
cache_get_duration = Histogram('cache_get_duration_seconds', 'Cache GET duration')
cache_set_duration = Histogram('cache_set_duration_seconds', 'Cache SET duration')

# Cache size
cache_size = Gauge('cache_total_keys', 'Total number of keys in cache')
cache_memory_usage = Gauge('cache_memory_bytes', 'Cache memory usage in bytes')

# Usage example
@cache_get_duration.time()
async def get_from_cache(key: str):
    try:
        value = await cache.get(key)
        if value:
            cache_hits.labels(entity_type=key.split(':')[0]).inc()
        else:
            cache_misses.labels(entity_type=key.split(':')[0]).inc()
        return value
    except Exception as e:
        cache_errors.labels(operation='get').inc()
        raise
```

### Cache Hit Rate Calculation

```python
class CacheMetrics:
    def __init__(self):
        self.hits = 0
        self.misses = 0
    
    def hit_rate(self) -> float:
        total = self.hits + self.misses
        return (self.hits / total * 100) if total > 0 else 0.0
    
    def miss_rate(self) -> float:
        return 100.0 - self.hit_rate()
    
    def record_hit(self, entity_type: str = None):
        self.hits += 1
        cache_hits.labels(entity_type=entity_type or 'unknown').inc()
    
    def record_miss(self, entity_type: str = None):
        self.misses += 1
        cache_misses.labels(entity_type=entity_type or 'unknown').inc()

cache_metrics = CacheMetrics()
```

### Health Checks

```python
async def check_cache_health() -> dict:
    """
    Comprehensive cache health check.
    """
    try:
        # Ping Redis
        await cache.redis.ping()
        
        # Get stats
        info = await cache.redis.info()
        
        # Get hit rate
        hit_rate = cache_metrics.hit_rate()
        
        return {
            "status": "healthy",
            "connected": True,
            "hit_rate": hit_rate,
            "memory_used": info.get("used_memory_human"),
            "total_keys": await cache.redis.dbsize(),
            "uptime_seconds": info.get("uptime_in_seconds")
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "connected": False,
            "error": str(e)
        }
```

---

## Best Practices

### 1. Cache Key Design

✅ **DO:**
- Use consistent naming conventions
- Include entity type prefix
- Use UUIDs for identifiers
- Hash long filter combinations
- Keep keys under 200 characters

❌ **DON'T:**
- Use spaces in keys
- Include sensitive data
- Use sequential IDs that reveal counts
- Create unbounded key patterns

### 2. TTL Management

✅ **DO:**
- Set appropriate TTLs for each data type
- Use longer TTLs for stable data
- Consider data volatility
- Extend TTL for verified/stable entities
- Use dynamic TTL based on entity state

❌ **DON'T:**
- Set TTL = 0 (never expire) for dynamic data
- Use same TTL for all data types
- Set TTL too short (causes thrashing)
- Set TTL too long (stale data)

### 3. Invalidation

✅ **DO:**
- Invalidate on all data modifications
- Use pattern-based invalidation for lists
- Invalidate related entities
- Log invalidation events
- Test invalidation logic thoroughly

❌ **DON'T:**
- Rely solely on TTL expiration
- Forget relationship invalidation
- Invalidate too broadly (performance impact)
- Skip invalidation for "small" updates

### 4. Error Handling

✅ **DO:**
- Gracefully handle cache failures
- Fall back to database on cache errors
- Log cache errors for monitoring
- Retry transient failures
- Continue operation if cache is down

❌ **DON'T:**
- Fail requests on cache errors
- Assume cache is always available
- Silently swallow cache errors
- Block on cache operations indefinitely

### 5. Serialization

✅ **DO:**
- Prefer JSON for simple types
- Use pickle for complex objects
- Compress large values
- Validate deserialized data
- Handle serialization errors

❌ **DON'T:**
- Store huge objects in cache
- Pickle sensitive data without encryption
- Mix serialization formats inconsistently
- Cache binary data without consideration

---

## Troubleshooting Guide

### High Cache Miss Rate

**Symptoms:** Hit rate < 70%

**Causes:**
- TTL too short
- Cache keys inconsistent
- Cold cache after restart
- Invalidation too aggressive

**Solutions:**
1. Increase TTL for stable data
2. Implement cache warming
3. Review key generation logic
4. Reduce invalidation scope

---

### Memory Pressure

**Symptoms:** Redis memory near limit, evictions occurring

**Causes:**
- TTLs too long
- Too many keys cached
- Large objects in cache
- Insufficient memory allocation

**Solutions:**
1. Reduce TTLs
2. Be more selective about what to cache
3. Compress large values
4. Increase Redis memory
5. Implement LRU eviction policy

---

### Stale Data

**Symptoms:** Users see outdated information

**Causes:**
- Missing invalidation
- Invalidation pattern mismatch
- Race conditions
- TTL too long

**Solutions:**
1. Review invalidation logic
2. Test invalidation thoroughly
3. Use shorter TTLs for volatile data
4. Implement versioning

---

### Slow Cache Operations

**Symptoms:** Cache GET/SET > 50ms

**Causes:**
- Network latency
- Large object serialization
- Connection pool exhausted
- Redis overloaded

**Solutions:**
1. Check network connectivity
2. Reduce object size
3. Increase connection pool
4. Scale Redis instance
5. Add caching layer (in-memory)

---

## Related Documentation

- [Application-Caching-Database Layers](layers.md)
- [Database Architecture](database.md)
- [API Specifications](../api/specifications.md)
- [System Architecture](overview.md)

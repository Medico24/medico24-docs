# Rate Limiting Guide

## Overview

This guide covers rate limiting implementation across all components of the Medico24 platform to protect against abuse and ensure fair resource usage.

## Rate Limiting Strategy

### Principles

1. **Protect Resources:** Prevent abuse and ensure system stability
2. **Fair Usage:** Ensure equal access for all users
3. **Performance:** Maintain system responsiveness under load
4. **Flexibility:** Different limits for different user types and endpoints
5. **Transparency:** Clear feedback about rate limits to users

### Rate Limiting Algorithms

1. **Token Bucket:** Allow burst traffic with sustained rate limit
2. **Fixed Window:** Simple implementation with fixed time windows
3. **Sliding Window:** More accurate rate limiting with memory of past requests
4. **Leaky Bucket:** Smooth out bursty traffic

## Backend Rate Limiting

### Redis-Based Rate Limiter

```python
# app/rate_limiter.py
import redis
import time
from typing import Optional
from fastapi import HTTPException
import json

class RateLimiter:
    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
    
    async def is_allowed(
        self,
        key: str,
        limit: int,
        window: int,
        algorithm: str = "sliding_window"
    ) -> tuple[bool, dict]:
        """
        Check if request is allowed based on rate limit.
        
        Returns:
            (is_allowed, info) where info contains rate limit details
        """
        if algorithm == "sliding_window":
            return await self._sliding_window(key, limit, window)
        elif algorithm == "token_bucket":
            return await self._token_bucket(key, limit, window)
        else:
            return await self._fixed_window(key, limit, window)
    
    async def _sliding_window(self, key: str, limit: int, window: int) -> tuple[bool, dict]:
        """Sliding window rate limiter using sorted sets."""
        now = time.time()
        pipeline = self.redis.pipeline()
        
        # Remove old entries
        pipeline.zremrangebyscore(key, 0, now - window)
        
        # Count current entries
        pipeline.zcard(key)
        
        # Add current request
        pipeline.zadd(key, {str(now): now})
        
        # Set expiration
        pipeline.expire(key, window)
        
        results = pipeline.execute()
        request_count = results[1]
        
        if request_count < limit:
            return True, {
                "allowed": True,
                "limit": limit,
                "remaining": limit - request_count - 1,
                "reset_time": int(now + window),
                "retry_after": None
            }
        else:
            # Remove the request we just added since it's not allowed
            self.redis.zrem(key, str(now))
            
            # Calculate retry after
            oldest_request = self.redis.zrange(key, 0, 0, withscores=True)
            retry_after = int(oldest_request[0][1] + window - now) if oldest_request else window
            
            return False, {
                "allowed": False,
                "limit": limit,
                "remaining": 0,
                "reset_time": int(now + window),
                "retry_after": retry_after
            }
    
    async def _token_bucket(self, key: str, limit: int, window: int) -> tuple[bool, dict]:
        """Token bucket rate limiter."""
        now = time.time()
        bucket_key = f"bucket:{key}"
        
        # Get current bucket state
        bucket_data = self.redis.get(bucket_key)
        
        if bucket_data:
            bucket = json.loads(bucket_data)
            last_refill = bucket["last_refill"]
            tokens = bucket["tokens"]
        else:
            last_refill = now
            tokens = limit
        
        # Calculate tokens to add based on time passed
        time_passed = now - last_refill
        tokens_to_add = time_passed * (limit / window)
        tokens = min(limit, tokens + tokens_to_add)
        
        if tokens >= 1:
            # Allow request and consume token
            tokens -= 1
            
            # Update bucket
            new_bucket = {
                "tokens": tokens,
                "last_refill": now
            }
            self.redis.setex(bucket_key, window * 2, json.dumps(new_bucket))
            
            return True, {
                "allowed": True,
                "limit": limit,
                "remaining": int(tokens),
                "reset_time": int(now + window),
                "retry_after": None
            }
        else:
            # Rate limited
            retry_after = int((1 - tokens) / (limit / window))
            
            return False, {
                "allowed": False,
                "limit": limit,
                "remaining": 0,
                "reset_time": int(now + window),
                "retry_after": retry_after
            }
    
    async def _fixed_window(self, key: str, limit: int, window: int) -> tuple[bool, dict]:
        """Fixed window rate limiter."""
        now = int(time.time())
        window_start = now - (now % window)
        window_key = f"{key}:{window_start}"
        
        current_count = self.redis.get(window_key)
        current_count = int(current_count) if current_count else 0
        
        if current_count < limit:
            # Allow request
            pipeline = self.redis.pipeline()
            pipeline.incr(window_key)
            pipeline.expire(window_key, window)
            pipeline.execute()
            
            return True, {
                "allowed": True,
                "limit": limit,
                "remaining": limit - current_count - 1,
                "reset_time": window_start + window,
                "retry_after": None
            }
        else:
            # Rate limited
            retry_after = window_start + window - now
            
            return False, {
                "allowed": False,
                "limit": limit,
                "remaining": 0,
                "reset_time": window_start + window,
                "retry_after": retry_after
            }
```

### FastAPI Middleware

```python
# app/middleware/rate_limit.py
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
import time

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(
        self,
        app,
        rate_limiter: RateLimiter,
        default_limit: int = 100,
        default_window: int = 3600,  # 1 hour
        skip_paths: list = None
    ):
        super().__init__(app)
        self.rate_limiter = rate_limiter
        self.default_limit = default_limit
        self.default_window = default_window
        self.skip_paths = skip_paths or []
    
    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for certain paths
        if request.url.path in self.skip_paths:
            return await call_next(request)
        
        # Get rate limit configuration for this endpoint
        rate_limit_config = self._get_rate_limit_config(request)
        
        if not rate_limit_config:
            return await call_next(request)
        
        # Generate rate limit key
        key = self._generate_key(request, rate_limit_config)
        
        # Check rate limit
        is_allowed, info = await self.rate_limiter.is_allowed(
            key=key,
            limit=rate_limit_config["limit"],
            window=rate_limit_config["window"],
            algorithm=rate_limit_config.get("algorithm", "sliding_window")
        )
        
        if not is_allowed:
            # Rate limited
            return JSONResponse(
                status_code=429,
                content={
                    "error": {
                        "message": "Rate limit exceeded",
                        "code": "RATE_LIMIT_EXCEEDED",
                        "retry_after": info["retry_after"]
                    }
                },
                headers={
                    "X-RateLimit-Limit": str(info["limit"]),
                    "X-RateLimit-Remaining": str(info["remaining"]),
                    "X-RateLimit-Reset": str(info["reset_time"]),
                    "Retry-After": str(info["retry_after"])
                }
            )
        
        # Process request
        response = await call_next(request)
        
        # Add rate limit headers
        response.headers["X-RateLimit-Limit"] = str(info["limit"])
        response.headers["X-RateLimit-Remaining"] = str(info["remaining"])
        response.headers["X-RateLimit-Reset"] = str(info["reset_time"])
        
        return response
    
    def _get_rate_limit_config(self, request: Request) -> dict:
        """Get rate limit configuration for the request."""
        # Check for route-specific configuration
        route = request.scope.get("route")
        if route and hasattr(route, "rate_limit"):
            return route.rate_limit
        
        # Check for user-specific limits
        user = getattr(request.state, "user", None)
        if user:
            if user.is_premium:
                return {"limit": 1000, "window": 3600}  # Premium users get higher limits
            elif user.role == "admin":
                return {"limit": 5000, "window": 3600}  # Admins get even higher limits
        
        # Default rate limit
        return {"limit": self.default_limit, "window": self.default_window}
    
    def _generate_key(self, request: Request, config: dict) -> str:
        """Generate rate limit key for the request."""
        # Use user ID if authenticated
        user = getattr(request.state, "user", None)
        if user:
            return f"rate_limit:user:{user.id}:{request.url.path}"
        
        # Fall back to IP address
        client_ip = request.client.host
        return f"rate_limit:ip:{client_ip}:{request.url.path}"
```

### Decorator-Based Rate Limiting

```python
# app/decorators/rate_limit.py
from functools import wraps
from fastapi import Request, HTTPException
from ..rate_limiter import RateLimiter

def rate_limit(
    limit: int,
    window: int,
    key_func: callable = None,
    algorithm: str = "sliding_window"
):
    """Decorator for rate limiting specific endpoints."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract request from args
            request = None
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                    break
            
            if not request:
                # If no request found, skip rate limiting
                return await func(*args, **kwargs)
            
            # Generate key
            if key_func:
                key = key_func(request)
            else:
                key = f"endpoint:{request.url.path}:ip:{request.client.host}"
            
            # Check rate limit
            rate_limiter = request.app.state.rate_limiter
            is_allowed, info = await rate_limiter.is_allowed(
                key=key,
                limit=limit,
                window=window,
                algorithm=algorithm
            )
            
            if not is_allowed:
                raise HTTPException(
                    status_code=429,
                    detail={
                        "message": "Rate limit exceeded",
                        "retry_after": info["retry_after"]
                    },
                    headers={
                        "X-RateLimit-Limit": str(info["limit"]),
                        "X-RateLimit-Remaining": str(info["remaining"]),
                        "X-RateLimit-Reset": str(info["reset_time"]),
                        "Retry-After": str(info["retry_after"])
                    }
                )
            
            return await func(*args, **kwargs)
        
        # Store rate limit config on the function
        wrapper.rate_limit = {
            "limit": limit,
            "window": window,
            "algorithm": algorithm
        }
        
        return wrapper
    return decorator

# Usage
@router.post("/auth/login")
@rate_limit(limit=5, window=300)  # 5 attempts per 5 minutes
async def login(request: Request, form_data: UserLogin):
    # Login logic
    pass

@router.get("/api/data")
@rate_limit(limit=100, window=3600, algorithm="token_bucket")
async def get_data(request: Request):
    # Data retrieval logic
    pass
```

### User-Based Rate Limiting

```python
# app/rate_limits.py
from enum import Enum

class UserTier(Enum):
    FREE = "free"
    PREMIUM = "premium"
    ADMIN = "admin"

# Rate limit configurations
RATE_LIMITS = {
    UserTier.FREE: {
        "api_calls": {"limit": 100, "window": 3600},  # 100 per hour
        "login_attempts": {"limit": 5, "window": 300},  # 5 per 5 minutes
        "password_reset": {"limit": 3, "window": 3600},  # 3 per hour
        "file_upload": {"limit": 10, "window": 3600},  # 10 per hour
    },
    UserTier.PREMIUM: {
        "api_calls": {"limit": 1000, "window": 3600},  # 1000 per hour
        "login_attempts": {"limit": 10, "window": 300},  # 10 per 5 minutes
        "password_reset": {"limit": 5, "window": 3600},  # 5 per hour
        "file_upload": {"limit": 100, "window": 3600},  # 100 per hour
    },
    UserTier.ADMIN: {
        "api_calls": {"limit": 10000, "window": 3600},  # 10000 per hour
        "login_attempts": {"limit": 50, "window": 300},  # 50 per 5 minutes
        "password_reset": {"limit": 20, "window": 3600},  # 20 per hour
        "file_upload": {"limit": 1000, "window": 3600},  # 1000 per hour
    }
}

def get_user_rate_limit(user: User, action: str) -> dict:
    """Get rate limit for user and action."""
    tier = UserTier(user.tier) if user else UserTier.FREE
    return RATE_LIMITS[tier].get(action, RATE_LIMITS[UserTier.FREE][action])
```

## Mobile App Rate Limiting

### Client-Side Rate Limiting

```dart
// lib/services/rate_limiter.dart
import 'dart:collection';

class RateLimiter {
  final Map<String, Queue<DateTime>> _requestHistory = {};
  
  bool canMakeRequest(String key, int limit, Duration window) {
    final now = DateTime.now();
    final history = _requestHistory.putIfAbsent(key, () => Queue<DateTime>());
    
    // Remove old requests outside the window
    while (history.isNotEmpty && 
           now.difference(history.first) > window) {
      history.removeFirst();
    }
    
    // Check if we can make a request
    if (history.length < limit) {
      history.add(now);
      return true;
    }
    
    return false;
  }
  
  Duration getRetryDelay(String key, int limit, Duration window) {
    final history = _requestHistory[key];
    if (history == null || history.isEmpty) {
      return Duration.zero;
    }
    
    final oldestRequest = history.first;
    final windowEnd = oldestRequest.add(window);
    final now = DateTime.now();
    
    return windowEnd.isAfter(now) 
        ? windowEnd.difference(now)
        : Duration.zero;
  }
}

// Usage in HTTP client
class ApiClient {
  final RateLimiter _rateLimiter = RateLimiter();
  
  Future<Response> makeRequest(String endpoint, {Map<String, dynamic>? data}) async {
    const limit = 10; // 10 requests
    const window = Duration(minutes: 1); // per minute
    
    final canProceed = _rateLimiter.canMakeRequest(
      'api_calls',
      limit,
      window
    );
    
    if (!canProceed) {
      final retryDelay = _rateLimiter.getRetryDelay(
        'api_calls',
        limit,
        window
      );
      
      throw RateLimitException(
        message: 'Too many requests. Please wait before trying again.',
        retryAfter: retryDelay,
      );
    }
    
    // Make the actual request
    return await _httpClient.post(endpoint, data: data);
  }
}

class RateLimitException implements Exception {
  final String message;
  final Duration retryAfter;
  
  const RateLimitException({
    required this.message,
    required this.retryAfter,
  });
}
```

### Exponential Backoff

```dart
// lib/utils/exponential_backoff.dart
import 'dart:math';

class ExponentialBackoff {
  final int maxRetries;
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;
  final double jitter;
  
  ExponentialBackoff({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.jitter = 0.1,
  });
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    var attempt = 0;
    var delay = initialDelay;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxRetries) {
          rethrow;
        }
        
        // Add jitter to prevent thundering herd
        final jitterAmount = delay.inMilliseconds * jitter * Random().nextDouble();
        final delayWithJitter = Duration(
          milliseconds: delay.inMilliseconds + jitterAmount.round()
        );
        
        await Future.delayed(delayWithJitter);
        
        // Increase delay for next attempt
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * multiplier).round(),
            maxDelay.inMilliseconds
          )
        );
      }
    }
    
    throw StateError('This should never be reached');
  }
}
```

## Web Dashboard Rate Limiting

### Client-Side Implementation

```typescript
// utils/rateLimiter.ts
interface RateLimitConfig {
  limit: number;
  windowMs: number;
}

interface RequestRecord {
  timestamp: number;
  count: number;
}

class ClientRateLimiter {
  private requestHistory = new Map<string, RequestRecord[]>();

  canMakeRequest(key: string, config: RateLimitConfig): boolean {
    const now = Date.now();
    const windowStart = now - config.windowMs;
    
    // Get or create history for this key
    const history = this.requestHistory.get(key) || [];
    
    // Remove old entries
    const validHistory = history.filter(record => record.timestamp > windowStart);
    
    // Count requests in current window
    const requestCount = validHistory.reduce((sum, record) => sum + record.count, 0);
    
    if (requestCount < config.limit) {
      // Add new request to history
      validHistory.push({ timestamp: now, count: 1 });
      this.requestHistory.set(key, validHistory);
      return true;
    }
    
    return false;
  }

  getRetryDelay(key: string, config: RateLimitConfig): number {
    const history = this.requestHistory.get(key);
    if (!history || history.length === 0) {
      return 0;
    }

    const oldestRequest = history[0];
    const windowEnd = oldestRequest.timestamp + config.windowMs;
    const now = Date.now();

    return Math.max(0, windowEnd - now);
  }

  reset(key?: string): void {
    if (key) {
      this.requestHistory.delete(key);
    } else {
      this.requestHistory.clear();
    }
  }
}

export const rateLimiter = new ClientRateLimiter();
```

### API Client with Rate Limiting

```typescript
// lib/apiClientWithRateLimit.ts
import { rateLimiter } from '../utils/rateLimiter';

class RateLimitedApiClient {
  private rateLimits = {
    default: { limit: 100, windowMs: 60000 }, // 100 per minute
    auth: { limit: 5, windowMs: 300000 }, // 5 per 5 minutes
    upload: { limit: 10, windowMs: 60000 }, // 10 per minute
  };

  async makeRequest(
    endpoint: string,
    options: RequestInit,
    rateLimitKey: keyof typeof this.rateLimits = 'default'
  ): Promise<Response> {
    const config = this.rateLimits[rateLimitKey];
    const key = `${rateLimitKey}:${endpoint}`;

    // Check client-side rate limit
    if (!rateLimiter.canMakeRequest(key, config)) {
      const retryDelay = rateLimiter.getRetryDelay(key, config);
      
      throw new RateLimitError(
        'Rate limit exceeded',
        retryDelay,
        {
          limit: config.limit,
          windowMs: config.windowMs,
          retryAfter: retryDelay,
        }
      );
    }

    try {
      const response = await fetch(endpoint, options);

      // Check server rate limit headers
      if (response.status === 429) {
        const retryAfter = parseInt(response.headers.get('Retry-After') || '60');
        const limit = parseInt(response.headers.get('X-RateLimit-Limit') || '100');
        const remaining = parseInt(response.headers.get('X-RateLimit-Remaining') || '0');

        throw new RateLimitError(
          'Server rate limit exceeded',
          retryAfter * 1000,
          {
            limit,
            remaining,
            retryAfter: retryAfter * 1000,
          }
        );
      }

      return response;
    } catch (error) {
      if (error instanceof RateLimitError) {
        throw error;
      }
      
      // Handle other errors
      throw new Error(`Request failed: ${error.message}`);
    }
  }
}

class RateLimitError extends Error {
  constructor(
    message: string,
    public retryAfter: number,
    public details: {
      limit: number;
      remaining?: number;
      retryAfter: number;
      windowMs?: number;
    }
  ) {
    super(message);
    this.name = 'RateLimitError';
  }
}
```

### React Hook for Rate Limiting

```typescript
// hooks/useRateLimit.ts
import { useState, useCallback, useEffect } from 'react';
import { rateLimiter } from '../utils/rateLimiter';

interface UseRateLimitOptions {
  limit: number;
  windowMs: number;
  key: string;
}

export const useRateLimit = (options: UseRateLimitOptions) => {
  const [canProceed, setCanProceed] = useState(true);
  const [retryAfter, setRetryAfter] = useState(0);

  const checkLimit = useCallback(() => {
    const allowed = rateLimiter.canMakeRequest(options.key, options);
    setCanProceed(allowed);

    if (!allowed) {
      const delay = rateLimiter.getRetryDelay(options.key, options);
      setRetryAfter(delay);
    }

    return allowed;
  }, [options]);

  const reset = useCallback(() => {
    rateLimiter.reset(options.key);
    setCanProceed(true);
    setRetryAfter(0);
  }, [options.key]);

  // Update retry countdown
  useEffect(() => {
    if (retryAfter > 0) {
      const interval = setInterval(() => {
        setRetryAfter(prev => {
          const newValue = prev - 1000;
          if (newValue <= 0) {
            setCanProceed(true);
            return 0;
          }
          return newValue;
        });
      }, 1000);

      return () => clearInterval(interval);
    }
  }, [retryAfter]);

  return {
    canProceed,
    retryAfter: Math.ceil(retryAfter / 1000),
    checkLimit,
    reset,
  };
};
```

## Rate Limit Headers

### Standard Headers

```python
# Standard rate limit headers
RATE_LIMIT_HEADERS = {
    "X-RateLimit-Limit": "Maximum number of requests allowed",
    "X-RateLimit-Remaining": "Number of requests remaining in window",
    "X-RateLimit-Reset": "Unix timestamp when the window resets",
    "X-RateLimit-Window": "Size of the rate limit window in seconds",
    "Retry-After": "Number of seconds to wait before retrying"
}
```

### Header Implementation

```python
# app/utils/headers.py
def add_rate_limit_headers(response: Response, info: dict):
    """Add rate limit headers to response."""
    response.headers["X-RateLimit-Limit"] = str(info["limit"])
    response.headers["X-RateLimit-Remaining"] = str(info["remaining"])
    response.headers["X-RateLimit-Reset"] = str(info["reset_time"])
    response.headers["X-RateLimit-Window"] = str(info.get("window", 3600))
    
    if info.get("retry_after"):
        response.headers["Retry-After"] = str(info["retry_after"])
```

## Monitoring and Metrics

### Rate Limit Metrics

```python
# app/metrics/rate_limit.py
from prometheus_client import Counter, Histogram, Gauge

# Rate limit metrics
rate_limit_counter = Counter(
    'medico_rate_limit_total',
    'Total number of rate limit checks',
    ['endpoint', 'user_tier', 'allowed']
)

rate_limit_exceeded_counter = Counter(
    'medico_rate_limit_exceeded_total',
    'Total number of rate limit violations',
    ['endpoint', 'user_tier']
)

rate_limit_response_time = Histogram(
    'medico_rate_limit_check_duration_seconds',
    'Time spent checking rate limits',
    ['algorithm']
)

def record_rate_limit_check(
    endpoint: str,
    user_tier: str,
    allowed: bool,
    duration: float,
    algorithm: str = "sliding_window"
):
    """Record rate limit metrics."""
    rate_limit_counter.labels(
        endpoint=endpoint,
        user_tier=user_tier,
        allowed=str(allowed).lower()
    ).inc()
    
    if not allowed:
        rate_limit_exceeded_counter.labels(
            endpoint=endpoint,
            user_tier=user_tier
        ).inc()
    
    rate_limit_response_time.labels(algorithm=algorithm).observe(duration)
```

### Alerting

```yaml
# prometheus/alerts.yml
groups:
  - name: rate_limiting
    rules:
      - alert: HighRateLimitViolations
        expr: |
          rate(medico_rate_limit_exceeded_total[5m]) > 10
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High rate of rate limit violations"
          description: "Rate limit violations are occurring at {{ $value }} per second"

      - alert: RateLimitSystemDown
        expr: |
          up{job="rate-limiter"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Rate limiting system is down"
          description: "The rate limiting service is unavailable"
```

## Best Practices

### Rate Limit Design

1. **Different Limits for Different Operations:**
   ```python
   OPERATION_LIMITS = {
       "auth": {"limit": 5, "window": 300},      # Strict for authentication
       "read": {"limit": 1000, "window": 3600},   # Generous for reads
       "write": {"limit": 100, "window": 3600},   # Moderate for writes
       "upload": {"limit": 10, "window": 3600},   # Restrictive for uploads
   }
   ```

2. **User-Based Tiers:**
   ```python
   USER_TIERS = {
       "free": {"multiplier": 1.0},
       "premium": {"multiplier": 10.0},
       "admin": {"multiplier": 100.0},
   }
   ```

3. **Graceful Error Messages:**
   ```json
   {
     "error": {
       "message": "Rate limit exceeded. You have made too many requests.",
       "code": "RATE_LIMIT_EXCEEDED",
       "retry_after": 60,
       "details": {
         "limit": 100,
         "window": 3600,
         "requests_made": 100
       }
     }
   }
   ```

### Implementation Guidelines

1. **Use Appropriate Algorithm:**
   - Fixed Window: Simple, memory efficient
   - Sliding Window: More accurate, higher memory usage
   - Token Bucket: Handles bursts well
   - Leaky Bucket: Smooth traffic flow

2. **Key Generation Strategy:**
   ```python
   def generate_rate_limit_key(request, config):
       # User-based if authenticated
       if request.user:
           return f"user:{request.user.id}:{config.get('scope', 'global')}"
       
       # IP-based for anonymous users
       return f"ip:{request.client.host}:{config.get('scope', 'global')}"
   ```

3. **Bypass for Internal Services:**
   ```python
   BYPASS_RATE_LIMIT_IPS = [
       "127.0.0.1",
       "10.0.0.0/8",
       "192.168.0.0/16"
   ]
   
   def should_bypass_rate_limit(ip: str) -> bool:
       return any(ipaddress.ip_address(ip) in ipaddress.ip_network(network) 
                 for network in BYPASS_RATE_LIMIT_IPS)
   ```

## Testing Rate Limits

### Unit Tests

```python
# tests/test_rate_limiter.py
import pytest
import time
from app.rate_limiter import RateLimiter

@pytest.fixture
async def rate_limiter(redis_client):
    return RateLimiter(redis_client)

@pytest.mark.asyncio
async def test_sliding_window_rate_limit(rate_limiter):
    key = "test:user:123"
    limit = 5
    window = 60
    
    # Should allow first 5 requests
    for i in range(5):
        allowed, info = await rate_limiter.is_allowed(key, limit, window)
        assert allowed
        assert info["remaining"] == limit - i - 1
    
    # 6th request should be denied
    allowed, info = await rate_limiter.is_allowed(key, limit, window)
    assert not allowed
    assert info["remaining"] == 0

@pytest.mark.asyncio
async def test_token_bucket_burst(rate_limiter):
    key = "test:burst:123"
    limit = 10
    window = 60
    
    # Should allow burst up to limit
    for i in range(limit):
        allowed, info = await rate_limiter.is_allowed(
            key, limit, window, "token_bucket"
        )
        assert allowed
    
    # Next request should be denied
    allowed, info = await rate_limiter.is_allowed(
        key, limit, window, "token_bucket"
    )
    assert not allowed
```

### Load Testing

```python
# tests/load_test_rate_limiter.py
import asyncio
import aiohttp
import time

async def test_rate_limit_load():
    """Test rate limiter under load."""
    url = "http://localhost:8000/api/test"
    headers = {"Authorization": "Bearer test-token"}
    
    async with aiohttp.ClientSession() as session:
        tasks = []
        start_time = time.time()
        
        # Send 1000 concurrent requests
        for i in range(1000):
            task = session.get(url, headers=headers)
            tasks.append(task)
        
        responses = await asyncio.gather(*tasks, return_exceptions=True)
        
        end_time = time.time()
        duration = end_time - start_time
        
        # Count successful vs rate limited responses
        success_count = sum(1 for r in responses if hasattr(r, 'status') and r.status == 200)
        rate_limited_count = sum(1 for r in responses if hasattr(r, 'status') and r.status == 429)
        
        print(f"Duration: {duration:.2f}s")
        print(f"Successful requests: {success_count}")
        print(f"Rate limited requests: {rate_limited_count}")
        print(f"Requests per second: {len(responses) / duration:.2f}")

if __name__ == "__main__":
    asyncio.run(test_rate_limit_load())
```

## Resources

- [Rate Limiting Patterns](https://blog.cloudflare.com/rate-limiting-nginx-conf/)
- [Redis Rate Limiting](https://redislabs.com/redis-best-practices/basic-rate-limiting/)
- [API Rate Limiting Best Practices](https://stripe.com/blog/rate-limiters)
- [Distributed Rate Limiting](https://engineering.grab.com/frequency-capping)
- [Token Bucket Algorithm](https://en.wikipedia.org/wiki/Token_bucket)
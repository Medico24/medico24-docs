# Caching Guide

## Overview

This guide covers caching strategies and implementations across all components of the Medico24 platform to improve performance and reduce load.

## Caching Strategy

### Cache Levels

1. **Browser Cache:** Static assets and API responses
2. **CDN Cache:** Global content delivery
3. **Application Cache:** In-memory and Redis caching
4. **Database Cache:** Query result caching
5. **API Gateway Cache:** Response caching at the edge

### Cache Patterns

1. **Cache-Aside:** Application manages cache directly
2. **Write-Through:** Write to cache and database simultaneously
3. **Write-Behind:** Write to cache immediately, database later
4. **Refresh-Ahead:** Proactively refresh cache before expiration

## Backend Caching

### Redis Cache Implementation

```python
# app/cache.py
import redis
import json
import pickle
from typing import Any, Optional, Union
from datetime import datetime, timedelta
import hashlib

class CacheManager:
    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
        self.default_ttl = 3600  # 1 hour
    
    async def get(self, key: str, deserialize: bool = True) -> Optional[Any]:
        """Get value from cache."""
        try:
            value = self.redis.get(key)
            if value is None:
                return None
            
            if deserialize:
                try:
                    return json.loads(value)
                except (json.JSONDecodeError, TypeError):
                    return pickle.loads(value)
            
            return value
        except Exception as e:
            logger.error(f"Cache get error for key {key}: {e}")
            return None
    
    async def set(
        self,
        key: str,
        value: Any,
        ttl: Optional[int] = None,
        serialize: bool = True
    ) -> bool:
        """Set value in cache."""
        try:
            if serialize:
                if isinstance(value, (dict, list, str, int, float, bool)):
                    serialized_value = json.dumps(value)
                else:
                    serialized_value = pickle.dumps(value)
            else:
                serialized_value = value
            
            expire_time = ttl or self.default_ttl
            self.redis.setex(key, expire_time, serialized_value)
            return True
        except Exception as e:
            logger.error(f"Cache set error for key {key}: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        """Delete key from cache."""
        try:
            return bool(self.redis.delete(key))
        except Exception as e:
            logger.error(f"Cache delete error for key {key}: {e}")
            return False
    
    async def clear_pattern(self, pattern: str) -> int:
        """Clear all keys matching pattern."""
        try:
            keys = self.redis.keys(pattern)
            if keys:
                return self.redis.delete(*keys)
            return 0
        except Exception as e:
            logger.error(f"Cache clear pattern error for {pattern}: {e}")
            return 0
    
    def generate_key(self, prefix: str, *args, **kwargs) -> str:
        """Generate cache key from arguments."""
        key_parts = [prefix] + [str(arg) for arg in args]
        
        if kwargs:
            sorted_kwargs = sorted(kwargs.items())
            key_parts.extend([f"{k}:{v}" for k, v in sorted_kwargs])
        
        key_string = ":".join(key_parts)
        
        # Hash long keys to prevent Redis key length issues
        if len(key_string) > 200:
            key_hash = hashlib.md5(key_string.encode()).hexdigest()
            return f"{prefix}:hash:{key_hash}"
        
        return key_string

cache = CacheManager(redis_client)
```

### Cache Decorators

```python
# app/decorators/cache.py
from functools import wraps
import asyncio
import inspect
from ..cache import cache

def cached(
    ttl: int = 3600,
    key_prefix: str = None,
    key_func: callable = None,
    condition: callable = None
):
    """Decorator for caching function results."""
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            # Generate cache key
            if key_func:
                cache_key = key_func(*args, **kwargs)
            else:
                prefix = key_prefix or f"func:{func.__name__}"
                cache_key = cache.generate_key(prefix, *args, **kwargs)
            
            # Check condition if provided
            if condition and not condition(*args, **kwargs):
                return await func(*args, **kwargs)
            
            # Try to get from cache
            cached_result = await cache.get(cache_key)
            if cached_result is not None:
                return cached_result
            
            # Execute function and cache result
            result = await func(*args, **kwargs)
            
            # Only cache if result is not None
            if result is not None:
                await cache.set(cache_key, result, ttl)
            
            return result
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            # Generate cache key
            if key_func:
                cache_key = key_func(*args, **kwargs)
            else:
                prefix = key_prefix or f"func:{func.__name__}"
                cache_key = cache.generate_key(prefix, *args, **kwargs)
            
            # Check condition if provided
            if condition and not condition(*args, **kwargs):
                return func(*args, **kwargs)
            
            # Try to get from cache (sync version)
            cached_result = cache.redis.get(cache_key)
            if cached_result is not None:
                try:
                    return json.loads(cached_result)
                except (json.JSONDecodeError, TypeError):
                    return pickle.loads(cached_result)
            
            # Execute function and cache result
            result = func(*args, **kwargs)
            
            # Only cache if result is not None
            if result is not None:
                try:
                    serialized = json.dumps(result)
                except (TypeError, ValueError):
                    serialized = pickle.dumps(result)
                cache.redis.setex(cache_key, ttl, serialized)
            
            return result
        
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator

# Cache invalidation decorator
def invalidate_cache(pattern: str = None, keys: list = None):
    """Decorator to invalidate cache after function execution."""
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            result = await func(*args, **kwargs)
            
            # Invalidate cache
            if pattern:
                await cache.clear_pattern(pattern)
            
            if keys:
                for key in keys:
                    await cache.delete(key)
            
            return result
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            result = func(*args, **kwargs)
            
            # Invalidate cache
            if pattern:
                cache_keys = cache.redis.keys(pattern)
                if cache_keys:
                    cache.redis.delete(*cache_keys)
            
            if keys:
                for key in keys:
                    cache.redis.delete(key)
            
            return result
        
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator
```

### Database Query Caching

```python
# app/services/user_service.py
from .cache import cached, invalidate_cache

class UserService:
    @cached(ttl=3600, key_prefix="user:profile")
    async def get_user_profile(self, user_id: str) -> dict:
        """Get user profile with caching."""
        user = await db.query(User).filter(User.id == user_id).first()
        if not user:
            return None
        
        return {
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "created_at": user.created_at.isoformat(),
            "last_login": user.last_login.isoformat() if user.last_login else None
        }
    
    @invalidate_cache(pattern="user:profile:*")
    async def update_user_profile(self, user_id: str, data: dict) -> dict:
        """Update user profile and invalidate cache."""
        user = await db.query(User).filter(User.id == user_id).first()
        for key, value in data.items():
            setattr(user, key, value)
        
        await db.commit()
        await db.refresh(user)
        
        return await self.get_user_profile(user_id)
    
    @cached(ttl=1800, key_prefix="user:appointments")
    async def get_user_appointments(self, user_id: str) -> list:
        """Get user appointments with caching."""
        appointments = await db.query(Appointment).filter(
            Appointment.user_id == user_id
        ).all()
        
        return [
            {
                "id": apt.id,
                "doctor_name": apt.doctor_name,
                "appointment_date": apt.appointment_date.isoformat(),
                "status": apt.status
            }
            for apt in appointments
        ]
```

### API Response Caching

```python
# app/middleware/cache_middleware.py
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import json

class ResponseCacheMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, cache_manager, default_ttl: int = 300):
        super().__init__(app)
        self.cache = cache_manager
        self.default_ttl = default_ttl
    
    async def dispatch(self, request: Request, call_next):
        # Check if request should be cached
        if not self._should_cache(request):
            return await call_next(request)
        
        # Generate cache key
        cache_key = self._generate_cache_key(request)
        
        # Try to get cached response
        cached_response = await self.cache.get(cache_key)
        if cached_response:
            return Response(
                content=cached_response["body"],
                status_code=cached_response["status_code"],
                headers=cached_response["headers"],
                media_type=cached_response["media_type"]
            )
        
        # Execute request
        response = await call_next(request)
        
        # Cache successful responses
        if response.status_code == 200:
            # Read response body
            body = b""
            async for chunk in response.body_iterator:
                body += chunk
            
            # Cache response data
            cache_data = {
                "body": body.decode(),
                "status_code": response.status_code,
                "headers": dict(response.headers),
                "media_type": response.media_type
            }
            
            ttl = self._get_cache_ttl(request)
            await self.cache.set(cache_key, cache_data, ttl)
            
            # Return response with cached body
            return Response(
                content=body,
                status_code=response.status_code,
                headers=response.headers,
                media_type=response.media_type
            )
        
        return response
    
    def _should_cache(self, request: Request) -> bool:
        """Determine if request should be cached."""
        # Only cache GET requests
        if request.method != "GET":
            return False
        
        # Skip authentication required endpoints
        if "auth" in request.url.path.lower():
            return False
        
        # Skip real-time endpoints
        if any(path in request.url.path for path in ["/ws/", "/live/", "/stream/"]):
            return False
        
        return True
    
    def _generate_cache_key(self, request: Request) -> str:
        """Generate cache key for request."""
        key_parts = [
            "api_response",
            request.url.path,
            str(request.query_params)
        ]
        
        # Include user ID if authenticated
        user = getattr(request.state, "user", None)
        if user:
            key_parts.append(f"user:{user.id}")
        
        return self.cache.generate_key(*key_parts)
    
    def _get_cache_ttl(self, request: Request) -> int:
        """Get cache TTL for request."""
        # Different TTL for different endpoints
        path = request.url.path.lower()
        
        if "/user/" in path:
            return 300  # 5 minutes for user data
        elif "/public/" in path:
            return 3600  # 1 hour for public data
        elif "/static/" in path:
            return 86400  # 24 hours for static content
        
        return self.default_ttl
```

## Frontend Caching

### Browser Caching

```typescript
// utils/cache.ts
interface CacheItem<T> {
  data: T;
  expiry: number;
  timestamp: number;
}

class BrowserCache {
  private storage: Storage;
  private prefix: string;

  constructor(storage: Storage = localStorage, prefix: string = 'medico24_') {
    this.storage = storage;
    this.prefix = prefix;
  }

  set<T>(key: string, data: T, ttlSeconds: number = 3600): void {
    const item: CacheItem<T> = {
      data,
      expiry: Date.now() + (ttlSeconds * 1000),
      timestamp: Date.now(),
    };

    try {
      this.storage.setItem(this.prefix + key, JSON.stringify(item));
    } catch (error) {
      console.warn('Failed to set cache item:', error);
    }
  }

  get<T>(key: string): T | null {
    try {
      const itemStr = this.storage.getItem(this.prefix + key);
      if (!itemStr) {
        return null;
      }

      const item: CacheItem<T> = JSON.parse(itemStr);

      // Check if expired
      if (Date.now() > item.expiry) {
        this.delete(key);
        return null;
      }

      return item.data;
    } catch (error) {
      console.warn('Failed to get cache item:', error);
      this.delete(key);
      return null;
    }
  }

  delete(key: string): void {
    this.storage.removeItem(this.prefix + key);
  }

  clear(): void {
    const keys = Object.keys(this.storage);
    keys.forEach(key => {
      if (key.startsWith(this.prefix)) {
        this.storage.removeItem(key);
      }
    });
  }

  getStats(): { size: number; items: number } {
    const keys = Object.keys(this.storage);
    const cacheKeys = keys.filter(key => key.startsWith(this.prefix));
    
    let totalSize = 0;
    cacheKeys.forEach(key => {
      const item = this.storage.getItem(key);
      if (item) {
        totalSize += item.length;
      }
    });

    return {
      size: totalSize,
      items: cacheKeys.length,
    };
  }
}

export const browserCache = new BrowserCache();
```

### React Query Caching

```typescript
// lib/queryClient.ts
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Cache data for 5 minutes
      staleTime: 5 * 60 * 1000,
      // Keep data in cache for 10 minutes
      cacheTime: 10 * 60 * 1000,
      // Retry failed requests
      retry: (failureCount, error: any) => {
        if (error?.status === 404) {
          return false; // Don't retry 404s
        }
        return failureCount < 3;
      },
      // Background refetch on window focus
      refetchOnWindowFocus: false,
      // Background refetch on reconnect
      refetchOnReconnect: true,
    },
    mutations: {
      // Invalidate related queries on mutation
      onSuccess: (data, variables, context: any) => {
        if (context?.invalidateQueries) {
          context.invalidateQueries.forEach((queryKey: string[]) => {
            queryClient.invalidateQueries(queryKey);
          });
        }
      },
    },
  },
});

// Cache configuration for different data types
export const cacheConfigs = {
  user: {
    staleTime: 5 * 60 * 1000, // 5 minutes
    cacheTime: 30 * 60 * 1000, // 30 minutes
  },
  appointments: {
    staleTime: 2 * 60 * 1000, // 2 minutes
    cacheTime: 10 * 60 * 1000, // 10 minutes
  },
  publicData: {
    staleTime: 30 * 60 * 1000, // 30 minutes
    cacheTime: 2 * 60 * 60 * 1000, // 2 hours
  },
  realtime: {
    staleTime: 0, // Always stale, always refetch
    cacheTime: 0, // Don't cache
  },
};
```

### Custom Hook with Caching

```typescript
// hooks/useApiWithCache.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { browserCache } from '../utils/cache';
import { apiClient } from '../lib/api';

interface UseApiOptions {
  cacheKey?: string;
  browserCacheKey?: string;
  browserCacheTtl?: number;
  enabled?: boolean;
  onSuccess?: (data: any) => void;
  onError?: (error: any) => void;
}

export const useApiWithCache = <T>(
  endpoint: string,
  options: UseApiOptions = {}
) => {
  const queryClient = useQueryClient();
  const {
    cacheKey = endpoint,
    browserCacheKey,
    browserCacheTtl = 3600,
    enabled = true,
    onSuccess,
    onError,
  } = options;

  const query = useQuery(
    [cacheKey],
    async () => {
      // Try browser cache first if enabled
      if (browserCacheKey) {
        const cachedData = browserCache.get<T>(browserCacheKey);
        if (cachedData) {
          return cachedData;
        }
      }

      // Fetch from API
      const response = await apiClient.get(endpoint);
      const data = response.data;

      // Store in browser cache
      if (browserCacheKey) {
        browserCache.set(browserCacheKey, data, browserCacheTtl);
      }

      return data;
    },
    {
      enabled,
      onSuccess,
      onError,
      ...cacheConfigs.user, // Default cache config
    }
  );

  const invalidateCache = () => {
    // Invalidate React Query cache
    queryClient.invalidateQueries([cacheKey]);
    
    // Clear browser cache
    if (browserCacheKey) {
      browserCache.delete(browserCacheKey);
    }
  };

  return {
    ...query,
    invalidateCache,
  };
};

// Usage
export const useUserProfile = (userId: string) => {
  return useApiWithCache<User>(`/users/${userId}`, {
    cacheKey: ['user', userId],
    browserCacheKey: `user_${userId}`,
    browserCacheTtl: 1800, // 30 minutes
  });
};
```

## Mobile App Caching

### Flutter Cache Implementation

```dart
// lib/services/cache_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  static const String _prefix = 'medico24_cache_';
  late SharedPreferences _prefs;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  Future<void> set<T>(
    String key, 
    T data, {
    Duration? ttl,
  }) async {
    final cacheItem = CacheItem<T>(
      data: data,
      expiry: ttl != null 
          ? DateTime.now().add(ttl).millisecondsSinceEpoch 
          : null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    final jsonString = jsonEncode(cacheItem.toJson());
    await _prefs.setString(_prefix + key, jsonString);
  }
  
  T? get<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final jsonString = _prefs.getString(_prefix + key);
    if (jsonString == null) return null;
    
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final cacheItem = CacheItem<T>.fromJson(json, fromJson);
      
      // Check expiry
      if (cacheItem.expiry != null && 
          DateTime.now().millisecondsSinceEpoch > cacheItem.expiry!) {
        delete(key);
        return null;
      }
      
      return cacheItem.data;
    } catch (e) {
      // Invalid cache item, remove it
      delete(key);
      return null;
    }
  }
  
  Future<void> delete(String key) async {
    await _prefs.remove(_prefix + key);
  }
  
  Future<void> clear() async {
    final keys = _prefs.getKeys();
    final cacheKeys = keys.where((key) => key.startsWith(_prefix));
    for (final key in cacheKeys) {
      await _prefs.remove(key);
    }
  }
  
  Map<String, dynamic> getStats() {
    final keys = _prefs.getKeys();
    final cacheKeys = keys.where((key) => key.startsWith(_prefix));
    
    int totalSize = 0;
    int validItems = 0;
    int expiredItems = 0;
    
    for (final key in cacheKeys) {
      final value = _prefs.getString(key);
      if (value != null) {
        totalSize += value.length;
        
        try {
          final json = jsonDecode(value) as Map<String, dynamic>;
          final expiry = json['expiry'] as int?;
          
          if (expiry != null && 
              DateTime.now().millisecondsSinceEpoch > expiry) {
            expiredItems++;
          } else {
            validItems++;
          }
        } catch (e) {
          expiredItems++;
        }
      }
    }
    
    return {
      'totalSize': totalSize,
      'validItems': validItems,
      'expiredItems': expiredItems,
      'totalItems': cacheKeys.length,
    };
  }
}

class CacheItem<T> {
  final T data;
  final int? expiry;
  final int timestamp;
  
  CacheItem({
    required this.data,
    this.expiry,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'expiry': expiry,
      'timestamp': timestamp,
    };
  }
  
  static CacheItem<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return CacheItem<T>(
      data: json['data'] is Map<String, dynamic> 
          ? fromJson(json['data'])
          : json['data'],
      expiry: json['expiry'],
      timestamp: json['timestamp'],
    );
  }
}

// Global cache instance
final cacheService = CacheService();
```

### HTTP Cache Interceptor

```dart
// lib/services/http_cache_interceptor.dart
import 'package:dio/dio.dart';
import 'cache_service.dart';

class HttpCacheInterceptor extends Interceptor {
  final CacheService _cache;
  final Duration _defaultTtl;
  
  HttpCacheInterceptor(this._cache, {
    Duration defaultTtl = const Duration(minutes: 5),
  }) : _defaultTtl = defaultTtl;
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Only cache GET requests
    if (options.method.toLowerCase() != 'get') {
      return handler.next(options);
    }
    
    // Check if caching is disabled for this request
    if (options.extra['cache'] == false) {
      return handler.next(options);
    }
    
    // Generate cache key
    final cacheKey = _generateCacheKey(options);
    
    // Try to get cached response
    final cachedResponse = _cache.get<Map<String, dynamic>>(
      cacheKey,
      (json) => json,
    );
    
    if (cachedResponse != null) {
      // Return cached response
      final response = Response(
        requestOptions: options,
        data: cachedResponse['data'],
        statusCode: cachedResponse['statusCode'],
        headers: Headers.fromMap(
          Map<String, List<String>>.from(cachedResponse['headers'])
        ),
      );
      
      return handler.resolve(response);
    }
    
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Only cache successful GET responses
    if (response.requestOptions.method.toLowerCase() == 'get' &&
        response.statusCode == 200 &&
        response.requestOptions.extra['cache'] != false) {
      
      final cacheKey = _generateCacheKey(response.requestOptions);
      final ttl = _getCacheTtl(response.requestOptions);
      
      // Cache response data
      final cacheData = {
        'data': response.data,
        'statusCode': response.statusCode,
        'headers': response.headers.map,
      };
      
      _cache.set(cacheKey, cacheData, ttl: ttl);
    }
    
    handler.next(response);
  }
  
  String _generateCacheKey(RequestOptions options) {
    final uri = options.uri.toString();
    final headers = options.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    
    return 'http_${uri}_$headers'.replaceAll(RegExp(r'[^\w]'), '_');
  }
  
  Duration _getCacheTtl(RequestOptions options) {
    // Check for custom TTL in request options
    final customTtl = options.extra['cacheTtl'] as Duration?;
    if (customTtl != null) {
      return customTtl;
    }
    
    // Different TTL based on endpoint
    final path = options.path.toLowerCase();
    
    if (path.contains('/user/')) {
      return const Duration(minutes: 5);
    } else if (path.contains('/public/')) {
      return const Duration(hours: 1);
    } else if (path.contains('/static/')) {
      return const Duration(hours: 24);
    }
    
    return _defaultTtl;
  }
}
```

## CDN and Asset Caching

### CDN Configuration

```nginx
# nginx.conf for CDN
server {
    listen 80;
    server_name cdn.medico24.com;
    
    # Static assets with long cache
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Content-Type-Options nosniff;
        
        # Enable compression
        gzip on;
        gzip_types
            text/css
            text/javascript
            text/xml
            text/plain
            text/x-component
            application/javascript
            application/x-javascript
            application/json
            application/xml
            application/rss+xml
            application/atom+xml
            font/truetype
            font/opentype
            application/vnd.ms-fontobject
            image/svg+xml;
    }
    
    # HTML files with shorter cache
    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }
    
    # API responses cache based on headers
    location /api/ {
        proxy_pass http://backend;
        
        # Cache GET requests
        proxy_cache api_cache;
        proxy_cache_methods GET;
        proxy_cache_valid 200 5m;
        proxy_cache_valid 404 1m;
        
        # Use custom cache key
        proxy_cache_key "$scheme$request_method$host$request_uri$http_authorization";
        
        # Add cache status headers
        add_header X-Cache-Status $upstream_cache_status;
    }
}

# Cache zone configuration
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m use_temp_path=off;
```

### Static Asset Versioning

```typescript
// build/assetVersioning.ts
import { createHash } from 'crypto';
import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';

interface AssetManifest {
  [originalPath: string]: string;
}

export function generateAssetManifest(buildDir: string): AssetManifest {
  const manifest: AssetManifest = {};
  const files = glob.sync(`${buildDir}/**/*.{js,css,png,jpg,jpeg,gif,svg}`);
  
  files.forEach(filePath => {
    const content = readFileSync(filePath);
    const hash = createHash('md5').update(content).digest('hex').slice(0, 8);
    
    const relativePath = filePath.replace(buildDir, '');
    const pathParts = relativePath.split('.');
    const extension = pathParts.pop();
    const baseName = pathParts.join('.');
    
    const versionedPath = `${baseName}.${hash}.${extension}`;
    manifest[relativePath] = versionedPath;
  });
  
  writeFileSync(
    `${buildDir}/asset-manifest.json`, 
    JSON.stringify(manifest, null, 2)
  );
  
  return manifest;
}

// Service Worker for cache busting
const CACHE_NAME = 'medico24-v1';
const STATIC_CACHE_NAME = 'medico24-static-v1';

self.addEventListener('install', (event: any) => {
  event.waitUntil(
    caches.open(STATIC_CACHE_NAME).then((cache) => {
      return cache.addAll([
        '/',
        '/static/css/main.css',
        '/static/js/main.js',
        '/manifest.json',
      ]);
    })
  );
});

self.addEventListener('fetch', (event: any) => {
  const url = new URL(event.request.url);
  
  // Cache static assets
  if (url.pathname.includes('/static/')) {
    event.respondWith(
      caches.match(event.request).then((response) => {
        if (response) {
          return response;
        }
        
        return fetch(event.request).then((response) => {
          const responseClone = response.clone();
          caches.open(STATIC_CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
          return response;
        });
      })
    );
  }
  
  // Cache API responses
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(
      caches.match(event.request).then((response) => {
        if (response) {
          // Serve from cache and update in background
          fetch(event.request).then((fetchResponse) => {
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, fetchResponse.clone());
            });
          });
          return response;
        }
        
        return fetch(event.request).then((response) => {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            if (response.status === 200) {
              cache.put(event.request, responseClone);
            }
          });
          return response;
        });
      })
    );
  }
});
```

## Cache Monitoring and Metrics

### Cache Performance Metrics

```python
# app/metrics/cache_metrics.py
from prometheus_client import Counter, Histogram, Gauge
import time

# Cache metrics
cache_hits = Counter(
    'medico_cache_hits_total',
    'Total cache hits',
    ['cache_type', 'key_prefix']
)

cache_misses = Counter(
    'medico_cache_misses_total',
    'Total cache misses',
    ['cache_type', 'key_prefix']
)

cache_operations_duration = Histogram(
    'medico_cache_operation_duration_seconds',
    'Time spent on cache operations',
    ['operation', 'cache_type']
)

cache_size = Gauge(
    'medico_cache_size_bytes',
    'Current cache size in bytes',
    ['cache_type']
)

def record_cache_hit(cache_type: str, key_prefix: str):
    cache_hits.labels(cache_type=cache_type, key_prefix=key_prefix).inc()

def record_cache_miss(cache_type: str, key_prefix: str):
    cache_misses.labels(cache_type=cache_type, key_prefix=key_prefix).inc()

def measure_cache_operation(operation: str, cache_type: str):
    def decorator(func):
        async def wrapper(*args, **kwargs):
            start_time = time.time()
            result = await func(*args, **kwargs)
            duration = time.time() - start_time
            
            cache_operations_duration.labels(
                operation=operation,
                cache_type=cache_type
            ).observe(duration)
            
            return result
        return wrapper
    return decorator
```

### Cache Health Monitoring

```python
# app/monitoring/cache_health.py
import aioredis
from typing import Dict, Any

class CacheHealthMonitor:
    def __init__(self, redis_client: aioredis.Redis):
        self.redis = redis_client
    
    async def get_health_status(self) -> Dict[str, Any]:
        """Get comprehensive cache health status."""
        try:
            # Basic connectivity check
            await self.redis.ping()
            
            # Get Redis info
            info = await self.redis.info()
            
            # Calculate hit ratio
            hit_ratio = self._calculate_hit_ratio(info)
            
            # Check memory usage
            memory_usage = self._check_memory_usage(info)
            
            # Check for slow operations
            slow_log = await self.redis.slowlog_get(10)
            
            health_status = {
                "status": "healthy",
                "redis_connected": True,
                "hit_ratio": hit_ratio,
                "memory_usage": memory_usage,
                "slow_operations": len(slow_log),
                "connections": info.get("connected_clients", 0),
                "operations_per_second": info.get("instantaneous_ops_per_sec", 0),
                "keyspace": await self._get_keyspace_info()
            }
            
            # Determine overall health
            if hit_ratio < 0.8:
                health_status["status"] = "degraded"
                health_status["warnings"] = ["Low cache hit ratio"]
            
            if memory_usage["percentage"] > 90:
                health_status["status"] = "degraded"
                health_status["warnings"] = health_status.get("warnings", []) + ["High memory usage"]
            
            return health_status
            
        except Exception as e:
            return {
                "status": "unhealthy",
                "redis_connected": False,
                "error": str(e)
            }
    
    def _calculate_hit_ratio(self, info: dict) -> float:
        hits = info.get("keyspace_hits", 0)
        misses = info.get("keyspace_misses", 0)
        total = hits + misses
        
        if total == 0:
            return 0.0
        
        return hits / total
    
    def _check_memory_usage(self, info: dict) -> dict:
        used_memory = info.get("used_memory", 0)
        max_memory = info.get("maxmemory", 0)
        
        if max_memory == 0:
            percentage = 0
        else:
            percentage = (used_memory / max_memory) * 100
        
        return {
            "used_bytes": used_memory,
            "max_bytes": max_memory,
            "percentage": percentage
        }
    
    async def _get_keyspace_info(self) -> dict:
        """Get information about keyspace."""
        try:
            # Sample key patterns to analyze
            patterns = ["user:*", "api_response:*", "func:*", "session:*"]
            keyspace = {}
            
            for pattern in patterns:
                keys = await self.redis.keys(pattern)
                keyspace[pattern] = len(keys)
            
            return keyspace
        except Exception:
            return {}

# Health check endpoint
@router.get("/health/cache")
async def cache_health_check():
    monitor = CacheHealthMonitor(redis_client)
    health = await monitor.get_health_status()
    
    status_code = 200 if health["status"] == "healthy" else 503
    return Response(content=json.dumps(health), status_code=status_code)
```

## Best Practices

### Cache Key Design

```python
# Good cache key patterns
CACHE_KEY_PATTERNS = {
    "user_profile": "user:profile:{user_id}",
    "user_appointments": "user:appointments:{user_id}:{page}",
    "api_response": "api:{endpoint}:{query_hash}:{user_id}",
    "session": "session:{session_id}",
    "rate_limit": "rate_limit:{user_id}:{endpoint}",
}

def generate_query_hash(params: dict) -> str:
    """Generate consistent hash for query parameters."""
    sorted_params = sorted(params.items())
    param_string = "&".join(f"{k}={v}" for k, v in sorted_params)
    return hashlib.md5(param_string.encode()).hexdigest()[:8]
```

### Cache Invalidation Strategies

```python
# app/cache/invalidation.py
from typing import List, Pattern
import re

class CacheInvalidationStrategy:
    """Smart cache invalidation based on data relationships."""
    
    INVALIDATION_RULES = {
        "user_update": [
            "user:profile:{user_id}",
            "user:appointments:{user_id}:*",
            "api:users/{user_id}:*"
        ],
        "appointment_create": [
            "user:appointments:{user_id}:*",
            "api:appointments:*",
            "dashboard:upcoming:*"
        ],
        "system_config_update": [
            "config:*",
            "api:public:*"
        ]
    }
    
    async def invalidate_for_event(self, event: str, context: dict):
        """Invalidate cache based on event and context."""
        patterns = self.INVALIDATION_RULES.get(event, [])
        
        for pattern in patterns:
            # Replace placeholders with actual values
            cache_pattern = pattern.format(**context)
            await cache.clear_pattern(cache_pattern)
    
    async def smart_invalidate(self, model_name: str, model_id: str, operation: str):
        """Smart invalidation based on model changes."""
        if model_name == "User":
            await self.invalidate_for_event("user_update", {"user_id": model_id})
        elif model_name == "Appointment":
            appointment = await get_appointment(model_id)
            if appointment:
                await self.invalidate_for_event("appointment_create", {
                    "user_id": appointment.user_id
                })
```

### Cache Warming

```python
# app/cache/warming.py
import asyncio
from typing import List

class CacheWarmer:
    """Proactively warm cache with frequently accessed data."""
    
    async def warm_user_cache(self, user_ids: List[str]):
        """Warm cache for specific users."""
        tasks = []
        for user_id in user_ids:
            tasks.append(self._warm_user_data(user_id))
        
        await asyncio.gather(*tasks, return_exceptions=True)
    
    async def _warm_user_data(self, user_id: str):
        """Warm all cache entries for a user."""
        # Warm user profile
        await user_service.get_user_profile(user_id)
        
        # Warm user appointments
        await user_service.get_user_appointments(user_id)
        
        # Warm user preferences
        await user_service.get_user_preferences(user_id)
    
    async def scheduled_warming(self):
        """Scheduled cache warming for hot data."""
        # Get most active users from last hour
        active_users = await analytics.get_active_users(hours=1)
        
        # Warm cache for active users
        await self.warm_user_cache([user.id for user in active_users])
        
        # Warm public endpoints
        await self._warm_public_data()
    
    async def _warm_public_data(self):
        """Warm public/static data."""
        # Warm system configuration
        await config_service.get_system_config()
        
        # Warm public announcements
        await content_service.get_announcements()
        
        # Warm static content
        await content_service.get_static_pages()

# Scheduled task
@scheduler.scheduled_job('interval', minutes=30)
async def cache_warming_job():
    warmer = CacheWarmer()
    await warmer.scheduled_warming()
```

## Resources

- [Redis Caching Patterns](https://redis.io/docs/manual/patterns/)
- [HTTP Caching Guide](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching)
- [React Query Documentation](https://tanstack.com/query/latest)
- [CDN Best Practices](https://developers.cloudflare.com/cache/best-practices/)
- [Cache Invalidation Strategies](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Strategies.html)
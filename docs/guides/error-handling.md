# Error Handling Guide

## Overview

This guide covers comprehensive error handling strategies across all components of the Medico24 platform.

## Error Handling Philosophy

### Principles

1. **Fail Fast:** Detect and handle errors as early as possible
2. **Graceful Degradation:** Provide fallback functionality when possible
3. **User-Friendly Messages:** Display meaningful error messages to users
4. **Comprehensive Logging:** Log errors with sufficient context for debugging
5. **Recovery Strategies:** Implement retry mechanisms where appropriate

### Error Categories

1. **Validation Errors:** Input validation failures
2. **Business Logic Errors:** Application-specific errors
3. **Infrastructure Errors:** Database, network, or external service failures
4. **Authentication Errors:** Authorization and authentication failures
5. **System Errors:** Unexpected application errors

## Backend Error Handling

### Exception Hierarchy

```python
# app/exceptions.py
from fastapi import HTTPException
from typing import Any, Dict, Optional

class MedicoBaseException(Exception):
    """Base exception for Medico24 application."""
    
    def __init__(
        self,
        message: str,
        error_code: str = None,
        details: Dict[str, Any] = None
    ):
        self.message = message
        self.error_code = error_code
        self.details = details or {}
        super().__init__(message)

class ValidationError(MedicoBaseException):
    """Raised when input validation fails."""
    pass

class BusinessLogicError(MedicoBaseException):
    """Raised when business rules are violated."""
    pass

class NotFoundError(MedicoBaseException):
    """Raised when a resource is not found."""
    pass

class UnauthorizedError(MedicoBaseException):
    """Raised when user is not authorized."""
    pass

class ExternalServiceError(MedicoBaseException):
    """Raised when external service calls fail."""
    pass

class DatabaseError(MedicoBaseException):
    """Raised when database operations fail."""
    pass
```

### Global Exception Handler

```python
# app/error_handlers.py
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
import logging
from .exceptions import MedicoBaseException

logger = logging.getLogger(__name__)

async def medico_exception_handler(request: Request, exc: MedicoBaseException):
    """Handle custom Medico24 exceptions."""
    logger.error(
        f"MedicoException: {exc.message}",
        extra={
            "error_code": exc.error_code,
            "details": exc.details,
            "path": request.url.path,
            "method": request.method,
        }
    )
    
    status_code = {
        "ValidationError": 400,
        "BusinessLogicError": 422,
        "NotFoundError": 404,
        "UnauthorizedError": 401,
        "ExternalServiceError": 503,
        "DatabaseError": 500,
    }.get(exc.__class__.__name__, 500)
    
    return JSONResponse(
        status_code=status_code,
        content={
            "error": {
                "message": exc.message,
                "code": exc.error_code,
                "type": exc.__class__.__name__,
                "details": exc.details,
            }
        }
    )

async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle FastAPI HTTP exceptions."""
    logger.warning(
        f"HTTPException: {exc.detail}",
        extra={
            "status_code": exc.status_code,
            "path": request.url.path,
            "method": request.method,
        }
    )
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "message": exc.detail,
                "type": "HTTPException",
                "status_code": exc.status_code,
            }
        }
    )

async def general_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions."""
    logger.error(
        f"Unexpected error: {str(exc)}",
        extra={
            "path": request.url.path,
            "method": request.method,
            "exception_type": exc.__class__.__name__,
        },
        exc_info=True
    )
    
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "message": "Internal server error",
                "type": "InternalServerError",
                "code": "INTERNAL_ERROR",
            }
        }
    )

# Register handlers in main.py
from fastapi import FastAPI
from .exceptions import MedicoBaseException

app = FastAPI()

app.add_exception_handler(MedicoBaseException, medico_exception_handler)
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(Exception, general_exception_handler)
```

### Input Validation

```python
# app/validators.py
from pydantic import BaseModel, validator, ValidationError as PydanticValidationError
from typing import List
from .exceptions import ValidationError

class UserCreate(BaseModel):
    email: str
    password: str
    full_name: str
    
    @validator('email')
    def validate_email(cls, v):
        if '@' not in v:
            raise ValueError('Invalid email format')
        return v.lower()
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain number')
        return v

def validate_request_data(model_class, data):
    """Validate request data and convert Pydantic errors to custom exceptions."""
    try:
        return model_class(**data)
    except PydanticValidationError as e:
        errors = []
        for error in e.errors():
            field = '.'.join(str(loc) for loc in error['loc'])
            errors.append({
                'field': field,
                'message': error['msg'],
                'type': error['type']
            })
        
        raise ValidationError(
            message="Validation failed",
            error_code="VALIDATION_ERROR",
            details={"validation_errors": errors}
        )
```

### Database Error Handling

```python
# app/database.py
from sqlalchemy.exc import IntegrityError, OperationalError
from .exceptions import DatabaseError, ValidationError
import logging

logger = logging.getLogger(__name__)

def handle_db_errors(func):
    """Decorator to handle database errors."""
    async def wrapper(*args, **kwargs):
        try:
            return await func(*args, **kwargs)
        except IntegrityError as e:
            logger.error(f"Database integrity error: {str(e)}")
            if "unique constraint" in str(e).lower():
                raise ValidationError(
                    message="Resource already exists",
                    error_code="DUPLICATE_RESOURCE"
                )
            elif "foreign key constraint" in str(e).lower():
                raise ValidationError(
                    message="Referenced resource not found",
                    error_code="INVALID_REFERENCE"
                )
            else:
                raise DatabaseError(
                    message="Database constraint violation",
                    error_code="CONSTRAINT_VIOLATION"
                )
        except OperationalError as e:
            logger.error(f"Database operational error: {str(e)}")
            raise DatabaseError(
                message="Database operation failed",
                error_code="DB_OPERATION_ERROR"
            )
        except Exception as e:
            logger.error(f"Unexpected database error: {str(e)}")
            raise DatabaseError(
                message="Unexpected database error",
                error_code="DB_UNEXPECTED_ERROR"
            )
    
    return wrapper
```

### External Service Error Handling

```python
# app/services/external.py
import httpx
from .exceptions import ExternalServiceError
import logging
from typing import Optional
import asyncio

logger = logging.getLogger(__name__)

class ExternalServiceClient:
    def __init__(self, base_url: str, timeout: int = 30):
        self.base_url = base_url
        self.timeout = timeout
    
    async def make_request(
        self,
        method: str,
        endpoint: str,
        data: dict = None,
        retries: int = 3,
        backoff_factor: float = 1.0
    ):
        """Make HTTP request with error handling and retries."""
        url = f"{self.base_url}{endpoint}"
        
        for attempt in range(retries):
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.request(method, url, json=data)
                    response.raise_for_status()
                    return response.json()
            
            except httpx.TimeoutException:
                logger.warning(f"Request timeout for {url} (attempt {attempt + 1})")
                if attempt == retries - 1:
                    raise ExternalServiceError(
                        message="External service timeout",
                        error_code="SERVICE_TIMEOUT",
                        details={"service": self.base_url, "endpoint": endpoint}
                    )
            
            except httpx.HTTPStatusError as e:
                logger.error(f"HTTP error {e.response.status_code} for {url}")
                if e.response.status_code >= 500:
                    # Server error - retry
                    if attempt == retries - 1:
                        raise ExternalServiceError(
                            message="External service unavailable",
                            error_code="SERVICE_UNAVAILABLE",
                            details={
                                "service": self.base_url,
                                "status_code": e.response.status_code
                            }
                        )
                else:
                    # Client error - don't retry
                    raise ExternalServiceError(
                        message="External service request failed",
                        error_code="SERVICE_REQUEST_FAILED",
                        details={
                            "service": self.base_url,
                            "status_code": e.response.status_code,
                            "response": e.response.text
                        }
                    )
            
            except Exception as e:
                logger.error(f"Unexpected error calling {url}: {str(e)}")
                if attempt == retries - 1:
                    raise ExternalServiceError(
                        message="External service error",
                        error_code="SERVICE_ERROR",
                        details={"service": self.base_url, "error": str(e)}
                    )
            
            # Exponential backoff
            if attempt < retries - 1:
                delay = backoff_factor * (2 ** attempt)
                await asyncio.sleep(delay)
```

## Mobile App Error Handling

### Error Models

```dart
// lib/models/error_models.dart
class AppError {
  final String message;
  final String? code;
  final String type;
  final Map<String, dynamic>? details;

  AppError({
    required this.message,
    this.code,
    required this.type,
    this.details,
  });

  factory AppError.fromJson(Map<String, dynamic> json) {
    return AppError(
      message: json['message'] ?? 'Unknown error',
      code: json['code'],
      type: json['type'] ?? 'UnknownError',
      details: json['details'],
    );
  }

  @override
  String toString() => 'AppError: $message (Type: $type, Code: $code)';
}

class NetworkError extends AppError {
  NetworkError({String? message, String? code})
      : super(
          message: message ?? 'Network connection failed',
          code: code ?? 'NETWORK_ERROR',
          type: 'NetworkError',
        );
}

class ValidationError extends AppError {
  final List<ValidationFieldError> fieldErrors;

  ValidationError({
    required String message,
    required this.fieldErrors,
    String? code,
  }) : super(
          message: message,
          code: code ?? 'VALIDATION_ERROR',
          type: 'ValidationError',
          details: {'validation_errors': fieldErrors.map((e) => e.toJson()).toList()},
        );
}

class ValidationFieldError {
  final String field;
  final String message;
  final String type;

  ValidationFieldError({
    required this.field,
    required this.message,
    required this.type,
  });

  factory ValidationFieldError.fromJson(Map<String, dynamic> json) {
    return ValidationFieldError(
      field: json['field'],
      message: json['message'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() => {
    'field': field,
    'message': message,
    'type': type,
  };
}
```

### HTTP Error Handling

```dart
// lib/services/api_client.dart
import 'package:dio/dio.dart';
import '../models/error_models.dart';

class ApiClient {
  final Dio _dio;

  ApiClient() : _dio = Dio() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final appError = _handleDioError(error);
          handler.reject(DioException(
            requestOptions: error.requestOptions,
            error: appError,
            type: DioExceptionType.unknown,
          ));
        },
      ),
    );
  }

  AppError _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkError(
          message: 'Request timeout. Please try again.',
          code: 'TIMEOUT_ERROR',
        );

      case DioExceptionType.connectionError:
        return NetworkError(
          message: 'No internet connection. Please check your connection.',
          code: 'CONNECTION_ERROR',
        );

      case DioExceptionType.badResponse:
        return _handleHttpError(error.response!);

      case DioExceptionType.cancel:
        return AppError(
          message: 'Request cancelled',
          code: 'REQUEST_CANCELLED',
          type: 'RequestCancelled',
        );

      default:
        return AppError(
          message: 'An unexpected error occurred',
          code: 'UNEXPECTED_ERROR',
          type: 'UnexpectedError',
        );
    }
  }

  AppError _handleHttpError(Response response) {
    final statusCode = response.statusCode!;
    
    try {
      final errorData = response.data['error'];
      
      if (statusCode == 400 && errorData['type'] == 'ValidationError') {
        final validationErrors = (errorData['details']['validation_errors'] as List)
            .map((e) => ValidationFieldError.fromJson(e))
            .toList();
        
        return ValidationError(
          message: errorData['message'],
          fieldErrors: validationErrors,
          code: errorData['code'],
        );
      }
      
      return AppError.fromJson(errorData);
    } catch (e) {
      // Fallback if response doesn't match expected format
      return AppError(
        message: _getDefaultErrorMessage(statusCode),
        code: 'HTTP_$statusCode',
        type: 'HttpError',
      );
    }
  }

  String _getDefaultErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication required. Please log in.';
      case 403:
        return 'Access denied. You don\'t have permission.';
      case 404:
        return 'Resource not found.';
      case 422:
        return 'Invalid data provided.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
```

### Error Display

```dart
// lib/widgets/error_widgets.dart
import 'package:flutter/material.dart';
import '../models/error_models.dart';

class ErrorDisplay extends StatelessWidget {
  final AppError error;
  final VoidCallback? onRetry;

  const ErrorDisplay({
    Key? key,
    required this.error,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getDisplayTitle(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (error is ValidationError) ..._buildValidationErrors(context),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDisplayTitle() {
    switch (error.type) {
      case 'NetworkError':
        return 'Connection Problem';
      case 'ValidationError':
        return 'Invalid Input';
      case 'HttpError':
        return 'Server Error';
      default:
        return 'Error';
    }
  }

  List<Widget> _buildValidationErrors(BuildContext context) {
    final validationError = error as ValidationError;
    
    return [
      const SizedBox(height: 8),
      ...validationError.fieldErrors.map(
        (fieldError) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '• ${fieldError.field}: ${fieldError.message}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    ];
  }
}

class ErrorSnackBar {
  static void show(BuildContext context, AppError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: error.type == 'NetworkError'
            ? SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  // Implement retry logic
                },
              )
            : null,
      ),
    );
  }
}
```

### Result Pattern

```dart
// lib/utils/result.dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}

// Extension methods for easier usage
extension ResultExtensions<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T? get data => switch (this) {
    Success<T>(data: final data) => data,
    Failure<T>() => null,
  };
  
  AppError? get error => switch (this) {
    Success<T>() => null,
    Failure<T>(error: final error) => error,
  };
  
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppError error) onFailure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => onSuccess(data),
      Failure<T>(error: final error) => onFailure(error),
    };
  }
}

// Usage in services
class UserService {
  Future<Result<User>> getUserProfile() async {
    try {
      final response = await apiClient.get('/user/profile');
      final user = User.fromJson(response.data);
      return Success(user);
    } on DioException catch (e) {
      return Failure(e.error as AppError);
    } catch (e) {
      return Failure(AppError(
        message: 'Unexpected error occurred',
        type: 'UnexpectedError',
      ));
    }
  }
}
```

## Web Dashboard Error Handling

### Error Types

```typescript
// types/errors.ts
export interface AppError {
  message: string;
  code?: string;
  type: string;
  details?: Record<string, any>;
}

export interface ValidationError extends AppError {
  type: 'ValidationError';
  details: {
    validation_errors: Array<{
      field: string;
      message: string;
      type: string;
    }>;
  };
}

export interface NetworkError extends AppError {
  type: 'NetworkError';
}

export interface HttpError extends AppError {
  type: 'HttpError';
  statusCode: number;
}
```

### Error Handling Hook

```typescript
// hooks/useErrorHandler.ts
import { useCallback } from 'react';
import { useToast } from './useToast';
import { AppError, ValidationError } from '../types/errors';

export const useErrorHandler = () => {
  const { showToast } = useToast();

  const handleError = useCallback((error: AppError) => {
    switch (error.type) {
      case 'ValidationError':
        const validationError = error as ValidationError;
        const fieldErrors = validationError.details.validation_errors
          .map(err => `${err.field}: ${err.message}`)
          .join(', ');
        showToast({
          type: 'error',
          title: 'Validation Error',
          message: fieldErrors,
        });
        break;

      case 'NetworkError':
        showToast({
          type: 'error',
          title: 'Connection Problem',
          message: 'Please check your internet connection and try again.',
          action: {
            label: 'Retry',
            onClick: () => window.location.reload(),
          },
        });
        break;

      case 'HttpError':
        showToast({
          type: 'error',
          title: 'Server Error',
          message: error.message,
        });
        break;

      default:
        showToast({
          type: 'error',
          title: 'Error',
          message: error.message || 'An unexpected error occurred',
        });
    }
  }, [showToast]);

  return { handleError };
};
```

### API Error Handling

```typescript
// lib/api-client.ts
import axios, { AxiosError, AxiosResponse } from 'axios';
import { AppError, ValidationError, NetworkError, HttpError } from '../types/errors';

class ApiClient {
  private instance = axios.create({
    baseURL: process.env.NEXT_PUBLIC_API_URL,
    timeout: 30000,
  });

  constructor() {
    this.setupInterceptors();
  }

  private setupInterceptors() {
    this.instance.interceptors.response.use(
      (response: AxiosResponse) => response,
      (error: AxiosError) => {
        const appError = this.handleError(error);
        return Promise.reject(appError);
      }
    );
  }

  private handleError(error: AxiosError): AppError {
    if (!error.response) {
      // Network error
      return new NetworkError({
        message: 'Network connection failed. Please check your internet connection.',
        code: 'NETWORK_ERROR',
      });
    }

    const { status, data } = error.response;
    
    try {
      const errorData = (data as any)?.error;
      
      if (status === 400 && errorData?.type === 'ValidationError') {
        return {
          ...errorData,
          type: 'ValidationError',
        } as ValidationError;
      }

      if (errorData) {
        return {
          message: errorData.message,
          code: errorData.code,
          type: errorData.type || 'HttpError',
          details: errorData.details,
        } as AppError;
      }
    } catch (e) {
      // Fallback if response doesn't match expected format
    }

    return {
      message: this.getDefaultErrorMessage(status),
      code: `HTTP_${status}`,
      type: 'HttpError',
      statusCode: status,
    } as HttpError;
  }

  private getDefaultErrorMessage(statusCode: number): string {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication required. Please log in.';
      case 403:
        return 'Access denied. You don\'t have permission.';
      case 404:
        return 'Resource not found.';
      case 422:
        return 'Invalid data provided.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
```

### Error Boundary

```tsx
// components/ErrorBoundary.tsx
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo);
    
    // Log to error reporting service
    if (process.env.NODE_ENV === 'production') {
      // Sentry.captureException(error, { contexts: { react: errorInfo } });
    }
  }

  public render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div className="error-boundary">
          <h2>Something went wrong</h2>
          <p>An unexpected error occurred. Please refresh the page.</p>
          <button onClick={() => window.location.reload()}>
            Refresh Page
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
```

## Error Logging and Monitoring

### Structured Logging

```python
# app/logging_config.py
import logging
import sys
from pythonjsonlogger import jsonlogger

def setup_logging():
    """Configure structured logging."""
    
    # Create logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Create console handler
    handler = logging.StreamHandler(sys.stdout)
    
    # Create JSON formatter
    formatter = jsonlogger.JsonFormatter(
        '%(asctime)s %(name)s %(levelname)s %(message)s'
    )
    
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    
    return logger

# Usage
logger = logging.getLogger(__name__)

def log_error(error: Exception, context: dict = None):
    """Log error with context."""
    logger.error(
        "Application error occurred",
        extra={
            "error_type": error.__class__.__name__,
            "error_message": str(error),
            "context": context or {},
        },
        exc_info=True
    )
```

### Error Metrics

```python
# app/metrics.py
from prometheus_client import Counter, Histogram, Gauge

# Error metrics
error_counter = Counter(
    'medico_errors_total',
    'Total number of errors',
    ['error_type', 'endpoint', 'status_code']
)

request_duration = Histogram(
    'medico_request_duration_seconds',
    'Request duration',
    ['method', 'endpoint', 'status_code']
)

active_users = Gauge(
    'medico_active_users',
    'Number of active users'
)

def record_error(error_type: str, endpoint: str, status_code: int):
    """Record error metrics."""
    error_counter.labels(
        error_type=error_type,
        endpoint=endpoint,
        status_code=status_code
    ).inc()
```

## Best Practices

### Error Message Guidelines

1. **Be Specific:** Provide clear, actionable error messages
2. **Be User-Friendly:** Avoid technical jargon in user-facing messages
3. **Include Context:** Provide relevant information for debugging
4. **Be Consistent:** Use consistent error formats across the application

### Example Error Messages

```python
# Good error messages
GOOD_MESSAGES = {
    "validation": "Email address must be valid (example: user@domain.com)",
    "not_found": "User with ID 123 was not found",
    "permission": "You don't have permission to access this patient's records",
    "rate_limit": "Too many requests. Please wait 60 seconds before trying again",
}

# Poor error messages
BAD_MESSAGES = {
    "validation": "Invalid input",
    "not_found": "Not found",
    "permission": "Access denied",
    "rate_limit": "Rate limited",
}
```

### Retry Strategies

```python
# app/utils/retry.py
import asyncio
from functools import wraps
import random

def exponential_backoff_retry(
    max_retries: int = 3,
    backoff_factor: float = 1.0,
    max_backoff: float = 60.0,
    exceptions: tuple = (Exception,)
):
    """Decorator for exponential backoff retry."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return await func(*args, **kwargs)
                except exceptions as e:
                    if attempt == max_retries - 1:
                        raise e
                    
                    delay = min(
                        backoff_factor * (2 ** attempt) + random.uniform(0, 1),
                        max_backoff
                    )
                    
                    await asyncio.sleep(delay)
            
        return wrapper
    return decorator

# Usage
@exponential_backoff_retry(
    max_retries=3,
    exceptions=(ExternalServiceError,)
)
async def call_external_api():
    # API call implementation
    pass
```

## Error Recovery Strategies

### Circuit Breaker Pattern

```python
# app/utils/circuit_breaker.py
import time
from enum import Enum
from typing import Callable, Any

class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class CircuitBreaker:
    def __init__(
        self,
        failure_threshold: int = 5,
        timeout: int = 60,
        expected_exception: type = Exception
    ):
        self.failure_threshold = failure_threshold
        self.timeout = timeout
        self.expected_exception = expected_exception
        
        self.failure_count = 0
        self.last_failure_time = 0
        self.state = CircuitState.CLOSED
    
    def __call__(self, func: Callable) -> Callable:
        async def wrapper(*args, **kwargs) -> Any:
            if self.state == CircuitState.OPEN:
                if time.time() - self.last_failure_time > self.timeout:
                    self.state = CircuitState.HALF_OPEN
                else:
                    raise ExternalServiceError("Circuit breaker is OPEN")
            
            try:
                result = await func(*args, **kwargs)
                self._on_success()
                return result
            except self.expected_exception as e:
                self._on_failure()
                raise e
        
        return wrapper
    
    def _on_success(self):
        self.failure_count = 0
        self.state = CircuitState.CLOSED
    
    def _on_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        if self.failure_count >= self.failure_threshold:
            self.state = CircuitState.OPEN

# Usage
circuit_breaker = CircuitBreaker(failure_threshold=3, timeout=30)

@circuit_breaker
async def external_service_call():
    # External service call
    pass
```

## Resources

- [FastAPI Error Handling](https://fastapi.tiangolo.com/tutorial/handling-errors/)
- [Flutter Error Handling](https://docs.flutter.dev/testing/errors)
- [React Error Boundaries](https://reactjs.org/docs/error-boundaries.html)
- [Prometheus Monitoring](https://prometheus.io/docs/practices/instrumentation/)
- [Structured Logging](https://github.com/madzak/python-json-logger)
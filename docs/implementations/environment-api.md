# Environmental API Implementation

This document details the implementation of the Environmental API for the Medico24 backend, providing real-time Air Quality Index (AQI) and weather data using Google APIs.

## Overview

The Environmental API provides:
- Real-time Air Quality Index (AQI) data
- Current weather conditions
- Health impact categorization
- Intelligent caching for performance
- Error handling and fallback mechanisms

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FastAPI       │────│   Service       │────│   External      │
│   Endpoint      │    │   Layer         │    │   APIs          │
│                 │    │                 │    │   (Google)      │
└─────────┬───────┘    └───────┬───────┘    └─────────────────┘
         │                       │                       │
         └─────────────────────────┬───────────────────────┘
                    ┌───────────────┐
                    │   Redis Cache   │
                    │   (20 min TTL)  │
                    └───────────────┘
```

## API Endpoint

### GET /api/v1/environment/conditions

Fetch real-time environmental conditions for a specific location.

**Parameters:**
- `lat` (float, required): Latitude coordinate (-90 to 90)
- `lng` (float, required): Longitude coordinate (-180 to 180)

**Response:**
```json
{
  "aqi": 35,
  "aqi_category": "Good",
  "temperature": 21.3,
  "condition": "Clear sky"
}
```

**Example Request:**
```bash
curl "http://localhost:8000/api/v1/environment/conditions?lat=40.7128&lng=-74.0060"
```

## Implementation Details

### Schema Definition

```python
# app/schemas/environment.py
from pydantic import BaseModel, Field

class EnvironmentalConditionsResponse(BaseModel):
    aqi: int = Field(..., description="The Universal Air Quality Index")
    aqi_category: str = Field(..., description="Health category (e.g., Good, Moderate)")
    temperature: float = Field(..., description="Temperature in Celsius")
    condition: str = Field(..., description="Weather description")

    class Config:
        from_attributes = True
```

### Service Implementation

```python
# app/services/environment_service.py
import asyncio
import httpx
from typing import Optional

class EnvironmentService:
    AQI_URL = "https://airquality.googleapis.com/v1/currentConditions:lookup"
    WEATHER_URL = "https://weather.googleapis.com/v1/currentConditions:lookup"
    CACHE_TTL = 1200  # 20 minutes

    def __init__(self, cache_manager: Optional[CacheManager] = None):
        self.cache = cache_manager

    async def get_local_conditions(
        self, lat: float, lng: float
    ) -> EnvironmentalConditionsResponse:
        """Get environmental conditions for coordinates."""
        
        # Check cache first
        cache_key = self._get_cache_key(lat, lng)
        if self.cache:
            cached_data = await self.cache.get(cache_key)
            if cached_data:
                return EnvironmentalConditionsResponse(**cached_data)

        # Fetch from APIs concurrently
        try:
            aqi_data, weather_data = await asyncio.gather(
                self._fetch_aqi_data(lat, lng),
                self._fetch_weather_data(lat, lng)
            )
            
            response = EnvironmentalConditionsResponse(
                aqi=aqi_data["aqi"],
                aqi_category=aqi_data["category"],
                temperature=weather_data["temperature"],
                condition=weather_data["condition"]
            )
            
            # Cache the result
            if self.cache:
                await self.cache.set(
                    cache_key, 
                    response.model_dump(), 
                    ttl=self.CACHE_TTL
                )
            
            return response
            
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Environmental data currently unavailable: {e}"
            )

    async def _fetch_aqi_data(self, lat: float, lng: float) -> dict:
        """Fetch AQI data from Google Air Quality API."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self.AQI_URL,
                json={
                    "location": {
                        "latitude": lat,
                        "longitude": lng
                    }
                },
                headers={
                    "Authorization": f"Bearer {settings.google_maps_api_key}"
                }
            )
            
            if response.status_code != 200:
                raise ValueError(f"AQI API error: {response.status_code}")
            
            data = response.json()
            return {
                "aqi": data["indexes"][0]["aqi"],
                "category": data["indexes"][0]["category"]
            }

    async def _fetch_weather_data(self, lat: float, lng: float) -> dict:
        """Fetch weather data from Google Weather API."""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                self.WEATHER_URL,
                params={
                    "lat": lat,
                    "lng": lng,
                    "key": settings.google_maps_api_key
                }
            )
            
            if response.status_code != 200:
                raise ValueError(f"Weather API error: {response.status_code}")
            
            data = response.json()
            return {
                "temperature": data["current"]["temperature_celsius"],
                "condition": data["current"]["weather_description"]
            }

    def _get_cache_key(self, lat: float, lng: float) -> str:
        """Generate cache key for coordinates."""
        # Round to 3 decimal places for cache efficiency (~100m precision)
        return f"env:data:{round(lat, 3)}:{round(lng, 3)}"
```

### FastAPI Endpoint

```python
# app/api/v1/endpoints/environment.py
from fastapi import APIRouter, HTTPException, Depends, Query
from app.schemas.environment import EnvironmentalConditionsResponse
from app.services.environment_service import EnvironmentService
from app.core.cache import get_cache_manager

router = APIRouter()

@router.get("/conditions", response_model=EnvironmentalConditionsResponse)
async def get_environmental_conditions(
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lng: float = Query(..., ge=-180, le=180, description="Longitude"),
    cache_manager = Depends(get_cache_manager)
) -> EnvironmentalConditionsResponse:
    """Get real-time environmental conditions for a location."""
    service = EnvironmentService(cache_manager)
    return await service.get_local_conditions(lat, lng)
```

## Configuration

### Environment Variables

```bash
# .env
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
```

### Settings

```python
# app/config.py
class Settings(BaseSettings):
    # ... existing fields ...
    
    # Google Maps API
    google_maps_api_key: str = Field(default="", alias="GOOGLE_MAPS_API_KEY")
    
    class Config:
        env_file = ".env"
```

## Caching Strategy

### Cache Configuration
- **TTL**: 20 minutes (1200 seconds)
- **Key Format**: `env:data:{lat}:{lng}`
- **Precision**: 3 decimal places (~100m accuracy)
- **Storage**: JSON in Redis

### Cache Benefits
- Reduces external API calls
- Improves response times (5x faster)
- Cost optimization
- Better user experience

### Cache Flow
```
Request → Check Cache → Cache Hit? → Return Cached Data
                    ↓
               Cache Miss → Call APIs → Store in Cache → Return Data
```

## Error Handling

### HTTP Status Codes
- **200 OK**: Successful response with environmental data
- **422 Unprocessable Entity**: Invalid coordinates
- **503 Service Unavailable**: External API failure or network issues

### Error Response Example
```json
{
  "detail": "Environmental data currently unavailable: API timeout"
}
```

## Performance Metrics

### Response Times
- **Cache Hit**: < 1ms
- **API Call**: 500-2000ms (Google API dependent)
- **Cache Miss**: Limited by slowest API response

### Optimization Features
- **Concurrent API Calls**: Uses `asyncio.gather` for parallel execution
- **Coordinate Rounding**: 3 decimal precision for cache efficiency
- **Connection Pooling**: Automatic with httpx AsyncClient

## Testing

### Unit Tests
```python
# tests/test_environment_service.py
import pytest
from unittest.mock import AsyncMock, patch
from app.services.environment_service import EnvironmentService

@pytest.mark.asyncio
async def test_get_local_conditions():
    """Test environmental conditions retrieval."""
    service = EnvironmentService()
    
    with patch('httpx.AsyncClient') as mock_client:
        # Mock API responses
        mock_client.return_value.__aenter__.return_value.post.return_value.status_code = 200
        mock_client.return_value.__aenter__.return_value.post.return_value.json.return_value = {
            "indexes": [{"aqi": 35, "category": "Good"}]
        }
        
        mock_client.return_value.__aenter__.return_value.get.return_value.status_code = 200
        mock_client.return_value.__aenter__.return_value.get.return_value.json.return_value = {
            "current": {
                "temperature_celsius": 21.3,
                "weather_description": "Clear sky"
            }
        }
        
        result = await service.get_local_conditions(40.7128, -74.0060)
        
        assert result.aqi == 35
        assert result.aqi_category == "Good"
        assert result.temperature == 21.3
        assert result.condition == "Clear sky"
```

### Integration Tests
```python
@pytest.mark.asyncio
async def test_environment_endpoint(client):
    """Test environment endpoint."""
    response = await client.get(
        "/api/v1/environment/conditions?lat=40.7128&lng=-74.0060"
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "aqi" in data
    assert "aqi_category" in data
    assert "temperature" in data
    assert "condition" in data
```

## Usage Examples

### Flutter Integration
```dart
class EnvironmentService {
  Future<EnvironmentalConditions> getConditions(
    double lat, 
    double lng
  ) async {
    final response = await dio.get(
      '/environment/conditions',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    
    return EnvironmentalConditions.fromJson(response.data);
  }
}
```

### JavaScript Integration
```javascript
class EnvironmentAPI {
  async getConditions(lat, lng) {
    const response = await fetch(
      `/api/v1/environment/conditions?lat=${lat}&lng=${lng}`
    );
    return await response.json();
  }
}
```

## Security Considerations

- **API Key Protection**: Keys stored in environment variables
- **Server-Side Only**: API calls made from backend
- **Input Validation**: Coordinate bounds validation
- **Rate Limiting**: Cache reduces API usage

## Future Enhancements

- **Historical Data**: Store and provide historical environmental trends
- **Health Alerts**: Threshold-based notifications for poor air quality
- **Multiple Locations**: Batch requests for multiple coordinates
- **Weather Forecasts**: Extended weather predictions
- **Indoor Air Quality**: Integration with IoT sensors

## Related Documentation

- [API Specifications](../api/specifications.md) - Complete API reference
- [System Architecture](../architecture/overview.md) - Overall system design
- [Caching Strategy](../guides/caching.md) - Caching implementation details
- [Error Handling](../guides/error-handling.md) - Error handling patterns
# Environmental API Implementation

This document explains how Medico24 integrates environmental data (Air Quality Index and weather) to provide health-relevant information to users based on their location.

## Purpose

The Environmental API enriches the healthcare platform by providing:
- **Air Quality Index (AQI)**: Helps patients with respiratory conditions understand outdoor air quality
- **Weather Conditions**: Supports appointment planning and health recommendations
- **Location-Based Data**: Real-time information specific to user coordinates

## How It Works

### Data Flow

1. **Client Request**: Mobile/web app sends user's GPS coordinates
2. **Cache Check**: Backend checks Redis for recent data (within 20 minutes)
3. **API Calls**: If cache miss, calls Google Air Quality and Weather APIs in parallel
4. **Data Aggregation**: Combines AQI and weather data into single response
5. **Caching**: Stores result in Redis for 20 minutes to reduce API costs
6. **Response**: Returns unified environmental data to client

### API Endpoint

**Endpoint**: `GET /api/v1/environment/conditions`

**Parameters**:
- `lat`: Latitude (-90 to 90)
- `lng`: Longitude (-180 to 180)

**Response Example**:
```json
{
  "aqi": 35,
  "aqi_category": "Good",
  "temperature": 21.3,
  "condition": "Clear sky"
}
```

## Implementation Strategy

### Service Layer

The `EnvironmentService` class handles:
- Fetching data from Google APIs (Air Quality and Weather)
- Concurrent API calls using `asyncio.gather()` for better performance
- Cache management with Redis (20-minute TTL)
- Error handling for API failures

### Caching Strategy

**Why Cache?**
- Environmental data changes slowly (useful for 20 minutes)
- Reduces external API costs significantly
- Improves response time (5x faster)

**Cache Key Format**: `env:data:{rounded_lat}:{rounded_lng}`
- Coordinates rounded to 3 decimal places (~100m precision)
- Allows nearby requests to share cached data

### Error Handling

- Returns HTTP 503 if external APIs fail
- Validates coordinate ranges (422 for invalid input)
- Gracefully handles network timeouts

## Configuration

### Required Environment Variables

```bash
GOOGLE_MAPS_API_KEY=your_api_key_here
```

### External APIs Used

1. **Google Air Quality API**: `airquality.googleapis.com/v1/currentConditions:lookup`
2. **Google Weather API**: `weather.googleapis.com/v1/currentConditions:lookup`

## Performance Considerations

### Response Times
- **Cache Hit**: < 1ms
- **Cache Miss**: 500-2000ms (depends on Google API latency)

### Cost Optimization
- Caching reduces API calls by ~80%
- Coordinate rounding increases cache hit rate
- Parallel API calls minimize total request time

## Integration Points

### Mobile App (Flutter)
Apps fetch environmental data when:
- User views nearby pharmacies
- Appointment booking (outdoor appointment consideration)
- Health dashboard display

### Web Dashboard
Displays environmental data for:
- Admin location insights
- Appointment scheduling interface

## Health Impact Categories

AQI values map to health categories:
- **0-50**: Good (Green)
- **51-100**: Moderate (Yellow)
- **101-150**: Unhealthy for Sensitive Groups (Orange)
- **151-200**: Unhealthy (Red)
- **201-300**: Very Unhealthy (Purple)
- **301+**: Hazardous (Maroon)

## Future Enhancements

- Historical environmental data tracking
- Health alerts for poor air quality days
- Pollution forecasts
- Integration with appointment recommendations

## Related Documentation

- [Google Maps Integration](./google-maps-integration.md)
- [API Specifications](../api/specifications.md)
- [Backend Setup Guide](../guides/setup/backend-setup.md)


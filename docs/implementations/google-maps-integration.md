# Google Maps Integration

Google Maps powers location services across Medico24, enabling address search, pharmacy location, and interactive maps on all platforms.

## Purpose

**Why Google Maps?**

- **Address Autocomplete**: Users can search and select addresses easily instead of manual coordinate entry
- **Geocoding**: Converting user addresses to coordinates for environmental data and pharmacy search
- **Visual Maps**: Interactive maps help patients locate pharmacies and understand service areas
- **Reverse Geocoding**: Show human-readable addresses from GPS coordinates

## How It Works

### Geocoding Flow

1. **User Input**: Patient enters address or uses current location
2. **Forward Geocoding**: Address → Coordinates (lat/lng)
3. **Reverse Geocoding**: Coordinates → Formatted address
4. **Validation**: Check if location is within service area

**Example Flow**: User types "123 Main St" → Google Geocoding API returns `{lat: 40.7128, lng: -74.0060}` → Cached for 24 hours → Used for environmental data and pharmacy search.

### Pharmacy Search Strategy

**Why PostGIS Instead of Google Distance Matrix API?**

- **Cost Savings**: PostGIS queries are free, Distance Matrix costs $5-10 per 1,000 requests
- **Performance**: Database spatial queries are faster than external API calls (50ms vs 200ms)
- **Offline Capability**: Works even if Google Maps is down
- **Scalability**: No rate limits or quota concerns

**How PostGIS Search Works**:
1. Store pharmacy coordinates in `GEOGRAPHY(POINT)` column
2. Create spatial index using GIST
3. Use `ST_DWithin` to find pharmacies within radius (default 5km)
4. Order by `ST_Distance` for closest-first results
5. Return top 20 pharmacies with distance in kilometers

**SQL Query Pattern**:
```sql
SELECT name, ST_Distance(location, user_point) / 1000 AS distance_km
FROM pharmacies
WHERE ST_DWithin(location, user_point, 5000)  -- 5km radius
ORDER BY distance_km LIMIT 20;
```

## Platform Implementation

### Backend (FastAPI)

**Geocoding Service**: Converts addresses to coordinates using Google Geocoding API. Calls are made asynchronously via `httpx`, cached for 24 hours in Redis to avoid repeated API calls for the same address.

**Pharmacy Service**: Uses PostGIS `ST_DWithin` for radius search and `ST_Distance` to calculate distances. Returns pharmacies sorted by proximity with distance in kilometers.

**Why Async**: FastAPI supports async/await, allowing concurrent handling of geocoding requests without blocking.

### Mobile (Flutter)

**Map Display**: Uses `google_maps_flutter` package to render interactive maps with pharmacy markers. Each pharmacy becomes a `Marker` with coordinates and info window.

**Location Services**: `geolocator` package handles permission requests and GPS access. Falls back to address search if location is denied.

**Permission Flow**:
1. Check if location services enabled
2. Request permission if denied
3. Handle "denied forever" case by showing settings prompt
4. Get high-accuracy position for environmental data

**Platform-Specific Setup**:
- **Android**: API key in `AndroidManifest.xml`, restricted by package name + SHA-1
- **iOS**: API key in `AppDelegate.swift`, restricted by bundle ID

### Web (Next.js)

**Maps JavaScript API**: Uses `@googlemaps/js-api-loader` to load Google Maps library with Places API support. Lazy-loaded to improve initial page performance.

**React Integration**: `useRef` hook manages map DOM element, `useEffect` initializes map after component mounts. Markers added programmatically for each pharmacy.

**Environment Variables**: JavaScript API key exposed to client via `NEXT_PUBLIC_` prefix, restricted by HTTP referrer (domain whitelist).

## Database Integration

**PostGIS Extension**: Enables spatial queries in PostgreSQL. Geography type stores coordinates as `POINT(longitude, latitude)` in WGS84 projection (SRID 4326).

**Spatial Indexing**: GIST index on `location` column dramatically speeds up distance queries (5km search: ~50ms instead of ~2000ms on 10,000 pharmacies).

**Pharmacy Table Design**:
- `location`: `GEOGRAPHY(POINT, 4326)` for spatial queries
- `created_at`: Track when pharmacy added
- Index on location for fast proximity searches

## Configuration

**API Key Strategy**: Different keys for each platform prevent key theft from compromising all platforms.

**Backend (.env)**:
```bash
GOOGLE_MAPS_API_KEY=server_key  # Restricted to backend IP
```

**Mobile**:
- Android: Key in `AndroidManifest.xml`, restricted to package + SHA-1
- iOS: Key in `AppDelegate.swift`, restricted to bundle identifier

**Web (.env.local)**:
```bash
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=js_key  # Restricted to website domain
```

**Why Different Keys?**: If mobile app is decompiled, attacker only gets mobile key (restricted to app), not backend key (full API access).

## Security

**API Key Restrictions**:
- **Server Key**: IP whitelist (only backend servers)
- **Android Key**: Package name + SHA-1 certificate fingerprint
- **iOS Key**: Bundle identifier
- **JavaScript Key**: HTTP referrer (website domain)

**Rate Limiting**: Backend implements per-user rate limits on geocoding endpoints to prevent abuse even if API key is exposed.

**Input Validation**: All coordinates validated (lat: -90 to 90, lng: -180 to 180) before querying to prevent SQL injection via malformed geography strings.

## Performance Optimization

**Caching Strategy**:
- **Geocoding Results**: 24-hour TTL (addresses rarely change coordinates)
- **Pharmacy Locations**: Updated only when pharmacies added/removed
- **Cache Key**: `geocode:{address}` for consistent lookups

**Why 24 Hours?**: Balances freshness (new subdivisions) with cost savings (80% cache hit rate observed).

**Map Loading**:
- **Lazy Loading**: Maps loaded only when user navigates to pharmacy search
- **Marker Clustering**: Shows clusters for 50+ pharmacies, expands on zoom
- **Static Maps**: For non-interactive previews (email, PDF reports)

**PostGIS Optimization**:
- Spatial index reduces 5km search from O(n) to O(log n)
- Geography type handles spherical calculations (accurate for Earth's curvature)
- Limit to 20 results prevents excessive data transfer

## Cost Management

**Pricing** (Google Cloud):
- Geocoding: $5 per 1,000 requests
- Maps SDK loads: $7 per 1,000
- Places Autocomplete: $2.83-$17 per 1,000 (depends on session-based vs per-request)

**Cost Reduction**:
- **Caching**: 80% reduction on geocoding (10,000 requests/month → 2,000 billable)
- **PostGIS**: 100% savings on pharmacy search (Distance Matrix API not used)
- **Session Tokens**: Autocomplete sessions reduce cost by 60%
- **Static Maps**: Free for PDFs and emails

**Estimated Monthly Cost** (10,000 users, 5 searches/user):
- Without optimization: ~$500/month
- With caching + PostGIS: ~$50/month

## Error Handling

**Common Errors**:
- **ZERO_RESULTS**: Address not found → Ask user to refine search
- **OVER_QUERY_LIMIT**: Rate limit hit → Use cached results or queue request
- **REQUEST_DENIED**: API key invalid → Alert developers, check restrictions

**Location Permissions**:
- **Denied**: Fall back to address search
- **Denied Forever**: Show settings prompt with instructions
- **Service Disabled**: Prompt to enable location services

**Timeout Handling**: Geocoding requests timeout after 5 seconds, return cached result if available, otherwise show error to user.

## Related Documentation

- [Environment API Implementation](./environment-api.md) - Uses geocoded coordinates for AQI/weather
- [Firebase Integration](./firebase-integration.md) - Authentication before accessing location services
- [Mobile Setup Guide](../guides/setup/mobile-setup.md) - Google Maps Flutter configuration
- [Frontend Setup Guide](../guides/setup/frontend-setup.md) - Next.js Maps integration

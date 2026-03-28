# Tracker API Server

Node.js/TypeScript REST API for device registration, subscription validation, and download authentication.

**Deployment**: DigitalOcean Droplet YOUR_SERVER_IP (Docker container)

## Overview

The tracker-api provides backend services for the Obsession Tracker mobile app:

1. **Device Registration**: Register new devices and issue API keys
2. **Subscription Validation**: Validate premium subscriptions via RevenueCat V2 API
3. **Download Metadata**: Provide available state download information

**Technology Stack**:
- Node.js 20 (Alpine Linux)
- TypeScript
- Express.js
- SQLite (better-sqlite3)
- RevenueCat V2 API integration

## Architecture

```
Mobile App
    ↓
tracker-api (Node.js, Port 3003)
    ↓
├── Device Registration → SQLite database
├── Subscription Validation → RevenueCat V2 API
└── Download Metadata → Local /var/www/downloads directory
```

## API Endpoints

### Health Check

```http
GET /health
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2026-01-08T13:00:00.000Z"
}
```

### Device Registration

```http
POST /api/v1/devices/register
Content-Type: application/json

{
  "device_id": "4ff75924-929c-4791-8272-fba7ed391f76",
  "platform": "android",
  "app_version": "1.11.0"
}
```

**Response**:
```json
{
  "device_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "api_key": "64-character-hex-string-returned-by-server",
  "created_at": "2026-01-08T13:00:00.000Z"
}
```

**Notes**:
- Device ID should be persistent identifier from `device_info_plus` package
- API key is used for all subsequent authenticated requests
- Safe to call multiple times (idempotent) - returns existing key if device already registered

### Subscription Validation

```http
POST /api/v1/subscription/validate
X-API-Key: {api_key}
```

**Response (Premium)**:
```json
{
  "is_premium": true,
  "entitlements": {
    "premium": {
      "expires_date": null,
      "product_identifier": "annual_premium"
    }
  },
  "expires_at": null
}
```

**Response (Free)**:
```json
{
  "is_premium": false,
  "entitlements": {},
  "expires_at": null
}
```

**Notes**:
- Called by NHP server plugin to validate downloads
- Checks RevenueCat V2 API: `GET /v2/customers/{device_id}`
- Updates `last_seen_at` timestamp for device
- Test bypass for specific device IDs (see `src/routes/subscription.ts`)

### Subscription Status (User Facing)

```http
GET /api/v1/subscription/status
X-API-Key: {api_key}
```

**Response**:
```json
{
  "is_premium": true,
  "subscription_type": "premium",
  "features": ["offline_maps", "premium_layers"],
  "expires_at": null,
  "first_seen": "2025-12-01T00:00:00.000Z",
  "last_seen": "2026-01-08T13:00:00.000Z"
}
```

**Notes**:
- Used by mobile app to display subscription status
- Returns more detailed information than `/validate` endpoint
- Includes entitlement details and feature flags

### Download Metadata

```http
GET /api/v1/downloads/metadata
X-API-Key: {api_key}
```

**Response**:
```json
{
  "versions": {
    "data": "2.0-GNIS"
  },
  "states": [
    {
      "state_code": "WY",
      "land_size": 15728640,
      "trails_size": 12582912,
      "historical_size": 998400,
      "total_size": 29309952
    }
  ],
  "split_available": true
}
```

**Notes**:
- Scans `/var/www/downloads/states/` directory
- Returns file sizes for capacity planning
- Used by mobile app to show download requirements

### List Available States

```http
GET /api/v1/downloads/states
X-API-Key: {api_key}
```

**Response**:
```json
{
  "states": ["AK", "AL", "AR", "AZ", ...]
}
```

## Database Schema

**File**: `/app/data/obsession-api.db` (SQLite)

```sql
CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  device_id TEXT UNIQUE NOT NULL,
  api_key TEXT UNIQUE NOT NULL,
  platform TEXT,
  app_version TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT (datetime('now')),
  last_seen_at TEXT DEFAULT (datetime('now'))
);
```

## Environment Variables

```bash
# Required
REVENUECAT_API_KEY=sk_xxxx   # RevenueCat V2 secret API key

# Optional
NODE_ENV=production           # Environment mode
PORT=3003                     # Server port
DOWNLOADS_PATH=/app/downloads # Path to state ZIP files
FCM_SERVICE_ACCOUNT={}        # Firebase Cloud Messaging credentials (future)
```

## Local Development

### Prerequisites

- Node.js 20+
- npm

### Setup

```bash
cd obsession-tracker/server

# Install dependencies
npm install

# Build TypeScript
npm run build

# Run in development mode (with auto-reload)
npm run dev

# Server runs on http://localhost:3003
```

### Testing Locally

```bash
# Test health endpoint
curl http://localhost:3003/health

# Register a test device
curl -X POST http://localhost:3003/api/v1/devices/register \
  -H "Content-Type: application/json" \
  -d '{"device_id":"test-device","platform":"ios","app_version":"1.0.0"}'

# Validate subscription (will fail without RevenueCat API key)
curl -X POST http://localhost:3003/api/v1/subscription/validate \
  -H "X-API-Key: YOUR-API-KEY"
```

## Deployment

### Docker Build

```bash
# Build image
docker build -t tracker-api .

# Run container
docker run -d \
  --name tracker-api \
  -p 3003:3003 \
  -e REVENUECAT_API_KEY=sk_xxx \
  -v $(pwd)/data:/app/data \
  tracker-api
```

### Production Deployment

Deployment is automated via GitHub Actions:

```bash
# Deploy via workflow
# See: .github/workflows/deploy-droplet.yml

# Trigger deployment
gh workflow run deploy-droplet.yml -f service=tracker-api
```

**Deployment Process**:
1. Build Docker image on droplet
2. Stop existing container
3. Start new container with updated code
4. Verify health endpoint
5. Clean up old images

### Manual Deployment (Emergency)

```bash
# SSH to droplet
ssh root@YOUR_SERVER_IP

# Navigate to infrastructure
cd /var/www/obsession/infrastructure

# Rebuild and restart
docker compose build tracker-api
docker compose up -d tracker-api

# Check logs
docker logs tracker-api --tail 50

# Verify health
curl http://localhost:3003/health
```

## RevenueCat Integration

### API V2 Migration

**Important**: This service uses RevenueCat API V2. V1 is deprecated.

**Endpoint**: `GET https://api.revenuecat.com/v2/customers/{device_id}`

**Changes from V1**:
- V1: `/v1/subscribers/{app_user_id}`
- V2: `/v2/customers/{customer_id}`
- URL path changed from `subscribers` to `customers`
- All other response formats remain the same

### Device ID Requirement

**CRITICAL**: The mobile app **must** initialize RevenueCat with the device ID as app user ID:

```dart
// Mobile app initialization
final deviceId = await DeviceIdService().getDeviceId();
await SubscriptionService.instance.initialize(
  apiKey: RevenueCatConfig.currentApiKey,
  appUserId: deviceId, // REQUIRED!
);
```

**Why**: tracker-api validates subscriptions by looking up `device_id` in RevenueCat. If RevenueCat has an anonymous ID instead (e.g., `$RCAnonymousID:abc123`), validation will fail.

### Test Bypass

For development, specific device IDs bypass RevenueCat validation:

```typescript
// src/routes/subscription.ts
const testPremiumDeviceIds = [
  // Add your test device UUIDs here during development
  // e.g., 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
];
```

**Production**: Remove or comment out test bypass in production builds.

## Troubleshooting

### 403 Error from RevenueCat

**Symptom**: Logs show `RevenueCat API error: 403`

**Cause**: Using V1 API key with V2 endpoints (or vice versa)

**Solution**: Verify `REVENUECAT_API_KEY` is a V2 secret key (starts with `sk_`)

### Subscription Validation Returns False

**Symptom**: User has subscription but `/validate` returns `is_premium: false`

**Causes**:
1. RevenueCat has subscription under anonymous ID, not device ID
2. Subscription expired
3. Wrong RevenueCat project

**Solution**:
1. Check RevenueCat dashboard for customer with device ID
2. If customer doesn't exist, user needs to restore purchases
3. If customer exists but no entitlements, check subscription status

### Database Locked Errors

**Symptom**: `SQLITE_BUSY: database is locked`

**Cause**: Multiple connections attempting concurrent writes

**Solution**: SQLite uses WAL mode by default (configured in `db/index.ts`). Ensure only one server instance is running.

### Container Won't Start

**Symptoms**: Container exits immediately

**Debug Steps**:

```bash
# Check logs
docker logs tracker-api

# Run interactively
docker run -it --rm tracker-api npm start

# Check environment variables
docker exec tracker-api env | grep REVENUECAT
```

## Monitoring

### Health Check

```bash
# From droplet
curl http://localhost:3003/health

# From external
curl https://api.obsessiontracker.com/health
```

### Database Stats

```bash
# SSH to droplet
ssh root@YOUR_SERVER_IP

# Check database size
du -h /var/lib/docker/volumes/infrastructure_tracker-api-data/_data/obsession-api.db

# Query device count
sqlite3 /var/lib/docker/volumes/infrastructure_tracker-api-data/_data/obsession-api.db \
  "SELECT COUNT(*) FROM devices"

# Check recent activity
sqlite3 /var/lib/docker/volumes/infrastructure_tracker-api-data/_data/obsession-api.db \
  "SELECT device_id, last_seen_at FROM devices ORDER BY last_seen_at DESC LIMIT 10"
```

### Logs

```bash
# Real-time logs
docker logs -f tracker-api

# Last 100 lines
docker logs tracker-api --tail 100

# Errors only
docker logs tracker-api 2>&1 | grep -i error

# RevenueCat API calls
docker logs tracker-api 2>&1 | grep -i revenuecat
```

## Security

### API Key Generation

API keys are cryptographically secure 64-character hex strings (256 bits of entropy):

```typescript
// src/utils/crypto.ts
crypto.randomBytes(32).toString('hex')
```

### Database Security

- SQLite database file has restricted permissions (root:root)
- No sensitive data stored except API keys (which are randomly generated)
- Device IDs are user-controlled identifiers, not personally identifiable

### RevenueCat API Key

**CRITICAL**: RevenueCat secret key must be kept secure:
- Stored in environment variable only
- Never committed to git
- Provides full access to subscription data
- Rotatable via RevenueCat dashboard

## Integration with NHP Downloads

tracker-api is called by NHP server plugin during download authentication:

```
Mobile App
  ↓ Knock: GET /knock with X-Device-ID and X-API-Key
NHP Server (NHP_CONTAINER_IP)
  ↓ Validate: POST http://API_CONTAINER_IP:3003/api/v1/subscription/validate
tracker-api
  ↓ Check: GET https://api.revenuecat.com/v2/customers/{device_id}
RevenueCat API
  ↓ Returns subscription status
tracker-api → NHP Server
  ↓ If premium: whitelist IP for 1 hour
  ↓ Returns: {success: true, open_time: 3600}
Mobile App → Download state files
```

**See**: `infrastructure/README-NHP-DOWNLOADS.md` for complete flow documentation

## Future Enhancements

- [ ] Firebase Cloud Messaging for push notifications
- [ ] Admin authentication and device management endpoints
- [ ] Usage analytics (privacy-preserving)
- [ ] Rate limiting per device
- [ ] Caching layer for RevenueCat responses

## Related Documentation

- **Mobile App Integration**: `../CLAUDE.md` (Premium Downloads with NHP section)
- **NHP System**: `../../infrastructure/README-NHP-DOWNLOADS.md`
- **RevenueCat Setup**: `../docs/REVENUECAT_SETUP_GUIDE.md`
- **Deployment Workflow**: `../../.github/workflows/deploy-droplet.yml`

---

**Last Updated**: January 8, 2026

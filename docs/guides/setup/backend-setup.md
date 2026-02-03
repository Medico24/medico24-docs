# Backend Development Setup

This guide covers setting up the Medico24 backend API (FastAPI + Python).

## Prerequisites

- Python 3.11 or higher
- PostgreSQL client tools (optional, for direct database access)
- Redis (will use cloud service)
- Docker and Docker Compose (for local infrastructure)

---

## Installation

### 1. Navigate to Backend Directory

```bash
cd medico24-backend
```

### 2. Create Virtual Environment

=== "Windows"
    ```powershell
    python -m venv venv
    .\venv\Scripts\activate
    ```

=== "macOS/Linux"
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

### 3. Install Dependencies

```bash
# Upgrade pip
pip install --upgrade pip

# Install production dependencies
pip install -e .

# Install development dependencies
pip install -e ".[dev]"
```

---

## Environment Configuration

### Create `.env` File

Copy the example environment file:

```bash
cp .env.example .env
```

### Complete Environment Variables

```env
# Application Settings
APP_NAME=Medico24
APP_VERSION=1.0.0
ENVIRONMENT=development
DEBUG=true
LOG_LEVEL=INFO

# Server Configuration
HOST=0.0.0.0
PORT=8000
RELOAD=true
WORKERS=1

# Database (Neon PostgreSQL - get from external services)
DATABASE_URL=postgresql://user:password@host/database?sslmode=require
TEST_DATABASE_URL=postgresql://user:password@host/test_db?sslmode=require

# SQLAlchemy Pool Settings
DB_POOL_SIZE=5
DB_MAX_OVERFLOW=10
DB_POOL_PRE_PING=true
DB_ECHO=false

# Redis (Redis Cloud - get from external services)
REDIS_HOST=redis-xxxxx.cloud.redislabs.com
REDIS_PORT=xxxxx
REDIS_PASSWORD=your-password
REDIS_USERNAME=default
REDIS_DB=0
REDIS_DECODE_RESPONSES=true

# Alternative: Redis URL format
# REDIS_URL=redis://default:password@host:port/0

# JWT Authentication
JWT_SECRET_KEY=your-generated-secret-key-here  # Generate using: openssl rand -hex 32
JWT_REFRESH_SECRET_KEY=your-refresh-secret-here
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Google OAuth (get from Google Cloud Console)
GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abc123
GOOGLE_REDIRECT_URI=http://localhost:8000/api/v1/auth/google/callback

# Firebase Admin SDK (download service account JSON)
FIREBASE_CREDENTIALS_PATH=firebase-service-account.json

# Google Maps API (get from Google Cloud Console)
GOOGLE_MAPS_API_KEY=AIzaSyD...your-api-key

# External APIs
OPENWEATHER_API_KEY=your-openweather-key  # Optional: for weather data
VISUAL_CROSSING_API_KEY=your-visualcrossing-key  # Alternative weather API

# CORS Settings
CORS_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:8000
CORS_ALLOW_CREDENTIALS=true
CORS_ALLOW_METHODS=GET,POST,PUT,DELETE,PATCH,OPTIONS
CORS_ALLOW_HEADERS=*

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
RATE_LIMIT_PER_HOUR=1000

# File Upload
MAX_UPLOAD_SIZE_MB=10
ALLOWED_FILE_TYPES=image/jpeg,image/png,application/pdf

# Email Configuration (optional, for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=noreply@medico24.com
SMTP_FROM_NAME=Medico24

# Admin Settings
ADMIN_NOTIFICATION_SECRET=your-admin-secret
ADMIN_EMAIL=admin@medico24.com
SUPER_ADMIN_EMAIL=superadmin@medico24.com

# Sentry (optional, for error tracking)
SENTRY_DSN=https://...@sentry.io/...
SENTRY_ENVIRONMENT=development
SENTRY_TRACES_SAMPLE_RATE=0.1

# Celery (for background tasks - optional)
CELERY_BROKER_URL=redis://default:password@host:port/1
CELERY_RESULT_BACKEND=redis://default:password@host:port/2

# Feature Flags
ENABLE_GOOGLE_LOGIN=true
ENABLE_EMAIL_VERIFICATION=false  # Set to true in production
ENABLE_SMS_NOTIFICATIONS=false
ENABLE_METRICS=true

# Security
SECRET_KEY=another-secret-key-for-general-encryption
ALLOWED_HOSTS=localhost,127.0.0.1,*.medico24.com
```

!!! tip "Secret Generation"
    Generate secure secrets using:
    ```bash
    openssl rand -hex 32
    ```

!!! warning "Security"
    - Never commit `.env` to Git
    - Use different secrets for dev/staging/production
    - Keep `firebase-service-account.json` private

---

## Database Setup

### 1. Run Migrations

Apply database schema:

```bash
# Create/upgrade database schema
alembic upgrade head
```

### 2. Create Database Migrations (Optional)

When you modify models:

```bash
# Generate migration from model changes
alembic revision --autogenerate -m "Description of changes"

# Review the generated migration file in alembic/versions/

# Apply the migration
alembic upgrade head
```

### 3. Seed Initial Data (Optional)

```bash
# Run seed script
python scripts/seed_database.py
```

### Common Alembic Commands

```bash
# Show current migration version
alembic current

# Show migration history
alembic history

# Downgrade to previous version
alembic downgrade -1

# Downgrade to specific version
alembic downgrade <revision_id>

# Stamp database without running migrations
alembic stamp head
```

---

## Running the Application

### Development Server

```bash
# Standard run
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Or using the shortcut
python -m app.main

# Or using make (if Makefile exists)
make dev
```

### Using Docker

```bash
# Build image
docker build -t medico24-backend .

# Run container
docker run -p 8000:8000 --env-file .env medico24-backend
```

### Using Docker Compose

```bash
# Start backend + dependencies (PostgreSQL, Redis)
docker-compose up

# Run in detached mode
docker-compose up -d

# View logs
docker-compose logs -f backend

# Stop services
docker-compose down
```

---

## Testing

### Run All Tests

```bash
# Run all tests with coverage
pytest

# Or using make
make test
```

### Run Specific Tests

```bash
# Run tests for specific module
pytest tests/test_auth.py

# Run specific test function
pytest tests/test_auth.py::test_user_registration

# Run with verbose output
pytest -v

# Run with print statements visible
pytest -s
```

### Test Coverage

```bash
# Generate coverage report
pytest --cov=app --cov-report=html

# Open HTML report
# Windows
start htmlcov/index.html
# macOS
open htmlcov/index.html
# Linux
xdg-open htmlcov/index.html
```

### Integration Tests

```bash
# Run only integration tests
pytest tests/integration/

# Run excluding integration tests (faster)
pytest --ignore=tests/integration/
```

---

## Code Quality

### Linting

```bash
# Lint code with ruff
ruff check app/

# Auto-fix linting issues
ruff check --fix app/

# Format code
ruff format app/
```

### Type Checking

```bash
# Run mypy type checker
mypy app/

# Check specific file
mypy app/services/auth.py
```

### Pre-commit Hooks

```bash
# Install pre-commit hooks
pre-commit install

# Run all hooks manually
pre-commit run --all-files

# Update hooks to latest version
pre-commit autoupdate
```

---

## API Documentation

### Interactive API Docs

Once the server is running, access:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/openapi.json

### Generate API Documentation

```bash
# Generate OpenAPI spec file
python scripts/generate_openapi.py > openapi.json
```

---

## Debugging

### Using VS Code Debugger

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: FastAPI",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": [
        "app.main:app",
        "--reload",
        "--host",
        "0.0.0.0",
        "--port",
        "8000"
      ],
      "jinja": true,
      "justMyCode": false,
      "env": {
        "PYTHONPATH": "${workspaceFolder}"
      }
    }
  ]
}
```

Set breakpoints and press F5 to start debugging.

### Using Python Debugger (pdb)

```python
# Add breakpoint in code
import pdb; pdb.set_trace()

# Or use built-in breakpoint()
breakpoint()
```

### Logging

```python
import logging
logger = logging.getLogger(__name__)

# In your code
logger.debug("Debug information")
logger.info("Informational message")
logger.warning("Warning message")
logger.error("Error message")
logger.exception("Exception with traceback")
```

---

## Project Structure

```
medico24-backend/
├── alembic/                  # Database migrations
│   ├── versions/            # Migration files
│   └── env.py              # Alembic configuration
├── app/
│   ├── main.py             # FastAPI application entry point
│   ├── config.py           # Application configuration
│   ├── database.py         # Database connection
│   ├── models/             # SQLAlchemy models
│   ├── schemas/            # Pydantic schemas
│   ├── routers/            # API route handlers
│   ├── services/           # Business logic
│   ├── utils/              # Utility functions
│   └── middleware/         # Custom middleware
├── tests/                   # Test files
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── conftest.py        # Pytest fixtures
├── scripts/                 # Utility scripts
├── .env.example            # Example environment file
├── .gitignore
├── alembic.ini             # Alembic config
├── docker-compose.yml      # Docker services
├── Dockerfile              # Backend container
├── Makefile               # Common commands
├── pyproject.toml         # Python project config
├── pytest.ini             # Pytest configuration
└── README.md
```

---

## Common Development Tasks

### Add a New API Endpoint

1. **Create Pydantic schema** in `app/schemas/`:

```python
# app/schemas/pharmacy.py
from pydantic import BaseModel

class PharmacyCreate(BaseModel):
    name: str
    address: str
    latitude: float
    longitude: float

class PharmacyResponse(PharmacyCreate):
    id: int
    created_at: datetime
```

2. **Create database model** in `app/models/`:

```python
# app/models/pharmacy.py
from sqlalchemy import Column, Integer, String, Float, DateTime
from app.database import Base

class Pharmacy(Base):
    __tablename__ = "pharmacies"
    
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    address = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)
```

3. **Create service logic** in `app/services/`:

```python
# app/services/pharmacy.py
from sqlalchemy.orm import Session
from app.models.pharmacy import Pharmacy
from app.schemas.pharmacy import PharmacyCreate

def create_pharmacy(db: Session, pharmacy: PharmacyCreate):
    db_pharmacy = Pharmacy(**pharmacy.dict())
    db.add(db_pharmacy)
    db.commit()
    db.refresh(db_pharmacy)
    return db_pharmacy
```

4. **Create router** in `app/routers/`:

```python
# app/routers/pharmacy.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.pharmacy import PharmacyCreate, PharmacyResponse
from app.services import pharmacy as pharmacy_service

router = APIRouter(prefix="/api/v1/pharmacies", tags=["pharmacies"])

@router.post("/", response_model=PharmacyResponse)
def create_pharmacy(
    pharmacy: PharmacyCreate,
    db: Session = Depends(get_db)
):
    return pharmacy_service.create_pharmacy(db, pharmacy)
```

5. **Register router** in `app/main.py`:

```python
from app.routers import pharmacy

app.include_router(pharmacy.router)
```

6. **Create migration**:

```bash
alembic revision --autogenerate -m "Add pharmacy table"
alembic upgrade head
```

7. **Write tests** in `tests/`:

```python
# tests/test_pharmacy.py
def test_create_pharmacy(client, db_session):
    response = client.post("/api/v1/pharmacies/", json={
        "name": "Test Pharmacy",
        "address": "123 Main St",
        "latitude": 12.34,
        "longitude": 56.78
    })
    assert response.status_code == 200
    assert response.json()["name"] == "Test Pharmacy"
```

### Add Background Tasks

```python
# app/tasks/celery_app.py
from celery import Celery

celery_app = Celery(
    "medico24",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND
)

@celery_app.task
def send_notification_email(user_id: int, message: str):
    # Email sending logic
    pass
```

Run Celery worker:

```bash
celery -A app.tasks.celery_app worker --loglevel=info
```

---

## Troubleshooting

### Import Errors

```bash
# Ensure PYTHONPATH includes project root
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

# Or use editable install
pip install -e .
```

### Database Connection Issues

??? question "Connection refused"
    - Check DATABASE_URL in `.env`
    - Verify database server is running
    - Ensure SSL mode is correct (`sslmode=require` for Neon)

??? question "Migration conflicts"
    ```bash
    # Reset migrations (development only!)
    alembic downgrade base
    alembic upgrade head
    ```

### Redis Connection Issues

??? question "Connection timeout"
    - Verify REDIS_HOST and REDIS_PORT
    - Check firewall rules
    - Test connection: `redis-cli -h <host> -p <port> -a <password> PING`

### Module Not Found Errors

```bash
# Reinstall dependencies
pip install -e ".[dev]"

# Clear cache
pip cache purge
find . -type d -name __pycache__ -exec rm -rf {} +
```

---

## Production Deployment

### Environment Variables

Use production values:

```env
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=WARNING
RELOAD=false
WORKERS=4  # (2 x CPU cores) + 1
```

### Security Checklist

- [ ] Use strong JWT secrets
- [ ] Enable HTTPS only
- [ ] Configure CORS properly
- [ ] Enable rate limiting
- [ ] Set up Sentry for error tracking
- [ ] Use production database
- [ ] Configure firewall rules
- [ ] Enable database backups
- [ ] Rotate secrets regularly

### Gunicorn (Production Server)

```bash
# Install gunicorn
pip install gunicorn

# Run with workers
gunicorn app.main:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000
```

---

## Next Steps

1. Complete [External Services Setup](external-services.md) if you haven't
2. Set up [Frontend Development](frontend-setup.md)
3. Set up [Mobile Development](mobile-setup.md)
4. Read [API Documentation](../api/overview.md)
5. Explore [Architecture Documentation](../architecture/overview.md)

**Related Guides:**

- [Setup Overview](overview.md)
- [External Services](external-services.md)
- [Frontend Setup](frontend-setup.md)
- [Mobile Setup](mobile-setup.md)

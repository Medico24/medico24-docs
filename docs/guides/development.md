# Development Guide

This guide provides comprehensive instructions for setting up and contributing to the Medico24 platform development.

## Overview

Medico24 is a multi-component healthcare platform consisting of:
- **Backend API** (FastAPI + Python)
- **Mobile App** (Flutter + Dart)
- **Web Dashboard** (Next.js + TypeScript)
- **ML Module** (Python + Jupyter)
- **Observability Stack** (Docker Compose)

## Prerequisites

### Required Software

- **Git** (latest version)
- **Docker** and **Docker Compose**
- **Python** 3.11+
- **Node.js** 18+
- **Flutter** 3.x
- **PostgreSQL** client tools (optional)

### Platform-Specific Requirements

#### Windows
```powershell
# Install Chocolatey first
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required tools
choco install git docker-desktop python nodejs flutter
```

#### macOS
```bash
# Install Homebrew first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install git docker python node flutter
```

#### Linux (Ubuntu/Debian)
```bash
# Update package list
sudo apt update

# Install dependencies
sudo apt install -y git docker.io docker-compose python3 python3-pip nodejs npm

# Install Flutter
sudo snap install flutter --classic
```

## Repository Setup

### Clone Main Repository

```bash
git clone https://github.com/medico24/medico24.git
cd medico24
```

### Directory Structure

```
medico24/
├── medico24-backend/         # FastAPI backend
├── medico24-application/     # Flutter mobile app
├── medico24-website/         # Next.js web dashboard
├── medico24-ml/              # ML/AI module
├── medico24-observability/   # Monitoring stack
├── medico24-docs/            # Documentation
├── docker-compose.yml        # Full stack orchestration
├── Makefile                  # Common commands
└── README.md
```

## Backend Development

### Environment Setup

```bash
cd medico24-backend

# Create virtual environment
python -m venv .venv

# Activate virtual environment
# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install development dependencies
pip install -r requirements-dev.txt
```

### Environment Variables

Create `.env` file:

```env
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/medico24

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
JWT_SECRET_KEY=your-secret-key-here
JWT_REFRESH_SECRET_KEY=your-refresh-secret-key
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# Firebase
FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json

# Google APIs
GOOGLE_MAPS_API_KEY=your-google-maps-api-key

# Admin
ADMIN_SECRET_KEY=your-admin-secret-key

# Environment
ENVIRONMENT=development
DEBUG=true
```

### Database Setup

```bash
# Start PostgreSQL and Redis
docker compose up -d postgres redis

# Run migrations
alembic upgrade head

# Create initial admin user (optional)
python scripts/create_admin.py
```

### Run Development Server

```bash
# Start FastAPI server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Alternative using Makefile
make dev
```

### Testing

```bash
# Run all tests
pytest

# Run tests with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_auth.py

# Run tests in verbose mode
pytest -v
```

## Frontend Development (Web)

### Setup

```bash
cd medico24-website

# Install dependencies
npm install

# Create environment variables
cp .env.example .env.local
```

### Environment Configuration

```env
# .env.local
NEXT_PUBLIC_API_URL=http://localhost:8000
NEXT_PUBLIC_FIREBASE_CONFIG='{"apiKey":"...","authDomain":"..."}'
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
```

### Development Server

```bash
# Start development server
npm run dev

# Run on specific port
npm run dev -- --port 3001
```

### Build and Test

```bash
# Type checking
npm run type-check

# Linting
npm run lint

# Build production
npm run build

# Start production server
npm run start
```

## Mobile Development (Flutter)

### Setup

```bash
cd medico24-application

# Get dependencies
flutter pub get

# Run code generation
flutter packages pub run build_runner build
```

### Configuration

#### Firebase Setup

1. Create Firebase project
2. Download configuration files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

#### Environment Configuration

```dart
// lib/core/config/app_config.dart
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
```

### Development

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Hot reload is automatic during development

# Run tests
flutter test

# Analyze code
flutter analyze
```

## ML Module Development

### Setup

```bash
cd medico24-ml

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows

# Install dependencies
pip install -r requirements.txt

# Install Jupyter
pip install jupyter
```

### Development

```bash
# Start Jupyter Lab
jupyter lab

# Run training scripts
python src/train_model.py

# Run tests
pytest tests/
```

## Observability Stack

### Setup and Run

```bash
cd medico24-observability

# Create environment file
cp .env.example .env

# Start all services
docker compose --profile all up -d

# Or start specific profiles
docker compose --profile monitoring up -d
```

### Access Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001 (admin/admin)
- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601

## Full Stack Development

### Using Docker Compose

```bash
# Start all services
docker compose up -d

# Start specific services
docker compose up -d backend frontend mobile-build

# View logs
docker compose logs -f backend

# Stop all services
docker compose down
```

### Using Makefile

```bash
# Setup development environment
make setup

# Start all services
make up

# Run all tests
make test

# Clean up
make clean

# View all commands
make help
```

## Code Quality

### Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit

# Setup hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

### Linting and Formatting

#### Backend (Python)

```bash
# Format code
black .

# Sort imports
isort .

# Lint code
ruff check .

# Type checking
mypy app/
```

#### Frontend (TypeScript)

```bash
# Lint and format
npm run lint
npm run format

# Type checking
npm run type-check
```

#### Mobile (Dart)

```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Database Management

### Migrations

```bash
# Create new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback migration
alembic downgrade -1

# Check current revision
alembic current

# View migration history
alembic history
```

### Database Operations

```bash
# Connect to database
psql $DATABASE_URL

# Backup database
pg_dump $DATABASE_URL > backup.sql

# Restore database
psql $DATABASE_URL < backup.sql

# Reset database
alembic downgrade base
alembic upgrade head
```

## Testing Strategy

### Backend Testing

```bash
# Unit tests
pytest tests/unit/

# Integration tests
pytest tests/integration/

# API tests
pytest tests/api/

# Coverage report
pytest --cov=app --cov-report=html
```

### Frontend Testing

```bash
# Unit tests
npm test

# E2E tests
npm run test:e2e

# Component tests
npm run test:component
```

### Mobile Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Widget tests
flutter test test/widget/
```

## Debugging

### Backend Debugging

```bash
# Start with debugger
python -m debugpy --listen 0.0.0.0:5678 --wait-for-client -m uvicorn app.main:app --reload

# View logs
tail -f logs/app.log

# Debug SQL queries
export SQLALCHEMY_ECHO=true
```

### Frontend Debugging

```bash
# Debug mode
npm run dev

# Debug build
npm run build && npm run start

# Analyze bundle
npm run analyze
```

### Mobile Debugging

```bash
# Debug mode
flutter run --debug

# Release mode
flutter run --release

# Profile mode
flutter run --profile

# DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

## Deployment

### Environment Preparation

```bash
# Production environment variables
cp .env.example .env.production

# Build all components
make build

# Run production tests
make test-prod
```

### Docker Deployment

```bash
# Build production images
docker compose -f docker-compose.prod.yml build

# Deploy to production
docker compose -f docker-compose.prod.yml up -d

# Check deployment
docker compose -f docker-compose.prod.yml ps
```

## Troubleshooting

### Common Issues

#### Database Connection Issues

```bash
# Check PostgreSQL status
docker compose ps postgres

# Check connection
psql $DATABASE_URL -c "SELECT 1;"

# Reset database container
docker compose down postgres
docker compose up -d postgres
```

#### Redis Connection Issues

```bash
# Check Redis status
docker compose ps redis

# Test connection
redis-cli -u $REDIS_URL ping

# Reset Redis container
docker compose restart redis
```

#### Port Conflicts

```bash
# Check port usage
netstat -tulpn | grep :8000

# Kill process using port
kill -9 $(lsof -t -i:8000)

# Use different port
uvicorn app.main:app --port 8001
```

#### Permission Issues

```bash
# Fix Docker permissions (Linux)
sudo chown -R $USER:$USER ./volumes/

# Fix file permissions
chmod +x scripts/*.sh

# Reset Git permissions
git config core.fileMode false
```

### Getting Help

1. **Check Documentation**: Start with this documentation
2. **Search Issues**: Look through GitHub issues
3. **Ask Team**: Contact team members via Slack
4. **Create Issue**: Create detailed GitHub issue if needed

## Best Practices

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and commit
git add .
git commit -m "feat: add new feature"

# Push and create PR
git push origin feature/new-feature

# After review, merge to main
git checkout main
git pull origin main
git branch -d feature/new-feature
```

### Commit Messages

Use conventional commits:

```
feat: add new user authentication
fix: resolve database connection issue
docs: update API documentation
test: add unit tests for user service
refactor: improve error handling
```

### Code Review

- Create focused, single-purpose PRs
- Write clear PR descriptions
- Include tests for new features
- Update documentation
- Respond to feedback promptly

## Next Steps

- [Contributing Guide](contributing.md) - Contribution guidelines
- [Testing Guide](testing.md) - Comprehensive testing strategies
- [Deployment Guide](deployment.md) - Production deployment
- [API Documentation](../api/overview.md) - API integration guide
# Medico24 Platform Documentation

Welcome to the comprehensive documentation for the Medico24 healthcare appointment management platform.

## Overview

**Medico24** is an enterprise-grade healthcare appointment management system built with modern microservices architecture. The platform enables patients to book appointments, search for nearby pharmacies, receive real-time environmental health data, and manage their healthcare needs through intuitive mobile and web interfaces.

### Platform Components

- **[Flutter Mobile Application](guides/mobile-app.md)** - Cross-platform iOS/Android patient app
- **[Next.js Web Dashboard](implementations/dashboard.md)** - Admin dashboard and management interface
- **[FastAPI Backend](api/overview.md)** - RESTful API server with PostgreSQL database
- **[Machine Learning Module](guides/ml-module.md)** - Predictive analytics and health insights
- **[Observability Stack](monitoring/overview.md)** - Comprehensive monitoring and logging

### Key Features

- ✅ Google OAuth authentication via Firebase
- ✅ JWT-based session management (access + refresh tokens)
- ✅ Appointment booking and management
- ✅ Geographic pharmacy search with PostGIS
- ✅ Real-time environmental data (AQI, weather)
- ✅ Push notifications via Firebase Cloud Messaging
- ✅ Admin dashboard with analytics
- ✅ Role-based access control (Patient/Doctor/Admin)
- ✅ Comprehensive testing infrastructure
- ✅ Full observability stack with monitoring
- ✅ Cloud-native infrastructure

## Quick Start

### For Developers

1. **Backend Development**: See [API Documentation](api/specifications.md)
2. **Frontend Development**: See [Dashboard Implementation](implementations/dashboard.md)
3. **Mobile Development**: See [Mobile App Guide](guides/mobile-app.md)
4. **Monitoring Setup**: See [Observability Guide](monitoring/setup.md)

### For System Administrators

1. **Architecture Overview**: See [System Architecture](architecture/overview.md)
2. **Deployment Guide**: See [Deployment Documentation](guides/deployment.md)
3. **Monitoring & Observability**: See [Monitoring Overview](monitoring/overview.md)

### For Contributors

1. **Contributing Guidelines**: See [Contributing Guide](guides/contributing.md)
2. **Development Setup**: See [Development Guide](guides/development.md)
3. **Testing Guide**: See [Testing Documentation](guides/testing.md)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLIENT APPLICATIONS                          │
├─────────────────────────────────────────────────────────────────┤
│  Flutter Mobile App     │     Next.js Web Dashboard             │
│  (iOS/Android)          │     (React + TypeScript)              │
└────────────┬────────────┼────────────────────┬──────────────────┘
             │            │                    │
             └────────────┼────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                    FastAPI Backend                              │
│                 (Python + PostgreSQL)                           │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│               External Services & Storage                       │
├─────────────────────────────────────────────────────────────────┤
│  Firebase Auth  │  PostgreSQL   │  Redis Cache  │  Google APIs  │
│  (Identity)     │  (Neon Cloud) │  (Redis Labs) │  (Maps/Env)   │
└─────────────────────────────────────────────────────────────────┘
```

## Getting Help

- **Issues & Bug Reports**: [GitHub Issues](https://github.com/medico24/medico24/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/medico24/medico24/discussions)
- **Documentation**: This documentation site
- **Contact**: [Team Contact Information](guides/contact.md)

## License

This project is licensed under the MIT License - see the [LICENSE](guides/license.md) file for details.

---

**Copyright © 2026 Medico24 Team. All rights reserved.**
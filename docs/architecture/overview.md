# Medico24 - System Architecture Documentation

**Version:** 2.1  
**Last Updated:** January 31, 2026  
**Status:** Production

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [High-Level System Architecture](#high-level-system-architecture)
3. [Low-Level System Architecture](#low-level-system-architecture)
4. [Observability & Monitoring](#observability--monitoring)
5. [Component Diagrams](#component-diagrams)
6. [Data Flow Diagrams](#data-flow-diagrams)
7. [Testing Infrastructure](#testing-infrastructure)
8. [Technology Stack](#technology-stack)
9. [Infrastructure](#infrastructure)
10. [Security Architecture](#security-architecture)

---

## Executive Summary

**Medico24** is an enterprise-grade healthcare appointment management system built with a modern microservices architecture. The system consists of:

- **Flutter Mobile Application** (iOS/Android) - Patient-facing mobile app
- **Next.js Web Application** - Admin dashboard and web interface
- **FastAPI Backend** - RESTful API server with PostgreSQL database
- **Firebase Authentication** - Identity and authentication provider
- **Redis Cache** - Session and data caching layer (Cloud - Redis Labs)
- **PostgreSQL Database** - Cloud-hosted on Neon (Singapore region)
- **Observability Stack** - Comprehensive monitoring, logging, and metrics collection
- **PostGIS** - Geographic data for pharmacy location services

### Key Features
- Google OAuth authentication via Firebase
- JWT-based session management (access + refresh tokens)
- Appointment booking and management
- Nearby pharmacy search with geolocation
- Real-time environmental data (AQI, weather)
- User profile management
- Push notifications via Firebase Cloud Messaging (FCM)
- Real-time health monitoring with Prometheus metrics
- Admin dashboard with analytics
- User and appointment management console
- Pharmacy verification system
- Broadcast notification system
- Role-based access control (Patient/Doctor/Admin)
- Comprehensive testing infrastructure
- Full observability stack with centralized monitoring and logging
- Cloud-native infrastructure with managed services (Neon PostgreSQL, Redis Labs)

---

## High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐         ┌─────────────────┐                    │
│  │  Flutter App    │         │   Next.js Web   │                    │
│  │  (iOS/Android)  │         │  Admin Console  │                    │
│  │                 │         │   (React 19)    │                    │
│  └────────┬────────┘         └────────┬────────┘                    │
│           │                           │                             │
└───────────┼───────────────────────────┼─────────────────────────────┘
            │                           │
            │        HTTPS/REST         │
            │                           │
┌───────────▼───────────────────────────▼─────────────────────────────┐
│                      API GATEWAY / LOAD BALANCER                    │
│                         (NGINX - Future)                            │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
┌───────────────────────────────▼─────────────────────────────────────┐
│                         APPLICATION LAYER                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │              FastAPI Backend Server                        │     │
│  │              (Python 3.14)                                 │     │
│  │                                                            │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │     │
│  │  │    Auth      │  │  Appointments│  │  Pharmacies  │      │     │
│  │  │   Service    │  │   Service    │  │   Service    │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  │                                                            │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │     │
│  │  │    User      │  │ Notification │  │    Admin     │      │     │
│  │  │   Service    │  │   Service    │  │   Service    │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  │                                                            │     │
│  │  ┌──────────────┐  ┌──────────────┐                        │     │
│  │  │  Middleware  │  │   Testing    │  │  Prometheus  │      │     │
│  │  │    Layer     │  │   (pytest)   │  │   Metrics    │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
└───────────────────────────┬───────────────┬─────────────────────────┘
                            │               │
        ┌───────────────────┘               └──────────────────┐
        │                                                      │
┌───────▼────────┐                                    ┌────────▼────────┐
│                │                                    │                 │
│  AUTHENTICATION│                                    │   CACHE LAYER   │
│     LAYER      │                                    │                 │
│                │                                    │  ┌───────────┐  │
│ ┌────────────┐ │                                    │  │   Redis   │  │
│ │  Firebase  │ │                                    │  │   Labs    │  │
│ │   Admin    │ │                                    │  │  (Cloud)  │  │
│ │    SDK     │ │                                    │  └───────────┘  │
│ └────────────┘ │                                    │                 │
│                │                                    │  Mumbai Region  │
│  Google OAuth  │                                    │  Session/Token  │
│  ID Token      │                                    │   Management    │
│  Verification  │                                    │  Cache Pharmacy │
│                │                                    │   & User Data   │
│                │                                    │                 │
└────────────────┘                                    └─────────────────┘
        │
        │
┌───────▼────────────────────────────────────────────────────────────┐
│                         DATA LAYER                                 │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌───────────────────────────────────────────────────────────┐     │
│  │           PostgreSQL Database (Neon Cloud)                │     │
│  │           Singapore Region (ap-southeast-1)               │     │
│  │                                                           │     │
│  │  ┌──────────┐  ┌──────────────┐  ┌──────────────┐         │     │
│  │  │  Users   │  │ Appointments │  │  Pharmacies  │         │     │
│  │  │  Table   │  │    Table     │  │    Table     │         │     │
│  │  └──────────┘  └──────────────┘  └──────────────┘         │     │
│  │                                                           │     │
│  │  ┌──────────────────┐  ┌──────────────────┐               │     │
│  │  │ Pharmacy Hours   │  │Pharmacy Location │               │     │
│  │  │     Table        │  │  Table (PostGIS) │               │     │
│  │  └──────────────────┘  └──────────────────┘               │     │
│  │                                                           │     │
│  │  Features: UUID, JSONB, Geographic Queries, Transactions  │     │
│  └───────────────────────────────────────────────────────────┘     │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                     OBSERVABILITY LAYER                              │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐          │
│  │   Prometheus   │  │    Grafana     │  │ Elasticsearch  │          │
│  │  (Metrics)     │  │ (Visualization)│  │  (Log Store)   │          │
│  └────────────────┘  └────────────────┘  └────────────────┘          │
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐          │
│  │   Logstash     │  │    Kibana      │  │   Filebeat     │          │
│  │ (Log Pipeline) │  │ (Log Analysis) │  │ (Log Shipper)  │          │
│  └────────────────┘  └────────────────┘  └────────────────┘          │
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐          │
│  │ Node Exporter  │  │   cAdvisor     │  │  PostgreSQL    │          │
│  │ (Host Metrics) │  │(Container Mgmt)│  │   Exporter     │          │
│  └────────────────┘  └────────────────┘  └────────────────┘          │
│                                                                      │
│  ┌────────────────┐                                                  │
│  │     Redis      │                                                  │
│  │   Exporter     │                                                  │
│  └────────────────┘                                                  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                     EXTERNAL SERVICES                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐          │
│  │    Google      │  │   Google Maps  │  │   Firebase     │          │
│  │    OAuth       │  │   Geocoding    │  │   Cloud        │          │
│  └────────────────┘  └────────────────┘  └────────────────┘          │
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐                              │
│  │ Google Environ │  │   Google      │                              │
│  │ mental APIs    │  │   Places      │                              │
│  └────────────────┘  └────────────────┘                              │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Low-Level System Architecture

### Backend Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FastAPI Application                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Middleware Stack                         │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  CORS Middleware                                     │  │     │
│  │  │  - Allow Origins / Credentials                       │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Logging Middleware                                  │  │     │
│  │  │  - Structured Logging (structlog)                    │  │     │
│  │  │  - Request/Response Logging                          │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Error Handler Middleware                            │  │     │
│  │  │  - HTTP Exceptions                                   │  │     │
│  │  │  - Validation Errors                                 │  │     │
│  │  │  - App Exceptions                                    │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   API Router (v1)                          │     │
│  │                   /api/v1                                  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Health Endpoints       (/health)                    │  │     │
│  │  │  - Basic health check                                │  │     │
│  │  │  - Detailed health (DB, Redis status)                │  │     │
│  │  │  - Ping endpoint                                     │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Auth Endpoints         (/auth)                      │  │     │
│  │  │  - POST /firebase/verify                             │  │     │
│  │  │  - POST /refresh                                     │  │     │
│  │  │  - POST /logout                                      │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  User Endpoints         (/users)                     │  │     │
│  │  │  - GET    /me                                        │  │     │
│  │  │  - PATCH  /me                                        │  │     │
│  │  │  - POST   /me/onboard                                │  │     │
│  │  │  - GET    /{user_id}/profile                         │  │     │
│  │  │  - DELETE /me                                        │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Appointment Endpoints  (/appointments)              │  │     │
│  │  │  - POST   /                                          │  │     │
│  │  │  - GET    /                                          │  │     │
│  │  │  - GET    /{id}                                      │  │     │
│  │  │  - PUT    /{id}                                      │  │     │
│  │  │  - PATCH  /{id}/status                               │  │     │
│  │  │  - DELETE /{id}                                      │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Pharmacy Endpoints     (/pharmacies)                │  │     │
│  │  │  - POST   /                                          │  │     │
│  │  │  - GET    /                                          │  │     │
│  │  │  - GET    /search/nearby                             │  │     │
│  │  │  - GET    /{id}                                      │  │     │
│  │  │  - PATCH  /{id}                                      │  │     │
│  │  │  - DELETE /{id}                                      │  │     │
│  │  │  - PATCH  /{id}/location                             │  │     │
│  │  │  - POST   /{id}/hours                                │  │     │
│  │  │  - GET    /{id}/hours                                │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Environmental Endpoints (/environment)              │  │     │
│  │  │  - GET    /conditions                                │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Notification Endpoints (/notifications)             │  │     │
│  │  │  - POST   /register-token                            │  │     │
│  │  │  - POST   /send                                      │  │     │
│  │  │  - POST   /send-batch                                │  │     │
│  │  │  - POST   /admin-send (admin secret key)             │  │     │
│  │  │  - DELETE /deactivate-token                          │  │     │
│  │  │  - DELETE /deactivate-all                            │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Admin Endpoints        (/admin) [ADMIN ROLE]        │  │     │
│  │  │  - GET    /users                (paginated list)     │  │     │
│  │  │  - GET    /appointments         (paginated list)     │  │     │
│  │  │  - GET    /metrics              (system stats)       │  │     │
│  │  │  - GET    /notifications/logs   (notification logs)  │  │     │
│  │  │  - POST   /notifications/broadcast (to all)          │  │     │
│  │  │  - PATCH  /pharmacies/{id}/verify (toggle verified)  │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Service Layer                            │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │     │
│  │  │AuthService   │  │UserService   │  │AppointmentSvc│      │     │
│  │  │              │  │              │  │              │      │     │
│  │  │-verify_token │  │-get_user     │  │-create       │      │     │
│  │  │-create_jwt   │  │-update_user  │  │-list         │      │     │
│  │  │-refresh      │  │-onboard      │  │-update       │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  │                                                            │     │
│  │  ┌──────────────┐  ┌──────────────┐                        │     │
│  │  │PharmacySvc   │  │NotificationSvc│                       │     │
│  │  │              │  │              │                        │     │
│  │  │-create       │  │-register_tkn │                        │     │
│  │  │-search_nearby│  │-send         │                        │     │
│  │  │-get_by_id    │  │-send_batch   │                        │     │
│  │  └──────────────┘  └──────────────┘                        │     │
│  │                                                            │     │
│  │  ┌──────────────┐                                          │     │
│  │  │EnvironmentSvc│                                          │     │
│  │  │              │                                          │     │
│  │  │-get_conditions│                                         │     │
│  │  └──────────────┘                                          │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Core Layer                               │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │     │
│  │  │Security      │  │Redis Cache   │  │Firebase      │      │     │
│  │  │-JWT tokens   │  │-Session mgmt │  │-Admin SDK    │      │     │
│  │  │-Password hash│  │-Rate limiting│  │-Token verify │      │     │
│  │  │-Admin secret │  │              │  │-FCM send     │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  │                                                            │     │
│  │  ┌──────────────┐  ┌──────────────┐                        │     │
│  │  │Exceptions    │  │Config        │                        │     │
│  │  │-Custom errors│  │-Settings     │                        │     │
│  │  └──────────────┘  └──────────────┘                        │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Data Layer                               │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │     │
│  │  │SQLAlchemy    │  │Alembic       │  │Models        │      │     │
│  │  │Core Engine   │  │Migrations    │  │(Table defs)  │      │     │
│  │  │              │  │              │  │              │      │     │
│  │  │-AsyncEngine  │  │-Version ctrl │  │-users        │      │     │
│  │  │-AsyncSession │  │-Auto-migrate │  │-appointments │      │     │
│  │  │-Connection   │  │              │  │-pharmacies   │      │     │
│  │  │ Pool         │  │              │  │-push_tokens  │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Flutter Application Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Flutter Application (Medico24)                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Presentation Layer                       │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │     │
│  │  │  Splash      │  │    Auth      │  │    Home      │      │     │
│  │  │  Screen      │  │   Screens    │  │   Screen     │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  │                                                            │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │     │
│  │  │ Appointments │  │  Pharmacies  │  │   Profile    │      │     │
│  │  │   Screens    │  │   Screens    │  │   Screens    │      │     │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │     │
│  │                                                            │     │
│  │  ┌──────────────┐  ┌──────────────┐                        │     │
│  │  │  Location    │  │Accessibility │                        │     │
│  │  │   Screens    │  │   Features   │                        │     │
│  │  └──────────────┘  └──────────────┘                        │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Routing Layer                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  GoRouter                                            │  │     │
│  │  │  - Named routes                                      │  │     │
│  │  │  - Navigation stack                                  │  │     │
│  │  │  - Deep linking                                      │  │     │
│  │  │  - Route guards                                      │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Core Layer                               │     │
│  │                                                            │     │
│  │  ┌────────────────────────────────────────┐                │     │
│  │  │  API Layer                             │                │     │
│  │  │  ┌──────────────┐  ┌──────────────┐    │                │     │
│  │  │  │ Dio Client   │  │ Interceptors │    │                │     │
│  │  │  │              │  │              │    │                │     │
│  │  │  │ - HTTP Client│  │ - Auth       │    │                │     │
│  │  │  │ - Base URL   │  │ - Logging    │    │                │     │
│  │  │  │ - Timeout    │  │ - Error      │    │                │     │
│  │  │  └──────────────┘  └──────────────┘    │                │     │
│  │  │                                        │                │     │
│  │  │  ┌──────────────────────────────────┐  │                │     │
│  │  │  │  API Services                    │  │                │     │
│  │  │  │  - AuthApiService                │  │                │     │
│  │  │  │  - UserApiService                │  │                │     │
│  │  │  │  - AppointmentApiService         │  │                │     │
│  │  │  │  - PharmacyApiService            │  │                │     │
│  │  │  │  - NotificationApiService        │  │                │     │
│  │  │  └──────────────────────────────────┘  │                │     │
│  │  │                                        │                │     │
│  │  │  ┌──────────────────────────────────┐  │                │     │
│  │  │  │  API Models (DTOs)               │  │                │     │
│  │  │  │  - Request Models                │  │                │     │
│  │  │  │  - Response Models               │  │                │     │
│  │  │  └──────────────────────────────────┘  │                │     │
│  │  └────────────────────────────────────────┘                │     │
│  │                                                            │     │
│  │  ┌────────────────────────────────────────┐                │     │
│  │  │  Services                              │                │     │
│  │  │  - AuthService (Firebase)              │                │     │
│  │  │  - NotificationService (FCM)           │                │     │
│  │  │  - LocationService (GPS)               │                │     │
│  │  │  - GeocodingService (Maps API)         │                │     │
│  │  │  - PlacesService (Places API)          │                │     │
│  │  └────────────────────────────────────────┘                │     │
│  │                                                            │     │
│  │  ┌────────────────────────────────────────┐                │     │
│  │  │  Repositories                          │                │     │
│  │  │  - Data abstraction layer              │                │     │
│  │  │  - Local + Remote data coordination    │                │     │
│  │  └────────────────────────────────────────┘                │     │
│  │                                                            │     │
│  │  ┌────────────────────────────────────────┐                │     │
│  │  │  Database (Local)                      │                │     │
│  │  │  - Offline storage                     │                │     │
│  │  │  - Cache management                    │                │     │
│  │  └────────────────────────────────────────┘                │     │
│  │                                                            │     │
│  │  ┌────────────────────────────────────────┐                │     │
│  │  │  Theme & Styling                       │                │     │
│  │  │  - AppTheme                            │                │     │
│  │  │  - Colors                              │                │     │
│  │  │  - Typography                          │                │     │
│  │  └────────────────────────────────────────┘                │     │
│  │                                                            │     │
│  │  ┌────────────────────────────────────────┐                │     │
│  │  │  Utils                                 │                │     │
│  │  │  - Constants                           │                │     │
│  │  │  - Validators                          │                │     │
│  │  │  - Helpers                             │                │     │
│  │  └────────────────────────────────────────┘                │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   Service Locator                          │     │
│  │  - Dependency Injection                                    │     │
│  │  - Singleton Management                                    │     │
│  │  - Service Registration                                    │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    External Integrations                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │   Firebase   │  │ Google Maps  │  │    Backend   │               │
│  │     Auth     │  │     SDK      │  │     API      │               │
│  │              │  │              │  │              │               │
│  │ - Google Sign│  │ - Geocoding  │  │ - REST API   │               │
│  │   In         │  │ - Places     │  │ - WebSocket  │               │
│  │ - ID Tokens  │  │ - Maps       │  │   (Future)   │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Observability & Monitoring

### Architecture Overview

**Medico24** implements a comprehensive observability stack for monitoring, logging, and metrics collection. All observability components are containerized using Docker Compose with profile-based orchestration.

**Location:** `medico24-observability/`

**Configuration:** Environment-based using `.env` file

### Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY STACK                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   MONITORING (Profile)                     │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Prometheus (Port: 9090)                             │  │     │
│  │  │  - Metrics collection & storage                      │  │     │
│  │  │  - Time-series database                              │  │     │
│  │  │  - Scrape interval: 15s                              │  │     │
│  │  │  - Retention: 30d                                    │  │     │
│  │  │  - Targets:                                          │  │     │
│  │  │    • Backend API (host.docker.internal:8000)         │  │     │
│  │  │    • PostgreSQL Exporter                             │  │     │
│  │  │    • Redis Exporter                                  │  │     │
│  │  │    • Node Exporter                                   │  │     │
│  │  │    • cAdvisor                                        │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Grafana (Port: 3001)                                │  │     │
│  │  │  - Visualization & dashboards                        │  │     │
│  │  │  - Data source: Prometheus                           │  │     │
│  │  │  - Anonymous access: disabled                        │  │     │
│  │  │  - Default credentials: admin/admin                  │  │     │
│  │  │  - Dashboards:                                       │  │     │
│  │  │    • Backend API Metrics                             │  │     │
│  │  │    • Database Performance                            │  │     │
│  │  │    • Redis Performance                               │  │     │
│  │  │    • Container Metrics                               │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   LOGGING (Profile)                        │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Elasticsearch (Port: 9200)                          │  │     │
│  │  │  - Log storage & indexing                            │  │     │
│  │  │  - Full-text search engine                           │  │     │
│  │  │  - Index lifecycle management                        │  │     │
│  │  │  - Retention: 30 days                                │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Logstash (Port: 5044, 9600)                         │  │     │
│  │  │  - Log processing pipeline                           │  │     │
│  │  │  - Data transformation & enrichment                  │  │     │
│  │  │  - Input: Filebeat                                   │  │     │
│  │  │  - Output: Elasticsearch                             │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Kibana (Port: 5601)                                 │  │     │
│  │  │  - Log visualization & analysis                      │  │     │
│  │  │  - Search interface                                  │  │     │
│  │  │  - Log pattern detection                             │  │     │
│  │  │  - Dashboards & alerts                               │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Filebeat                                            │  │     │
│  │  │  - Log shipping agent                                │  │     │
│  │  │  - Monitors: /var/lib/docker/containers/*.log        │  │     │
│  │  │  - Multiline support for stack traces                │  │     │
│  │  │  - Output: Logstash                                  │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                   EXPORTERS (Profile)                      │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  PostgreSQL Exporter (Port: 9187)                    │  │     │
│  │  │  - Database metrics collection                       │  │     │
│  │  │  - Connected to: Neon PostgreSQL (Singapore)         │  │     │
│  │  │  - Metrics:                                          │  │     │
│  │  │    • Connection pool stats                           │  │     │
│  │  │    • Query performance                               │  │     │
│  │  │    • Table statistics                                │  │     │
│  │  │    • Replication lag                                 │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Redis Exporter (Port: 9121)                         │  │     │
│  │  │  - Cache metrics collection                          │  │     │
│  │  │  - Connected to: Redis Labs (Mumbai)                 │  │     │
│  │  │  - Metrics:                                          │  │     │
│  │  │    • Memory usage                                    │  │     │
│  │  │    • Hit/miss ratio                                  │  │     │
│  │  │    • Connected clients                               │  │     │
│  │  │    • Key eviction rate                               │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  Node Exporter (Port: 9100)                          │  │     │
│  │  │  - Host system metrics                               │  │     │
│  │  │  - Metrics:                                          │  │     │
│  │  │    • CPU usage                                       │  │     │
│  │  │    • Memory usage                                    │  │     │
│  │  │    • Disk I/O                                        │  │     │
│  │  │    • Network statistics                              │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  │                                                            │     │
│  │  ┌──────────────────────────────────────────────────────┐  │     │
│  │  │  cAdvisor (Port: 8080)                               │  │     │
│  │  │  - Container metrics                                 │  │     │
│  │  │  - Metrics:                                          │  │     │
│  │  │    • Container CPU/memory usage                      │  │     │
│  │  │    • Network traffic                                 │  │     │
│  │  │    • Disk usage                                      │  │     │
│  │  │    • Container lifecycle events                      │  │     │
│  │  └──────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────┘     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Backend Metrics Integration

The FastAPI backend exposes Prometheus metrics at `/metrics` endpoint using `prometheus-fastapi-instrumentator`:

**Metrics Exposed:**
- HTTP request count by method, path, status
- Request duration histogram
- Request size histogram
- Response size histogram
- Active requests gauge
- Python process metrics (CPU, memory, threads)
- Custom business metrics

**Configuration:**
```python
# app/main.py
Instrumentator(
    excluded_handlers=["/docs", "/redoc", "/openapi.json"],
    should_group_status_codes=True,
    should_ignore_untemplated=True,
    should_respect_env_var=False,  # Always enabled
    should_instrument_requests_inprogress=True,
).instrument(app).expose(app, endpoint="/metrics", include_in_schema=True)
```

### Cloud Service Monitoring

**Neon PostgreSQL (Singapore - ap-southeast-1)**
- Connection: SSL required
- Monitoring via PostgreSQL Exporter
- Connection pooling enabled
- Metrics: Query performance, connection stats, table sizes

**Redis Labs (Mumbai - ap-south-1)**
- Connection: Password-protected
- Monitoring via Redis Exporter
- Metrics: Cache hit/miss, memory usage, eviction rate

### Docker Compose Profiles

The observability stack uses Docker Compose profiles for selective service deployment:

```bash
# Start all services
docker compose --profile all up -d

# Start only monitoring (Prometheus + Grafana)
docker compose --profile monitoring up -d

# Start only logging (ELK stack)
docker compose --profile logging up -d

# Start only exporters
docker compose --profile exporters up -d

# Start monitoring + exporters
docker compose --profile monitoring --profile exporters up -d
```

### Environment Configuration

All services configured via `.env` file:

```env
# Backend Configuration
BACKEND_URL=http://localhost:8000

# Prometheus Configuration
PROMETHEUS_RETENTION_TIME=30d
PROMETHEUS_SCRAPE_INTERVAL=15s

# Grafana Configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
GRAFANA_PORT=3001

# Elasticsearch Configuration
ELASTICSEARCH_HEAP_SIZE=1g
ELASTICSEARCH_PORT=9200

# Log Retention
LOG_RETENTION_DAYS=30

# Cloud Database Monitoring
POSTGRES_DATA_SOURCE_NAME=postgresql://username:password@your-neon-host.aws.neon.tech/dbname?sslmode=require

# Cloud Redis Monitoring
REDIS_ADDR=redis://username:password@your-redis-host.cloud.redislabs.com:port
```

### Networking

**Docker → Host Communication:**
- Uses `host.docker.internal` for containers to access services running on host machine
- Backend scraping: `host.docker.internal:8000`
- Configured via `extra_hosts` in docker-compose.yml

**Service Ports:**
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3001`
- Elasticsearch: `http://localhost:9200`
- Kibana: `http://localhost:5601`
- Backend Metrics: `http://localhost:8000/metrics`

### Operations

**Health Checks:**
- Prometheus: `/-/ready`
- Grafana: `/api/health`
- Elasticsearch: `/_cluster/health`
- Kibana: `/api/status`

**Data Persistence:**
- Prometheus: `./volumes/prometheus`
- Grafana: `./volumes/grafana`
- Elasticsearch: `./volumes/elasticsearch`

**Restart Policy:** `no` (manual control for development)

### Monitoring Dashboards

**Grafana Default Dashboards:**
1. **Backend API Performance**
   - Request rate & latency
   - Error rate by endpoint
   - Response size distribution
   - Active requests

2. **Database Metrics**
   - Connection pool usage
   - Query execution time
   - Table sizes & growth
   - Slow queries

3. **Cache Performance**
   - Redis hit/miss ratio
   - Memory utilization
   - Key eviction rate
   - Connected clients

4. **Infrastructure**
   - Host CPU/Memory/Disk
   - Container resource usage
   - Network traffic
   - Docker container health

---

## Component Diagrams

### Authentication Flow

```
┌───────────┐                ┌───────────┐                ┌───────────┐
│  Flutter  │                │  Backend  │                │ Firebase  │
│    App    │                │    API    │                │   Auth    │
└─────┬─────┘                └─────┬─────┘                └─────┬─────┘
      │                            │                            │
      │ 1. User taps "Sign in      │                            │
      │    with Google"            │                            │
      ├────────────────────────────────────────────────────────>│
      │                            │   2. Google Sign-In Flow   │
      │                            │      (OAuth 2.0)           │
      │<────────────────────────────────────────────────────────┤
      │  3. Firebase ID Token      │                            │
      │                            │                            │
      │ 4. POST /auth/firebase/verify                           │
      │    {id_token: "..."}       │                            │
      ├───────────────────────────>│                            │
      │                            │ 5. Verify ID Token         │
      │                            ├───────────────────────────>│
      │                            │                            │
      │                            │<───────────────────────────┤
      │                            │ 6. Token Valid + User Info │
      │                            │                            │
      │                            │ 7. Check user in DB        │
      │                            │    (Create if new)         │
      │                            │                            │
      │                            │ 8. Generate JWT Tokens     │
      │                            │    - Access Token          │
      │                            │    - Refresh Token         │
      │                            │                            │
      │<───────────────────────────┤                            │
      │  9. Return tokens + user   │                            │
      │     {access_token,         │                            │
      │      refresh_token,        │                            │
      │      user: {...}}          │                            │
      │                            │                            │
      │ 10. Store tokens locally   │                            │
      │     (Secure Storage)       │                            │
      │                            │                            │
      │ 11. Navigate to Home       │                            │
      │                            │                            │
```

### Appointment Booking Flow

```
┌───────────┐                ┌───────────┐                ┌───────────┐
│  Flutter  │                │  Backend  │                │PostgreSQL │
│    App    │                │    API    │                │  Database │
└─────┬─────┘                └─────┬─────┘                └─────┬─────┘
      │                            │                            │
      │ 1. User fills appointment  │                            │
      │    booking form            │                            │
      │                            │                            │
      │ 2. POST /appointments/     │                            │
      │    Authorization: Bearer   │                            │
      │    {doctor_name,           │                            │
      │     appointment_at,        │                            │
      │     reason, ...}           │                            │
      ├───────────────────────────>│                            │
      │                            │ 3. Validate JWT Token      │
      │                            │    (Auth Interceptor)      │
      │                            │                            │
      │                            │ 4. Validate Request        │
      │                            │    (Pydantic Schema)       │
      │                            │                            │
      │                            │ 5. INSERT appointment      │
      │                            ├───────────────────────────>│
      │                            │                            │
      │                            │<───────────────────────────┤
      │                            │ 6. Appointment Created     │
      │                            │    (with UUID)             │
      │                            │                            │
      │<───────────────────────────┤                            │
      │  7. Return appointment     │                            │
      │     {id, status,           │                            │
      │      appointment_at, ...}  │                            │
      │                            │                            │
      │ 8. Show success message    │                            │
      │    Navigate to details     │                            │
      │                            │                            │
```

### Pharmacy Search Flow

```
┌───────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐
│  Flutter  │     │  Backend  │     │PostgreSQL │     │  Google   │
│    App    │     │    API    │     │ (PostGIS) │     │   Maps    │
└─────┬─────┘     └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
      │                 │                 │                 │
      │ 1. Get User     │                 │                 │
      │    Location     │                 │                 │
      ├────────────────────────────────────────────────────>│
      │                 │                 │ 2. GPS Coords   │
      │<────────────────────────────────────────────────────┤
      │  (lat, lng)     │                 │                 │
      │                 │                 │                 │
      │ 3. GET /pharmacies/search/nearby  │                 │
      │    ?latitude=X&longitude=Y        │                 │
      │    &radius_km=10                  │                 │
      ├────────────────>│                 │                 │
      │                 │ 4. PostGIS Query│                 │
      │                 │ ST_DWithin(     │                 │
      │                 │   location,     │                 │
      │                 │   point(X,Y),   │                 │
      │                 │   10000)        │                 │
      │                 ├────────────────>│                 │
      │                 │                 │                 │
      │                 │<────────────────┤                 │
      │                 │ 5. Pharmacies   │                 │
      │                 │    (with distance)                │
      │                 │                 │                 │
      │<────────────────┤                 │                 │
      │  6. Pharmacy list                 │                 │
      │     [{ name, address,             │                 │
      │        distance_km, ... }]        │                 │
      │                 │                 │                 │
      │ 7. Display on   │                 │                 │
      │    map/list     │                 │                 │
      │                 │                 │                 │
```

---

## Data Flow Diagrams

### User Registration & Profile Creation

```
Start
  │
  ├─> User initiates Google Sign-In
  │
  ├─> Firebase authenticates via Google OAuth
  │
  ├─> Firebase returns ID Token
  │
  ├─> App sends ID Token to Backend
  │
  ├─> Backend verifies token with Firebase Admin SDK
  │
  ├─> Backend checks if user exists (by firebase_uid)
  │
  ├─> If NEW user:
  │   ├─> Extract user info from token
  │   ├─> INSERT into users table
  │   │   - firebase_uid (unique)
  │   │   - email
  │   │   - full_name
  │   │   - photo_url
  │   │   - is_onboarded = false
  │   │   - role = 'patient'
  │   └─> Create user record
  │
  ├─> If EXISTING user:
  │   ├─> SELECT user from database
  │   └─> UPDATE last_login_at
  │
  ├─> Generate JWT tokens
  │   ├─> Access Token (30 min expiry)
  │   └─> Refresh Token (7 day expiry)
  │
  ├─> Store refresh token in Redis
  │
  ├─> Return to app:
  │   - Access Token
  │   - Refresh Token
  │   - User Profile
  │
  ├─> App stores tokens in secure storage
  │
  └─> Navigate to appropriate screen
      - If is_onboarded = false → Onboarding
      - If is_onboarded = true → Home
```

### Appointment Management

```
CREATE APPOINTMENT
  │
  ├─> User fills form (doctor, date, reason)
  │
  ├─> App validates inputs
  │
  ├─> POST /api/v1/appointments/
  │
  ├─> Backend validates JWT
  │
  ├─> Backend validates schema
  │
  ├─> INSERT into appointments
  │   - patient_id = current_user.id
  │   - status = 'scheduled'
  │   - appointment_at
  │   - doctor_name, reason, etc.
  │
  ├─> Return appointment object
  │
  └─> App navigates to appointment details

UPDATE APPOINTMENT STATUS
  │
  ├─> User cancels/confirms appointment
  │
  ├─> PATCH /api/v1/appointments/{id}/status
  │   {status: "cancelled"}
  │
  ├─> Backend validates ownership
  │   (patient_id == current_user.id)
  │
  ├─> UPDATE appointments SET
  │   - status = 'cancelled'
  │   - cancelled_at = NOW()
  │
  ├─> Return updated appointment
  │
  └─> App updates UI
```

### Admin Dashboard Management

```
ADMIN LOGIN
  │
  ├─> Admin logs in via Google (Firebase)
  │
  ├─> POST /auth/firebase/verify
  │
  ├─> Backend checks user.role == 'admin'
  │
  ├─> Returns JWT tokens
  │
  ├─> Web app stores in localStorage + cookies
  │
  └─> Navigate to admin dashboard

DASHBOARD - VIEW METRICS
  │
  ├─> GET /admin/metrics (with JWT token)
  │
  ├─> Backend validates admin role
  │
  ├─> Query aggregated statistics:
  │   - Total users, active users, users by role
  │   - Total appointments, by status
  │   - Total pharmacies, verified, active
  │   - Notifications sent (today/week/month)
  │
  ├─> Return metrics object
  │
  └─> Dashboard displays cards & charts

MANAGE USERS
  │
  ├─> GET /admin/users?page=1&page_size=20&role=patient
  │
  ├─> Backend validates admin role
  │
  ├─> SELECT users with pagination
  │   - Filter by role, is_active
  │   - Order by created_at DESC
  │
  ├─> Return paginated user list
  │
  └─> Display in data table with filters

BROADCAST NOTIFICATION
  │
  ├─> Admin fills broadcast form
  │   - Target: all | patients | pharmacies
  │   - Title, body, data
  │
  ├─> POST /admin/notifications/broadcast
  │
  ├─> Backend validates admin role
  │
  ├─> Query active users by target:
  │   - all: WHERE is_active = true
  │   - patients: WHERE role = 'patient' AND is_active = true
  │   - pharmacies: WHERE role = 'pharmacy' AND is_active = true
  │
  ├─> Get FCM tokens for all target users
  │
  ├─> Send multicast message via Firebase FCM
  │
  ├─> INSERT notification records for audit
  │
  ├─> Return success/failure counts
  │
  └─> Display result toast notification

VERIFY PHARMACY
  │
  ├─> Admin clicks verify toggle
  │
  ├─> PATCH /admin/pharmacies/{id}/verify
  │
  ├─> Backend validates admin role
  │
  ├─> UPDATE pharmacies SET
  │   - is_verified = !is_verified
  │   - updated_at = NOW()
  │
  ├─> Invalidate pharmacy cache in Redis
  │
  ├─> Return updated pharmacy object
  │
  └─> UI updates verification badge
```

---

## Testing Infrastructure

### Backend Testing Strategy

```
Test Organization
  │
  ├─> Unit Tests (tests/)
  │   ├─> test_admin.py (19 tests)
  │   │   - Admin user listing (pagination, filters)
  │   │   - Admin appointment listing
  │   │   - System metrics aggregation
  │   │   - Notification logs
  │   │   - Broadcast notifications
  │   │   - Pharmacy verification
  │   │   - Authorization checks (403 for non-admin)
  │   │
  │   ├─> test_auth.py (planned)
  │   │   - Firebase token verification
  │   │   - JWT token generation
  │   │   - Token refresh flow
  │   │
  │   ├─> test_appointments.py (planned)
  │   │   - CRUD operations
  │   │   - Ownership validation
  │   │   - Status updates
  │   │
  │   └─> test_pharmacies.py (planned)
  │       - Pharmacy creation
  │       - Nearby search (PostGIS)
  │       - Hours management
  │
  ├─> Fixtures (tests/conftest.py)
  │   ├─> test_db - Test database session
  │   ├─> client - Async HTTP test client
  │   ├─> test_user - Regular user fixture
  │   ├─> test_admin_user - Admin user fixture
  │   ├─> admin_token - Admin JWT token
  │   ├─> patient_token - Patient JWT token
  │   ├─> test_pharmacy_id - Pharmacy fixture
  │   └─> auth_headers - Authorization headers
  │
  ├─> Test Configuration
  │   ├─> pytest.ini - Pytest settings
  │   ├─> .coveragerc - Coverage config
  │   └─> asyncio mode for async tests
  │
  └─> Test Execution
      ├─> pytest tests/ -v (verbose)
      ├─> pytest tests/test_admin.py (specific file)
      ├─> pytest --cov=app (with coverage)
      └─> Current coverage: 50%

Test Results (Admin Endpoints)
  ├─> 19/19 tests passing ✅
  ├─> Coverage areas:
  │   - Authorization enforcement
  │   - Pagination logic
  │   - Filtering (role, status, is_active)
  │   - Metrics aggregation
  │   - Notification broadcasting
  │   - Cache invalidation
  └─> All critical paths validated
```

### Code Quality Tools

```
Pre-commit Hooks (.pre-commit-config.yaml)
  │
  ├─> Formatting & Style
  │   ├─> black - Code formatting
  │   ├─> ruff - Fast Python linter
  │   ├─> ruff-format - Ruff formatter
  │   ├─> isort - Import sorting
  │   └─> prettier - Frontend formatting
  │
  ├─> Code Quality
  │   ├─> check-yaml - YAML validation
  │   ├─> check-json - JSON validation
  │   ├─> check-toml - TOML validation
  │   ├─> check-ast - Python AST validation
  │   └─> check-docstring-first - Docstring position
  │
  ├─> Security
  │   ├─> bandit - Security vulnerability scanner
  │   ├─> detect-secrets - Secret detection
  │   └─> check-added-large-files - Prevent large commits
  │
  └─> Best Practices
      ├─> trim-trailing-whitespace
      ├─> fix-end-of-files
      ├─> check-merge-conflicts
      └─> mixed-line-ending
```

---

## Data Flow Diagrams

### Frontend (Flutter Application)

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Framework | Flutter | 3.x | Cross-platform mobile development |
| Language | Dart | 3.x | Programming language |
| State Management | Provider/Riverpod | Latest | State management (to be confirmed) |
| Routing | GoRouter | Latest | Declarative routing |
| HTTP Client | Dio | Latest | Network requests |
| Authentication | Firebase Auth | Latest | User authentication |
| Maps | Google Maps Flutter | Latest | Map display & location |
| Local Storage | Shared Preferences | Latest | Key-value storage |
| Secure Storage | Flutter Secure Storage | Latest | Token storage |

### Frontend (Next.js Web Dashboard)

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Framework | Next.js | 16.0.10 | React framework with App Router |
| Language | TypeScript | Latest | Type-safe JavaScript |
| UI Library | React | 19 | User interface library |
| Styling | Tailwind CSS | v4 | Utility-first CSS |
| Component Library | shadcn/ui | Latest | Accessible component system |
| State Management | React Query (TanStack Query) | Latest | Server state management |
| HTTP Client | Fetch API | Native | Network requests |
| Maps | Google Maps JavaScript API | Latest | Interactive maps |
| Authentication | Firebase Auth | Latest | User authentication (Google Sign-In) |

### Backend (FastAPI Server)

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Framework | FastAPI | Latest | Web framework |
| Language | Python | 3.14 | Programming language |
| ASGI Server | Uvicorn | Latest | Production server |
| Database | SQLAlchemy Core | 2.x | Database toolkit (not ORM) |
| Migration | Alembic | Latest | Database migrations |
| Validation | Pydantic | 2.x | Data validation |
| Authentication | Firebase Admin SDK | Latest | Token verification |
| JWT | PyJWT | Latest | JWT token generation |
| Password Hashing | Passlib + Bcrypt | Latest | Secure password storage |
| Logging | Structlog | Latest | Structured logging |
| Metrics | prometheus-fastapi-instrumentator | Latest | Prometheus metrics export |
| Testing | Pytest | Latest | Unit & integration tests |
| Async Testing | pytest-asyncio | Latest | Async test support |
| Test Client | httpx | Latest | Async HTTP client for tests |
| Code Quality | Ruff | Latest | Linting & formatting |
| Code Formatting | Black | Latest | Python code formatter |
| Security Scanning | Bandit | Latest | Security vulnerability scanner |
| Pre-commit Hooks | pre-commit | Latest | Git hook framework |

### Database & Storage

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Primary DB | PostgreSQL (Neon) | 15+ | Cloud-hosted relational database (Singapore region) |
| Geographic Ext | PostGIS | 3.x | Geographic queries |
| Cache | Redis Labs | 7.x | Cloud-hosted cache & session store (Mumbai region) |
| Session Store | Redis Labs | 7.x | Refresh token storage with TTL |
| Pharmacy Cache | Redis Labs | 7.x | Pharmacy data caching (TTL: 1 hour) |
| User Cache | Redis Labs | 7.x | User profile caching (TTL: 30 min) |
|---------|----------|---------|
| Authentication | Firebase Auth | OAuth & identity |
| Geocoding | Google Maps API | Address to coordinates |
| Places | Google Places API | Location search |
| Maps | Google Maps SDK | Map rendering |
| Cloud Messaging | Firebase FCM | Push notifications (✅ Implemented) |
| Environmental | Google Air Quality & Weather APIs | Real-time AQI and weather data |

### DevOps & Infrastructure

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Containerization | Docker | Application packaging |
| Orchestration | Docker Compose | Multi-service development with profiles |
| CI/CD | GitHub Actions | Automated testing/deployment |
| Metrics Collection | Prometheus | Time-series metrics database |
| Visualization | Grafana | Monitoring dashboards & alerts |
| Log Storage | Elasticsearch | Centralized log indexing & search |
| Log Processing | Logstash | Log aggregation & transformation |
| Log Analysis | Kibana | Log visualization & analysis |
| Log Shipping | Filebeat | Container log forwarding |
| Database Exporter | PostgreSQL Exporter | Neon PostgreSQL metrics |
| Cache Exporter | Redis Exporter | Redis Labs metrics |
| Host Metrics | Node Exporter | System resource monitoring |
| Container Metrics | cAdvisor | Docker container monitoring |
## Infrastructure

### Development Environment

```
┌─────────────────────────────────────────────────────────────────┐
│                      Developer Machine                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   Flutter   │  │  Next.js    │  │   Python    │              │
│  │   Mobile    │  │  Admin      │  │   Backend   │              │
│  │             │  │  Web        │  │             │              │
│  │  Port: N/A  │  │  Port: 3000 │  │  Port: 8000 │              │
│  └─────────────┘  └─────────────┘  └──────┬──────┘              │
│                                           │                     │
│                                           │                     │
│  ┌─────────────────────┐      ┌───────────▼───────┐             │
│  │ PostgreSQL (Cloud)  │      │  Redis Labs       │             │
│  │  Neon - Singapore   │      │  Mumbai Region    │             │
│  │  ap-southeast-1     │      │  ap-south-1       │             │
│  │  Port: 5432 (SSL)   │      │  Port: 11701      │             │
│  └─────────────────────┘      └───────────────────┘             │
│                                                                 │
│  Environment: .env files                                        │
│  - DATABASE_URL (Neon connection string)                        │
│  - REDIS_URL (Redis Labs connection string)                     │
│  - FIREBASE_CREDENTIALS_PATH                                    │
│  - JWT_SECRET_KEY, JWT_REFRESH_SECRET_KEY                       │
│  - ADMIN_SECRET_KEY                                             │
│  - GOOGLE_MAPS_API_KEY                                          │
│                                                                 │
│  Backend: http://localhost:8000                                 │
│  Admin Web: http://localhost:3000                               │
│  API Docs: http://localhost:8000/docs                           │
│                                                                 │
│  Observability Stack (Docker Compose):                          │
│  - Prometheus: http://localhost:9090                            │
│  - Grafana: http://localhost:3001                               │
│  - Elasticsearch: http://localhost:9200                         │
│  - Kibana: http://localhost:5601                                │
│  - Backend Metrics: /metrics endpoint                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Production Environment (Proposed)

```
┌─────────────────────────────────────────────────────────┐
│                    Cloud Provider (AWS/GCP)             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │         Load Balancer / CDN                    │     │
│  │         (NGINX / CloudFlare)                   │     │
│  └──────────────────┬─────────────────────────────┘     │
│                     │                                   │
│         ┌───────────┼───────────┐                       │
│         │           │           │                       │
│  ┌──────▼──┐  ┌─────▼────┐  ┌──▼──────┐                 │
│  │ Backend │  │ Backend  │  │ Backend │                 │
│  │ Server 1│  │ Server 2 │  │ Server N│                 │
│  │ (Docker)│  │ (Docker) │  │ (Docker)│                 │
│  └────┬────┘  └────┬─────┘  └────┬────┘                 │
│       │            │             │                      │
│       └────────────┼─────────────┘                      │
│                    │                                    │
│       ┌────────────┼────────────┐                       │
│       │            │            │                       │
│  ┌────▼─────┐  ┌──▼───────┐  ┌─▼───────┐                │
│  │PostgreSQL│  │  Redis   │  │Firebase │                │
│  │   Neon   │  │  Labs    │  │  Auth   │                │
│  │ (Cloud)  │  │ (Cloud)  │  │         │                │
│  └────┬─────┘  └──────────┘  └─────────┘                │
│       │                                                 │
│  ┌────▼─────┐                                           │
│  │PostgreSQL│                                           │
│  │  Replica │                                           │
│  │  (Neon)  │                                           │
│  └──────────┘                                           │
│                                                         │
│  ┌──────────────────────────────────────┐               │
│  │    Monitoring & Logging              │               │
│  │    - Prometheus (metrics)            │               │
│  │    - Grafana (dashboards)            │               │
│  │    - ELK Stack (centralized logs)    │               │
│  │    - Exporters (DB, cache, host)     │               │
│  └──────────────────────────────────────┘               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Database Schema

```
┌─────────────────┐         ┌──────────────────┐
│     users       │         │   appointments   │
├─────────────────┤         ├──────────────────┤
│ id (UUID) PK    │         │ id (UUID) PK     │
│ firebase_uid    │────┐    │ patient_id (FK)  │
│ email           │    │    │ doctor_id (FK)   │
│ email_verified  │    │    │ clinic_id        │
│ full_name       │    │    │ doctor_name      │
│ given_name      │    │    │ clinic_name      │
│ family_name     │    │    │ appointment_at   │
│ photo_url       │    │    │ appointment_end  │
│ phone           │    │    │ reason           │
│ role            │    │    │ contact_phone    │
│ is_active       │    │    │ status           │
│ is_onboarded    │    │    │ notes            │
│ created_at      │    │    │ source           │
│ updated_at      │    │    │ created_at       │
│ last_login_at   │    │    │ updated_at       │
└─────────────────┘    │    │ cancelled_at     │
                       │    │ deleted_at       │
                       │    └──────────────────┘
                       │
                       └────(one-to-many)

┌─────────────────────┐      ┌─────────────────────┐
│    pharmacies       │      │ pharmacy_locations  │
├─────────────────────┤      ├─────────────────────┤
│ id (UUID) PK        │──────│ id (UUID) PK        │
│ name                │      │ pharmacy_id (FK)    │
│ description         │      │ address_line        │
│ phone               │      │ city                │
│ email               │      │ state               │
│ is_verified         │      │ country             │
│ is_active           │      │ pincode             │
│ rating              │      │ latitude            │
│ rating_count        │      │ longitude           │
│ supports_delivery   │      │ geo (GEOGRAPHY)     │
│ supports_pickup     │      │ created_at          │
│ created_at          │      └─────────────────────┘
│ updated_at          │
└─────────────────────┘      ┌─────────────────────┐
         │                   │  pharmacy_hours     │
         │                   ├─────────────────────┤
         └───────────────────│ id (UUID) PK        │
                             │ pharmacy_id (FK)    │
                             │ day_of_week         │
                             │ open_time           │
                             │ close_time          │
                             │ is_closed           │
                             └─────────────────────┘
```

---

## Security Architecture

### Authentication & Authorization

```
┌──────────────────────────────────────────────────────────┐
│                   Security Layers                        │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Layer 1: Firebase Authentication                        │
│  ┌────────────────────────────────────────────────┐      │
│  │  - Google OAuth 2.0                            │      │
│  │  - Email verification                          │      │
│  │  - Firebase ID Tokens (1 hour expiry)          │      │
│  │  - Token refresh handled by Firebase SDK       │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  Layer 2: Backend JWT Tokens                             │
│  ┌────────────────────────────────────────────────┐      │
│  │  - Access Token (30 min expiry)                │      │
│  │  - Refresh Token (7 day expiry)                │      │
│  │  - HS256 algorithm                             │      │
│  │  - Signed with JWT_SECRET_KEY                  │      │
│  │  - Refresh token signed with separate key      │      │
│  │  - Payload: {sub: user_id, exp: timestamp}     │      │
│  │  - Clock skew tolerance: 10 seconds            │      │
│  │  - Stored in: localStorage + cookies (web)     │      │
│  │  - Stored in: Secure Storage (mobile)          │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  Layer 3: Role-Based Access Control (RBAC)               │
│  ┌────────────────────────────────────────────────┐      │
│  │  Roles:                                        │      │
│  │  - patient (default for new users)             │      │
│  │  - doctor (future)                             │      │
│  │  - admin (manual DB assignment)                │      │
│  │                                                │      │
│  │  Permission Enforcement:                       │      │
│  │  - require_admin() dependency checks role      │      │
│  │  - Returns 403 Forbidden if not admin          │      │
│  │  - Used by all /admin/* endpoints              │      │
│  │                                                │      │
│  │  Admin Endpoints Protected:                    │      │
│  │  - /admin/users                                │      │
│  │  - /admin/appointments                         │      │
│  │  - /admin/metrics                              │      │
│  │  - /admin/notifications/*                      │      │
│  │  - /admin/pharmacies/{id}/verify               │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  Layer 4: Resource Ownership Validation                  │
│  ┌────────────────────────────────────────────────┐      │
│  │  - Users can only access their own data        │      │
│  │  - Appointments: patient_id == current_user.id │      │
│  │  - Profile: user_id == current_user.id         │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  Layer 5: Input Validation                               │
│  ┌────────────────────────────────────────────────┐      │
│  │  - Pydantic schema validation                  │      │
│  │  - Type checking                               │      │
│  │  - SQL injection prevention (parameterized)    │      │
│  │  - XSS prevention (escaped outputs)            │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  Layer 6: Rate Limiting                                  │
│  ┌────────────────────────────────────────────────┐      │
│  │  - Redis-based rate limiting                   │      │
│  │  - 60 requests/minute per IP                   │      │
│  │  - Configurable per endpoint                   │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
│  Layer 7: HTTPS/TLS                                      │
│  ┌────────────────────────────────────────────────┐      │
│  │  - All communication encrypted                 │      │
│  │  - TLS 1.2+ only                               │      │
│  │  - Certificate pinning (mobile app)            │      │
│  └────────────────────────────────────────────────┘      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Data Protection

- **At Rest**: PostgreSQL encryption, secure backups
- **In Transit**: TLS/HTTPS for all API calls
- **Sensitive Data**: 
  - Passwords: Not stored (Firebase handles)
  - Tokens: Stored in Redis with TTL
  - PII: Encrypted in mobile secure storage

### Compliance Considerations

- **HIPAA**: Healthcare data handling (future compliance)
- **GDPR**: User data privacy, right to deletion
- **Data Retention**: Soft deletes with deleted_at timestamp

---

## Performance Considerations

### Caching Strategy

- **Redis Labs (Cloud - Mumbai Region)**: 
  - User sessions (refresh tokens with TTL)
  - Frequently accessed data (pharmacy, user profiles)
  - Rate limiting counters
  - Automatic failover & persistence
  - Connection pooling enabled
  
### Database Optimization

- **Neon PostgreSQL (Cloud - Singapore Region)**:
  - Serverless autoscaling
  - Automatic connection pooling
  - Point-in-time recovery (PITR)
  - Auto-suspend on idle
  
- **Indexes**: 
  - firebase_uid, email (users)
  - patient_id, status, appointment_at (appointments)
  - latitude/longitude (pharmacy_locations - PostGIS)
  
- **Connection Pooling**: 
  - Neon built-in pooler (PgBouncer)
  - Pool size: 10
  - Max overflow: 20
  - Pool recycle: 3600s

### API Performance

- **Pagination**: All list endpoints (default: 20 items)
- **Field Selection**: Future optimization
- **Query Optimization**: N+1 prevention with joins

---

## Scalability

### Horizontal Scaling

- Stateless API servers (can add more instances)
- Load balancer distribution
- Neon PostgreSQL: Automatic read replicas
- Redis Labs: Cluster mode for higher throughput

### Vertical Scaling

- Neon PostgreSQL: Automatic compute scaling based on load
- Redis Labs: Seamless instance upgrades
- Backend: Container orchestration (Kubernetes future)

---

## Cloud Infrastructure

### Neon PostgreSQL (Primary Database)

**Region:** Singapore (ap-southeast-1)  
**Plan:** Cloud-hosted serverless PostgreSQL  
**Features:**
- Serverless compute with autoscaling
- Branch-based development workflows
- Automatic connection pooling (PgBouncer)
- Point-in-time recovery (PITR)
- Auto-suspend when idle
- SSL/TLS encryption enforced
- PostGIS extension enabled

**Connection:**
```
postgresql://username:password@your-neon-host.aws.neon.tech/dbname?sslmode=require
```

**Monitoring:**
- PostgreSQL Exporter (Prometheus)
- Neon web console metrics
- Custom Grafana dashboards

### Redis Labs (Cache & Session Store)

**Region:** Mumbai (ap-south-1)  
**Plan:** Cloud-hosted managed Redis  
**Features:**
- Automatic failover & high availability
- Data persistence (AOF + RDB)
- SSL/TLS encryption
- Automatic backups
- Memory optimization
- Eviction policies configured

**Connection:**
```
redis://username:password@your-redis-host.cloud.redislabs.com:port
```

**Monitoring:**
- Redis Exporter (Prometheus)
- Redis Labs web console
- Custom Grafana dashboards

### Network Architecture

**Regional Distribution:**
- **Backend Server:** Host machine (local development) / Cloud deployment (production)
- **Database:** Singapore (low latency for APAC users)
- **Cache:** Mumbai (centrally located for Indian market)
- **Observability:** Local Docker containers (development) / Cloud deployment (production)

**Latency Considerations:**
- Backend to Database: ~10-50ms (cross-region)
- Backend to Cache: ~20-100ms (cross-region)
- Client to Backend: Varies by location
- Observability scraping: Local network (development)

---

**Document End**

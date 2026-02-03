# Medico24 Documentation

This repository contains the comprehensive documentation for the Medico24 healthcare appointment management platform.

## Overview

Medico24 is an enterprise-grade healthcare appointment management system built with modern microservices architecture. This documentation provides:

- **API Documentation** - Complete REST API reference
- **System Architecture** - High-level and low-level system design
- **Implementation Guides** - Detailed implementation documentation
- **Development Guides** - Setup and development instructions
- **Monitoring & Observability** - Comprehensive monitoring setup

## Documentation Structure

```
docs/
├── api/                    # API documentation
├── architecture/           # System architecture
├── implementations/        # Implementation details
├── monitoring/             # Observability and monitoring
├── guides/                 # Development guides
└── assets/                 # Images and static assets
```

## Building Documentation

### Prerequisites

Choose one of the following options:

**Option 1: Docker**
- Docker
- Docker Compose

**Option 2: Local Python**
- Python 3.11+
- pip

### Setup

#### Using Docker (Recommended)

```bash
# Clone repository
git clone https://github.com/medico24/medico24-docs.git
cd medico24-docs

# Build and start the documentation server
docker-compose up -d

# Open in browser
# Navigate to http://localhost:8000
```

The documentation server will automatically reload when you make changes to files in the `docs/` directory.

**Docker Commands:**

```bash
# Start the container
docker-compose up -d

# Stop the container
docker-compose down

# View logs
docker-compose logs -f

# Rebuild after requirements change
docker-compose up -d --build
```

#### Using Local Python

```bash
# Clone repository
git clone https://github.com/medico24/medico24-docs.git
cd medico24-docs

# Install dependencies
pip install -r requirements.txt
```

### Development

#### With Docker

```bash
# Container runs automatically with live reload
docker-compose up -d

# View logs
docker-compose logs -f docs
```

#### With Local Python

```bash
# Start development server
mkdocs serve

# Open in browser
open http://localhost:8000
```

### Build

#### With Docker

```bash
# Build static site inside container
docker-compose exec docs mkdocs build

# Or build using Docker without compose
docker build -t medico24-docs .
docker run --rm -v ${PWD}/site:/docs/site medico24-docs mkdocs build
```

#### With Local Python

```bash
# Build static site
mkdocs build

# Output will be in site/ directory
```

### Deploy

```bash
# Deploy to GitHub Pages
mkdocs gh-deploy

# Or deploy to custom domain
mkdocs build
# Upload site/ contents to your web server
```

## Documentation Features

### Theme

- **Material for MkDocs** - Modern, responsive theme
- **Dark/Light Mode** - Automatic theme switching
- **Search** - Full-text search functionality
- **Navigation** - Tabbed navigation with sections

### Extensions

- **Code Highlighting** - Syntax highlighting for multiple languages
- **Mermaid Diagrams** - Support for Mermaid diagrams
- **MathJax** - Mathematical notation support
- **Admonitions** - Callout boxes for notes, warnings, etc.
- **Tabs** - Tabbed content sections

### Custom Features

- **API Endpoint Styling** - Custom styling for REST API endpoints
- **Status Code Badges** - Color-coded HTTP status codes
- **Architecture Diagrams** - Enhanced diagram display
- **Feature Badges** - Implementation status indicators

## Contributing

### Making Changes

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test locally** with `mkdocs serve`
5. **Submit a pull request**

### Documentation Standards

- **Accuracy** - Ensure all information is current and correct
- **Completeness** - Cover all necessary details
- **Clarity** - Write for your target audience
- **Consistency** - Follow established patterns
- **Examples** - Include practical examples

## License

This documentation is licensed under the MIT License. See [LICENSE](docs/guides/license.md) for details.

---

**Copyright © 2026 Medico24 Team. All rights reserved.**
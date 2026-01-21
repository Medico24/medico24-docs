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

- Python 3.8+
- pip

### Setup

```bash
# Clone repository
git clone https://github.com/medico24/medico24-docs.git
cd medico24-docs

# Install dependencies
pip install -r requirements.txt
```

### Development

```bash
# Start development server
mkdocs serve

# Open in browser
open http://localhost:8000
```

### Build

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
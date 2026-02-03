# Development Setup Overview

This guide provides an overview of the Medico24 platform development setup. For detailed setup instructions for each component, see the specific guides linked below.

## Platform Components

Medico24 is a multi-component healthcare platform consisting of:

- **Backend API** (FastAPI + Python) - [Setup Guide](backend-setup.md)
- **Mobile App** (Flutter + Dart) - [Setup Guide](mobile-setup.md)
- **Web Dashboard** (Next.js + TypeScript) - [Setup Guide](frontend-setup.md)
- **ML Module** (Python + Jupyter) - [Setup Guide](ml-setup.md)
- **Observability Stack** (Docker Compose) - [Setup Guide](observability-setup.md)

## Prerequisites

### Required Software

- **Git** (latest version)
- **Docker** and **Docker Compose**
- **Python** 3.11+
- **Node.js** 18+
- **Flutter** 3.x
- **PostgreSQL** client tools (optional)

### Platform-Specific Installation

=== "Windows"
    ```powershell
    # Install Chocolatey first
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Install required tools
    choco install git docker-desktop python nodejs flutter
    ```

=== "macOS"
    ```bash
    # Install Homebrew first
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Install required tools
    brew install git docker python node flutter
    ```

=== "Linux (Ubuntu/Debian)"
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

## External Services Required

Before starting development, you'll need to set up these external services:

1. **[Google Maps API](external-services.md#google-maps-api-key)** - Location services
2. **[Firebase](external-services.md#firebase-setup)** - Authentication & push notifications
3. **[PostgreSQL (Neon)](external-services.md#postgresql-database-neon-cloud)** - Database
4. **[Redis Cloud](external-services.md#redis-redis-cloud)** - Caching & sessions
5. **[Weather API](external-services.md#environment-data-apis)** - Environmental data (optional)

See the [External Services Setup Guide](external-services.md) for detailed instructions.

## Quick Start Paths

Choose your development focus:

### Backend Development
1. [Setup Backend Environment](backend-setup.md)
2. [Configure External Services](external-services.md)
3. Start coding!

### Frontend Development
1. [Setup Frontend Environment](frontend-setup.md)
2. [Configure Firebase for Web](external-services.md#firebase-setup)
3. Start coding!

### Mobile Development
1. [Setup Mobile Environment](mobile-setup.md)
2. [Configure Firebase for Mobile](external-services.md#firebase-setup)
3. Start coding!

### ML Development
1. [Setup ML Environment](ml-setup.md)
2. [Access Training Data](ml-setup.md#data-access)
3. Start experimenting!

### Full Stack Development
1. Setup all components above
2. Use [Docker Compose](../development.md#full-stack-development) for orchestration
3. Access all services locally

## Code Quality Standards

We maintain high code quality standards across all components:

- **Linting & Formatting**: Automated via pre-commit hooks
- **Type Checking**: Python (mypy), TypeScript (tsc), Dart (analyzer)
- **Testing**: Comprehensive test coverage required
- **Documentation**: Code and API documentation required

See [Code Quality Guide](../code-quality.md) for details.

## Getting Help

- **Documentation**: Browse these guides
- **GitHub Issues**: Report bugs or request features
- **GitHub Discussions**: Ask questions
- **Team Chat**: Contact via Slack (if applicable)

## Next Steps

1. Install [prerequisites](#prerequisites) for your platform
2. Clone the [repository](#clone-main-repository)
3. Setup [external services](external-services.md)
4. Choose your [development path](#quick-start-paths)
5. Read the [contributing guide](../contributing.md)

---

**Related Guides:**

- [Backend Setup](backend-setup.md)
- [Frontend Setup](frontend-setup.md)
- [Mobile Setup](mobile-setup.md)
- [ML Setup](ml-setup.md)
- [External Services](external-services.md)
- [Code Quality](../code-quality.md)

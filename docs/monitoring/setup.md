# Monitoring Setup Guide

**Medico24** uses a comprehensive observability stack for monitoring, logging, and metrics collection. This guide covers the setup and configuration of the monitoring infrastructure.

## Overview

The monitoring stack consists of:
- **Prometheus** - Metrics collection and storage
- **Grafana** - Visualization and dashboards
- **ELK Stack** - Centralized logging (Elasticsearch, Logstash, Kibana)
- **Filebeat** - Log shipping
- **Exporters** - Database, cache, and system metrics

## Prerequisites

- Docker and Docker Compose installed
- Access to backend API (running on localhost:8000)
- Environment variables configured (.env file)

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/medico24/medico24-observability.git
cd medico24-observability
cp .env.example .env
```

### 2. Configure Environment

Edit `.env` file with your configuration:

```env
# Backend Configuration
BACKEND_URL=http://localhost:8000

# Prometheus Settings
PROMETHEUS_RETENTION_TIME=30d
PROMETHEUS_SCRAPE_INTERVAL=15s

# Grafana Settings
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
GRAFANA_PORT=3001

# Database Monitoring
POSTGRES_DATA_SOURCE_NAME=postgresql://user:pass@host:port/db?sslmode=require

# Cache Monitoring
REDIS_ADDR=redis://user:pass@host:port

# Log Retention
LOG_RETENTION_DAYS=30
```

### 3. Start Services

#### Start All Services
```bash
docker compose --profile all up -d
```

#### Start Specific Profiles
```bash
# Monitoring only (Prometheus + Grafana)
docker compose --profile monitoring up -d

# Logging only (ELK Stack)
docker compose --profile logging up -d

# Exporters only
docker compose --profile exporters up -d

# Monitoring + Exporters
docker compose --profile monitoring --profile exporters up -d
```

## Service Endpoints

### Core Services
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3001 (admin/admin)
- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601
- **Backend Metrics**: http://localhost:8000/metrics

### Exporters
- **PostgreSQL Exporter**: http://localhost:9187/metrics
- **Redis Exporter**: http://localhost:9121/metrics
- **Node Exporter**: http://localhost:9100/metrics
- **cAdvisor**: http://localhost:8080

## Configuration Details

### Prometheus Configuration

The Prometheus configuration (`prometheus/prometheus.yml`) includes:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    environment: 'development'
    service: 'medico24'

scrape_configs:
  - job_name: 'medico24-backend'
    static_configs:
      - targets: ['host.docker.internal:8000']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'postgresql'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

### Grafana Dashboards

Pre-configured dashboards include:

1. **Backend API Performance**
   - Request rate and latency
   - Error rates by endpoint
   - Response time percentiles
   - Active requests gauge

2. **Database Metrics**
   - Connection pool usage
   - Query performance
   - Table statistics
   - Slow queries

3. **Cache Performance**
   - Redis hit/miss ratio
   - Memory usage
   - Key eviction rate
   - Connected clients

4. **Infrastructure**
   - Host CPU/Memory/Disk usage
   - Network traffic
   - Docker container health

### ELK Stack Configuration

#### Logstash Pipeline
```ruby
input {
  beats {
    port => 5044
  }
}

filter {
  if [docker][container][name] == "medico24-backend" {
    json {
      source => "message"
    }
    
    date {
      match => [ "timestamp", "ISO8601" ]
    }
    
    mutate {
      add_field => { "service" => "backend" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "medico24-logs-%{+YYYY.MM.dd}"
  }
}
```

#### Filebeat Configuration
```yaml
filebeat.inputs:
- type: docker
  containers.ids:
    - '*'
  processors:
  - add_docker_metadata: ~

output.logstash:
  hosts: ["logstash:5044"]

logging.level: info
```

## Health Checks

### Service Health
```bash
# Check Prometheus
curl http://localhost:9090/-/ready

# Check Grafana
curl http://localhost:3001/api/health

# Check Elasticsearch
curl http://localhost:9200/_cluster/health

# Check Kibana
curl http://localhost:5601/api/status
```

### Metrics Validation
```bash
# Check if backend metrics are being scraped
curl http://localhost:9090/api/v1/query?query=up{job="medico24-backend"}

# Check database metrics
curl http://localhost:9090/api/v1/query?query=pg_up

# Check Redis metrics
curl http://localhost:9090/api/v1/query?query=redis_up
```

## Troubleshooting

### Common Issues

#### Backend Not Reachable
```bash
# Check if backend is running
curl http://localhost:8000/health

# Check Docker networking
docker compose exec prometheus ping host.docker.internal
```

#### Database Connection Issues
```bash
# Check PostgreSQL exporter logs
docker compose logs postgres-exporter

# Test database connection
docker compose exec postgres-exporter psql $POSTGRES_DATA_SOURCE_NAME -c "SELECT 1;"
```

#### Redis Connection Issues
```bash
# Check Redis exporter logs
docker compose logs redis-exporter

# Test Redis connection
docker compose exec redis-exporter redis-cli -u $REDIS_ADDR ping
```

### Log Analysis

#### Check Container Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f prometheus
docker compose logs -f grafana
docker compose logs -f elasticsearch
```

#### Check Service Status
```bash
# List running services
docker compose ps

# Check resource usage
docker stats
```

## Performance Tuning

### Prometheus Optimization
```yaml
# prometheus.yml
global:
  scrape_interval: 30s  # Increase for lower load
  evaluation_interval: 30s

storage:
  tsdb:
    retention.time: 15d  # Reduce for less storage
    retention.size: 10GB
```

### Elasticsearch Optimization
```yaml
# docker-compose.yml
services:
  elasticsearch:
    environment:
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"  # Adjust heap size
      - "discovery.type=single-node"
    deploy:
      resources:
        limits:
          memory: 4g
```

## Maintenance

### Data Cleanup
```bash
# Clean old Prometheus data
docker compose exec prometheus promtool tsdb delete-series --match='{__name__=~".*"}' --min-time=$(date -d "30 days ago" +%s)000

# Clean old Elasticsearch indices
curl -X DELETE "localhost:9200/medico24-logs-$(date -d "30 days ago" +%Y.%m.%d)"
```

### Backup
```bash
# Backup Grafana dashboards
docker compose exec grafana grafana-cli admin export-dashboard

# Backup Prometheus data
cp -r ./volumes/prometheus ./backups/prometheus-$(date +%Y%m%d)
```

## Next Steps

- [Monitoring Overview](overview.md) - Detailed monitoring architecture
- [Alert Configuration](alerts.md) - Setting up alerts and notifications
- [Dashboard Customization](dashboards.md) - Creating custom dashboards
- [Performance Optimization](performance.md) - Optimizing monitoring performance
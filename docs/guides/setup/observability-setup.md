# Observability Stack Setup

This guide covers setting up the Medico24 observability stack for monitoring, logging, and tracing.

## Overview

The observability stack includes:

- **Prometheus** - Metrics collection and storage
- **Grafana** - Metrics visualization and dashboards
- **ELK Stack** (Elasticsearch, Logstash, Kibana) - Log aggregation and analysis
- **Filebeat** - Log shipping
- **Jaeger** (planned) - Distributed tracing

---

## Prerequisites

- Docker and Docker Compose
- At least 8GB RAM (16GB recommended)
- 20GB disk space

---

## Installation

### 1. Navigate to Observability Directory

```bash
cd medico24-observability
```

### 2. Start Services

```bash
# Start all observability services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### 3. Verify Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | admin/admin |
| **Prometheus** | http://localhost:9090 | - |
| **Kibana** | http://localhost:5601 | - |
| **Elasticsearch** | http://localhost:9200 | - |

---

## Project Structure

```
medico24-observability/
├── docker-compose.yml       # Orchestration file
├── prometheus/
│   ├── prometheus.yml      # Prometheus configuration
│   └── rules/              # Alerting rules
│       └── alerts.yml
├── grafana/
│   ├── dashboards/         # Pre-built dashboards
│   │   ├── backend.json
│   │   ├── frontend.json
│   │   └── system.json
│   └── provisioning/       # Auto-provisioning config
│       ├── dashboards/
│       └── datasources/
├── elasticsearch/
│   └── elasticsearch.yml   # ES configuration
├── logstash/
│   ├── logstash.conf      # Log processing pipeline
│   └── patterns/          # Custom grok patterns
├── filebeat/
│   └── filebeat.yml       # Log shipping config
└── README.md
```

---

## Configuration

### Prometheus

Edit `prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

# Load alerting rules
rule_files:
  - "rules/*.yml"

# Scrape configurations
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Backend API metrics
  - job_name: 'backend-api'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'

  # Frontend metrics
  - job_name: 'frontend'
    static_configs:
      - targets: ['frontend:3000']
    metrics_path: '/api/metrics'

  # PostgreSQL metrics
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Redis metrics
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  # Node exporter (system metrics)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

### Grafana Datasources

Create `grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false

  - name: Elasticsearch
    type: elasticsearch
    access: proxy
    url: http://elasticsearch:9200
    database: "[logstash-]YYYY.MM.DD"
    jsonData:
      timeField: "@timestamp"
      esVersion: "8.0.0"
      logMessageField: message
      logLevelField: level
```

### Alerting Rules

Create `prometheus/rules/alerts.yml`:

```yaml
groups:
  - name: backend_alerts
    interval: 30s
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors/sec"

      # High response time
      - alert: HighResponseTime
        expr: histogram_quantile(0.95, http_request_duration_seconds_bucket) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time"
          description: "95th percentile response time is {{ $value }}s"

      # Service down
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"

  - name: database_alerts
    interval: 30s
    rules:
      # High database connections
      - alert: HighDatabaseConnections
        expr: pg_stat_database_numbackends > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database connection count"

      # Slow queries
      - alert: SlowQueries
        expr: pg_stat_statements_mean_exec_time > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow database queries detected"

  - name: system_alerts
    interval: 30s
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"

      # High memory usage
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"

      # Disk space low
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
```

---

## Instrumentation

### Backend (FastAPI + Prometheus)

Install dependencies:

```bash
pip install prometheus-client prometheus-fastapi-instrumentator
```

Instrument your FastAPI app:

```python
# app/main.py
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()

# Add Prometheus instrumentation
Instrumentator().instrument(app).expose(app)

# Custom metrics
from prometheus_client import Counter, Histogram

request_count = Counter(
    'custom_requests_total',
    'Total custom requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'custom_request_duration_seconds',
    'Request duration in seconds',
    ['method', 'endpoint']
)

@app.get('/api/v1/pharmacies')
def get_pharmacies():
    with request_duration.labels('GET', '/pharmacies').time():
        # Your logic here
        request_count.labels('GET', '/pharmacies', '200').inc()
        return pharmacies
```

### Frontend (Next.js)

Create metrics endpoint:

```typescript
// app/api/metrics/route.ts
import { NextResponse } from 'next/server'
import { register } from 'prom-client'

export async function GET() {
  const metrics = await register.metrics()
  return new NextResponse(metrics, {
    headers: {
      'Content-Type': register.contentType,
    },
  })
}
```

Track custom metrics:

```typescript
// lib/metrics.ts
import { Counter, Histogram } from 'prom-client'

export const pageViewCounter = new Counter({
  name: 'page_views_total',
  help: 'Total page views',
  labelNames: ['page'],
})

export const apiCallDuration = new Histogram({
  name: 'api_call_duration_seconds',
  help: 'API call duration',
  labelNames: ['endpoint', 'method'],
})
```

---

## Logging

### Structured Logging (Backend)

```python
# app/utils/logger.py
import logging
import json
from datetime import datetime

class StructuredLogger:
    def __init__(self, name: str):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.INFO)
        
        handler = logging.StreamHandler()
        handler.setFormatter(self.JSONFormatter())
        self.logger.addHandler(handler)
    
    class JSONFormatter(logging.Formatter):
        def format(self, record):
            log_data = {
                'timestamp': datetime.utcnow().isoformat(),
                'level': record.levelname,
                'logger': record.name,
                'message': record.getMessage(),
                'module': record.module,
                'function': record.funcName,
                'line': record.lineno,
            }
            
            if record.exc_info:
                log_data['exception'] = self.formatException(record.exc_info)
            
            return json.dumps(log_data)

# Usage
logger = StructuredLogger(__name__)
logger.logger.info('User logged in', extra={'user_id': 123})
```

### Filebeat Configuration

Edit `filebeat/filebeat.yml`:

```yaml
filebeat.inputs:
  # Backend logs
  - type: log
    enabled: true
    paths:
      - /var/log/medico24/backend/*.log
    fields:
      service: backend
      environment: production
    json.keys_under_root: true
    json.add_error_key: true

  # Frontend logs
  - type: log
    enabled: true
    paths:
      - /var/log/medico24/frontend/*.log
    fields:
      service: frontend
      environment: production

  # Nginx logs
  - type: log
    enabled: true
    paths:
      - /var/log/nginx/access.log
      - /var/log/nginx/error.log
    fields:
      service: nginx

# Output to Logstash
output.logstash:
  hosts: ["logstash:5044"]

# Output to Elasticsearch (alternative)
# output.elasticsearch:
#   hosts: ["elasticsearch:9200"]
#   index: "medico24-logs-%{+yyyy.MM.dd}"
```

### Logstash Pipeline

Edit `logstash/logstash.conf`:

```conf
input {
  beats {
    port => 5044
  }
}

filter {
  # Parse JSON logs
  if [service] == "backend" {
    json {
      source => "message"
      target => "parsed"
    }
    
    mutate {
      add_field => { "[@metadata][index]" => "backend-logs" }
    }
  }
  
  # Parse Nginx logs
  if [service] == "nginx" {
    grok {
      match => { "message" => "%{NGINXACCESS}" }
    }
    
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
      target => "@timestamp"
    }
  }
  
  # Geo IP lookup
  geoip {
    source => "clientip"
    target => "geoip"
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "%{[@metadata][index]}-%{+YYYY.MM.dd}"
  }
  
  # Debug output
  stdout {
    codec => rubydebug
  }
}
```

---

## Grafana Dashboards

### Backend API Dashboard

Create `grafana/dashboards/backend.json`:

```json
{
  "dashboard": {
    "title": "Backend API Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])"
          }
        ]
      },
      {
        "title": "Response Time (p95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, http_request_duration_seconds_bucket)"
          }
        ]
      },
      {
        "title": "Active Connections",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends"
          }
        ]
      }
    ]
  }
}
```

### Import Dashboards

Pre-built dashboards available:

- **Node Exporter Full** (ID: 1860) - System metrics
- **PostgreSQL Database** (ID: 9628) - Database metrics
- **Redis Dashboard** (ID: 11835) - Redis metrics
- **NGINX** (ID: 12708) - Nginx metrics

Import via Grafana UI:
1. Go to http://localhost:3000
2. **Dashboards** → **Import**
3. Enter dashboard ID
4. Select Prometheus datasource

---

## Distributed Tracing (Jaeger)

### Add to Docker Compose

```yaml
# docker-compose.yml
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"  # UI
      - "14268:14268"  # HTTP collector
      - "6831:6831/udp"  # Jaeger agent
    environment:
      - COLLECTOR_ZIPKIN_HOST_PORT=:9411
```

### Instrument Backend

```bash
pip install opentelemetry-api opentelemetry-sdk opentelemetry-instrumentation-fastapi
```

```python
# app/main.py
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# Configure tracer
trace.set_tracer_provider(TracerProvider())
jaeger_exporter = JaegerExporter(
    agent_host_name="localhost",
    agent_port=6831,
)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(jaeger_exporter)
)

# Instrument FastAPI
FastAPIInstrumentor.instrument_app(app)

# Manual tracing
tracer = trace.get_tracer(__name__)

@app.get("/api/v1/pharmacies")
def get_pharmacies():
    with tracer.start_as_current_span("get_pharmacies"):
        # Your logic
        pass
```

---

## Monitoring Best Practices

### 1. The Four Golden Signals

Monitor these key metrics:

- **Latency**: Request/response time
- **Traffic**: Request rate
- **Errors**: Error rate
- **Saturation**: Resource utilization (CPU, memory, disk)

### 2. SLI/SLO/SLA

Define Service Level Indicators (SLIs):

```yaml
# Example SLIs
availability_sli: 99.9%  # Uptime
latency_sli: p95 < 500ms  # 95% requests < 500ms
error_rate_sli: < 0.1%   # Less than 0.1% errors
```

### 3. Alert Fatigue Prevention

- Set meaningful thresholds
- Use alert grouping
- Implement alert escalation
- Add runbooks to alerts

### 4. Dashboard Organization

- **Overview Dashboard**: High-level metrics
- **Service-Specific Dashboards**: Detailed per service
- **Troubleshooting Dashboards**: For incident response

---

## Troubleshooting

### Elasticsearch Issues

??? question "Elasticsearch won't start"
    ```bash
    # Increase virtual memory
    sudo sysctl -w vm.max_map_count=262144
    
    # Make permanent
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    ```

??? question "Out of memory"
    - Reduce Elasticsearch heap size in docker-compose.yml
    - Increase Docker memory limit
    - Reduce retention period for logs

### Prometheus Issues

??? question "Target down"
    - Check service is running: `docker-compose ps`
    - Verify network connectivity
    - Check Prometheus config: `docker-compose exec prometheus cat /etc/prometheus/prometheus.yml`

### Grafana Issues

??? question "No data in dashboards"
    - Verify Prometheus datasource is configured
    - Check Prometheus is scraping targets: http://localhost:9090/targets
    - Verify time range in Grafana dashboard

---

## Resource Management

### Disk Space

```bash
# Clean old Elasticsearch indices
curl -X DELETE "localhost:9200/logstash-$(date -d '30 days ago' +%Y.%m.%d)"

# Set index lifecycle policy
curl -X PUT "localhost:9200/_ilm/policy/medico24-logs" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {}
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
'
```

### Memory Limits

Edit `docker-compose.yml`:

```yaml
services:
  elasticsearch:
    environment:
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    mem_limit: 1g

  logstash:
    environment:
      - "LS_JAVA_OPTS=-Xms256m -Xmx256m"
    mem_limit: 512m
```

---

## Production Deployment

### Security

1. **Enable authentication**:
   - Elasticsearch: Enable X-Pack security
   - Grafana: Change default password
   - Prometheus: Use reverse proxy with auth

2. **Use HTTPS**: Configure TLS certificates

3. **Network isolation**: Use private networks

4. **Access control**: Implement RBAC

### Scaling

- Use Elasticsearch cluster for high log volume
- Deploy Prometheus federation for multi-region
- Use remote storage for Prometheus (Thanos, Cortex)

---

## Next Steps

1. Start observability stack: `docker-compose up -d`
2. Instrument [Backend](backend-setup.md) with metrics
3. Configure alerts in Prometheus
4. Create custom Grafana dashboards
5. Read [Observability Roadmap](../../roadmap/observability.md)

**Related Guides:**

- [Setup Overview](overview.md)
- [Backend Setup](backend-setup.md)
- [Observability Roadmap](../../roadmap/observability.md)

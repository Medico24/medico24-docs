## 🧠 Observability Strategy (High-Level)

| Concern              | Tool           | Why                        |
| -------------------- | -------------- | -------------------------- |
| **Metrics**          | **Prometheus** | Time-series metrics, SLOs  |
| **Dashboards**       | **Grafana**    | Visualization & alerting   |
| **Logs**             | **ELK Stack**  | Searchable structured logs |
| **Tracing (future)** | OpenTelemetry  | Distributed tracing        |

> **Golden Rule**
> **Prometheus = “What is slow/broken?”**
> **ELK = “Why did it break?”**

---

## 1️⃣ Where Monitoring Fits in *Your* Architecture

### Extended Architecture (Observability Layer)

![Image](https://bravenewgeek.com/wp-content/uploads/2018/09/observability_pipeline.png)

![Image](https://miro.medium.com/1%2AgtxL8IpXN94rreE8JINYcA.jpeg)

![Image](https://miro.medium.com/0%2AtcWITi1VCaBv294D)

```
Flutter / Admin Web
        |
     FastAPI API
        |
 ┌───────────────────────┐
 │  Observability Layer  │
 │                       │
 │  Metrics → Prometheus │
 │  Logs    → ELK Stack  │
 │  Dash    → Grafana    │
 └───────────────────────┘
        |
 PostgreSQL / Redis
```

This sits **outside** your application logic (important for scale).

---

## 2️⃣ Prometheus Integration (Metrics)

### 🎯 What You Measure (Medico24-specific)

From your API + architecture :

| Category         | Examples                        |
| ---------------- | ------------------------------- |
| **HTTP**         | request count, latency, 4xx/5xx |
| **Auth**         | token verify failures           |
| **Appointments** | booking rate, cancellation rate |
| **Pharmacies**   | geo search latency              |
| **Redis**        | cache hit/miss                  |
| **DB**           | connection pool usage           |
| **Infra**        | CPU, memory                     |

---

### 🔧 FastAPI → Prometheus

**Install**

```bash
pip install prometheus-fastapi-instrumentator
```

**Wire it**

```python
from prometheus_fastapi_instrumentator import Instrumentator

Instrumentator() \
  .instrument(app) \
  .expose(app, endpoint="/metrics")
```

This automatically exposes:

```
GET /metrics
```

Prometheus scrapes this endpoint.

---

### 📡 Prometheus Scrape Config

```yaml
scrape_configs:
  - job_name: "medico24-backend"
    static_configs:
      - targets: ["backend:8000"]
```

> Your existing `/health` and `/health/detailed` endpoints (from API specs) remain **separate** and are **not metrics** 

---

### 📊 Grafana Dashboards (Recommended)

Create dashboards for:

* **API Latency P95**
* **Appointments Created / Min**
* **Error Rate (4xx vs 5xx)**
* **Redis Hit Ratio**
* **DB Connection Pool Saturation**

---

## 3️⃣ ELK Stack Integration (Logs)

### 🎯 Logging Philosophy (Critical)

Your backend already uses **structured logging middleware** (from system docs) 

**You should log ONLY JSON.**

Example:

```json
{
  "timestamp": "2026-01-03T10:12:00Z",
  "level": "ERROR",
  "service": "appointments",
  "request_id": "uuid",
  "user_id": "uuid",
  "endpoint": "/appointments/",
  "status_code": 500,
  "message": "DB timeout"
}
```

---

### 🔧 FastAPI → Logstash

**Logging stack**

* App → stdout (JSON)
* Filebeat → Logstash → Elasticsearch
* Kibana → dashboards

---

### 📦 Filebeat Config (Backend Container)

```yaml
filebeat.inputs:
- type: container
  paths:
    - /var/lib/docker/containers/*/*.log
  json.keys_under_root: true

output.logstash:
  hosts: ["logstash:5044"]
```

---

### 🔍 Elasticsearch Indexing Strategy

```
medico24-api-logs-YYYY.MM.DD
```

Index fields:

* `service`
* `endpoint`
* `user_id`
* `request_id`
* `status_code`
* `latency_ms`

---

### 📊 Kibana Dashboards

Create saved views:

* ❌ Error spikes per endpoint
* 🔐 Auth failures
* 🕒 Slow pharmacy geo queries
* 🧑 Admin actions audit trail

---

## 4️⃣ Correlating Metrics + Logs (Industry Trick)

**Add `request_id` everywhere**

### Middleware Pattern

```python
request.state.request_id = uuid4()
logger.bind(request_id=request.state.request_id)
```

Now:

* **Grafana** → latency spike
* Copy timestamp
* **Kibana** → filter by time + endpoint
* Boom → root cause in seconds

---

## 5️⃣ Redis & PostgreSQL Monitoring

### Redis

* Enable Redis Exporter
* Metrics:

  * memory_used
  * connected_clients
  * cache_hits / misses

### PostgreSQL

* Use postgres_exporter
* Metrics:

  * active connections
  * slow queries
  * transaction rate

---

## 6️⃣ Alerts You *Should* Configure (Minimum)

| Alert                  | Tool       |
| ---------------------- | ---------- |
| API error rate > 2%    | Prometheus |
| P95 latency > 800ms    | Prometheus |
| DB connections > 80%   | Prometheus |
| Auth failures spike    | ELK        |
| Pharmacy search > 1.5s | Prometheus |

Grafana → Slack / Email / PagerDuty.

---

## 7️⃣ What NOT To Do (Common Mistakes)

❌ Logging PII (emails, phone numbers)
❌ Logging request/response bodies
❌ Scraping `/health` instead of `/metrics`
❌ Mixing monitoring logic into business code

---

## 8️⃣ Future-Proofing (Highly Recommended)

When you scale to microservices:

* Add **OpenTelemetry**
* Use **Tempo / Jaeger** for tracing
* Correlate:

  ```
  Request → Metrics → Logs → Trace
  ```

---

## ✅ Final Verdict

Your architecture is **already observability-ready**.

You only need to:

1. Expose `/metrics`
2. Standardize JSON logs
3. Deploy ELK + Prometheus side-by-side
4. Correlate via `request_id`

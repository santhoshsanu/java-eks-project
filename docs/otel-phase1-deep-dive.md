# OpenTelemetry Phase 1 — Deep Dive Documentation
## How Metrics Flow from Spring Boot to Grafana

---

## Overview

```
Spring Boot App (backend pod)
        │
        │ OTLP gRPC port 4317
        ↓
OTEL Collector (monitoring namespace)
        │
        │ Prometheus format port 8889
        ↓
Prometheus (scrapes every 15s)
        │
        │ PromQL queries
        ↓
Grafana (dashboard)
```

---

## Part 1 — Spring Boot Only Knows About OTEL

### Where Configured
**File:** `k8s/backend-deployment.yaml`

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "product-catalog-backend"
    # Identifies this service in all metrics/traces
    # Shows as service.name label in Prometheus

  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.monitoring.svc.cluster.local:4317"
    # Spring Boot ONLY knows this address
    # Does NOT know about Prometheus or Grafana
    # K8s DNS: otel-collector (service name) . monitoring (namespace) . svc.cluster.local

  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "grpc"
    # gRPC is faster than HTTP for telemetry data

  - name: OTEL_METRICS_EXPORTER
    value: "otlp"
    # Export metrics via OTLP protocol (not direct to Prometheus)

  - name: OTEL_TRACES_EXPORTER
    value: "otlp"
    # Export traces via OTLP protocol

  - name: OTEL_LOGS_EXPORTER
    value: "none"
    # Logs disabled in Phase 1 (enabled in Phase 2)

  - name: OTEL_INSTRUMENTATION_MICROMETER_ENABLED
    value: "true"
    # Bridge Spring Boot Micrometer metrics → OTEL
    # Captures JVM, HTTP, DB metrics automatically
```

### How Env Vars Are Used

```
Kubernetes starts backend pod
        ↓
Injects env vars into container OS
        ↓
JVM starts with OTEL agent:
java -javaagent:/app/opentelemetry-javaagent.jar -jar app.jar
        ↓
Agent reads ALL env vars at startup
        ↓
Configures itself:
  - service name = "product-catalog-backend"
  - send to = otel-collector:4317
  - protocol = gRPC
        ↓
App starts — agent instruments automatically
```

---

## Part 2 — OTEL Java Agent (Auto-Instrumentation)

### Where Configured
**File:** `backend/Dockerfile`

```dockerfile
# Stage 2 Runtime
FROM eclipse-temurin:17-jre-alpine

# Downloads the OTEL Java agent jar
RUN wget -q https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.2.0/opentelemetry-javaagent.jar \
    -O /app/opentelemetry-javaagent.jar

# Starts app WITH agent attached
ENTRYPOINT ["java",
  "-javaagent:/app/opentelemetry-javaagent.jar",   ← agent loads before app
  "-jar", "app.jar"]
```

### What the Agent Does Automatically

```
HTTP Request arrives: GET /api/products
        ↓
Agent intercepts (bytecode instrumentation)
        ↓
Agent records:
  - http.method = GET
  - http.route = /api/products
  - http.status_code = 200
  - http.server.duration = 45ms
        ↓
Agent creates metric:
  http_server_requests_seconds{method="GET", uri="/api/products", status="200"} 0.045
        ↓
Agent batches metrics
        ↓
Agent sends to otel-collector:4317 via gRPC
```

**Zero code changes in Java files** — agent handles everything.

### What Gets Auto-Instrumented

| Library | Metrics Captured |
|---------|-----------------|
| Spring MVC | HTTP request rate, duration, status codes |
| JDBC/H2 | DB query duration, connection pool |
| JVM | Heap memory, GC pause, thread count |
| Spring Boot | App startup time, active requests |

---

## Part 3 — OTEL Collector (The Middleman)

### Where Configured
**File:** `k8s/monitoring/otel-collector.yaml`

```yaml
data:
  config.yaml: |

    # ── EXTENSIONS ──────────────────────────────────
    extensions:
      health_check:
        endpoint: 0.0.0.0:13133    # K8s liveness probe checks this

    # ── RECEIVERS (data comes IN) ────────────────────
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317   # listens for Spring Boot OTLP data
          http:
            endpoint: 0.0.0.0:4318   # HTTP alternative

    # ── PROCESSORS (data transformation) ────────────
    processors:
      batch:
        timeout: 10s                  # wait max 10s before sending batch
        send_batch_size: 1000         # or send when 1000 metrics collected
      
      resource:
        attributes:
          - key: environment
            value: production
            action: upsert            # adds environment=production label

      memory_limiter:
        limit_mib: 256                # collector uses max 256MB RAM

    # ── EXPORTERS (data goes OUT) ────────────────────
    exporters:
      prometheus:
        endpoint: "0.0.0.0:8889"     # converts OTLP → Prometheus format
        namespace: product_catalog    # prefix: product_catalog_http_server_...

      debug:
        verbosity: basic              # prints to collector logs

    # ── SERVICE (connects everything) ───────────────
    service:
      extensions: [health_check]
      pipelines:
        metrics:
          receivers:  [otlp]          # receive from Spring Boot
          processors: [memory_limiter, batch, resource]
          exporters:  [prometheus]    # serve to Prometheus

        traces:
          receivers:  [otlp]
          processors: [memory_limiter, batch, resource]
          exporters:  [debug]         # just log traces (Jaeger added Phase 2)
```

### Data Transformation

```
OTLP format (received from Spring Boot):
{
  "resourceMetrics": [{
    "resource": {"attributes": [{"key": "service.name", "value": "product-catalog-backend"}]},
    "scopeMetrics": [{
      "metrics": [{
        "name": "http.server.duration",
        "histogram": {"dataPoints": [{"sum": 0.045, "count": 1, "attributes": [...]}]}
      }]
    }]
  }]
}

Prometheus format (served on :8889):
# HELP product_catalog_http_server_duration_seconds
# TYPE product_catalog_http_server_duration_seconds histogram
product_catalog_http_server_duration_seconds_bucket{method="GET",uri="/api/products",status="200",le="0.1"} 1
product_catalog_http_server_duration_seconds_sum{method="GET",uri="/api/products",status="200"} 0.045
product_catalog_http_server_duration_seconds_count{method="GET",uri="/api/products",status="200"} 1
```

---

## Part 4 — Prometheus Scrapes the Collector

### Where Configured
**File:** `k8s/monitoring/prometheus.yaml`

```yaml
scrape_configs:

  # Scrape OTEL Collector metrics
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector.monitoring.svc.cluster.local:8889']
    metrics_path: '/metrics'
    scrape_interval: 15s       # every 15 seconds

  # Scrape Spring Boot Actuator directly (backup path)
  - job_name: 'product-catalog-backend'
    static_configs:
      - targets: ['backend-service.product-catalog.svc.cluster.local:80']
    metrics_path: '/actuator/prometheus'
    scrape_interval: 15s
```

### Pull vs Push

```
OTEL Agent → PUSHES to collector (port 4317)
Prometheus → PULLS from collector (port 8889)

Push:  App initiates connection → sends data
Pull:  Prometheus initiates connection → requests data
```

### Spring Boot Actuator (Direct Path)

```yaml
# application.properties
management.endpoints.web.exposure.include=health,info,prometheus
management.metrics.export.prometheus.enabled=true
```

This exposes `GET /actuator/prometheus` directly on the backend service.
Prometheus scrapes this directly — gives JVM metrics even without OTEL agent.

---

## Part 5 — Grafana Visualizes

### Where Configured
**File:** `k8s/monitoring/grafana.yaml`

```yaml
# Auto-provision Prometheus as data source
datasources.yaml: |
  datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus.monitoring.svc.cluster.local:9090
      isDefault: true
```

When Grafana starts — it automatically connects to Prometheus. No manual setup.

### How Grafana Gets Data

```
You open Grafana dashboard
        ↓
Panel runs PromQL query:
rate(http_server_requests_seconds_count{job="product-catalog-backend"}[1m])
        ↓
Grafana sends query to Prometheus API:
GET http://prometheus:9090/api/v1/query_range?query=rate(...)
        ↓
Prometheus calculates result from stored time-series
        ↓
Returns JSON with data points
        ↓
Grafana renders chart
```

---

## Part 6 — For 10 Microservices

Same pattern for every service — only `OTEL_SERVICE_NAME` changes:

```yaml
# user-service-deployment.yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "user-service"                    ← unique per service
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector:4317"      ← same for all

# order-service-deployment.yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "order-service"                   ← unique per service
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector:4317"      ← same for all
```

All services → ONE collector → ONE Prometheus → ONE Grafana.

### Shared ConfigMap Pattern (Best Practice)

```yaml
# otel-shared-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-shared-config
data:
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector.monitoring.svc.cluster.local:4317"
  OTEL_EXPORTER_OTLP_PROTOCOL: "grpc"
  OTEL_METRICS_EXPORTER: "otlp"
  OTEL_TRACES_EXPORTER: "otlp"
```

Each deployment references it:
```yaml
envFrom:
  - configMapRef:
      name: otel-shared-config    ← shared
env:
  - name: OTEL_SERVICE_NAME
    value: "user-service"         ← unique
```

---

## Part 7 — Phase 2 Preview (Logs + Traces)

### What Changes

**backend-deployment.yaml:**
```yaml
- name: OTEL_LOGS_EXPORTER
  value: "otlp"    # change from "none" to "otlp"
```

**otel-collector.yaml — add exporters:**
```yaml
exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"      # metrics (existing)

  otlp/jaeger:
    endpoint: "jaeger:4317"        # traces (NEW)

  loki:
    endpoint: "http://loki:3100/loki/api/v1/push"  # logs (NEW)
```

**otel-collector.yaml — add pipelines:**
```yaml
service:
  pipelines:
    metrics:                        # existing
      receivers: [otlp]
      exporters: [prometheus]

    traces:                         # NEW
      receivers: [otlp]
      exporters: [otlp/jaeger]

    logs:                           # NEW
      receivers: [otlp]
      exporters: [loki]
```

### Phase 2 Full Flow

```
Spring Boot
    ├── metrics → OTEL Collector → Prometheus → Grafana (metrics tab)
    ├── traces  → OTEL Collector → Jaeger     → Grafana (traces tab)
    └── logs    → OTEL Collector → Loki       → Grafana (logs tab)
```

All three signals in ONE Grafana UI.

---

## Summary Table

| Component | Role | File | Port |
|-----------|------|------|------|
| OTEL Java Agent | Auto-instruments Spring Boot | `backend/Dockerfile` | N/A |
| OTEL Env Vars | Configure agent behavior | `k8s/backend-deployment.yaml` | N/A |
| OTEL Collector receiver | Listens for app data | `k8s/monitoring/otel-collector.yaml` | 4317 |
| OTEL Collector exporter | Serves Prometheus metrics | `k8s/monitoring/otel-collector.yaml` | 8889 |
| Prometheus scrape | Pulls metrics every 15s | `k8s/monitoring/prometheus.yaml` | 9090 |
| Spring Actuator | Direct metrics endpoint | `application.properties` | 80/actuator/prometheus |
| Grafana datasource | Connects to Prometheus | `k8s/monitoring/grafana.yaml` | 3000 |

---

## Key Takeaways

1. **Spring Boot never knows about Prometheus** — only knows OTEL endpoint
2. **OTEL Collector is the translator** — converts OTLP → Prometheus format
3. **One collector for all services** — scales to 10, 50, 100 microservices
4. **Zero code changes** — agent instruments via env vars only
5. **Port 4317 handles all 3 signals** — metrics, traces, logs
6. **Grafana is just a viewer** — Prometheus stores, Grafana displays
7. **Phase 2 adds Jaeger + Loki** — same collector, new exporters + pipelines

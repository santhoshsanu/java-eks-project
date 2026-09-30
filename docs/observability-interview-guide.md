# Observability — Learning & Interview Guide
## OpenTelemetry + Prometheus + Grafana

---

## SECTION 1 — The Big Picture

### What is Observability?
Observability is the ability to understand what's happening **inside** your system
by looking at the data it produces from the **outside**.

Three pillars of observability:
```
Metrics  → What is happening?     (numbers over time)
Traces   → Why is it happening?   (request flow through code)
Logs     → What happened exactly? (text records of events)
```

In our project:
```
Metrics  → Prometheus + Grafana
Traces   → OTEL Collector (Phase 2: Jaeger)
Logs     → Console (Phase 2: Loki)
```

---

### Why Observability Matters

Without observability:
```
User reports: "App is slow"
You: "Let me SSH into the server and check..."
Result: 30 minutes to find the problem
```

With observability:
```
Alert fires: "p95 response time > 2 seconds"
You: Open Grafana → see DB queries spiked → fix in 5 minutes
Result: Problem found before users even notice
```

---

## SECTION 2 — OpenTelemetry (OTEL)

### What is OpenTelemetry?
OpenTelemetry is an **open-source observability framework** — a vendor-neutral
standard for collecting metrics, traces, and logs from applications.

Before OTEL:
```
Using Datadog?   → install Datadog agent
Using New Relic? → install New Relic agent
Using Jaeger?    → install Jaeger client
```
Each vendor had different APIs. Switching was painful.

With OTEL:
```
Instrument once with OTEL
        ↓
Send to any backend (Prometheus, Jaeger, Datadog, New Relic)
```
One standard, any backend.

---

### OTEL Components

| Component | What it is | What it does |
|-----------|-----------|-------------|
| OTEL API | Interfaces | Defines how to create spans, metrics |
| OTEL SDK | Implementation | Implements the API |
| OTEL Java Agent | JAR file | Auto-instruments Java apps (no code changes) |
| OTEL Collector | Service | Receives, processes, exports telemetry |
| OTLP | Protocol | OpenTelemetry Line Protocol — how data is sent |

---

### OTEL Java Agent — How it Works in Our Project

```dockerfile
ENTRYPOINT ["java",
  "-javaagent:/app/opentelemetry-javaagent.jar",   ← agent attached here
  "-jar", "app.jar"]
```

The agent:
1. Hooks into the JVM at startup using bytecode instrumentation
2. Automatically instruments Spring Boot, JDBC, HTTP clients
3. Creates spans for every HTTP request and DB query
4. Sends data to OTEL Collector via gRPC on port 4317

**Zero code changes** to your Java files.

---

### OTEL Collector — Pipeline Architecture

```yaml
receivers:    # how data comes IN
  otlp:
    protocols:
      grpc: 0.0.0.0:4317   # receives from Spring Boot app
      http: 0.0.0.0:4318

processors:   # how data is processed
  batch:      # batches data for efficiency
  memory_limiter:  # prevents OOM

exporters:    # where data goes OUT
  prometheus: 0.0.0.0:8889  # scraped by Prometheus
  debug:      # prints to logs

service:
  pipelines:
    metrics:
      receivers:  [otlp]
      processors: [batch]
      exporters:  [prometheus]
```

Think of OTEL Collector as a **router** for telemetry data.

---

### OTEL Environment Variables Explained

| Variable | Our Value | Purpose |
|----------|-----------|---------|
| `OTEL_SERVICE_NAME` | `product-catalog-backend` | Name shown in traces/metrics |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://otel-collector:4317` | Where to send data |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | gRPC is faster than HTTP |
| `OTEL_METRICS_EXPORTER` | `otlp` | Export metrics via OTLP |
| `OTEL_TRACES_EXPORTER` | `otlp` | Export traces via OTLP |
| `OTEL_INSTRUMENTATION_MICROMETER_ENABLED` | `true` | Bridge Spring Micrometer → OTEL |

---

## SECTION 3 — Prometheus

### What is Prometheus?
Prometheus is an **open-source time-series database** for storing metrics.
It works by **pulling** (scraping) metrics from targets at regular intervals.

```
Prometheus → scrapes → http://backend:80/actuator/prometheus
                    → http://otel-collector:8889/metrics
Every 15 seconds → stores the data
```

---

### Pull vs Push Model

| | Pull (Prometheus) | Push (StatsD, Graphite) |
|--|-------------------|------------------------|
| How | Prometheus calls the app | App sends to server |
| Config | Central — in prometheus.yml | Distributed — in each app |
| Discovery | Easy — just add targets | App must know server address |
| Firewall | App needs to be reachable | Server needs to be reachable |

---

### Prometheus Data Model

Every metric has:
```
metric_name{label1="value1", label2="value2"} numeric_value timestamp

Example:
http_server_requests_seconds_count{method="GET", uri="/api/products", status="200"} 142 1234567890
```

Labels allow filtering:
```promql
# All GET requests
http_server_requests_seconds_count{method="GET"}

# Only 5xx errors
http_server_requests_seconds_count{status=~"5.."}

# Specific endpoint
http_server_requests_seconds_count{uri="/api/products"}
```

---

### Prometheus Metric Types

| Type | What it is | Example |
|------|-----------|---------|
| Counter | Always increases | Total requests, total errors |
| Gauge | Goes up and down | Current memory, active connections |
| Histogram | Distribution of values | Request duration buckets |
| Summary | Similar to histogram | Quantiles (p50, p95, p99) |

---

### PromQL — Key Queries

```promql
# Request rate per second (last 1 minute)
rate(http_server_requests_seconds_count[1m])

# p95 response time (last 5 minutes)
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))

# Error rate percentage
rate(http_server_requests_seconds_count{status=~"5.."}[1m])
  /
rate(http_server_requests_seconds_count[1m]) * 100

# JVM heap used in MB
jvm_memory_used_bytes{area="heap"} / 1024 / 1024

# Active HTTP connections
http_server_active_requests
```

---

### Prometheus Configuration in Our Project

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'product-catalog-backend'
    static_configs:
      - targets: ['backend-service.product-catalog.svc.cluster.local:80']
    metrics_path: '/actuator/prometheus'   # Spring Boot exposes metrics here
    scrape_interval: 15s

  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector.monitoring.svc.cluster.local:8889']
    scrape_interval: 30s
```

---

### Spring Boot Actuator + Micrometer

```properties
# application.properties
management.endpoints.web.exposure.include=health,info,prometheus
management.metrics.export.prometheus.enabled=true
```

This exposes: `GET /actuator/prometheus`

Output format:
```
# HELP http_server_requests_seconds_count
# TYPE http_server_requests_seconds_count counter
http_server_requests_seconds_count{exception="None",method="GET",
  outcome="SUCCESS",status="200",uri="/api/products"} 42.0
```

---

## SECTION 4 — Grafana

### What is Grafana?
Grafana is an **open-source visualization platform** — it connects to data
sources (Prometheus, Loki, Jaeger etc.) and creates dashboards.

```
Grafana → queries → Prometheus → displays → charts/graphs/alerts
```

It does NOT store data — Prometheus stores, Grafana visualizes.

---

### Grafana Key Concepts

| Concept | What it is |
|---------|-----------|
| Data Source | Where data comes from (Prometheus, Loki, MySQL etc.) |
| Panel | Single chart/visualization |
| Dashboard | Collection of panels |
| Provisioning | Auto-configure data sources + dashboards via config files |
| Alerting | Send notifications when metrics cross thresholds |

---

### How We Auto-Provision in Our Project

Instead of manually adding Prometheus in UI, we use config files:

```yaml
# grafana-datasources ConfigMap
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus.monitoring.svc.cluster.local:9090
    isDefault: true
```

When Grafana starts → reads this file → automatically connects to Prometheus.
No manual clicks needed.

---

### Dashboard JSON

Grafana dashboards are stored as JSON. We pre-load our Product Catalog
dashboard via ConfigMap — it appears automatically on first login.

Our dashboard panels:
```
HTTP Request Rate     → rate(http_server_requests_seconds_count[1m])
Response Time p95     → histogram_quantile(0.95, ...)
JVM Heap Memory       → jvm_memory_used_bytes{area="heap"}
Error Rate            → requests with status 4xx/5xx
Active Threads        → jvm_threads_live_threads
GC Pause Time         → jvm_gc_pause_seconds_sum
```

---

## SECTION 5 — How All Three Work Together

```
Spring Boot app (backend pod)
      │
      │ OTLP gRPC port 4317
      ↓
OTEL Collector (monitoring namespace)
      │
      │ Exposes /metrics on port 8889
      ↓
Prometheus (scrapes every 15s)
      │
      │ Stores time-series data
      ↓
Grafana (queries Prometheus)
      │
      │ Renders charts
      ↓
Your browser (dashboard)
```

Also directly:
```
Spring Boot → /actuator/prometheus → Prometheus scrapes directly
```
This gives JVM metrics even without OTEL agent.

---

## SECTION 6 — Interview Questions & Answers

### OpenTelemetry Questions

**Q: What is OpenTelemetry and why is it used?**
A: OpenTelemetry is a vendor-neutral open-source framework for collecting
metrics, traces, and logs. It's used because it provides a single standard
for instrumentation — you instrument once and can export to any backend
(Prometheus, Jaeger, Datadog) without changing code.

**Q: What is the difference between OTEL SDK and OTEL Agent?**
A: The SDK requires manual instrumentation — you add code to create spans.
The Agent uses bytecode instrumentation to auto-instrument at JVM startup
without any code changes. For Spring Boot, the agent is preferred.

**Q: What is OTLP?**
A: OpenTelemetry Protocol — the wire protocol used to send telemetry data
between OTEL components. Supports gRPC (port 4317) and HTTP (port 4318).
gRPC is faster and preferred for high-throughput environments.

**Q: What is the OTEL Collector and why not send directly to Prometheus?**
A: The Collector acts as a pipeline — receives from multiple sources,
processes (batching, filtering, enriching), and exports to multiple backends.
Benefits: decoupling (app doesn't need to know about backends), batching
(improves performance), and fan-out (send to multiple backends simultaneously).

**Q: What does `OTEL_INSTRUMENTATION_MICROMETER_ENABLED=true` do?**
A: Spring Boot uses Micrometer internally for metrics. This setting bridges
Micrometer metrics into OTEL, so JVM, HTTP, and DB metrics captured by
Micrometer are also sent through the OTEL pipeline.

---

### Prometheus Questions

**Q: What is the difference between Prometheus and traditional monitoring tools?**
A: Traditional tools (Nagios, Zabbix) use push model — agents push data to server.
Prometheus uses pull model — it scrapes targets at intervals. Pull model is
easier to configure centrally and better for dynamic environments like Kubernetes.

**Q: What is a scrape interval?**
A: How often Prometheus calls the metrics endpoint. We use 15 seconds — meaning
Prometheus checks `/actuator/prometheus` every 15 seconds and stores the values.

**Q: What is the difference between Counter and Gauge?**
A: Counter only goes up (total requests, total errors). Gauge goes up and down
(current memory usage, active connections). Never use rate() on a Gauge —
only on Counters.

**Q: What is `rate()` in PromQL?**
A: Calculates per-second rate of increase of a counter over a time window.
`rate(http_requests_total[1m])` = average requests per second over last 1 minute.
Essential because raw counter values aren't useful — the rate is.

**Q: What is `histogram_quantile()`?**
A: Calculates percentile from a histogram metric.
`histogram_quantile(0.95, ...)` = p95 response time — 95% of requests
complete within this time. Better than average because it shows tail latency.

**Q: What is a Prometheus target and how does service discovery work?**
A: A target is an endpoint Prometheus scrapes. In our project we use static
config. In production, Prometheus uses Kubernetes service discovery —
automatically finds pods with specific annotations and scrapes them.

**Q: What is retention in Prometheus?**
A: How long Prometheus keeps data. We set `--storage.tsdb.retention.time=7d`
— keeps 7 days. After 7 days old data is deleted. For long-term storage,
use Thanos or Cortex on top of Prometheus.

---

### Grafana Questions

**Q: What is the difference between Grafana and Prometheus UI?**
A: Prometheus UI is basic — good for ad-hoc queries and debugging.
Grafana is a full visualization platform — supports multiple data sources,
beautiful dashboards, alerting, and team sharing. Production monitoring
always uses Grafana, not Prometheus UI directly.

**Q: What is provisioning in Grafana?**
A: Automatically configuring Grafana via config files instead of the UI.
Data sources and dashboards can be provisioned via YAML/JSON files mounted
as ConfigMaps. This makes Grafana configuration reproducible and version-controlled.

**Q: What is the difference between a Panel and a Dashboard?**
A: A panel is a single visualization (one chart). A dashboard is a collection
of panels organized on a page. A panel has one query; a dashboard can have
20+ panels showing different metrics.

**Q: How would you set up an alert in Grafana?**
A: In Grafana → Alerting → Alert Rules → Create rule → Set condition
(e.g., error rate > 5%) → Set evaluation interval → Add notification channel
(email, Slack, PagerDuty). Alert fires when condition is met for the duration.

**Q: What is the difference between Grafana and Kibana?**
A: Grafana is primarily for metrics (time-series data from Prometheus).
Kibana is primarily for logs (from Elasticsearch). Grafana now supports logs
via Loki, making it a unified observability platform. Many teams use Grafana
for everything.

---

### Architecture Questions

**Q: Explain the observability stack in your project.**
A: Our Spring Boot backend uses the OTEL Java agent which auto-instruments
all HTTP requests and JVM metrics. The agent sends data via OTLP gRPC to
the OTEL Collector running in the monitoring namespace. The collector exports
metrics in Prometheus format on port 8889. Prometheus scrapes both the
collector and the Spring Boot actuator endpoint directly every 15 seconds.
Grafana connects to Prometheus as a data source and displays a pre-provisioned
dashboard showing HTTP request rates, response times, JVM heap, and error rates.

**Q: Why run OTEL Collector instead of sending directly from app to Prometheus?**
A: Three reasons: 1) Decoupling — app doesn't need to know about Prometheus
format or address. 2) Fan-out — in Phase 2 we add Jaeger for traces without
changing the app — just add a Jaeger exporter to the collector. 3) Processing
— the collector batches, filters, and enriches data before exporting, reducing
load on the backend systems.

**Q: How do you handle monitoring when pods restart and lose data?**
A: Prometheus stores data externally — pod restarts don't lose historical data
because it's stored on the Prometheus pod's volume. However in our setup we
use `emptyDir` which is lost on restart. For production, use a PersistentVolume
or remote storage like Amazon Managed Prometheus (AMP) which persists data
outside the cluster.

**Q: What metrics would you monitor for a production Spring Boot app?**
A: Five key areas:
1. **Request rate** — `rate(http_server_requests_seconds_count[1m])`
2. **Error rate** — requests with 4xx/5xx status codes
3. **Latency** — p95/p99 response times
4. **JVM health** — heap usage, GC pause time, thread count
5. **Resource usage** — pod CPU and memory from K8s metrics

---

## SECTION 7 — Key Terms Quick Reference

| Term | One-line definition |
|------|-------------------|
| Observability | Ability to understand system internals from external outputs |
| Metrics | Numeric measurements over time (counters, gauges) |
| Traces | Record of a request's journey through the system |
| Logs | Text records of events with timestamps |
| Span | Single unit of work in a trace (one function call) |
| OTLP | OpenTelemetry Protocol — wire format for telemetry data |
| Scraping | Prometheus polling an endpoint to collect metrics |
| Cardinality | Number of unique label combinations — high cardinality = slow Prometheus |
| PromQL | Prometheus Query Language |
| Time series | Sequence of data points indexed by time |
| Retention | How long data is kept before deletion |
| Provisioning | Auto-configuring tools via config files |
| Data source | Where Grafana reads data from |
| SLI | Service Level Indicator — metric that measures service health |
| SLO | Service Level Objective — target value for an SLI |
| SLA | Service Level Agreement — contract with users about uptime |

---

## SECTION 8 — Golden Signals (Must Know for Interviews)

Google SRE defined 4 golden signals every service should monitor:

| Signal | What it measures | Our metric |
|--------|-----------------|-----------|
| **Latency** | How long requests take | `histogram_quantile(0.95, ...)` |
| **Traffic** | How much demand | `rate(http_requests_total[1m])` |
| **Errors** | Rate of failed requests | `rate(http_requests_total{status=~"5.."}[1m])` |
| **Saturation** | How full the system is | JVM heap %, CPU % |

> *"If you can only monitor 4 things — monitor the golden signals."*

---

## SECTION 9 — Comparison Table

| Tool | Type | Made by | Stores data? | Visualizes? |
|------|------|---------|-------------|------------|
| OpenTelemetry | Framework | CNCF | ❌ No | ❌ No |
| OTEL Collector | Pipeline | CNCF | ❌ No | ❌ No |
| Prometheus | Time-series DB | CNCF | ✅ Yes | Basic |
| Grafana | Visualization | Grafana Labs | ❌ No | ✅ Yes |
| Jaeger | Trace storage | CNCF | ✅ Yes | ✅ Yes |
| Loki | Log storage | Grafana Labs | ✅ Yes | Via Grafana |
| Datadog | All-in-one | Datadog | ✅ Yes | ✅ Yes |
| New Relic | All-in-one | New Relic | ✅ Yes | ✅ Yes |

---

## SECTION 10 — What to Say in Interviews

### Short Version (30 seconds)
> *"In our project we use OpenTelemetry for instrumentation, Prometheus for
> metric storage, and Grafana for visualization. The OTEL Java agent
> auto-instruments the Spring Boot app with zero code changes, sends data
> to the OTEL Collector, which exports to Prometheus. Grafana queries
> Prometheus and shows dashboards for HTTP rates, latency, JVM health, and errors."*

### Detailed Version (2 minutes)
> *"Our observability stack follows the CNCF standard. The Spring Boot backend
> uses the OpenTelemetry Java agent v2.2 which hooks into the JVM at startup
> and auto-instruments all HTTP requests, JDBC queries, and JVM internals
> without any code changes. Data is sent via OTLP gRPC on port 4317 to an
> OTEL Collector deployed as a Kubernetes Deployment in the monitoring namespace.
> The collector receives, batches, and exports metrics in Prometheus exposition
> format on port 8889. Prometheus scrapes both the collector and the Spring Boot
> actuator endpoint directly every 15 seconds using static service discovery.
> Grafana connects to Prometheus as a data source and has a pre-provisioned
> dashboard via ConfigMap showing the four golden signals — traffic, latency,
> errors, and saturation. All three components run as Kubernetes Deployments
> in the monitoring namespace and are deployed automatically as part of the
> infrastructure pipeline."*

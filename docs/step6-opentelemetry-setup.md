# Step 6 — OpenTelemetry Phase 1: Observability Setup

## Overview

```
Spring Boot Backend
      ↓ (OTEL Java Agent — auto-instruments, zero code changes)
OTEL Collector (receives OTLP metrics + traces)
      ↓
Prometheus (scrapes + stores metrics)
      ↓
Grafana (visualizes dashboards)
```

---

## What Was Changed

| File | Change |
|------|--------|
| `backend/Dockerfile` | Downloads OTEL Java agent v2.2.0, starts app with `-javaagent` |
| `k8s/backend-deployment.yaml` | Added OTEL env vars (service name, collector URL, protocol) |
| `backend/build.gradle` | Added `micrometer-registry-prometheus` dependency |
| `backend/src/main/resources/application.properties` | Prometheus actuator endpoint already enabled |

---

## New Files Created

```
k8s/monitoring/
├── namespace.yaml        ← monitoring namespace
├── otel-collector.yaml   ← OTEL Collector Deployment + Service + ConfigMap
├── prometheus.yaml       ← Prometheus Deployment + Service + ConfigMap
└── grafana.yaml          ← Grafana Deployment + Service + ConfigMap + Dashboard
```

---

## Part A — Deploy Monitoring Stack

### Step 1 — Apply all monitoring manifests

```bash
# Create namespace first
kubectl apply -f k8s/monitoring/namespace.yaml

# Deploy OTEL Collector
kubectl apply -f k8s/monitoring/otel-collector.yaml

# Deploy Prometheus
kubectl apply -f k8s/monitoring/prometheus.yaml

# Deploy Grafana
kubectl apply -f k8s/monitoring/grafana.yaml
```

Or apply all at once:
```bash
kubectl apply -f k8s/monitoring/
```

### Step 2 — Verify all pods are running

```bash
kubectl get pods -n monitoring
```

Expected:
```
NAME                              READY   STATUS    AGE
otel-collector-xxx                1/1     Running   1m
prometheus-xxx                    1/1     Running   1m
grafana-xxx                       1/1     Running   1m
```

### Step 3 — Get Grafana URL

```bash
kubectl get svc grafana -n monitoring
```

Output:
```
NAME      TYPE           CLUSTER-IP    EXTERNAL-IP                    PORT(S)
grafana   LoadBalancer   172.20.x.x    xxx.ap-south-1.elb.amazonaws.com   80:xxx/TCP
```

Open: `http://xxx.ap-south-1.elb.amazonaws.com`

---

## Part B — Access Grafana

### Login Credentials
```
Username: admin
Password: admin123
```

> Change the password after first login in production.

### Pre-built Dashboard
A "Product Catalog - Application Metrics" dashboard is automatically provisioned.

Navigate to: **Dashboards → Product Catalog → Product Catalog - Application Metrics**

---

## Part C — Deploy Updated Backend

Push code to GitHub to trigger the pipeline:

```bash
git add .
git commit -m "Add OpenTelemetry observability - Phase 1"
git push origin main
```

The pipeline will:
1. Build new backend image with OTEL agent
2. Push to ECR
3. Deploy to EKS with OTEL env vars

---

## Part D — Verify Metrics are Flowing

### Check Prometheus is scraping correctly

```bash
# Port-forward Prometheus UI
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
```

Open: `http://localhost:9090`

1. Go to **Status → Targets**
2. You should see:
   - `product-catalog-backend` → UP ✅
   - `otel-collector` → UP ✅

### Test a metric query in Prometheus

In the Prometheus UI query box, type:
```
http_server_requests_seconds_count
```
Click **Execute** → you should see data.

---

## Part E — Grafana Dashboard Panels Explained

| Panel | Metric | What it shows |
|-------|--------|--------------|
| HTTP Request Rate | `http_server_requests_seconds_count` | Requests per second |
| Response Time p95 | `http_server_requests_seconds_bucket` | 95th percentile latency |
| JVM Heap Memory | `jvm_memory_used_bytes` | RAM used by the app |
| Error Rate | `http_server_requests_seconds_count{status=~"4..\|5.."}` | 4xx + 5xx errors |
| Active Threads | `jvm_threads_live_threads` | Current thread count |
| GC Pause Time | `jvm_gc_pause_seconds_sum` | Garbage collection impact |

---

## Part F — How OTEL Java Agent Works

```
java -javaagent:/app/opentelemetry-javaagent.jar -jar app.jar
         ↓
Agent hooks into JVM at startup
         ↓
Auto-instruments:
  - All HTTP requests/responses
  - Spring Boot internals
  - H2 database queries
  - JVM metrics (heap, GC, threads)
         ↓
Sends data via OTLP gRPC to:
  http://otel-collector.monitoring.svc.cluster.local:4317
```

Zero code changes to your Java files — the agent does everything automatically.

---

## Part G — OTEL Env Vars Explained

| Variable | Value | Purpose |
|----------|-------|---------|
| `OTEL_SERVICE_NAME` | `product-catalog-backend` | Identifies the service in metrics/traces |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://otel-collector:4317` | Where to send telemetry data |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | Protocol for sending data |
| `OTEL_METRICS_EXPORTER` | `otlp` | Send metrics via OTLP |
| `OTEL_TRACES_EXPORTER` | `otlp` | Send traces via OTLP |
| `OTEL_LOGS_EXPORTER` | `none` | Logs disabled (Phase 2) |
| `OTEL_INSTRUMENTATION_MICROMETER_ENABLED` | `true` | Bridge Spring Boot Micrometer metrics to OTEL |

---

## Part H — Port Forward for Local Access

If you don't want LoadBalancer for Grafana (save cost):

```bash
# Access Grafana locally
kubectl port-forward svc/grafana 3001:80 -n monitoring
# Open: http://localhost:3001

# Access Prometheus locally
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Grafana shows "No data" | Wait 2-3 min after deploy for metrics to flow |
| Prometheus target DOWN | Check backend pod is running: `kubectl get pods -n product-catalog` |
| OTEL agent not connecting | Check env vars in pod: `kubectl describe pod <backend-pod> -n product-catalog` |
| Grafana LoadBalancer pending | Wait 2-3 min for AWS NLB to provision |
| Pod OOMKilled | OTEL agent uses ~50MB extra RAM — increase memory limit in deployment |

---

## Useful Commands

```bash
# Check OTEL collector logs
kubectl logs -f deployment/otel-collector -n monitoring

# Check Prometheus logs
kubectl logs -f deployment/prometheus -n monitoring

# Check Grafana logs
kubectl logs -f deployment/grafana -n monitoring

# Check backend OTEL connection
kubectl logs -f deployment/backend -n product-catalog | grep -i otel

# Check all monitoring pods
kubectl get pods -n monitoring -w

# Restart monitoring stack
kubectl rollout restart deployment -n monitoring
```

---

## Phase 2 — Coming Next

Phase 2 will add:
- **Jaeger** — distributed tracing (see exact request path through the code)
- **Loki** — log aggregation (search logs in Grafana)
- **Alertmanager** — alerts via email/Slack when metrics exceed thresholds

---

## Checklist

- [ ] `kubectl apply -f k8s/monitoring/` completed
- [ ] All 3 pods Running in monitoring namespace
- [ ] Grafana LoadBalancer URL accessible
- [ ] Login with admin/admin123
- [ ] Product Catalog dashboard visible
- [ ] Pipeline triggered with new backend image
- [ ] Prometheus targets showing UP
- [ ] Metrics visible in Grafana panels

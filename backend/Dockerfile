# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Copy gradle wrapper and build files first (layer caching)
COPY gradle/ gradle/
COPY gradlew .
COPY build.gradle .
COPY settings.gradle .

# Make gradlew executable
RUN chmod +x gradlew

# Download dependencies (cached if build files unchanged)
RUN ./gradlew dependencies --no-daemon

# Copy source code
COPY src/ src/

# Build the fat jar (skip tests in Docker build — tests run in Jenkins)
RUN ./gradlew bootJar --no-daemon -x test

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Download OpenTelemetry Java Agent
# The agent auto-instruments Spring Boot — no code changes needed
RUN wget -q https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.2.0/opentelemetry-javaagent.jar \
    -O /app/opentelemetry-javaagent.jar

# Copy jar from builder stage
COPY --from=builder /app/build/libs/product-catalog.jar app.jar

# Change ownership to non-root user
RUN chown appuser:appgroup app.jar opentelemetry-javaagent.jar

USER appuser

# Expose backend port
EXPOSE 8080

# Health check for Docker / K8s
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/products/health || exit 1

# Start app with OTEL Java agent attached
# OTEL config is passed via env vars in backend-deployment.yaml
ENTRYPOINT ["java", \
  "-javaagent:/app/opentelemetry-javaagent.jar", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]

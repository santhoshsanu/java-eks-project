# DevOps & Cloud Engineer — Interview Guide
## Product Catalog Project (Spring Boot + React + EKS)

---

## SECTION 1 — Gradle (Build Tool)

### What is Gradle?
Gradle is a build automation tool for Java projects.
It compiles code, runs tests, and packages the app into a JAR file.
Think of it as the tool that turns your Java source code into a runnable artifact.

### Key Commands You Must Know

| Command | What it does | When used |
|---------|-------------|-----------|
| `./gradlew build` | Compile + test + package JAR | Full build |
| `./gradlew build -x test` | Compile + package, skip tests | Docker build stage |
| `./gradlew bootRun` | Build and run locally | Local development |
| `./gradlew test` | Run unit tests only | CI pipeline test stage |
| `./gradlew clean` | Delete build/ folder | Before fresh build |
| `./gradlew clean build` | Clean then full build | Pipeline |
| `./gradlew dependencies` | Show dependency tree | Debugging |
| `./gradlew bootJar` | Build executable fat JAR | Docker image creation |

### What is a Fat JAR?
A fat JAR (also called uber JAR) contains:
- Your compiled application code
- ALL dependencies (Spring Boot, H2, Hibernate etc.)
- Embedded Tomcat web server

Result: one self-contained file you can run anywhere with `java -jar app.jar`

### build.gradle — Key Sections
```groovy
plugins {
    id 'org.springframework.boot' version '3.2.3'  // Spring Boot plugin
    id 'java'                                        // Java compilation
}
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'  // REST API
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'  // Database
    runtimeOnly 'com.h2database:h2'  // In-memory DB
}
bootJar {
    archiveFileName = 'product-catalog.jar'  // Output JAR name
}
```

### Common Interview Questions on Gradle

**Q: What is the difference between `build` and `bootJar`?**
A: `build` runs the full lifecycle (compile + test + jar). `bootJar` only creates the executable Spring Boot JAR without running tests.

**Q: Why do we use `./gradlew` instead of `gradle`?**
A: The Gradle wrapper (`gradlew`) ensures everyone uses the exact same Gradle version defined in `gradle-wrapper.properties`. No need to install Gradle globally — the wrapper downloads it automatically.

**Q: What is `gradle-wrapper.jar` and why is it committed to Git?**
A: It's the bootstrap JAR that downloads the correct Gradle version. It must be in Git so CI/CD pipelines (GitHub Actions) can build without Gradle pre-installed.

**Q: Why do we skip tests in Docker build (`-x test`)?**
A: Tests are already run in the pipeline as a separate stage. Running them again in Docker build slows down image creation. Tests run on source code; Docker builds the already-tested artifact.

---

## SECTION 2 — Spring Boot Backend

### What is Spring Boot?
Spring Boot is a Java framework for building REST APIs quickly.
It comes with an embedded Tomcat server — no need to deploy to an external server.

### Project Structure You Should Understand
```
src/main/java/com/sample/app/
├── ProductCatalogApplication.java  ← Entry point (@SpringBootApplication)
├── model/Product.java              ← Database entity (maps to PRODUCTS table)
├── repository/ProductRepository.java ← Database queries (extends JpaRepository)
├── service/ProductService.java     ← Business logic
└── controller/ProductController.java ← REST API endpoints (@RestController)
```

### REST API Endpoints
| Method | URL | What it does |
|--------|-----|-------------|
| GET | `/api/products` | Get all products |
| GET | `/api/products?search=iphone` | Search products |
| GET | `/api/products?category=Electronics` | Filter by category |
| GET | `/api/products/{id}` | Get single product |
| POST | `/api/products` | Create new product |
| PUT | `/api/products/{id}` | Update product |
| DELETE | `/api/products/{id}` | Delete product |
| GET | `/api/products/health` | Health check (used by K8s probes) |

### H2 In-Memory Database
- Data lives in RAM — resets every restart
- Used for development/testing only
- In production → replace with RDS PostgreSQL
- Console: `http://localhost:8080/h2-console`

### application.properties — Key Settings
```properties
server.port=8080                    # port the app listens on
spring.datasource.url=jdbc:h2:mem:productdb  # H2 in-memory DB
spring.jpa.hibernate.ddl-auto=create-drop    # creates tables on start
spring.sql.init.mode=always                  # loads data.sql on start
spring.h2.console.enabled=true              # H2 web console
```

### Common Interview Questions on Spring Boot

**Q: What is `@RestController`?**
A: Marks a class as a REST API controller. Combines `@Controller` + `@ResponseBody` — automatically serializes return values to JSON.

**Q: What is `@CrossOrigin(origins = "*")`?**
A: Allows the frontend (running on port 3000) to call the backend (port 8080). Without this, browsers block cross-origin requests (CORS policy). In production, restrict to your actual domain.

**Q: What port does the backend run on?**
A: 8080 (configured in application.properties). In Docker/K8s the container exposes port 8080.

**Q: How does data.sql work?**
A: Spring Boot automatically runs `data.sql` on startup when `spring.sql.init.mode=always`. This pre-loads the 12 sample products into H2.

**Q: What is the health endpoint used for?**
A: `/api/products/health` is called by Kubernetes liveness and readiness probes to check if the app is running correctly.

---

## SECTION 3 — React Frontend

### What is React?
React is a JavaScript library for building user interfaces. 
As a DevOps engineer you don't need to write React — but you need to understand how it builds and runs.

### What is Vite?
Vite is the build tool for the frontend (equivalent of Gradle for Java).
- `npm run dev` → starts local dev server on port 3000
- `npm run build` → produces optimized static files in `dist/` folder
- The `dist/` folder is what gets served by Nginx in Docker

### Build Output
```
npm run build
      ↓
dist/
├── index.html      ← single HTML file
├── assets/
│   ├── index-xxx.js   ← all JavaScript bundled
│   └── index-xxx.css  ← all CSS bundled
```

### How Frontend Talks to Backend
```
Browser → React app calls /api/products
                ↓
        Vite proxy (dev) or Nginx (prod)
                ↓
        Spring Boot on :8080
```

**Local dev:** Vite proxy in `vite.config.js` forwards `/api/*` to `localhost:8080`
**Production (EKS):** Nginx in the frontend container proxies `/api/*` to backend service

### VITE_API_URL Environment Variable
```javascript
const BASE_URL = import.meta.env.VITE_API_URL || ''
```
- Local: empty string → uses Vite proxy
- EKS: injected via Docker build arg → points to backend service URL
- This is how frontend knows where the backend is in different environments

### Common Interview Questions on Frontend

**Q: What does `npm run build` produce?**
A: Static files (HTML, JS, CSS) in the `dist/` folder. These are served by Nginx.

**Q: Why do we use Nginx to serve the frontend?**
A: Nginx is a lightweight, high-performance web server. It serves static files efficiently and can proxy API calls to the backend. Node.js dev server is not suitable for production.

**Q: What is the SPA routing problem and how does nginx.conf solve it?**
A: React is a Single Page Application — all routes are handled by JavaScript. If you refresh on `/products/123`, Nginx would look for a file called `products/123` which doesn't exist. The fix: `try_files $uri $uri/ /index.html` — always serve index.html and let React handle routing.

**Q: What is CORS?**
A: Cross-Origin Resource Sharing. Browser security policy that blocks requests from one origin (localhost:3000) to another (localhost:8080). Solved by `@CrossOrigin` on the backend.

---

## SECTION 4 — Docker (Most Important for DevOps)

### Multi-Stage Backend Dockerfile Explained
```dockerfile
# Stage 1 — Build
FROM eclipse-temurin:17-jdk-alpine AS builder
COPY . .
RUN ./gradlew bootJar    # produces product-catalog.jar

# Stage 2 — Runtime (smaller image)
FROM eclipse-temurin:17-jre-alpine
COPY --from=builder /app/build/libs/product-catalog.jar app.jar
USER appuser              # non-root for security
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Why multi-stage?**
- Builder image has JDK (600MB+) — needed to compile
- Runtime image has only JRE (200MB) — needed to run
- Final image is much smaller = faster pulls, less attack surface

### Common Interview Questions on Docker

**Q: What is the difference between JDK and JRE?**
A: JDK (Java Development Kit) includes compiler + runtime. JRE (Java Runtime Environment) is runtime only. We use JDK to build, JRE to run — smaller final image.

**Q: Why run as non-root in Docker?**
A: Security best practice. If the container is compromised, attacker has limited privileges. Root inside container = root on host if container escapes.

**Q: What does `HEALTHCHECK` in Dockerfile do?**
A: Docker periodically calls the health endpoint. If it fails, Docker marks the container unhealthy. K8s uses its own probes (liveness/readiness) which are more powerful.

**Q: Why `--no-cache` in `docker build`?**
A: Forces Docker to rebuild all layers fresh. Used in CI to avoid stale cached layers. Without it, Docker might use a cached layer with old code.

---

## SECTION 5 — The Pipeline Flow (Most Asked in Interviews)

### GitHub Actions Pipeline — What Happens on Every Push

```
git push to main
      ↓
Job 1: build-and-test
  - actions/setup-java@v4    → installs Java 17
  - ./gradlew clean build    → compiles code
  - ./gradlew test           → runs unit tests
  - upload JAR as artifact
      ↓
Job 2: docker-build-scan-push
  - download JAR artifact
  - configure AWS credentials
  - aws ecr get-login-password | docker login
  - docker build backend → backend:build-42
  - docker build frontend → frontend:build-42
  - trivy image scan → report saved
  - docker push to ECR
      ↓
Job 3: deploy-to-eks
  - aws eks update-kubeconfig
  - kubectl apply namespace + configmap
  - sed replaces IMAGE_TAG with build-42
  - kubectl apply deployments + ingress + hpa
  - kubectl rollout status (waits for deploy)
  - kubectl get ingress → prints ALB URL
```

### Common Interview Questions on CI/CD

**Q: What is the difference between CI and CD?**
A: CI (Continuous Integration) = automatically build and test on every commit. CD (Continuous Deployment) = automatically deploy to production after CI passes.

**Q: What is a build number and why is it important?**
A: Unique identifier for each pipeline run (`github.run_number`). Used to tag Docker images (`build-42`). Allows you to roll back to any previous version by deploying that specific tag.

**Q: How does GitHub Actions authenticate with AWS?**
A: Via `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` stored as GitHub Secrets. The `aws-actions/configure-aws-credentials` action sets these as environment variables for the job.

**Q: What is Trivy?**
A: Open-source container vulnerability scanner by Aqua Security. Scans Docker images for known CVEs (Common Vulnerabilities and Exposures). We scan for CRITICAL and HIGH severity issues.

**Q: What happens if Trivy finds a vulnerability?**
A: In our pipeline `continue-on-error: true` — it reports but doesn't fail the build. In production you'd set this to false to block deployments with CRITICAL vulnerabilities.

**Q: How does `sed` work in the deploy step?**
A: `sed "s|IMAGE_TAG|build-42|g"` replaces the placeholder text `IMAGE_TAG` in the K8s YAML with the actual build number before applying. This avoids hardcoding image tags in the manifest files.

---

## SECTION 6 — Kubernetes Concepts (Critical for DevOps)

### Resources in Our Project

**Deployment** — manages pods
```yaml
replicas: 1               # number of pod copies
image: ECR_URL:build-42   # which Docker image to run
resources:
  requests: cpu:200m memory:256Mi   # minimum guaranteed
  limits:   cpu:500m memory:512Mi   # maximum allowed
```

**Service (ClusterIP)** — internal networking
```yaml
type: ClusterIP    # only accessible inside the cluster
port: 80           # service port
targetPort: 8080   # container port
```

**Ingress (ALB)** — external access
```yaml
/api/*  → backend-service   # API calls go to Spring Boot
/*      → frontend-service  # everything else goes to React
```

**HPA** — auto scaling
```yaml
minReplicas: 1
maxReplicas: 4
averageUtilization: 70   # scale up when CPU > 70%
```

### Common Interview Questions on K8s

**Q: What is the difference between a Deployment and a Pod?**
A: A Pod is a single instance of your container. A Deployment manages multiple pods, handles rolling updates, and ensures the desired number of replicas are always running.

**Q: What is a liveness probe vs readiness probe?**
A: Liveness = is the app alive? If fails → restart the pod. Readiness = is the app ready to receive traffic? If fails → remove from load balancer rotation but don't restart.

**Q: What is a rolling update?**
A: Kubernetes replaces pods one at a time. New pod starts → health check passes → old pod removed. Zero downtime during deployment.

**Q: What is `kubectl rollout status`?**
A: Waits until a deployment finishes rolling out. Used in pipeline to confirm deployment completed before marking the job as success.

**Q: What is a namespace?**
A: Logical isolation within a cluster. Our app runs in `product-catalog` namespace, system components run in `kube-system`. Prevents resource name collisions.

---

## SECTION 7 — Quick Reference Cheat Sheet

### Daily Commands
```bash
# Local development
./gradlew bootRun              # start backend
npm run dev                    # start frontend

# Build
./gradlew clean build          # full build with tests
./gradlew build -x test        # build without tests

# Docker
docker build -t app:latest .   # build image
docker run -p 8080:8080 app    # run container

# Kubernetes
kubectl get pods -n product-catalog        # list pods
kubectl get svc -n product-catalog         # list services
kubectl get ingress -n product-catalog     # get ALB URL
kubectl logs -f <pod-name> -n product-catalog  # tail logs
kubectl describe pod <pod-name>            # debug pod issues
kubectl rollout restart deployment/backend # force redeploy

# AWS
aws eks update-kubeconfig --region ap-south-1 --name java-eks-cluster
aws ecr describe-repositories             # list ECR repos
aws ecr list-images --repository-name java-eks-backend  # list images
```

---

## Key Takeaways for Interviews

1. **You don't need to write Java or React** — understand the build process, ports, and how components connect
2. **Gradle = build tool** — produces JAR → JAR goes into Docker image → Docker image runs on EKS
3. **`./gradlew bootJar`** is what the Dockerfile runs — produces the fat JAR
4. **Port 8080** = backend, **Port 80** = frontend (Nginx), **Port 3000** = local dev only
5. **Health endpoint** `/api/products/health` = K8s liveness/readiness probe target
6. **Multi-stage Docker build** = smaller, secure images
7. **IMAGE_TAG** in K8s manifests = replaced by `sed` in pipeline with actual build number
8. **GitHub Secrets** = secure way to pass AWS credentials to pipeline
9. **Trivy** = scans images before pushing to ECR
10. **HPA** = Kubernetes auto-scaler based on CPU/memory metrics

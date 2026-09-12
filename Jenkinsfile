pipeline {
    agent any

    // ── Environment Variables ─────────────────────────────────────────────────
    environment {
        // AWS config
        AWS_REGION          = 'ap-south-1'
        AWS_ACCOUNT_ID      = '889951088124'
        ECR_REGISTRY        = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        // ECR repo names (must match terraform ecr.tf)
        BACKEND_REPO        = 'java-eks-backend'
        FRONTEND_REPO       = 'java-eks-frontend'

        // EKS cluster
        EKS_CLUSTER_NAME    = 'java-eks-cluster'

        // K8s namespace
        K8S_NAMESPACE       = 'product-catalog'

        // Image tags — BUILD_NUMBER is auto-injected by Jenkins
        BACKEND_IMAGE       = "${ECR_REGISTRY}/${BACKEND_REPO}:build-${BUILD_NUMBER}"
        FRONTEND_IMAGE      = "${ECR_REGISTRY}/${FRONTEND_REPO}:build-${BUILD_NUMBER}"

        // Trivy severity threshold — fail build if CRITICAL vulns found
        TRIVY_SEVERITY      = 'CRITICAL,HIGH'

        // Git repo (update with your GitHub repo URL)
        GIT_REPO_URL        = 'https://github.com/santhoshsanu/java-eks-project.git'
    }

    // ── Build Options ─────────────────────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))   // keep last 10 builds
        timeout(time: 45, unit: 'MINUTES')               // fail if pipeline runs > 45 min
        timestamps()                                      // add timestamps to all logs
        disableConcurrentBuilds()                         // prevent parallel builds on same branch
    }

    // ── Triggers ──────────────────────────────────────────────────────────────
    triggers {
        // Poll GitHub every 2 minutes (replace with webhook for production)
        pollSCM('H/2 * * * *')
    }

    // ── Stages ────────────────────────────────────────────────────────────────
    stages {

        // ── Stage 1: Checkout ─────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                echo "========== STAGE 1: CHECKOUT =========="
                echo "Build Number : ${BUILD_NUMBER}"
                echo "Branch       : ${GIT_BRANCH}"
                echo "Workspace    : ${WORKSPACE}"
                checkout scm
            }
        }

        // ── Stage 2: Build Backend ────────────────────────────────────────────
        stage('Build Backend') {
            steps {
                echo "========== STAGE 2: BUILD BACKEND (GRADLE) =========="
                dir('backend') {
                    sh 'chmod +x gradlew'
                    sh './gradlew clean build --no-daemon'
                    echo "Backend JAR built successfully"
                }
            }
            post {
                success {
                    // Archive the built JAR for reference
                    archiveArtifacts artifacts: 'backend/build/libs/*.jar',
                                     fingerprint: true,
                                     allowEmptyArchive: false
                }
            }
        }

        // ── Stage 3: Unit Tests ───────────────────────────────────────────────
        stage('Unit Tests') {
            steps {
                echo "========== STAGE 3: UNIT TESTS =========="
                dir('backend') {
                    sh './gradlew test --no-daemon'
                }
            }
            post {
                always {
                    // Publish JUnit test results
                    junit testResults: 'backend/build/test-results/**/*.xml',
                          allowEmptyResults: true
                }
                failure {
                    echo "Unit tests failed — stopping pipeline"
                }
            }
        }

        // ── Stage 4: Docker Build ─────────────────────────────────────────────
        stage('Docker Build') {
            steps {
                echo "========== STAGE 4: DOCKER BUILD =========="
                echo "Building backend image  : ${BACKEND_IMAGE}"
                echo "Building frontend image : ${FRONTEND_IMAGE}"

                // Build backend image
                sh """
                    docker build \
                        --no-cache \
                        --tag ${BACKEND_IMAGE} \
                        --tag ${ECR_REGISTRY}/${BACKEND_REPO}:latest \
                        ./backend
                """

                // Build frontend image
                sh """
                    docker build \
                        --no-cache \
                        --build-arg VITE_API_URL="" \
                        --tag ${FRONTEND_IMAGE} \
                        --tag ${ECR_REGISTRY}/${FRONTEND_REPO}:latest \
                        ./frontend
                """

                echo "Docker images built successfully"
            }
        }

        // ── Stage 5: Trivy Security Scan ──────────────────────────────────────
        stage('Trivy Scan') {
            steps {
                echo "========== STAGE 5: TRIVY SECURITY SCAN =========="

                // Scan backend image
                echo "Scanning backend image..."
                sh """
                    trivy image \
                        --exit-code 1 \
                        --severity ${TRIVY_SEVERITY} \
                        --no-progress \
                        --format table \
                        --output trivy-backend-report.txt \
                        ${BACKEND_IMAGE} || true
                """

                // Scan frontend image
                echo "Scanning frontend image..."
                sh """
                    trivy image \
                        --exit-code 1 \
                        --severity ${TRIVY_SEVERITY} \
                        --no-progress \
                        --format table \
                        --output trivy-frontend-report.txt \
                        ${FRONTEND_IMAGE} || true
                """

                // Print reports to console
                sh 'echo "=== BACKEND SCAN REPORT ===" && cat trivy-backend-report.txt'
                sh 'echo "=== FRONTEND SCAN REPORT ===" && cat trivy-frontend-report.txt'
            }
            post {
                always {
                    // Archive Trivy reports as build artifacts
                    archiveArtifacts artifacts: 'trivy-*.txt',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 6: Push to ECR ──────────────────────────────────────────────
        stage('Push to ECR') {
            steps {
                echo "========== STAGE 6: PUSH TO ECR =========="

                // Authenticate Docker to ECR
                sh """
                    aws ecr get-login-password \
                        --region ${AWS_REGION} | \
                    docker login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}
                """

                // Push backend image (build-number tag + latest tag)
                echo "Pushing backend image: ${BACKEND_IMAGE}"
                sh "docker push ${BACKEND_IMAGE}"
                sh "docker push ${ECR_REGISTRY}/${BACKEND_REPO}:latest"

                // Push frontend image (build-number tag + latest tag)
                echo "Pushing frontend image: ${FRONTEND_IMAGE}"
                sh "docker push ${FRONTEND_IMAGE}"
                sh "docker push ${ECR_REGISTRY}/${FRONTEND_REPO}:latest"

                echo "Images pushed to ECR successfully"
            }
        }

        // ── Stage 7: Deploy to EKS ────────────────────────────────────────────
        stage('Deploy to EKS') {
            steps {
                echo "========== STAGE 7: DEPLOY TO EKS =========="
                echo "Deploying build-${BUILD_NUMBER} to EKS cluster: ${EKS_CLUSTER_NAME}"

                // Update kubeconfig so kubectl can talk to EKS
                sh """
                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name ${EKS_CLUSTER_NAME}
                """

                // Apply namespace and configmap
                sh "kubectl apply -f k8s/namespace.yaml"
                sh "kubectl apply -f k8s/configmap.yaml"

                // Replace IMAGE_TAG placeholder with actual build number tag
                // then apply backend and frontend deployments
                sh """
                    sed 's|IMAGE_TAG|build-${BUILD_NUMBER}|g' k8s/backend-deployment.yaml | \
                    kubectl apply -f -
                """

                sh """
                    sed 's|IMAGE_TAG|build-${BUILD_NUMBER}|g' k8s/frontend-deployment.yaml | \
                    kubectl apply -f -
                """

                // Apply ingress and HPA
                sh "kubectl apply -f k8s/ingress.yaml"
                sh "kubectl apply -f k8s/hpa.yaml"

                echo "Manifests applied — waiting for rollout..."

                // Wait for deployments to roll out (max 3 minutes each)
                sh """
                    kubectl rollout status deployment/backend \
                        -n ${K8S_NAMESPACE} \
                        --timeout=180s
                """

                sh """
                    kubectl rollout status deployment/frontend \
                        -n ${K8S_NAMESPACE} \
                        --timeout=180s
                """

                echo "Deployment successful!"
            }
        }

        // ── Stage 8: Verify Deployment ────────────────────────────────────────
        stage('Verify') {
            steps {
                echo "========== STAGE 8: VERIFY DEPLOYMENT =========="

                // Show running pods
                sh "kubectl get pods -n ${K8S_NAMESPACE}"

                // Show services
                sh "kubectl get svc -n ${K8S_NAMESPACE}"

                // Get ALB URL from ingress (may take 1-2 min to provision)
                sh """
                    echo "=== ALB Ingress URL ==="
                    kubectl get ingress -n ${K8S_NAMESPACE} \
                        -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
                    echo ""
                """
            }
        }

    } // end stages

    // ── Post Pipeline Actions ─────────────────────────────────────────────────
    post {

        success {
            echo """
            ╔══════════════════════════════════════════════════════╗
            ║         PIPELINE SUCCESS — BUILD #${BUILD_NUMBER}          ║
            ║  Backend  : ${ECR_REGISTRY}/${BACKEND_REPO}:build-${BUILD_NUMBER}
            ║  Frontend : ${ECR_REGISTRY}/${FRONTEND_REPO}:build-${BUILD_NUMBER}
            ║  Cluster  : ${EKS_CLUSTER_NAME}
            ╚══════════════════════════════════════════════════════╝
            """
        }

        failure {
            echo """
            ╔══════════════════════════════════════════════════════╗
            ║         PIPELINE FAILED — BUILD #${BUILD_NUMBER}           ║
            ║  Check the logs above for the failed stage           ║
            ╚══════════════════════════════════════════════════════╝
            """
        }

        always {
            // Clean up local Docker images to save disk space on Jenkins
            sh """
                docker rmi ${BACKEND_IMAGE}  || true
                docker rmi ${FRONTEND_IMAGE} || true
                docker rmi ${ECR_REGISTRY}/${BACKEND_REPO}:latest  || true
                docker rmi ${ECR_REGISTRY}/${FRONTEND_REPO}:latest || true
            """
            echo "Docker images cleaned from Jenkins server"

            // Clean workspace
            cleanWs()
        }
    }

} // end pipeline

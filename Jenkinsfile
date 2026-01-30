pipeline {
  agent any

  environment {
    IMAGE_NAME        = 'food-delivery'
    SONAR_HOST_URL    = 'http://food-sonarqube:9000'
    SONAR_PROJECT_KEY = 'food-delivery'
    SONAR_TOKEN       = credentials('sonar-token')   // ✅ utilise le credential existant
    DOCKER_NET        = 'food-delivery_food-network'
  }

  stages {

    stage('🔍 Checkout') {
      steps {
        checkout scm
        script {
          env.GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        }
      }
    }

    stage('📦 Install Dependencies') {
      parallel {

        stage('Backend') {
          steps {
            dir('backend') {
              sh '''
                docker run --rm \
                  -v "$PWD:/app" -w /app \
                  node:18-alpine sh -lc "npm ci || npm install"
              '''
            }
          }
        }

        stage('Frontend') {
          steps {
            dir('frontend') {
              sh '''
                docker run --rm \
                  -v "$PWD:/app" -w /app \
                  node:18-alpine sh -lc "npm ci || npm install"
              '''
            }
          }
        }

      }
    }

    stage('🔐 SAST - SonarQube Analysis') {
      steps {
        sh '''
          docker run --rm \
            --network ${DOCKER_NET} \
            -v "$PWD:/usr/src" -w /usr/src \
            sonarsource/sonar-scanner-cli \
            -Dsonar.host.url=${SONAR_HOST_URL} \
            -Dsonar.login=${SONAR_TOKEN} \
            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
            -Dsonar.sources=backend,frontend/src \
            -Dsonar.exclusions=**/node_modules/**,**/dist/**
        '''
      }
    }

    stage('🔍 Quality Gate (simple)') {
      steps {
        sh '''
          echo "Checking SonarQube Quality Gate..."
          curl -s -u "${SONAR_TOKEN}:" \
            "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" \
            | tee qg.json

          if grep -q '"status":"ERROR"' qg.json; then
            echo "❌ Quality Gate FAILED"
            exit 1
          fi
          echo "✅ Quality Gate OK (PASS/WARN)"
        '''
      }
    }

    stage('🐳 Build Docker Images') {
      steps {
        script {
          docker.build("${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT}", "./backend")
          docker.build("${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT}", "./frontend")
        }
      }
    }

    stage('🛡️ Dependency Audit') {
      parallel {

        stage('Backend npm audit') {
          steps {
            dir('backend') {
              sh '''
                docker run --rm \
                  -v "$PWD:/app" -w /app \
                  node:18-alpine sh -lc "npm audit --audit-level=high --json > npm-audit-backend.json || true"
              '''
              archiveArtifacts artifacts: 'backend/npm-audit-backend.json', allowEmptyArchive: true
            }
          }
        }

        stage('Frontend npm audit') {
          steps {
            dir('frontend') {
              sh '''
                docker run --rm \
                  -v "$PWD:/app" -w /app \
                  node:18-alpine sh -lc "npm audit --audit-level=high --json > npm-audit-frontend.json || true"
              '''
              archiveArtifacts artifacts: 'frontend/npm-audit-frontend.json', allowEmptyArchive: true
            }
          }
        }

      }
    }

    stage('🔒 Container Scan (Trivy)') {
      steps {
        sh '''
          command -v trivy >/dev/null 2>&1 || (
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
          )

          trivy image --severity HIGH,CRITICAL --format json --output trivy-backend.json ${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT} || true
          trivy image --severity HIGH,CRITICAL --format json --output trivy-frontend.json ${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT} || true
        '''
        archiveArtifacts artifacts: 'trivy-*.json', allowEmptyArchive: true
      }
    }

  }

  post {
    always {
      echo "Pipeline finished."
      cleanWs()
    }
  }
}

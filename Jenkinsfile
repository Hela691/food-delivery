pipeline {
  agent any

  environment {
    IMAGE_NAME        = 'food-delivery'
    SONAR_HOST_URL    = 'http://food-sonarqube:9000'
    SONAR_PROJECT_KEY = 'food-delivery'
    SONAR_TOKEN       = credentials('sonar-token')
    DOCKER_NET        = 'food-delivery_food-network'
  }

  stages {

    stage('🔍 Checkout') {
      steps {
        deleteDir()
        checkout scm
        script {
          env.GIT_COMMIT_SHORT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        }
      }
    }

    stage('📂 Inspect Workspace (Debug)') {
      steps {
        sh '''
          echo "=== WHERE AM I ==="
          pwd
          echo "=== LIST ROOT ==="
          ls -la
          echo "=== LIST BACKEND ==="
          ls -la backend || true
          echo "=== CHECK backend/package.json ==="
          ls -la backend/package.json || true
          echo "=== LIST FRONTEND ==="
          ls -la frontend || true
          echo "=== FIND package.json (depth 3) ==="
          find . -maxdepth 3 -type f -name package.json -print
        '''
      }
    }

    stage('📦 Install Dependencies') {
      parallel {

        stage('Backend') {
          steps {
            dir('backend') {
              sh '''
                set -e
                echo "PWD=$PWD"
                ls -la
                ls -la package.json

                docker run --rm \
                  -v "$PWD:/app" -w /app \
                  node:18-alpine \
                  sh -lc 'npm ci || npm install'
              '''
            }
          }
        }

        stage('Frontend') {
          steps {
            dir('frontend') {
              sh '''
                set -e
                echo "PWD=$PWD"
                ls -la
                ls -la package.json

                docker run --rm \
                  -v "$PWD:/app" -w /app \
                  node:18-alpine \
                  sh -lc 'npm ci || npm install'
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
            -Dsonar.exclusions=**/node_modules/**,**/dist/**,**/coverage/**
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

  }

  post {
    always {
      echo "Pipeline finished."
      cleanWs()
    }
  }
}

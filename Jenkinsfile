pipeline {
  agent any

  environment {
    IMAGE_NAME        = 'food-delivery'
    SONAR_HOST_URL    = 'http://food-sonarqube:9000'
    SONAR_PROJECT_KEY = 'food-delivery'
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
            sh '''
              set -e
              WS="/var/jenkins_home/workspace/${JOB_NAME}/backend"

              docker run --rm \
                --volumes-from jenkins \
                -w "$WS" \
                node:18-alpine \
                sh -lc "ls -la && ls -la package.json && (npm ci || npm install)"
            '''
          }
        }

        stage('Frontend') {
          steps {
            sh '''
              set -e
              WS="/var/jenkins_home/workspace/${JOB_NAME}/frontend"

              docker run --rm \
                --volumes-from jenkins \
                -w "$WS" \
                node:18-alpine \
                sh -lc "ls -la && ls -la package.json && (npm ci || npm install)"
            '''
          }
        }

      }
    }

    stage('🛡️ Dependency Check') {
      parallel {

        stage('Backend Audit') {
          steps {
            sh '''
              set -e
              WS="/var/jenkins_home/workspace/${JOB_NAME}/backend"

              docker run --rm \
                --volumes-from jenkins \
                -w "$WS" \
                node:18-alpine \
                sh -lc "npm audit --audit-level=high --json > /var/jenkins_home/workspace/${JOB_NAME}/npm-audit-backend.json || true"
            '''
            archiveArtifacts artifacts: 'npm-audit-backend.json', allowEmptyArchive: false
          }
        }

        stage('Frontend Audit') {
          steps {
            sh '''
              set -e
              WS="/var/jenkins_home/workspace/${JOB_NAME}/frontend"

              docker run --rm \
                --volumes-from jenkins \
                -w "$WS" \
                node:18-alpine \
                sh -lc "npm audit --audit-level=high --json > /var/jenkins_home/workspace/${JOB_NAME}/npm-audit-frontend.json || true"
            '''
            archiveArtifacts artifacts: 'npm-audit-frontend.json', allowEmptyArchive: false
          }
        }

      }
    }

    stage('🔐 SAST - SonarQube Analysis') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh '''
            docker run --rm \
              --network ${DOCKER_NET} \
              --volumes-from jenkins \
              -w /var/jenkins_home/workspace/${JOB_NAME} \
              sonarsource/sonar-scanner-cli \
              -Dsonar.host.url=${SONAR_HOST_URL} \
              -Dsonar.login=${SONAR_TOKEN} \
              -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
              -Dsonar.sources=backend,frontend/src \
              -Dsonar.exclusions=**/node_modules/**,**/dist/**,**/coverage/** \
              -Dsonar.qualitygate.wait=false
          '''
        }
      }
    }

    stage('📊 Sonar Report (soft gate)') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          sh '''
            echo "=== SonarQube Quality Gate status (soft gate) ==="

            curl -s -u "${SONAR_TOKEN}:" \
              "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" \
              | tee sonar-qg.json

            if grep -q '"status":"ERROR"' sonar-qg.json; then
              echo ""
              echo "⚠️ QUALITY GATE = FAILED (mais on ne bloque pas le pipeline)"
              echo "➡️ Causes typiques : coverage=0%, vulnérabilités, hotspots non revus..."
              echo "➡️ Voir dashboard Sonar : ${SONAR_HOST_URL}/dashboard?id=${SONAR_PROJECT_KEY}"
              echo ""
            else
              echo "✅ QUALITY GATE = OK"
            fi
          '''
        }
        archiveArtifacts artifacts: 'sonar-qg.json', allowEmptyArchive: false
      }
    }

    stage('🐳 Build Docker Images') {
      steps {
        sh '''
          docker build -t ${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT} ./backend
          docker build -t ${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT} ./frontend
        '''
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

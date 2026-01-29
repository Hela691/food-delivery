pipeline {
  agent any

  environment {
    IMAGE_NAME = 'food-delivery'
    SONAR_HOST_URL = 'http://food-sonarqube:9000'
    SONAR_PROJECT_KEY = 'food-delivery'
    // Token SonarQube : mets-le dans Jenkins Credentials (Secret Text) et remplace l'id ci-dessous
    SONAR_TOKEN = 'sqp_dde66c3ed60ce44d201c51abb6042d833ee816b8'
  }

  stages {

    stage('🔍 Checkout') {
      steps {
        // Si tu utilises un job "Pipeline from SCM", cette étape est automatique.
        // Sinon, garde checkout scm.
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
              docker run --rm -v "$PWD/backend:/app" -w /app node:18-alpine \
                sh -lc "npm install"
            '''
           }
          }
        }
        stage('Frontend') {
          steps {
           dir('frontend') {
            sh '''
              docker run --rm -v "$PWD/frontend:/app" -w /app node:18-alpine \
                sh -lc "npm install"
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
            --network food-delivery_food-network \
            -v "$PWD:/usr/src" \
            sonarsource/sonar-scanner-cli \
            -Dsonar.host.url=${SONAR_HOST_URL} \
            -Dsonar.login=${SONAR_TOKEN} \
            -Dsonar.projectKey=${SONAR_PROJECT_KEY}
        '''
      }
    }

    stage('🔍 Quality Gate') {
      steps {
        // Simple et “prof-friendly”: on vérifie le Quality Gate via API (sans plugin Jenkins Sonar)
        sh '''
          echo "Waiting for SonarQube Quality Gate..."
          # récupère le status via l’API SonarQube (analyse la plus récente du projet)
          curl -s -u "${SONAR_TOKEN}:" "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" | tee qg.json

          if grep -q '"status":"ERROR"' qg.json; then
            echo "❌ Quality Gate FAILED"
            exit 1
          fi
          echo "✅ Quality Gate PASSED or WARN"
        '''
      }
    }

    stage('🛡️ Dependency Check') {
      parallel {
        stage('Backend Audit') {
          steps {
            sh '''
              docker run --rm -v "$PWD/backend:/app" -w /app node:18-alpine \
                sh -lc "npm audit --audit-level=high --json > npm-audit-backend.json || true"
            '''
            archiveArtifacts artifacts: 'backend/npm-audit-backend.json', allowEmptyArchive: true
          }
        }
        stage('Frontend Audit') {
          steps {
            sh '''
              docker run --rm -v "$PWD/frontend:/app" -w /app node:18-alpine \
                sh -lc "npm audit --audit-level=high --json > npm-audit-frontend.json || true"
            '''
            archiveArtifacts artifacts: 'frontend/npm-audit-frontend.json', allowEmptyArchive: true
          }
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline finished."
    }
  }
}

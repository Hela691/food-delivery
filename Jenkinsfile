pipeline {
  agent any

  environment {
    DOCKER_REGISTRY = 'local'
    IMAGE_NAME      = 'food-delivery'
    SONAR_HOST      = 'http://food-sonarqube:9000'
  }

  tools {
    nodejs 'NodeJS-18'
  }

  stages {

    stage('🔍 Checkout') {
      steps {
        checkout scm
        script {
          env.GIT_COMMIT_SHORT = sh(
            script: "git rev-parse --short HEAD",
            returnStdout: true
          ).trim()
        }
      }
    }

    stage('📦 Install Dependencies') {
      parallel {

        stage('Backend') {
          steps {
            dir('backend') {
              sh 'npm ci || npm install'
            }
          }
        }

        stage('Frontend') {
          steps {
            dir('frontend') {
              sh 'npm ci || npm install'
            }
          }
        }

      }
    }

    stage('🔐 SAST - SonarQube Analysis') {
      steps {
        withSonarQubeEnv('SonarQube') {
          sh '''
            sonar-scanner \
              -Dsonar.projectKey=food-delivery \
              -Dsonar.sources=backend/,frontend/src/ \
              -Dsonar.exclusions=**/node_modules/**,**/dist/** \
              -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
          '''
        }
      }
    }

    stage('🔍 Quality Gate') {
      steps {
        timeout(time: 5, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
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

    stage('🔒 Container Security Scan (Trivy)') {
      steps {
        sh '''
          # install trivy if not present (simple TP mode)
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
      cleanWs()
    }
  }
}

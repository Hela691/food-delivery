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
          env.GIT_BRANCH_NAME  = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
          echo "Branch = ${env.GIT_BRANCH_NAME} | Commit = ${env.GIT_COMMIT_SHORT}"
        }
      }
    }

    // ✅ AJOUTE CE STAGE ICI
    stage('🧾 Debug Branch') {
      steps {
        sh '''
          echo "========== DEBUG BRANCH =========="
          echo "BRANCH_NAME=$BRANCH_NAME"
          echo "GIT_BRANCH=$GIT_BRANCH"
          echo "GIT_BRANCH_NAME(from script)=${GIT_BRANCH_NAME}"
          echo "git rev-parse --abbrev-ref HEAD =>"
          git rev-parse --abbrev-ref HEAD || true
          echo "env | grep BRANCH/GIT =>"
          env | sort | grep -E 'BRANCH|GIT_' || true
          echo "=================================="
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
              docker run --rm --volumes-from jenkins -w "$WS" node:18-alpine sh -lc "(npm ci || npm install)"
            '''
          }
        }
        stage('Frontend') {
          steps {
            sh '''
              set -e
              WS="/var/jenkins_home/workspace/${JOB_NAME}/frontend"
              docker run --rm --volumes-from jenkins -w "$WS" node:18-alpine sh -lc "(npm ci || npm install)"
            '''
          }
        }
      }
    }

    stage('🛡️ Dependency Check (npm audit)') {
      parallel {
        stage('Backend Audit') {
          steps {
            sh '''
              set -e
              WS="/var/jenkins_home/workspace/${JOB_NAME}/backend"
              docker run --rm --volumes-from jenkins -w "$WS" node:18-alpine \
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
              docker run --rm --volumes-from jenkins -w "$WS" node:18-alpine \
                sh -lc "npm audit --audit-level=high --json > /var/jenkins_home/workspace/${JOB_NAME}/npm-audit-frontend.json || true"
            '''
            archiveArtifacts artifacts: 'npm-audit-frontend.json', allowEmptyArchive: false
          }
        }
      }
    }

    stage('🛡️ OWASP Dependency-Check') {
      steps {
        sh 'mkdir -p dependency-check'

        dependencyCheck additionalArguments: """
          --scan ${WORKSPACE}
          --exclude **/node_modules/**
          --exclude **/dist/**
          --format HTML
          --format JSON
          --prettyPrint
          --out ${WORKSPACE}/dependency-check
        """, odcInstallation: 'OWASP-DC'

        dependencyCheckPublisher pattern: '**/dependency-check-report.json'
        archiveArtifacts artifacts: 'dependency-check/*', allowEmptyArchive: true
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
            curl -s -u "${SONAR_TOKEN}:" \
              "${SONAR_HOST_URL}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" \
              | tee sonar-qg.json

            if grep -q '"status":"ERROR"' sonar-qg.json; then
              echo "⚠️ QUALITY GATE = FAILED (soft gate)"
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
          set -e
          docker build -t ${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT} ./backend
          docker build -t ${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT} ./frontend

          docker tag ${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT}  ${IMAGE_NAME}-backend:latest
          docker tag ${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT} ${IMAGE_NAME}-frontend:latest
        '''
      }
    }

    stage('🔒 Container Security Scan (Trivy)') {
      steps {
        sh '''
          set +e
          mkdir -p "${WORKSPACE}/trivy-reports"

          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            --format json \
            ${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT} \
            > "${WORKSPACE}/trivy-reports/trivy-backend.json"

          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            --severity HIGH,CRITICAL \
            --format json \
            ${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT} \
            > "${WORKSPACE}/trivy-reports/trivy-frontend.json"

          ls -la "${WORKSPACE}/trivy-reports" || true
        '''
        archiveArtifacts artifacts: 'trivy-reports/*.json', allowEmptyArchive: false
      }
    }

    stage('📤 Push to DockerHub') {
      when {
        anyOf {
          branch 'main'
          branch 'master'
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-creds',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            set -e
            echo "Pushing as DOCKER_USER=$DOCKER_USER"
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

            docker tag ${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT}  $DOCKER_USER/${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT}
            docker tag ${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT} $DOCKER_USER/${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT}

            docker tag ${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT}  $DOCKER_USER/${IMAGE_NAME}-backend:latest
            docker tag ${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT} $DOCKER_USER/${IMAGE_NAME}-frontend:latest

            docker push $DOCKER_USER/${IMAGE_NAME}-backend:${GIT_COMMIT_SHORT}
            docker push $DOCKER_USER/${IMAGE_NAME}-frontend:${GIT_COMMIT_SHORT}

            docker push $DOCKER_USER/${IMAGE_NAME}-backend:latest
            docker push $DOCKER_USER/${IMAGE_NAME}-frontend:latest
          '''
        }
      }
    }

    stage('🏭 Deploy to Production') {
      when {
        anyOf {
          branch 'main'
          branch 'master'
        }
      }
      steps {
        input message: 'Deploy to Production?', ok: 'Deploy'

        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-creds',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            set -e
            echo "Deploying as DOCKER_USER=$DOCKER_USER"
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

            export DOCKER_USER="$DOCKER_USER"
            export TAG=latest

            docker compose -f docker-compose.yml -f docker-compose.prod.yml pull
            docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-build
            docker compose -f docker-compose.yml -f docker-compose.prod.yml ps
          '''
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

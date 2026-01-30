#!/bin/bash
set -e
echo "🔍 Starting Security Audit..."
# Backend audit
echo "📦 Auditing Backend dependencies..."
cd backend
npm audit --json > ../reports/npm-audit-backend.json 2>&1 || true
BACKEND_VULNS=$(cat ../reports/npm-audit-backend.json | jq
'.metadata.vulnerabilities.high + .metadata.vulnerabilities.critical')
cd ..
# Frontend audit
echo "📦 Auditing Frontend dependencies..."
cd frontend
npm audit --json > ../reports/npm-audit-frontend.json 2>&1 || true
FRONTEND_VULNS=$(cat ../reports/npm-audit-frontend.json | jq
'.metadata.vulnerabilities.high + .metadata.vulnerabilities.critical')
cd ..
# Summary
echo ""
echo "📊 Audit Summary:"
echo " Backend High/Critical: $BACKEND_VULNS"
echo " Frontend High/Critical: $FRONTEND_VULNS"
TOTAL=$((BACKEND_VULNS + FRONTEND_VULNS))
if [ "$TOTAL" -gt 0 ]; then
 echo "❌ Found $TOTAL high/critical vulnerabilities!"
 exit 1
else
 echo "✅ No high/critical vulnerabilities found!"
fi

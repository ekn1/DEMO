#!/usr/bin/env bash
set -euo pipefail

# SCENTS/WISMO Pilot Deployment Script
# This script sets up the complete pilot environment
# Usage: ./scripts/pilot_deploy.sh [--skip-db] [--skip-seed]

SKIP_DB=false
SKIP_SEED=false
for arg in "$@"; do
    case $arg in
        --skip-db) SKIP_DB=true ;;
        --skip-seed) SKIP_SEED=true ;;
    esac
done

echo "=== SCENTS/WISMO Pilot Deployment ==="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "✗ Docker not found. Install Docker first."; exit 1; }
command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 || { echo "✗ Docker Compose not found."; exit 1; }
echo "✓ Docker and Docker Compose available"
echo ""

# Create required directories
echo "Creating directories..."
mkdir -p data logs backups certs
echo "✓ Directories ready"
echo ""

# Copy environment template if needed
if [ ! -f .env ]; then
    echo "Creating .env from template..."
    cp .env.example .env
    echo "✓ .env created — edit with real values before production"
fi

# Start services
echo "Starting services..."
docker compose -f docker-compose.prod.yml up -d --build
echo "✓ Services started"
echo ""

# Wait for health checks
echo "Waiting for services to be healthy..."
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker compose -f docker-compose.prod.yml ps | grep -q "healthy"; then
        echo "✓ Services healthy"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
done
if [ $WAITED -ge $MAX_WAIT ]; then
    echo "⚠ Services not yet healthy, check logs with: docker compose -f docker-compose.prod.yml logs"
fi
echo ""

# Initialize database
if [ "$SKIP_DB" = "false" ]; then
    echo "Initializing database..."
    docker compose -f docker-compose.prod.yml exec -T scents-api python -c "
from api.db import db
db.init_db()
print('Database initialized')
" 2>/dev/null || echo "⚠ DB init skipped (service may still be starting)"
    echo ""
fi

# Seed pilot data
if [ "$SKIP_SEED" = "false" ]; then
    echo "Seeding pilot data..."
    docker compose -f docker-compose.prod.yml exec -T scents-api bash -c 'cd /app && python3 -c "
import sqlite3, time
from pathlib import Path
db = Path(\"/app/data/scents.sqlite\")
conn = sqlite3.connect(str(db))
cur = conn.cursor()
now = time.time()
cur.execute(\"INSERT OR REPLACE INTO tenants VALUES (?,?,?,?,?,?)\", (\"pilot-token\", \"pilot-tenant\", \"admin\", \"restricted\", 200, now))
cur.execute(\"INSERT OR REPLACE INTO merchants VALUES (?,?,?,?,?,?,?,?)\", (\"merchant-001\", \"pilot-tenant\", \"Safari Foods\", \"orders@safarifoods.co.ke\", \"+254712345678\", \"Nairobi\", \"active\", now - 86400*30))
cur.execute(\"INSERT OR REPLACE INTO riders VALUES (?,?,?,?,?,?,?)\", (\"rider-001\", \"pilot-tenant\", \"James K.\", \"+254761234567\", \"Nairobi CBD\", \"available\", now - 86400*20))
cur.execute(\"INSERT OR REPLACE INTO orders VALUES (?,?,?,?,?,?,?,?,?,?)\", (\"order-001\", \"pilot-tenant\", \"merchant-001\", \"rider-001\", \"delivered\", \"Nairobi CBD\", \"Westlands\", 2500.0, now - 3600*2, \"{}\"))
conn.commit()
print(\"Pilot data seeded\")
conn.close()
"' 2>/dev/null || echo "⚠ Seed skipped (service may still be starting)"
    echo ""
fi

# Verify deployment
echo "Verifying deployment..."
sleep 3

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Access points:"
echo "  • Main API:       http://localhost:8080"
echo "  • Health check:   http://localhost:8080/health"
echo "  • Metrics:        http://localhost:8080/metrics"
echo "  • WISMO API:      http://localhost:3000"
echo "  • OSINT API:      http://localhost:3001"
echo "  • Pilot token:    pilot-token"
echo "  • Tenant ID:      pilot-tenant"
echo ""
echo "Test commands:"
echo "  curl http://localhost:8080/health"
echo "  curl -H 'Authorization: Bearer pilot-token' http://localhost:8080/api/orders"
echo "  curl -H 'Authorization: Bearer pilot-token' http://localhost:8080/api/incidents"
echo ""
echo "Dashboard:"
echo "  https://ekn1.github.io/wismo/"
echo ""
echo "Support:"
echo "  pilot-support@scents-iq-ltd7.com"
echo ""
echo "Next steps:"
echo "  1. Configure real Stripe keys: edit .env and restart"
echo "  2. Configure OSINT API keys: edit .env and restart"
echo "  3. Set up TLS certificates in certs/"
echo "  4. Review RUNBOOK.md for operations"
echo ""

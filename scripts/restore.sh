#!/usr/bin/env bash
set -euo pipefail

# SCENTS/WISMO restore script
# Restores database and tenant store from backup
# Usage: ./scripts/restore.sh [backup-file] [backup-dir]

BACKUP_FILE="${1:-}"
BACKUP_DIR="${2:-./backups}"
SCENTS_DB="${SCENTS_DB_PATH:-./data/scents.sqlite}"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file> [backup-dir]"
    echo ""
    echo "Available backups:"
    ls -lh "${BACKUP_DIR}"/scents_*.sqlite.gz 2>/dev/null || echo "  No backups found in ${BACKUP_DIR}"
    exit 1
fi

# Check if file exists
if [ ! -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    # Try without directory prefix
    if [ -f "$BACKUP_FILE" ]; then
        BACKUP_DIR=""
    else
        echo "✗ Backup file not found: ${BACKUP_DIR}/${BACKUP_FILE}"
        exit 1
    fi
fi

# Confirm restore
read -p "⚠ This will overwrite current database. Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Stop services
echo "Stopping SCENTS API..."
docker compose -f docker-compose.prod.yml stop scents-api || true

# Restore SQLite database
if [[ "$BACKUP_FILE" == *.sqlite.gz ]]; then
    echo "Restoring SQLite database..."
    gunzip -c "${BACKUP_DIR}/${BACKUP_FILE}" | sqlite3 "$SCENTS_DB"
    echo "✓ Database restored"
elif [[ "$BACKUP_FILE" == *.sqlite ]]; then
    echo "Restoring SQLite database..."
    sqlite3 "$SCENTS_DB" < "${BACKUP_DIR}/${BACKUP_FILE}"
    echo "✓ Database restored"
else
    echo "⚠ Unknown backup format: $BACKUP_FILE"
fi

# Restore tenant store if present
TENANT_BACKUP=$(ls -t ${BACKUP_DIR}/tenants_*.json.gz 2>/dev/null | head -1)
if [ -n "$TENANT_BACKUP" ]; then
    echo "Restoring tenant store..."
    gunzip -c "$TENANT_BACKUP" > ./data/tenants.json
    echo "✓ Tenant store restored"
fi

# Restart services
echo "Starting SCENTS API..."
docker compose -f docker-compose.prod.yml start scents-api

# Verify
sleep 3
if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
    echo "✓ Restore complete and service healthy"
else
    echo "⚠ Service may not be healthy yet. Check logs."
fi

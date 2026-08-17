#!/usr/bin/env bash
set -euo pipefail

# SCENTS/WISMO backup script
# Creates timestamped backups of SQLite DB, tenant config, and logs
# Usage: ./scripts/backup.sh [output-dir]

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="${1:-./backups}"
SCENTS_DB="${SCENTS_DB_PATH:-./data/scents.sqlite}"

mkdir -p "$OUTPUT_DIR"

# Backup SQLite database
if [ -f "$SCENTS_DB" ]; then
    echo "Backing up SQLite database..."
    sqlite3 "$SCENTS_DB" ".backup '${OUTPUT_DIR}/scents_${TIMESTAMP}.sqlite'"
    gzip -f "${OUTPUT_DIR}/scents_${TIMESTAMP}.sqlite"
    echo "✓ Database backed up to ${OUTPUT_DIR}/scents_${TIMESTAMP}.sqlite.gz"
else
    echo "⚠ SQLite database not found at $SCENTS_DB"
fi

# Backup tenant store
if [ -f "./data/tenants.json" ]; then
    echo "Backing up tenant store..."
    cp "./data/tenants.json" "${OUTPUT_DIR}/tenants_${TIMESTAMP}.json"
    gzip -f "${OUTPUT_DIR}/tenants_${TIMESTAMP}.json"
    echo "✓ Tenants backed up to ${OUTPUT_DIR}/tenants_${TIMESTAMP}.json.gz"
fi

# Backup logs (if they exist)
if [ -d "./logs" ]; then
    echo "Backing up logs..."
    tar -czf "${OUTPUT_DIR}/logs_${TIMESTAMP}.tar.gz" ./logs/ 2>/dev/null || true
    echo "✓ Logs backed up to ${OUTPUT_DIR}/logs_${TIMESTAMP}.tar.gz"
fi

# Create backup manifest
cat > "${OUTPUT_DIR}/manifest_${TIMESTAMP}.txt" <<EOF
Backup created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Database: scents_${TIMESTAMP}.sqlite.gz
Tenants: tenants_${TIMESTAMP}.json.gz
Logs: logs_${TIMESTAMP}.tar.gz
Host: $(hostname)
Environment: ${ENVIRONMENT:-development}
EOF

echo "✓ Backup manifest: ${OUTPUT_DIR}/manifest_${TIMESTAMP}.txt"
echo "✓ Backup complete: ${OUTPUT_DIR}/"

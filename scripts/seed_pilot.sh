#!/usr/bin/env bash
set -euo pipefail

# SCENTS/WISMO Pilot Seed Data Script
# Populates the database with sample merchants, riders, orders, and incidents
# Usage: ./scripts/seed_pilot.sh

echo "=== SCENTS/WISMO Pilot Seed Data ==="
echo ""

# Check if database exists
DB_PATH="${SCENTS_DB_PATH:-./data/scents.sqlite}"
if [ ! -f "$DB_PATH" ]; then
    echo "✗ Database not found at $DB_PATH"
    echo "  Run: docker compose -f docker-compose.prod.yml exec scents-api python -c 'from api.db import db; db.init_db()'"
    exit 1
fi

echo "✓ Database found at $DB_PATH"
echo ""

# Seed data via Python
cd /home/scents-iq-ltd7/scents && .venv/bin/python <<'PYEOF'
import sqlite3
import json
import uuid
import time
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[0] / ".." / ".." / "data" / "scents.sqlite"
if not DB_PATH.exists():
    # Fallback to default
    DB_PATH = Path(__file__).resolve().parents[2] / "data" / "scents.sqlite"

conn = sqlite3.connect(str(DB_PATH))
conn.row_factory = sqlite3.Row
cur = conn.cursor()

# Ensure tables exist
cur.executescript("""
CREATE TABLE IF NOT EXISTS tenants (
    token TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    role TEXT NOT NULL,
    visibility_tier TEXT NOT NULL,
    rate_limit_per_min INTEGER NOT NULL DEFAULT 60,
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE TABLE IF NOT EXISTS audit (
    event_id TEXT PRIMARY KEY,
    ts REAL NOT NULL,
    tenant_id TEXT,
    actor TEXT,
    path TEXT,
    method TEXT,
    status INTEGER,
    latency_ms INTEGER,
    entity_id TEXT,
    metadata TEXT
);
CREATE TABLE IF NOT EXISTS cases (
    case_id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    type TEXT NOT NULL,
    priority TEXT NOT NULL,
    status TEXT NOT NULL,
    description TEXT,
    ts REAL NOT NULL,
    metadata TEXT
);
CREATE TABLE IF NOT EXISTS usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tenant_id TEXT NOT NULL,
    path TEXT NOT NULL,
    method TEXT NOT NULL,
    status INTEGER NOT NULL,
    latency_ms INTEGER NOT NULL,
    ts REAL NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE TABLE IF NOT EXISTS merchants (
    merchant_id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    region TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE TABLE IF NOT EXISTS riders (
    rider_id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    zone TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'available',
    created_at REAL NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE TABLE IF NOT EXISTS orders (
    order_id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    merchant_id TEXT NOT NULL,
    rider_id TEXT,
    status TEXT NOT NULL,
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    value REAL NOT NULL,
    ts REAL NOT NULL,
    metadata TEXT
);
CREATE TABLE IF NOT EXISTS incidents (
    incident_id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    order_id TEXT,
    type TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    ts REAL NOT NULL,
    metadata TEXT
);
""")

# Check if seed data already exists
existing = cur.execute("SELECT COUNT(*) as c FROM tenants WHERE tenant_id = 'pilot-tenant'").fetchone()
if existing["c"] > 0:
    print("⚠ Pilot seed data already exists. Skipping.")
    conn.close()
    exit(0)

now = time.time()

# Tenant
tenant_token = "pilot-token"
cur.execute(
    "INSERT OR REPLACE INTO tenants (token, tenant_id, role, visibility_tier, rate_limit_per_min, created_at) VALUES (?, ?, ?, ?, ?, ?)",
    (tenant_token, "pilot-tenant", "admin", "restricted", 200, now)
)

# Merchants
merchants = [
    ("merchant-001", "pilot-tenant", "Safari Foods", "orders@safarifoods.co.ke", "+254712345678", "Nairobi", now - 86400 * 30),
    ("merchant-002", "pilot-tenant", "Kilimanjaro Pharmacy", "orders@kilipharm.co.ke", "+254723456789", "Mombasa", now - 86400 * 25),
    ("merchant-003", "pilot-tenant", "Savannah Retail", "orders@savannah.co.ke", "+254734567890", "Kisumu", now - 86400 * 20),
    ("merchant-004", "pilot-tenant", "Masai Mara Supplies", "orders@masaimara.co.ke", "+254745678901", "Nakuru", now - 86400 * 15),
    ("merchant-005", "pilot-tenant", "Lakeside Traders", "orders@lakeside.co.ke", "+254756789012", "Eldoret", now - 86400 * 10),
]
for m in merchants:
    cur.execute(
        "INSERT OR REPLACE INTO merchants (merchant_id, tenant_id, name, email, phone, region, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (m[0], m[1], m[2], m[3], m[4], m[5], "active", m[6])
    )

# Riders
riders = [
    ("rider-001", "pilot-tenant", "James K.", "+254761234567", "Nairobi CBD", "available", now - 86400 * 20),
    ("rider-002", "pilot-tenant", "Mary W.", "+254772345678", "Westlands", "busy", now - 86400 * 18),
    ("rider-003", "pilot-tenant", "David O.", "+254783456789", "Mombasa Island", "available", now - 86400 * 15),
    ("rider-004", "pilot-tenant", "Grace N.", "+254794567890", "Kisumu", "available", now - 86400 * 12),
    ("rider-005", "pilot-tenant", "Peter M.", "+254705678901", "Nakuru", "on_break", now - 86400 * 10),
    ("rider-006", "pilot-tenant", "Sarah J.", "+254716789012", "Eldoret", "available", now - 86400 * 8),
    ("rider-007", "pilot-tenant", "John K.", "+254727890123", "Nairobi", "available", now - 86400 * 5),
]
for r in riders:
    cur.execute(
        "INSERT OR REPLACE INTO riders (rider_id, tenant_id, name, phone, zone, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        (r[0], r[1], r[2], r[3], r[4], r[5], r[6])
    )

# Orders
orders = [
    ("order-001", "pilot-tenant", "merchant-001", "rider-001", "delivered", "Nairobi CBD", "Westlands", 2500.0, now - 3600 * 2, "{}"),
    ("order-002", "pilot-tenant", "merchant-001", "rider-002", "in_transit", "Nairobi CBD", "Karen", 1800.0, now - 3600, "{}"),
    ("order-003", "pilot-tenant", "merchant-002", "rider-003", "delivered", "Mombasa Island", "Nyali", 3200.0, now - 7200, "{}"),
    ("order-004", "pilot-tenant", "merchant-003", None, "pending", "Kisumu", "Ahero", 1500.0, now - 1800, "{}"),
    ("order-005", "pilot-tenant", "merchant-004", "rider-005", "in_transit", "Nakuru", "Naivasha", 4500.0, now - 900, "{}"),
    ("order-006", "pilot-tenant", "merchant-005", "rider-006", "delivered", "Eldoret", "Turbo", 2100.0, now - 5400, "{}"),
    ("order-007", "pilot-tenant", "merchant-002", None, "cancelled", "Mombasa Island", "Bamburi", 900.0, now - 10800, "{}"),
    ("order-008", "pilot-tenant", "merchant-001", "rider-007", "in_transit", "Nairobi CBD", "Thika", 2800.0, now - 600, "{}"),
    ("order-009", "pilot-tenant", "merchant-003", "rider-004", "delivered", "Kisumu", "Maseno", 1700.0, now - 3600 * 3, "{}"),
    ("order-010", "pilot-tenant", "merchant-004", None, "pending", "Nakuru", "Gilgil", 3500.0, now - 1200, "{}"),
]
for o in orders:
    cur.execute(
        "INSERT OR REPLACE INTO orders (order_id, tenant_id, merchant_id, rider_id, status, origin, destination, value, ts, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (o[0], o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9])
    )

# Incidents
incidents = [
    ("inc-001", "pilot-tenant", "order-002", "delay", "Rider stuck in traffic on Waiyaki Way", "open", now - 1800, "{}"),
    ("inc-002", "pilot-tenant", "order-005", "vehicle_issue", "Battery low on e-bike", "resolved", now - 3600, "{}"),
    ("inc-003", "pilot-tenant", None, "weather", "Heavy rain in Mombasa, deliveries delayed", "monitoring", now - 7200, "{}"),
    ("inc-004", "pilot-tenant", "order-007", "fraud_attempt", "Suspicious pickup location", "resolved", now - 10800, "{}"),
]
for inc in incidents:
    cur.execute(
        "INSERT OR REPLACE INTO incidents (incident_id, tenant_id, order_id, type, description, status, ts, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (inc[0], inc[1], inc[2], inc[3], inc[4], inc[5], inc[6], inc[7])
    )

conn.commit()
conn.close()

print("✓ Seeded pilot data:")
print("  - 1 tenant (pilot-tenant)")
print("  - 5 merchants")
print("  - 7 riders")
print("  - 10 orders")
print("  - 4 incidents")
print("")
print(f"  Pilot token: {tenant_token}")
print(f"  Tenant ID: pilot-tenant")
print("")
print("Next steps:")
print("  1. Test API: curl -H 'Authorization: Bearer pilot-token' http://localhost:8080/api/merchants")
print("  2. View orders: curl -H 'Authorization: Bearer pilot-token' http://localhost:8080/api/orders")
print("  3. Check incidents: curl -H 'Authorization: Bearer pilot-token' http://localhost:8080/api/incidents")
PYEOF

echo ""
echo "✓ Pilot seed data loaded successfully"

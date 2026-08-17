# SCENTS/WISMO Production Launch Runbook

## 1. Pre-Launch Checklist

### Environment Setup
- [ ] Copy `.env.example` to `.env` and fill in production values
- [ ] Generate TLS certificates (`certs/scents.crt`, `certs/scents.key`)
- [ ] Set `SCENTS_API_TOKEN` to a strong secret
- [ ] Configure `STRIPE_SECRET_KEY` and `STRIPE_PUBLISHABLE_KEY` for live mode
- [ ] Set `OSINT_REAL_CONNECTORS=true` and configure real API keys
- [ ] Configure `REDIS_URL` for production Redis instance

### Infrastructure
- [ ] Provision server(s) with Docker and Docker Compose
- [ ] Open ports: 80, 443, 8080, 8443, 3000, 3001
- [ ] Configure firewall rules
- [ ] Set up DNS records
- [ ] Configure SSL certificate auto-renewal (Let's Encrypt / cert-manager)

### Database
- [ ] Create `data/` directory with proper permissions
- [ ] Initialize SQLite database: `docker compose exec scents-api python -c "from api.db import db; db.init_db()"`
- [ ] Set up automated backup cron job: `0 2 * * * /app/scripts/backup.sh`
- [ ] Test backup/restore procedure

### Monitoring
- [ ] Set up log aggregation (ELK/Graylog/Datadog)
- [ ] Configure alerting for:
  - Health check failures
  - High error rates (>5%)
  - Slow response times (>2s)
  - Disk usage (>80%)
  - Memory usage (>85%)
- [ ] Configure tracing exporter for production

## 2. Deployment Steps

### Step 1: Build and Start
```bash
# Pull latest code
git pull origin main

# Build images
docker compose -f docker-compose.prod.yml build

# Start services
docker compose -f docker-compose.prod.yml up -d

# Verify health
curl https://your-domain.com/health
curl https://your-domain.com/healthz
curl https://your-domain.com/readyz
```

### Step 2: Initialize Database
```bash
# Run database migrations/init
docker compose -f docker-compose.prod.yml exec scents-api python -c "from api.db import db; db.init_db()"

# Verify tenant store
docker compose -f docker-compose.prod.yml exec scents-api python -c "from api.tenants import tenant_store; print(tenant_store.all())"
```

### Step 3: Verify Endpoints
```bash
# API health
curl https://your-domain.com/api/health

# Metrics
curl https://your-domain.com/metrics

# Admin status (requires token)
curl -H "Authorization: Bearer $SCENTS_API_TOKEN" https://your-domain.com/api/admin/status

# WISMO health
curl https://your-domain.com:3000/health
```

## 3. Common Issues

### Database Locked
```bash
# Check for connections
docker compose -f docker-compose.prod.yml exec scents-api lsof | grep scents.sqlite

# Restart if needed
docker compose -f docker-compose.prod.yml restart scents-api
```

### Out of Memory
```bash
# Check memory usage
docker stats

# Adjust worker count in Dockerfile.scents or docker-compose.prod.yml
```

### TLS Certificate Errors
```bash
# Verify cert files
docker compose -f docker-compose.prod.yml exec nginx ls -la /etc/nginx/certs/

# Test nginx config
docker compose -f docker-compose.prod.yml exec nginx nginx -t
```

## 4. Rollback Procedure

```bash
# Stop services
docker compose -f docker-compose.prod.yml down

# Restore from backup
bash scripts/restore.sh <backup-file>

# Start previous version
docker compose -f docker-compose.prod.yml up -d
```

## 5. Scaling

### Horizontal Scaling
```bash
# Scale SCENTS API workers
docker compose -f docker-compose.prod.yml up -d --scale scents-api=3

# Scale WISMO API workers
docker compose -f docker-compose.prod.yml up -d --scale wismo-api=2
```

### Load Balancer
```bash
# Update nginx.conf to add upstream servers
# Reload nginx
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

## 6. Backup Schedule

- **Full backups**: Daily at 2:00 AM UTC
- **Transaction logs**: Every 15 minutes
- **Retention**: 30 days
- **Offsite**: Upload to S3/Backblaze weekly

## 7. Emergency Contacts

- **Platform Owner**: [Your contact]
- **Stripe Support**: https://support.stripe.com
- **Cloud Provider**: [Your provider support]

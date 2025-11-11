# Production Deployment Guide

Complete guide for deploying MCP Client Docker infrastructure in production environments.

## 🎯 Production Architecture

### Infrastructure Requirements

**Minimum Requirements:**
- 3+ Docker Swarm nodes
- 16GB RAM per node
- 100GB SSD storage per node
- Load balancer (AWS ALB, GCP Load Balancer, CloudFlare)
- External storage backend (NFS, AWS EFS, GCP Persistent Disk)

**Recommended Setup:**
- 5+ Docker Swarm nodes (3 managers, 2+ workers)
- 32GB RAM per node
- 200GB SSD + separate data storage
- CDN for static content
- Backup and disaster recovery system

### Network Architecture

```
[External Load Balancer]
        |
[Docker Swarm Cluster]
        |
[Overlay Networks]
   |         |
[App Tier] [Data Tier]
```

## 🚀 Production Deployment Steps

### 1. Infrastructure Setup

#### Initialize Docker Swarm
```bash
# On manager node
docker swarm init --advertise-addr <manager-ip>

# On worker nodes (use token from init output)
docker swarm join --token <worker-token> <manager-ip>:2377

# Verify cluster
docker node ls
```

#### Node Labels for Placement
```bash
# Label nodes for specific workloads
docker node update --label-add postgres=true <node-id>
docker node update --label-add monitoring=true <node-id>
docker node update --label-add storage=true <node-id>
```

### 2. External Storage Configuration

#### NFS Setup (Example)
```bash
# On storage server
sudo apt install nfs-kernel-server
sudo mkdir -p /nfs/mcp-client/{postgresql,auth-keys,prometheus,grafana}
sudo chown -R nobody:nogroup /nfs/mcp-client
sudo chmod 755 /nfs/mcp-client

# Configure exports
echo "/nfs/mcp-client *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
sudo systemctl restart nfs-kernel-server
```

#### AWS EFS Setup
```bash
# Create EFS file system
aws efs create-file-system --creation-token mcp-client-$(date +%s)

# Mount on all nodes
sudo apt install nfs-common
sudo mkdir -p /mnt/efs
sudo mount -t nfs4 <efs-id>.efs.<region>.amazonaws.com:/ /mnt/efs
```

### 3. Security Configuration

#### Create Docker Secrets
```bash
# Database password
echo "your_secure_db_password" | docker secret create postgres_password -

# JWT secret for authentication
openssl rand -base64 32 | docker secret create jwt_secret -

# Bitcoin RPC authentication
echo "rpcuser:rpcpassword" | docker secret create bitcoin_rpc_auth -

# Grafana admin password
echo "secure_admin_password" | docker secret create grafana_admin_password -
```

#### SSL Certificates
```bash
# Let's Encrypt with Certbot
sudo certbot certonly --standalone -d mcp-client.yourdomain.com
sudo cp /etc/letsencrypt/live/mcp-client.yourdomain.com/fullchain.pem ./ssl/mcp-client.crt
sudo cp /etc/letsencrypt/live/mcp-client.yourdomain.com/privkey.pem ./ssl/mcp-client.key

# Create SSL config as Docker config
docker config create nginx_ssl_cert ./ssl/mcp-client.crt
docker config create nginx_ssl_key ./ssl/mcp-client.key
```

#### Network Security
```bash
# Create overlay networks with encryption
docker network create -d overlay --opt encrypted=true mcp-internal
docker network create -d overlay mcp-external
```

### 4. Configuration Management

#### Create Docker Configs
```bash
# NGINX configuration
docker config create nginx_config ./nginx/nginx.conf

# Prometheus configuration
docker config create prometheus_config ./monitoring/prometheus.yml

# Grafana configuration
docker config create grafana_config ./monitoring/grafana/grafana.ini
```

#### Environment Variables
```bash
# Create production environment file
cat > .env.prod << EOF
VERSION=1.0.0
LOG_LEVEL=warn
NODE_ENV=production
BITCOIN_NETWORK=mainnet
NFS_SERVER=your-nfs-server.local
NFS_PATH=/nfs/mcp-client
EOF
```

### 5. Deploy Production Stack

#### Deploy to Swarm
```bash
# Source environment variables
source .env.prod

# Deploy stack
docker stack deploy -c docker-compose.prod.yml mcp-client

# Verify deployment
docker stack services mcp-client
docker stack ps mcp-client
```

#### Monitor Deployment
```bash
# Watch service rollout
watch docker stack ps mcp-client

# Check service logs
docker service logs -f mcp-client_mcp-client
docker service logs -f mcp-client_knowledge-graph
```

## 🔄 Rolling Updates

### Application Updates
```bash
# Build new image
docker build -t mcp-client:1.1.0 ./client-application

# Update service
docker service update --image mcp-client:1.1.0 mcp-client_mcp-client

# Monitor rollout
docker service ps mcp-client_mcp-client
```

### Database Updates
```bash
# Scale down to single replica for schema changes
docker service scale mcp-client_knowledge-graph=1

# Run migrations
docker service exec mcp-client_knowledge-graph_<task-id> \
  psql -U graphuser -d mcpgraph -f /migrations/v2.sql

# Scale back up
docker service scale mcp-client_knowledge-graph=1
```

## 📊 Production Monitoring

### External Monitoring Integration

#### Prometheus Federation
```yaml
# Add to external Prometheus config
- job_name: 'mcp-client-federation'
  scrape_interval: 15s
  honor_labels: true
  metrics_path: '/federate'
  params:
    'match[]':
      - '{job="mcp-client"}'
      - '{job="auth-service"}'
  static_configs:
    - targets: ['mcp-client.yourdomain.com:8080']
```

#### Log Aggregation
```bash
# Configure centralized logging
docker service update --log-driver=syslog \
  --log-opt syslog-address=udp://your-logserver.com:514 \
  mcp-client_mcp-client
```

### Alerting Setup

#### Webhook Integration
```bash
# Configure Slack webhook
docker config create alertmanager_config - << EOF
route:
  group_by: ['alertname']
  receiver: 'web.hook'
receivers:
- name: 'web.hook'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#alerts'
EOF
```

## 🔐 Security Hardening

### Container Security
```bash
# Enable Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# Scan images for vulnerabilities
docker scan mcp-client:latest
docker scan auth-service:latest
```

### Network Security
```bash
# Configure firewall rules
sudo ufw allow 2377/tcp  # Swarm management
sudo ufw allow 7946/tcp  # Swarm communication
sudo ufw allow 7946/udp
sudo ufw allow 4789/udp  # Overlay network
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
```

### Secrets Rotation
```bash
# Automated secret rotation script
./scripts/rotate-secrets.sh
```

## 💾 Backup Strategy

### Database Backup
```bash
# Automated daily backup
cat > /etc/cron.daily/mcp-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

docker service exec mcp-client_knowledge-graph_$(docker service ps -q mcp-client_knowledge-graph | head -1) \
  pg_dump -U graphuser mcpgraph | gzip > $BACKUP_DIR/database.sql.gz

# Keep 30 days of backups
find /backups -type d -mtime +30 -exec rm -rf {} +
EOF
chmod +x /etc/cron.daily/mcp-backup
```

### Configuration Backup
```bash
# Backup configurations
./scripts/backup-configs.sh
```

## 🚨 Disaster Recovery

### Service Recovery
```bash
# Restore from backup
./scripts/restore-from-backup.sh 20241111

# Failover to standby cluster
./scripts/failover-cluster.sh standby-region
```

### Data Recovery
```bash
# Restore database from backup
gunzip < backup/database.sql.gz | \
docker service exec -i mcp-client_knowledge-graph_<task> \
  psql -U graphuser mcpgraph
```

## 📈 Performance Optimization

### Resource Tuning
```bash
# Adjust service resources based on load
docker service update --limit-memory 4G --reserve-memory 2G \
  mcp-client_mcp-client

# Enable CPU limits
docker service update --limit-cpu 2 --reserve-cpu 1 \
  mcp-client_mcp-client
```

### Database Optimization
```sql
-- PostgreSQL tuning for production
ALTER SYSTEM SET shared_buffers = '1GB';
ALTER SYSTEM SET effective_cache_size = '3GB';
ALTER SYSTEM SET maintenance_work_mem = '256MB';
ALTER SYSTEM SET wal_buffers = '16MB';
SELECT pg_reload_conf();
```

## 🔍 Production Troubleshooting

### Common Issues

#### Service Not Starting
```bash
# Check service events
docker service ps --no-trunc mcp-client_mcp-client

# Check node availability
docker node ls

# Inspect service configuration
docker service inspect mcp-client_mcp-client
```

#### Network Issues
```bash
# Test overlay network connectivity
docker service exec mcp-client_mcp-client_<task> \
  ping mcp-client_knowledge-graph

# Check network configuration
docker network ls
docker network inspect mcp-client_mcp-internal
```

#### Storage Issues
```bash
# Check volume mounts
docker service inspect mcp-client_knowledge-graph | jq '.[0].Spec.TaskTemplate.ContainerSpec.Mounts'

# Test storage connectivity
df -h /mnt/storage
```

## ✅ Production Checklist

### Pre-Deployment
- [ ] Infrastructure provisioned and configured
- [ ] SSL certificates installed and valid
- [ ] Secrets created and secured
- [ ] External storage mounted and accessible
- [ ] Load balancer configured
- [ ] DNS records updated
- [ ] Firewall rules configured
- [ ] Backup systems tested

### Post-Deployment
- [ ] All services healthy and running
- [ ] Health checks passing
- [ ] Monitoring systems operational
- [ ] Alerting configured and tested
- [ ] SSL certificates valid
- [ ] Backup schedules active
- [ ] Performance baselines established
- [ ] Documentation updated

---

**Production deployment requires careful planning and testing. Always test in staging environment first.**

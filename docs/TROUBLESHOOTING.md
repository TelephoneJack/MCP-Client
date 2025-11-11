# Troubleshooting Guide

Common issues and solutions for MCP Client Docker infrastructure.

## 🔧 Quick Diagnostics

### Health Check Script
```bash
# Run comprehensive health check
./scripts/health-check.sh

# Quick health check
./scripts/health-check.sh --quick
```

### Service Status
```bash
# Check all services
docker compose ps

# Check service logs
docker compose logs [service-name]

# Check resource usage
docker stats
```

## 🚨 Common Issues

### Services Won't Start

#### Issue: "Service failed to start"
**Symptoms:**
- Containers exit immediately
- Health checks failing
- Error messages in logs

**Diagnosis:**
```bash
# Check service status
docker compose ps

# View detailed logs
docker compose logs [service-name]

# Check container configuration
docker compose config
```

**Solutions:**
1. **Port conflicts:**
   ```bash
   # Check what's using the port
   sudo netstat -tulpn | grep :80
   sudo lsof -i :80
   
   # Change ports in docker-compose.yml or stop conflicting service
   ```

2. **Permission issues:**
   ```bash
   # Fix data directory permissions
   sudo chown -R $USER:$USER data/
   chmod 755 data/postgresql data/prometheus data/grafana
   chmod 700 data/auth-keys
   ```

3. **Missing environment variables:**
   ```bash
   # Verify .env file exists and is complete
   cat .env
   cp .env.template .env  # If missing
   ```

### Database Connection Issues

#### Issue: "Cannot connect to database"
**Symptoms:**
- MCP Client can't reach database
- Authentication failures
- Connection timeouts

**Diagnosis:**
```bash
# Check if database is running
docker compose ps knowledge-graph

# Test database connectivity
docker compose exec knowledge-graph pg_isready -U graphuser

# Check network connectivity
docker compose exec mcp-client nc -z knowledge-graph-db 5432
```

**Solutions:**
1. **Database not ready:**
   ```bash
   # Wait for database initialization
   docker compose logs knowledge-graph
   
   # Restart database service
   docker compose restart knowledge-graph
   ```

2. **Wrong credentials:**
   ```bash
   # Verify environment variables
   grep POSTGRES .env
   
   # Reset database with new credentials
   docker compose down -v
   docker compose up -d
   ```

3. **Network issues:**
   ```bash
   # Recreate networks
   docker network prune
   docker compose down
   docker compose up -d
   ```

### Load Balancer Issues

#### Issue: "502 Bad Gateway" or "Connection refused"
**Symptoms:**
- Can't access application via HTTP/HTTPS
- NGINX error messages
- SSL certificate errors

**Diagnosis:**
```bash
# Check NGINX status
docker compose logs load-balancer

# Test backend connectivity
curl -f http://localhost:3000/health

# Check SSL certificates
openssl x509 -in ssl/mcp-client.crt -text -noout
```

**Solutions:**
1. **Backend services down:**
   ```bash
   # Check upstream services
   docker compose ps mcp-client auth-service
   
   # Restart backend services
   docker compose restart mcp-client auth-service
   ```

2. **SSL certificate issues:**
   ```bash
   # Regenerate development certificates
   rm ssl/*
   ./scripts/setup.sh  # Will regenerate certificates
   
   # Or generate manually
   openssl req -x509 -newkey rsa:4096 -keyout ssl/mcp-client.key \
     -out ssl/mcp-client.crt -days 365 -nodes \
     -subj "/CN=localhost/O=MCP Client/C=US"
   ```

3. **NGINX configuration errors:**
   ```bash
   # Test NGINX configuration
   docker compose exec load-balancer nginx -t
   
   # Reload configuration
   docker compose restart load-balancer
   ```

### Resource Issues

#### Issue: High memory or CPU usage
**Symptoms:**
- Slow response times
- Container restarts
- System becomes unresponsive

**Diagnosis:**
```bash
# Check resource usage
docker stats

# Check system resources
free -h
df -h
top
```

**Solutions:**
1. **Adjust resource limits:**
   ```yaml
   # In docker-compose.yml
   services:
     mcp-client:
       deploy:
         resources:
           limits:
             memory: 4G  # Increase from 2G
             cpus: '2.0'   # Increase from 1.0
   ```

2. **Scale down services:**
   ```bash
   # Reduce service replicas
   docker compose up -d --scale mcp-client=1
   ```

3. **Clear unused resources:**
   ```bash
   # Remove unused containers, networks, images
   docker system prune -a
   
   # Clear logs
   docker compose logs --tail=0 -f > /dev/null
   ```

### Authentication Issues

#### Issue: "Authentication failed" or "Invalid token"
**Symptoms:**
- Login failures
- JWT token errors
- Bitcoin wallet connection issues

**Diagnosis:**
```bash
# Check auth service logs
docker compose logs auth-service

# Test auth service directly
curl -f http://localhost:4000/health

# Verify Bitcoin network connectivity
docker compose exec auth-service curl -s blockchain.info/latestblock
```

**Solutions:**
1. **JWT secret issues:**
   ```bash
   # Generate new JWT secret
   openssl rand -base64 32
   
   # Update .env file
   JWT_SECRET=new_secret_here
   
   # Restart auth service
   docker compose restart auth-service
   ```

2. **Bitcoin network issues:**
   ```bash
   # Check network configuration
   grep BITCOIN_NETWORK .env
   
   # For testnet development
   BITCOIN_NETWORK=testnet
   ```

### Monitoring Issues

#### Issue: "Prometheus/Grafana not accessible"
**Symptoms:**
- Monitoring dashboards not loading
- No metrics data
- Alert rules not firing

**Diagnosis:**
```bash
# Check monitoring services
docker compose ps prometheus grafana

# Test Prometheus metrics
curl -f http://localhost:8080/prometheus/metrics

# Check Grafana health
curl -f http://localhost:8080/grafana/api/health
```

**Solutions:**
1. **Service configuration:**
   ```bash
   # Verify monitoring configuration
   cat monitoring/prometheus.yml
   
   # Restart monitoring stack
   docker compose restart prometheus grafana
   ```

2. **Data persistence:**
   ```bash
   # Check data directories
   ls -la data/prometheus data/grafana
   
   # Fix permissions if needed
   sudo chown -R $USER:$USER data/prometheus data/grafana
   ```

## 🔍 Advanced Troubleshooting

### Container Debugging

#### Enter running container
```bash
# Access container shell
docker compose exec mcp-client /bin/sh
docker compose exec knowledge-graph /bin/bash

# Run commands inside container
docker compose exec mcp-client cat /etc/hosts
docker compose exec knowledge-graph ps aux
```

#### Inspect container configuration
```bash
# View container details
docker inspect mcp-client-app

# Check environment variables
docker compose exec mcp-client env

# View mounted volumes
docker compose exec mcp-client df -h
```

### Network Debugging

#### Test network connectivity
```bash
# List Docker networks
docker network ls

# Inspect network configuration
docker network inspect mcp-client_mcp-internal

# Test service discovery
docker compose exec mcp-client nslookup knowledge-graph-db
docker compose exec mcp-client ping auth-service
```

#### Port debugging
```bash
# Check listening ports in container
docker compose exec mcp-client netstat -tulpn

# Test specific port connectivity
docker compose exec mcp-client nc -zv knowledge-graph-db 5432
docker compose exec mcp-client telnet auth-service 4000
```

### Log Analysis

#### Structured log analysis
```bash
# Filter logs by service and level
docker compose logs mcp-client | grep ERROR
docker compose logs knowledge-graph | grep FATAL

# Follow logs in real-time
docker compose logs -f --tail=100

# Export logs for analysis
docker compose logs > logs/debug-$(date +%Y%m%d).log
```

#### Application-specific logs
```bash
# Node.js application logs
docker compose exec mcp-client cat /app/logs/app.log

# PostgreSQL logs
docker compose exec knowledge-graph cat /var/log/postgresql/postgresql.log

# NGINX access/error logs
docker compose exec load-balancer cat /var/log/nginx/access.log
docker compose exec load-balancer cat /var/log/nginx/error.log
```

## 🛠️ Maintenance Tasks

### Regular Maintenance

#### Log rotation
```bash
# Rotate Docker logs
docker compose logs --tail=0 > /dev/null

# Clean old log files
find logs/ -name "*.log" -mtime +7 -delete
```

#### Database maintenance
```bash
# Analyze database performance
docker compose exec knowledge-graph psql -U graphuser -d mcpgraph -c "ANALYZE;"

# Vacuum database
docker compose exec knowledge-graph psql -U graphuser -d mcpgraph -c "VACUUM;"

# Check database size
docker compose exec knowledge-graph psql -U graphuser -d mcpgraph -c "\l+"
```

#### Security updates
```bash
# Pull latest base images
docker compose pull

# Rebuild custom images
docker compose build --no-cache

# Restart with new images
docker compose up -d
```

### Backup and Recovery

#### Create backup
```bash
# Database backup
./scripts/backup.sh

# Manual database backup
docker compose exec knowledge-graph pg_dump -U graphuser mcpgraph > backup-$(date +%Y%m%d).sql
```

#### Restore from backup
```bash
# Restore database
cat backup-20241111.sql | docker compose exec -T knowledge-graph psql -U graphuser -d mcpgraph

# Restore configuration
cp backup/docker-compose.yml docker-compose.yml
cp backup/.env .env
```

## 📞 Getting Help

### Collect diagnostic information
```bash
# Generate comprehensive diagnostic report
cat > diagnostic-report.sh << 'EOF'
#!/bin/bash
echo "=== MCP Client Diagnostic Report ===" > diagnostic-$(date +%Y%m%d).txt
echo "Date: $(date)" >> diagnostic-$(date +%Y%m%d).txt
echo "" >> diagnostic-$(date +%Y%m%d).txt

echo "=== System Information ===" >> diagnostic-$(date +%Y%m%d).txt
uname -a >> diagnostic-$(date +%Y%m%d).txt
docker version >> diagnostic-$(date +%Y%m%d).txt
docker compose version >> diagnostic-$(date +%Y%m%d).txt

echo "=== Service Status ===" >> diagnostic-$(date +%Y%m%d).txt
docker compose ps >> diagnostic-$(date +%Y%m%d).txt

echo "=== Resource Usage ===" >> diagnostic-$(date +%Y%m%d).txt
docker stats --no-stream >> diagnostic-$(date +%Y%m%d).txt

echo "=== Recent Logs ===" >> diagnostic-$(date +%Y%m%d).txt
docker compose logs --tail=50 >> diagnostic-$(date +%Y%m%d).txt
EOF

chmod +x diagnostic-report.sh
./diagnostic-report.sh
```

### Contact support
When reporting issues, include:
1. Diagnostic report output
2. Specific error messages
3. Steps to reproduce
4. System configuration
5. Docker and Compose versions

---

**Need additional help?** Check the [README.md](README.md) or create an issue in the project repository.

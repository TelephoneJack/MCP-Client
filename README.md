# MCP Client Docker Infrastructure

Production-ready Docker containerization system for MCP Client + Knowledge Graph deployment with load balancing, monitoring, and scalability.

## 🏗️ Architecture Overview

**Multi-container system** with the following components:
- **MCP Client Application** - Main application server (Node.js)
- **Knowledge Graph Database** - PostgreSQL database for Graphiti
- **Authentication Service** - Bitcoin NFT authentication (Node.js)
- **Load Balancer** - NGINX reverse proxy with SSL termination
- **Monitoring Stack** - Prometheus + Grafana for metrics and alerting

## 📋 Prerequisites

### Development Environment
- Docker Engine 20.10+
- Docker Compose V2
- 8GB RAM minimum (16GB recommended)
- 50GB disk space

### Production Environment
- Docker Swarm cluster (3+ nodes)
- External load balancer (AWS ALB, GCP Load Balancer)
- Persistent storage backend (AWS EFS, GCP Persistent Disk)
- SSL certificates

## 🚀 Quick Start (Development)

### 1. Clone and Setup
```bash
git clone <repository-url>
cd mcp-client-docker
cp .env.template .env
# Edit .env with your configuration
```

### 2. Create Required Directories
```bash
mkdir -p data/{postgresql,auth-keys,prometheus,grafana} logs ssl
chmod 700 data/auth-keys
```

### 3. Generate SSL Certificates (Development)
```bash
./scripts/generate-dev-ssl.sh
```

### 4. Start the Stack
```bash
docker-compose up -d
```

### 5. Verify Deployment
```bash
./scripts/health-check.sh
```

## 🌐 Service Endpoints

| Service | URL | Purpose |
|---------|-----|---------|
| MCP Client | http://localhost | Main application |
| Grafana | http://localhost:8080/grafana | Monitoring dashboard |
| Prometheus | http://localhost:8080/prometheus | Metrics collection |

## 🔧 Configuration

### Environment Variables

Create `.env` file from template:

```bash
# Application Configuration
VERSION=latest
LOG_LEVEL=info
NODE_ENV=production

# Database Configuration
POSTGRES_PASSWORD=your_secure_password

# Bitcoin Configuration
BITCOIN_NETWORK=mainnet

# SSL Configuration
SSL_CERT_PATH=./ssl
```

### SSL Certificates

#### Development
```bash
./scripts/generate-dev-ssl.sh
```

#### Production
Place your certificates in the `ssl/` directory:
- `ssl/mcp-client.crt`
- `ssl/mcp-client.key`

## 📊 Monitoring

### Health Checks

All services include health checks:
```bash
# Check all services
docker-compose ps

# Manual health verification
./scripts/health-check.sh
```

### Metrics and Alerting

- **Prometheus**: Collects metrics from all services
- **Grafana**: Visualizes metrics and provides dashboards
- **Alert Rules**: Configured for critical conditions

**Key Metrics Monitored:**
- Service availability
- Resource utilization (CPU, Memory)
- Response times and error rates
- Database performance
- Authentication success rates

### Accessing Monitoring

1. **Grafana Dashboard**: http://localhost:8080/grafana
   - Username: admin
   - Password: admin123

2. **Prometheus**: http://localhost:8080/prometheus

## 🔄 Scaling

### Horizontal Scaling

Scale individual services:
```bash
# Scale MCP Client to 3 replicas
docker-compose up -d --scale mcp-client=3

# Scale authentication service
docker-compose up -d --scale auth-service=2
```

### Resource Optimization

Services are configured with resource limits:
- **MCP Client**: 2GB RAM, 1 CPU
- **Knowledge Graph**: 4GB RAM, 2 CPU
- **Auth Service**: 1GB RAM, 0.5 CPU
- **Load Balancer**: 512MB RAM, 0.25 CPU
- **Monitoring**: 1GB RAM, 0.5 CPU

## 🔒 Security

### Network Security
- Internal services isolated from external access
- TLS encryption for external communication
- Network segmentation with bridge networks

### Container Security
- Non-root user execution
- Minimal Alpine Linux base images
- Regular security updates
- Secrets management via Docker secrets

### Access Control
- Rate limiting on API endpoints
- Authentication required for sensitive operations
- Monitoring dashboard restricted to internal network

## 📦 Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed production deployment instructions.

### Quick Production Deploy
```bash
# Initialize Docker Swarm
docker swarm init

# Create secrets
./scripts/create-secrets.sh

# Deploy production stack
docker stack deploy -c docker-compose.prod.yml mcp-client
```

## 🔧 Maintenance

### Backup
```bash
# Automated backup
./scripts/backup.sh

# Manual database backup
docker-compose exec knowledge-graph pg_dump -U graphuser mcpgraph > backup.sql
```

### Updates
```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```

### Logs
```bash
# View all logs
docker-compose logs -f

# Service-specific logs
docker-compose logs -f mcp-client
docker-compose logs -f knowledge-graph
```

## 🛠️ Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

### Quick Diagnostics
```bash
# Check service health
./scripts/health-check.sh

# View resource usage
docker stats

# Check network connectivity
docker network ls
docker-compose exec mcp-client ping knowledge-graph
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test changes locally
4. Submit pull request

## 📄 License

[Your License Here]

## 🆘 Support

- **Issues**: GitHub Issues
- **Documentation**: [docs/](docs/)
- **Health Checks**: `./scripts/health-check.sh`

---

**Built with ❤️ for scalable MCP Client deployment**

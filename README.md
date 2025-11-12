# MCP Client

Knowledge Graph-powered MCP (Model Context Protocol) Client with episodic memory system.

## Features

- **Knowledge Graph Integration**: Graphiti-powered episodic memory system
- **MCP Protocol Support**: Full Model Context Protocol implementation
- **Docker Deployment**: Production-ready containerized architecture
- **Control Center Dashboard**: Interactive knowledge graph visualization
- **Bridge Architecture**: Maintains Sconce operational continuity

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose V2
- 8GB RAM minimum
- 20GB disk space

### Installation

1. **Clone Repository**
   ```bash
   git clone https://github.com/[your-username]/MCP-Client.git
   cd MCP-Client
   ```

2. **Configure Environment**
   ```bash
   cp .env.template .env
   # Edit .env with your configuration
   ```

3. **Deploy with Docker**
   ```bash
   docker-compose up -d
   ```

4. **Verify Installation**
   ```bash
   docker-compose ps
   curl http://localhost/health
   ```

## Architecture

### Container Services

- **mcp-client-app**: Main MCP Client application
- **knowledge-graph-db**: PostgreSQL database for Graphiti knowledge graph
- **load-balancer**: NGINX reverse proxy
- **monitoring**: Prometheus + Grafana monitoring

### Network Architecture

```
Internet → Load Balancer → MCP Client → Knowledge Graph DB
                        ↓
                   Monitoring System
```

## Configuration

### Environment Variables

```bash
# Database Configuration
DATABASE_URL=postgresql://postgres:password@knowledge-graph:5432/graphiti
NODE_ENV=production

# Application Configuration
MCP_PORT=3000
LOG_LEVEL=info
```

### Docker Compose Services

The system uses a 4-container architecture:

1. **MCP Client** (Node.js application)
2. **Knowledge Graph Database** (PostgreSQL)
3. **Load Balancer** (NGINX)
4. **Monitoring** (Prometheus)

## Development

### Local Development Setup

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Run tests
npm test
```

### Building Docker Images

```bash
# Build all services
docker-compose build

# Build specific service
docker-compose build mcp-client
```

## Monitoring

Access monitoring dashboards:

- **Prometheus**: http://localhost:9090
- **Application Health**: http://localhost/health
- **Container Stats**: `docker-compose ps`

## Production Deployment

### Docker Swarm Deployment

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.prod.yml mcp-client

# Monitor deployment
docker service ls
```

### Environment Setup

1. Configure external database
2. Set up SSL certificates
3. Configure monitoring alerts
4. Set up backup procedures

## API Documentation

### Health Check

```
GET /health
Response: {"status": "ok", "services": {"database": "connected", "graph": "ready"}}
```

### MCP Endpoints

```
POST /mcp/tools
POST /mcp/resources
GET /mcp/status
```

## Knowledge Graph

The integrated knowledge graph provides:

- **Episodic Memory**: Context-aware conversation memory
- **Entity Recognition**: Automatic entity extraction and linking
- **Relationship Mapping**: Dynamic relationship discovery
- **Query Interface**: GraphQL and REST APIs

### Graph Operations

```bash
# Query graph
curl -X POST http://localhost/graph/query -d '{"query": "MATCH (n) RETURN n LIMIT 10"}'

# Add entities
curl -X POST http://localhost/graph/entities -d '{"name": "example", "type": "concept"}'
```

## Troubleshooting

### Common Issues

**Database Connection Failed**
```bash
# Check database status
docker-compose logs knowledge-graph
# Restart database
docker-compose restart knowledge-graph
```

**High Memory Usage**
```bash
# Check container resources
docker stats
# Restart services
docker-compose restart
```

**SSL Certificate Issues**
```bash
# Renew certificates
./scripts/renew-ssl.sh
# Restart load balancer
docker-compose restart load-balancer
```

### Logs

```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs mcp-client
docker-compose logs knowledge-graph

# Follow logs in real-time
docker-compose logs -f
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[Specify your license here]

## Support

- **Issues**: [GitHub Issues](https://github.com/[your-username]/MCP-Client/issues)
- **Documentation**: [Wiki](https://github.com/[your-username]/MCP-Client/wiki)
- **Contact**: [your-email@example.com]

---

**Project Status**: Active Development  
**Latest Version**: v1.0.0  
**Docker Support**: ✅ Production Ready
#!/bin/bash

# MCP Client Setup Script
# Automated deployment for development environment

set -e

echo "🚀 MCP Client Development Setup"
echo "================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose found"

# Check system resources
echo "💻 Checking system resources..."
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 8192 ]; then
    echo "⚠️  Warning: Less than 8GB RAM detected (${TOTAL_RAM}MB). Performance may be impacted."
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p logs/nginx
mkdir -p monitoring
mkdir -p nginx/ssl
mkdir -p init-db

# Set up environment
echo "⚙️  Setting up environment..."
if [ ! -f .env ]; then
    cp .env.template .env
    echo "✅ Environment file created. Please review .env file before continuing."
    echo "📝 Default database password: mcppassword"
fi

# Create monitoring config
echo "📊 Setting up monitoring..."
cat > monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'mcp-client'
    static_configs:
      - targets: ['mcp-client:3000']
  
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'nginx'
    static_configs:
      - targets: ['load-balancer:80']
EOF

# Create database initialization script
echo "🗄️  Setting up database..."
cat > init-db/init.sql << EOF
-- Initialize Graphiti knowledge graph database
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create basic tables for knowledge graph
CREATE TABLE IF NOT EXISTS entities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    type VARCHAR(100),
    properties JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_id UUID REFERENCES entities(id),
    target_id UUID REFERENCES entities(id),
    type VARCHAR(100),
    properties JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_entities_name ON entities USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_entities_type ON entities(type);
CREATE INDEX IF NOT EXISTS idx_relationships_source ON relationships(source_id);
CREATE INDEX IF NOT EXISTS idx_relationships_target ON relationships(target_id);
CREATE INDEX IF NOT EXISTS idx_relationships_type ON relationships(type);
EOF

# Pull required images
echo "🐳 Pulling Docker images..."
docker-compose pull

# Build application
echo "🔨 Building MCP Client..."
docker-compose build

# Start services
echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Health checks
echo "🏥 Performing health checks..."
RETRIES=5
for i in $(seq 1 $RETRIES); do
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "✅ MCP Client is healthy"
        break
    else
        if [ $i -eq $RETRIES ]; then
            echo "❌ Health check failed after $RETRIES attempts"
            echo "📋 Container status:"
            docker-compose ps
            echo "📋 Logs:"
            docker-compose logs --tail=50
            exit 1
        fi
        echo "⏳ Attempt $i/$RETRIES failed, retrying in 10 seconds..."
        sleep 10
    fi
done

# Display status
echo ""
echo "🎉 MCP Client Setup Complete!"
echo "================================"
echo "📊 Services Status:"
docker-compose ps

echo ""
echo "🔗 Access URLs:"
echo "• MCP Client: http://localhost"
echo "• Health Check: http://localhost/health"
echo "• Monitoring: http://localhost:9090"

echo ""
echo "📋 Useful Commands:"
echo "• View logs: docker-compose logs -f"
echo "• Stop services: docker-compose down"
echo "• Restart: docker-compose restart"
echo "• Update: docker-compose pull && docker-compose up -d"

echo ""
echo "✅ Setup completed successfully!"
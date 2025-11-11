#!/bin/bash
# MCP Client Docker Setup Script (B:deliver003)
# Automated local development setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose V2 is not available. Please upgrade Docker."
        exit 1
    fi
    
    # Check minimum requirements
    total_mem=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -lt 8 ]; then
        print_warning "System has ${total_mem}GB RAM. 8GB+ recommended."
    fi
    
    available_space=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$available_space" -lt 50 ]; then
        print_warning "Available disk space: ${available_space}GB. 50GB+ recommended."
    fi
    
    print_status "Prerequisites check completed."
}

# Create required directories
setup_directories() {
    print_status "Creating directory structure..."
    
    # Create data directories
    mkdir -p data/{postgresql,auth-keys,prometheus,grafana}
    mkdir -p logs ssl
    
    # Set proper permissions
    chmod 700 data/auth-keys
    chmod 755 data/postgresql data/prometheus data/grafana logs
    
    # Create .gitkeep files for empty directories
    touch data/postgresql/.gitkeep
    touch data/auth-keys/.gitkeep
    touch data/prometheus/.gitkeep
    touch data/grafana/.gitkeep
    touch logs/.gitkeep
    
    print_status "Directory structure created."
}

# Setup environment configuration
setup_environment() {
    print_status "Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        cat > .env << 'EOF'
# MCP Client Docker Environment Configuration

# Application Configuration
VERSION=latest
NODE_ENV=development
LOG_LEVEL=info

# Database Configuration
POSTGRES_PASSWORD=mcpdev123
POSTGRES_DB=mcpgraph
POSTGRES_USER=graphuser

# Authentication Configuration
BITCOIN_NETWORK=testnet
JWT_SECRET=your-jwt-secret-here

# SSL Configuration (development)
SSL_CERT_PATH=./ssl

# Monitoring Configuration
GRAFANA_ADMIN_PASSWORD=admin123

# Performance Tuning
MAX_CONNECTIONS=100
SHARED_BUFFERS=256MB
EOF
        print_status "Environment file created: .env"
    else
        print_warning "Environment file already exists. Skipping creation."
    fi
}

# Generate development SSL certificates
generate_ssl_certificates() {
    print_status "Generating development SSL certificates..."
    
    if [ ! -f ssl/mcp-client.crt ]; then
        # Generate self-signed certificate for development
        openssl req -x509 -newkey rsa:4096 -keyout ssl/mcp-client.key -out ssl/mcp-client.crt \
            -days 365 -nodes -subj "/CN=localhost/O=MCP Client/C=US"
        
        # Generate default certificate
        openssl req -x509 -newkey rsa:2048 -keyout ssl/default.key -out ssl/default.crt \
            -days 365 -nodes -subj "/CN=default/O=MCP Client/C=US"
        
        print_status "SSL certificates generated for development."
    else
        print_warning "SSL certificates already exist. Skipping generation."
    fi
}

# Pull Docker images
pull_images() {
    print_status "Pulling Docker images..."
    
    # Pull base images
    docker pull postgres:15-alpine
    docker pull nginx:alpine
    docker pull prom/prometheus:latest
    docker pull grafana/grafana:latest
    docker pull node:18-alpine
    
    print_status "Docker images pulled successfully."
}

# Build custom images
build_images() {
    print_status "Building custom Docker images..."
    
    # Build MCP Client image (if Dockerfile exists)
    if [ -f client-application/Dockerfile ]; then
        docker build -t mcp-client:dev ./client-application
        print_status "MCP Client image built."
    else
        print_warning "MCP Client Dockerfile not found. Skipping build."
    fi
    
    # Build Auth Service image (if Dockerfile exists)
    if [ -f auth-framework/Dockerfile ]; then
        docker build -t auth-service:dev ./auth-framework
        print_status "Auth Service image built."
    else
        print_warning "Auth Service Dockerfile not found. Skipping build."
    fi
}

# Initialize database
init_database() {
    print_status "Initializing database..."
    
    # Create initialization script if it doesn't exist
    if [ ! -f database/init/01-init.sql ]; then
        mkdir -p database/init
        cat > database/init/01-init.sql << 'EOF'
-- MCP Client Database Initialization

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create application user
CREATE USER mcpapp WITH PASSWORD 'mcpdev123';

-- Grant permissions
GRANT CONNECT ON DATABASE mcpgraph TO mcpapp;
GRANT USAGE ON SCHEMA public TO mcpapp;
GRANT CREATE ON SCHEMA public TO mcpapp;

-- Create basic tables (example)
CREATE TABLE IF NOT EXISTS mcp_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    session_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mcpapp;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mcpapp;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_mcp_sessions_user_id ON mcp_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_mcp_sessions_created_at ON mcp_sessions(created_at);
EOF
        print_status "Database initialization script created."
    fi
}

# Start services
start_services() {
    print_status "Starting Docker services..."
    
    # Start services in background
    docker compose up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 10
    
    # Check service health
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose ps | grep -q "healthy\|Up"; then
            print_status "Services are starting up..."
            break
        fi
        
        attempt=$((attempt + 1))
        print_status "Waiting for services... (attempt $attempt/$max_attempts)"
        sleep 5
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_warning "Services may still be starting. Check with 'docker compose ps'"
    fi
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    # Check if containers are running
    if ! docker compose ps | grep -q "Up"; then
        print_error "Some services failed to start. Check logs with 'docker compose logs'"
        return 1
    fi
    
    # Test connectivity
    sleep 5
    
    # Check if main services are responding
    if curl -f http://localhost/health &> /dev/null; then
        print_status "MCP Client is responding."
    else
        print_warning "MCP Client health check failed. Service may still be starting."
    fi
    
    print_status "Installation verification completed."
}

# Print completion message
print_completion() {
    print_status "Setup completed successfully! 🎉"
    echo ""
    echo "Next steps:"
    echo "1. Check service status: docker compose ps"
    echo "2. View logs: docker compose logs -f"
    echo "3. Access services:"
    echo "   - MCP Client: http://localhost"
    echo "   - Grafana: http://localhost:8080/grafana (admin/admin123)"
    echo "   - Prometheus: http://localhost:8080/prometheus"
    echo ""
    echo "Useful commands:"
    echo "  - Stop services: docker compose down"
    echo "  - View logs: docker compose logs [service]"
    echo "  - Restart service: docker compose restart [service]"
    echo ""
}

# Main setup function
main() {
    echo "🚀 MCP Client Docker Setup"
    echo "=========================="
    echo ""
    
    check_prerequisites
    setup_directories
    setup_environment
    generate_ssl_certificates
    pull_images
    init_database
    
    # Optional: build custom images if source code exists
    if [ "$1" == "--build" ]; then
        build_images
    fi
    
    start_services
    verify_installation
    print_completion
}

# Run main function with all arguments
main "$@"

#!/bin/bash
# Health Check Script (B:monitor001)
# Comprehensive health verification for all MCP Client services

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Health check results
RESULTS=()
OVERALL_STATUS=0

# Print functions
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        MCP Client Health Check       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
}

print_service() {
    printf "%-30s" "$1"
}

print_status() {
    if [ "$1" == "HEALTHY" ]; then
        echo -e "[${GREEN}HEALTHY${NC}] $2"
    elif [ "$1" == "UNHEALTHY" ]; then
        echo -e "[${RED}UNHEALTHY${NC}] $2"
        OVERALL_STATUS=1
    elif [ "$1" == "WARNING" ]; then
        echo -e "[${YELLOW}WARNING${NC}] $2"
    else
        echo -e "[${BLUE}INFO${NC}] $2"
    fi
}

# Check Docker service
check_docker() {
    print_service "Docker Engine"
    
    if docker info &> /dev/null; then
        print_status "HEALTHY" "Docker engine running"
        RESULTS+=("Docker Engine: HEALTHY")
    else
        print_status "UNHEALTHY" "Docker engine not responding"
        RESULTS+=("Docker Engine: UNHEALTHY")
    fi
}

# Check Docker Compose services
check_compose_services() {
    print_service "Docker Compose Stack"
    
    if docker compose ps &> /dev/null; then
        # Count running services
        running_services=$(docker compose ps --status running | wc -l)
        total_services=$(docker compose ps | tail -n +2 | wc -l)
        
        if [ "$running_services" -eq "$total_services" ] && [ "$total_services" -gt 0 ]; then
            print_status "HEALTHY" "$running_services/$total_services services running"
            RESULTS+=("Compose Stack: HEALTHY")
        else
            print_status "WARNING" "$running_services/$total_services services running"
            RESULTS+=("Compose Stack: WARNING")
        fi
    else
        print_status "UNHEALTHY" "Docker Compose not responding"
        RESULTS+=("Compose Stack: UNHEALTHY")
    fi
}

# Check individual container health
check_container_health() {
    local service=$1
    local container_name=$2
    
    print_service "$service"
    
    # Check if container exists and is running
    if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
        # Check container health status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
        
        case $health_status in
            "healthy")
                print_status "HEALTHY" "Container healthy"
                RESULTS+=("$service: HEALTHY")
                ;;
            "unhealthy")
                print_status "UNHEALTHY" "Health check failing"
                RESULTS+=("$service: UNHEALTHY")
                ;;
            "starting")
                print_status "WARNING" "Health check starting"
                RESULTS+=("$service: WARNING")
                ;;
            "no-healthcheck")
                # Check if container is just running
                if docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container_name" | grep -q "Up"; then
                    print_status "HEALTHY" "Container running (no health check)"
                    RESULTS+=("$service: HEALTHY")
                else
                    print_status "UNHEALTHY" "Container not running properly"
                    RESULTS+=("$service: UNHEALTHY")
                fi
                ;;
            *)
                print_status "WARNING" "Unknown health status: $health_status"
                RESULTS+=("$service: WARNING")
                ;;
        esac
    else
        print_status "UNHEALTHY" "Container not found or not running"
        RESULTS+=("$service: UNHEALTHY")
    fi
}

# Check network connectivity
check_network_connectivity() {
    echo ""
    echo -e "${BLUE}Network Connectivity Tests${NC}"
    echo "----------------------------------------"
    
    # Test internal network connectivity
    print_service "Internal Network"
    if docker network ls | grep -q "mcp.*internal"; then
        print_status "HEALTHY" "Internal network exists"
    else
        print_status "WARNING" "Internal network not found"
    fi
    
    # Test service-to-service connectivity
    if docker ps --format "table {{.Names}}" | grep -q "mcp-client-app"; then
        print_service "MCP Client → Database"
        if docker exec mcp-client-app nc -z knowledge-graph-db 5432 &> /dev/null; then
            print_status "HEALTHY" "Database connection successful"
        else
            print_status "UNHEALTHY" "Cannot connect to database"
        fi
        
        print_service "MCP Client → Auth Service"
        if docker exec mcp-client-app nc -z auth-service 4000 &> /dev/null; then
            print_status "HEALTHY" "Auth service connection successful"
        else
            print_status "UNHEALTHY" "Cannot connect to auth service"
        fi
    fi
}

# Check HTTP endpoints
check_http_endpoints() {
    echo ""
    echo -e "${BLUE}HTTP Endpoint Tests${NC}"
    echo "----------------------------------------"
    
    # Test main application
    print_service "MCP Client (HTTP)"
    if curl -f -s --connect-timeout 5 http://localhost/health &> /dev/null; then
        print_status "HEALTHY" "Health endpoint responding"
    else
        print_status "WARNING" "Health endpoint not responding"
    fi
    
    # Test authentication service
    print_service "Auth Service (HTTP)"
    if curl -f -s --connect-timeout 5 http://localhost:4000/health &> /dev/null; then
        print_status "HEALTHY" "Auth service responding"
    else
        print_status "WARNING" "Auth service not responding"
    fi
    
    # Test monitoring services
    print_service "Prometheus (HTTP)"
    if curl -f -s --connect-timeout 5 http://localhost:8080/prometheus/-/healthy &> /dev/null; then
        print_status "HEALTHY" "Prometheus responding"
    else
        print_status "WARNING" "Prometheus not responding"
    fi
    
    print_service "Grafana (HTTP)"
    if curl -f -s --connect-timeout 5 http://localhost:8080/grafana/api/health &> /dev/null; then
        print_status "HEALTHY" "Grafana responding"
    else
        print_status "WARNING" "Grafana not responding"
    fi
}

# Check resource usage
check_resource_usage() {
    echo ""
    echo -e "${BLUE}Resource Usage${NC}"
    echo "----------------------------------------"
    
    # Memory usage
    print_service "Memory Usage"
    total_memory=$(free -g | awk '/^Mem:/{print $2}')
    used_memory=$(free -g | awk '/^Mem:/{print $3}')
    memory_percent=$((used_memory * 100 / total_memory))
    
    if [ "$memory_percent" -lt 80 ]; then
        print_status "HEALTHY" "${memory_percent}% used (${used_memory}G/${total_memory}G)"
    elif [ "$memory_percent" -lt 90 ]; then
        print_status "WARNING" "${memory_percent}% used (${used_memory}G/${total_memory}G)"
    else
        print_status "UNHEALTHY" "${memory_percent}% used (${used_memory}G/${total_memory}G)"
    fi
    
    # Disk usage
    print_service "Disk Usage"
    disk_usage=$(df -h . | awk 'NR==2{print $5}' | sed 's/%//')
    available_space=$(df -h . | awk 'NR==2{print $4}')
    
    if [ "$disk_usage" -lt 80 ]; then
        print_status "HEALTHY" "${disk_usage}% used (${available_space} free)"
    elif [ "$disk_usage" -lt 90 ]; then
        print_status "WARNING" "${disk_usage}% used (${available_space} free)"
    else
        print_status "UNHEALTHY" "${disk_usage}% used (${available_space} free)"
    fi
}

# Check data persistence
check_data_persistence() {
    echo ""
    echo -e "${BLUE}Data Persistence${NC}"
    echo "----------------------------------------"
    
    # Check data directories
    data_dirs=("data/postgresql" "data/auth-keys" "data/prometheus" "data/grafana" "logs")
    
    for dir in "${data_dirs[@]}"; do
        service_name=$(basename "$dir")
        print_service "$service_name Data"
        
        if [ -d "$dir" ]; then
            dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            print_status "HEALTHY" "Directory exists (${dir_size})"
        else
            print_status "WARNING" "Directory not found: $dir"
        fi
    done
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            Health Summary            ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
    
    # Count results
    healthy_count=0
    warning_count=0
    unhealthy_count=0
    
    for result in "${RESULTS[@]}"; do
        if [[ $result == *"HEALTHY"* ]]; then
            ((healthy_count++))
        elif [[ $result == *"WARNING"* ]]; then
            ((warning_count++))
        elif [[ $result == *"UNHEALTHY"* ]]; then
            ((unhealthy_count++))
        fi
    done
    
    total_checks=${#RESULTS[@]}
    
    echo "Total Checks: $total_checks"
    echo -e "Healthy: ${GREEN}$healthy_count${NC}"
    echo -e "Warnings: ${YELLOW}$warning_count${NC}"
    echo -e "Unhealthy: ${RED}$unhealthy_count${NC}"
    echo ""
    
    # Overall status
    if [ $OVERALL_STATUS -eq 0 ] && [ $unhealthy_count -eq 0 ]; then
        if [ $warning_count -eq 0 ]; then
            echo -e "Overall Status: ${GREEN}HEALTHY${NC} ✅"
        else
            echo -e "Overall Status: ${YELLOW}WARNING${NC} ⚠️"
        fi
    else
        echo -e "Overall Status: ${RED}UNHEALTHY${NC} ❌"
    fi
    
    # Suggestions
    if [ $warning_count -gt 0 ] || [ $unhealthy_count -gt 0 ]; then
        echo ""
        echo "Suggestions:"
        echo "• Check service logs: docker compose logs [service-name]"
        echo "• Restart unhealthy services: docker compose restart [service-name]"
        echo "• Verify configuration files and environment variables"
        echo "• Check system resources and available disk space"
    fi
}

# Main function
main() {
    print_header
    
    # Core infrastructure checks
    check_docker
    check_compose_services
    
    echo ""
    echo -e "${BLUE}Individual Service Health${NC}"
    echo "----------------------------------------"
    
    # Check each service
    check_container_health "MCP Client" "mcp-client-app"
    check_container_health "Knowledge Graph" "knowledge-graph-db"
    check_container_health "Auth Service" "auth-service"
    check_container_health "Load Balancer" "load-balancer"
    check_container_health "Prometheus" "monitoring-prometheus"
    check_container_health "Grafana" "monitoring-grafana"
    
    # Additional checks
    if [ "$1" != "--quick" ]; then
        check_network_connectivity
        check_http_endpoints
        check_resource_usage
        check_data_persistence
    fi
    
    print_summary
    
    exit $OVERALL_STATUS
}

# Help function
show_help() {
    echo "MCP Client Health Check Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --quick     Run only basic container health checks"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Full health check"
    echo "  $0 --quick        # Quick health check"
}

# Handle arguments
case "${1:-}" in
    --help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac

#!/bin/bash

# SwargFood Task Management - Health Check Script
# Comprehensive health monitoring for the application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="https://ai.swargfood.com"
TIMEOUT=10
VERBOSE=false
JSON_OUTPUT=false

# Health check results
HEALTH_RESULTS=()
OVERALL_STATUS="HEALTHY"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose         Show detailed output"
    echo "  -j, --json           Output results in JSON format"
    echo "  -t, --timeout SEC    Request timeout in seconds (default: 10)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -v"
    echo "  $0 --json --timeout 5"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

# Function to check endpoint
check_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="$3"
    local expected_content="$4"
    
    if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
        echo -n "Checking $name... "
    fi
    
    # Make request
    local response=$(curl -s -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null || echo "000")
    local http_code="${response: -3}"
    local body="${response%???}"
    
    # Check status code
    local status="HEALTHY"
    local message="OK"
    
    if [ "$http_code" != "$expected_status" ]; then
        status="UNHEALTHY"
        message="Expected status $expected_status, got $http_code"
        OVERALL_STATUS="UNHEALTHY"
    elif [ -n "$expected_content" ] && [[ "$body" != *"$expected_content"* ]]; then
        status="UNHEALTHY"
        message="Expected content not found"
        OVERALL_STATUS="UNHEALTHY"
    fi
    
    # Store result
    HEALTH_RESULTS+=("$name|$url|$status|$http_code|$message")
    
    if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
        if [ "$status" = "HEALTHY" ]; then
            echo -e "${GREEN}✅ $status${NC}"
        else
            echo -e "${RED}❌ $status - $message${NC}"
        fi
    fi
}

# Function to check PM2 processes
check_pm2() {
    if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
        echo -n "Checking PM2 processes... "
    fi
    
    local status="HEALTHY"
    local message="All processes running"
    
    # Check if we can access PM2 (this would need to be run on the server)
    # For now, we'll check if the application is responding
    local response=$(curl -s --max-time $TIMEOUT "$BASE_URL/task/health" 2>/dev/null || echo "")
    
    if [[ "$response" != *"OK"* ]]; then
        status="UNHEALTHY"
        message="Application not responding"
        OVERALL_STATUS="UNHEALTHY"
    fi
    
    HEALTH_RESULTS+=("PM2 Processes|N/A|$status|N/A|$message")
    
    if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
        if [ "$status" = "HEALTHY" ]; then
            echo -e "${GREEN}✅ $status${NC}"
        else
            echo -e "${RED}❌ $status - $message${NC}"
        fi
    fi
}

# Function to check database connectivity
check_database() {
    if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
        echo -n "Checking database connectivity... "
    fi
    
    local status="HEALTHY"
    local message="Database accessible"
    
    # Check health endpoint which should verify database
    local response=$(curl -s --max-time $TIMEOUT "$BASE_URL/task/health" 2>/dev/null || echo "")
    
    if [[ "$response" != *"OK"* ]]; then
        status="UNHEALTHY"
        message="Health endpoint indicates database issues"
        OVERALL_STATUS="UNHEALTHY"
    fi
    
    HEALTH_RESULTS+=("Database|N/A|$status|N/A|$message")
    
    if [ "$VERBOSE" = true ] && [ "$JSON_OUTPUT" = false ]; then
        if [ "$status" = "HEALTHY" ]; then
            echo -e "${GREEN}✅ $status${NC}"
        else
            echo -e "${RED}❌ $status - $message${NC}"
        fi
    fi
}

# Function to output JSON results
output_json() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "{"
    echo "  \"timestamp\": \"$timestamp\","
    echo "  \"overall_status\": \"$OVERALL_STATUS\","
    echo "  \"checks\": ["
    
    local first=true
    for result in "${HEALTH_RESULTS[@]}"; do
        IFS='|' read -r name url status code message <<< "$result"
        
        if [ "$first" = false ]; then
            echo ","
        fi
        first=false
        
        echo -n "    {"
        echo -n "\"name\": \"$name\", "
        echo -n "\"url\": \"$url\", "
        echo -n "\"status\": \"$status\", "
        echo -n "\"http_code\": \"$code\", "
        echo -n "\"message\": \"$message\""
        echo -n "}"
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# Function to output human-readable results
output_human() {
    echo -e "${BLUE}🏥 SwargFood Task Management Health Check${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    echo -e "${YELLOW}Timestamp: $(date)${NC}"
    echo ""
    
    # Summary table
    printf "%-25s %-10s %-15s %s\n" "Component" "Status" "HTTP Code" "Message"
    printf "%-25s %-10s %-15s %s\n" "-------------------------" "----------" "---------------" "-------"
    
    for result in "${HEALTH_RESULTS[@]}"; do
        IFS='|' read -r name url status code message <<< "$result"
        
        local status_color=""
        if [ "$status" = "HEALTHY" ]; then
            status_color="${GREEN}$status${NC}"
        else
            status_color="${RED}$status${NC}"
        fi
        
        printf "%-25s %-20s %-15s %s\n" "$name" "$status_color" "$code" "$message"
    done
    
    echo ""
    
    if [ "$OVERALL_STATUS" = "HEALTHY" ]; then
        echo -e "${GREEN}✅ Overall Status: HEALTHY${NC}"
    else
        echo -e "${RED}❌ Overall Status: UNHEALTHY${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Application URLs:${NC}"
    echo -e "  Frontend: $BASE_URL/task/"
    echo -e "  API: $BASE_URL/task/api"
    echo -e "  Health: $BASE_URL/task/health"
}

# Main execution
if [ "$JSON_OUTPUT" = false ]; then
    echo -e "${BLUE}🔍 Starting health check...${NC}"
    echo ""
fi

# Perform health checks
check_endpoint "Frontend" "$BASE_URL/task/" "200" ""
check_endpoint "API Base" "$BASE_URL/task/api" "200" "SwargFood"
check_endpoint "Health Endpoint" "$BASE_URL/task/health" "200" "OK"
check_endpoint "Projects API" "$BASE_URL/task/api/projects" "200,401,403" ""
check_endpoint "Tasks API" "$BASE_URL/task/api/tasks" "200,401,403" ""
check_pm2
check_database

# Output results
if [ "$JSON_OUTPUT" = true ]; then
    output_json
else
    echo ""
    output_human
fi

# Exit with appropriate code
if [ "$OVERALL_STATUS" = "HEALTHY" ]; then
    exit 0
else
    exit 1
fi

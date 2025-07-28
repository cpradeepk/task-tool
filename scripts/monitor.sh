#!/bin/bash

# SwargFood Task Management - Monitoring Script
# Continuous monitoring with alerting capabilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INTERVAL=60  # Check interval in seconds
LOG_FILE="/tmp/swargfood-monitor.log"
ALERT_THRESHOLD=3  # Number of consecutive failures before alert
WEBHOOK_URL=""  # Slack/Discord webhook URL for alerts

# Counters
FAILURE_COUNT=0
LAST_STATUS="UNKNOWN"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --interval SEC    Check interval in seconds (default: 60)"
    echo "  -l, --log FILE       Log file path (default: /tmp/swargfood-monitor.log)"
    echo "  -t, --threshold NUM  Alert threshold (default: 3)"
    echo "  -w, --webhook URL    Webhook URL for alerts"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -i 30 -t 2"
    echo "  $0 --webhook https://hooks.slack.com/..."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -t|--threshold)
            ALERT_THRESHOLD="$2"
            shift 2
            ;;
        -w|--webhook)
            WEBHOOK_URL="$2"
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

# Function to log message
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to send alert
send_alert() {
    local status="$1"
    local message="$2"
    
    if [ -n "$WEBHOOK_URL" ]; then
        local payload=$(cat << EOF
{
    "text": "🚨 SwargFood Task Management Alert",
    "attachments": [
        {
            "color": "danger",
            "fields": [
                {
                    "title": "Status",
                    "value": "$status",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "$message",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date)",
                    "short": true
                },
                {
                    "title": "Application",
                    "value": "https://ai.swargfood.com/task/",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )
        
        curl -X POST -H 'Content-type: application/json' \
             --data "$payload" \
             "$WEBHOOK_URL" > /dev/null 2>&1 || true
    fi
    
    # Also log the alert
    log_message "ALERT" "$status - $message"
}

# Function to send recovery notification
send_recovery() {
    if [ -n "$WEBHOOK_URL" ]; then
        local payload=$(cat << EOF
{
    "text": "✅ SwargFood Task Management Recovery",
    "attachments": [
        {
            "color": "good",
            "fields": [
                {
                    "title": "Status",
                    "value": "RECOVERED",
                    "short": true
                },
                {
                    "title": "Message",
                    "value": "Application is healthy again",
                    "short": false
                },
                {
                    "title": "Timestamp",
                    "value": "$(date)",
                    "short": true
                },
                {
                    "title": "Application",
                    "value": "https://ai.swargfood.com/task/",
                    "short": true
                }
            ]
        }
    ]
}
EOF
        )
        
        curl -X POST -H 'Content-type: application/json' \
             --data "$payload" \
             "$WEBHOOK_URL" > /dev/null 2>&1 || true
    fi
    
    log_message "INFO" "Application recovered - all systems healthy"
}

# Function to perform health check
perform_health_check() {
    local health_output
    local health_status
    
    # Run health check script
    if health_output=$(./scripts/health-check.sh --json 2>&1); then
        health_status=$(echo "$health_output" | grep -o '"overall_status": "[^"]*"' | cut -d'"' -f4)
        
        if [ "$health_status" = "HEALTHY" ]; then
            # Reset failure count on success
            if [ $FAILURE_COUNT -gt 0 ]; then
                log_message "INFO" "Health check passed - resetting failure count"
                
                # Send recovery notification if we were in failure state
                if [ $FAILURE_COUNT -ge $ALERT_THRESHOLD ]; then
                    send_recovery
                fi
                
                FAILURE_COUNT=0
            fi
            
            LAST_STATUS="HEALTHY"
            return 0
        else
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            LAST_STATUS="UNHEALTHY"
            
            log_message "WARN" "Health check failed (attempt $FAILURE_COUNT/$ALERT_THRESHOLD)"
            
            # Send alert if threshold reached
            if [ $FAILURE_COUNT -eq $ALERT_THRESHOLD ]; then
                send_alert "UNHEALTHY" "Application health check failed $FAILURE_COUNT consecutive times"
            fi
            
            return 1
        fi
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        LAST_STATUS="ERROR"
        
        log_message "ERROR" "Health check script failed (attempt $FAILURE_COUNT/$ALERT_THRESHOLD): $health_output"
        
        # Send alert if threshold reached
        if [ $FAILURE_COUNT -eq $ALERT_THRESHOLD ]; then
            send_alert "ERROR" "Health check script failed $FAILURE_COUNT consecutive times"
        fi
        
        return 1
    fi
}

# Function to display status
display_status() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -ne "\r${BLUE}[$timestamp]${NC} "
    
    case $LAST_STATUS in
        "HEALTHY")
            echo -ne "${GREEN}✅ HEALTHY${NC}"
            ;;
        "UNHEALTHY")
            echo -ne "${YELLOW}⚠️  UNHEALTHY${NC}"
            ;;
        "ERROR")
            echo -ne "${RED}❌ ERROR${NC}"
            ;;
        *)
            echo -ne "${BLUE}🔍 CHECKING${NC}"
            ;;
    esac
    
    echo -ne " | Failures: $FAILURE_COUNT/$ALERT_THRESHOLD | Next check in ${INTERVAL}s"
}

# Function to handle cleanup on exit
cleanup() {
    echo ""
    log_message "INFO" "Monitoring stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main monitoring loop
echo -e "${BLUE}🔍 SwargFood Task Management Monitor${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo -e "  Check Interval: ${GREEN}${INTERVAL}s${NC}"
echo -e "  Alert Threshold: ${GREEN}$ALERT_THRESHOLD${NC}"
echo -e "  Log File: ${GREEN}$LOG_FILE${NC}"
echo -e "  Webhook: ${GREEN}$([ -n "$WEBHOOK_URL" ] && echo "Configured" || echo "Not configured")${NC}"
echo ""

log_message "INFO" "Monitoring started with interval ${INTERVAL}s, threshold $ALERT_THRESHOLD"

while true; do
    # Perform health check
    perform_health_check
    
    # Display current status
    display_status
    
    # Wait for next check
    sleep $INTERVAL
done

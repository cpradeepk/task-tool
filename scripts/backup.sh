#!/bin/bash

# Task Management Tool - Backup Script
# This script creates backups of the database and uploaded files

set -e

# Configuration
BACKUP_DIR="/backups"
DB_HOST="${DB_HOST:-database}"
DB_NAME="${DB_NAME:-taskmanagement}"
DB_USER="${DB_USER:-taskuser}"
DB_PASSWORD="${PGPASSWORD:-taskpassword123}"
UPLOADS_DIR="${UPLOADS_DIR:-/app/uploads}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Database backup
backup_database() {
    print_info "Starting database backup..."
    
    local backup_file="$BACKUP_DIR/database_backup_$TIMESTAMP.sql"
    
    if pg_dump -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" > "$backup_file"; then
        gzip "$backup_file"
        print_success "Database backup completed: ${backup_file}.gz"
    else
        print_error "Database backup failed"
        exit 1
    fi
}

# Files backup
backup_files() {
    print_info "Starting files backup..."
    
    if [ -d "$UPLOADS_DIR" ]; then
        local backup_file="$BACKUP_DIR/files_backup_$TIMESTAMP.tar.gz"
        
        if tar -czf "$backup_file" -C "$(dirname "$UPLOADS_DIR")" "$(basename "$UPLOADS_DIR")"; then
            print_success "Files backup completed: $backup_file"
        else
            print_error "Files backup failed"
            exit 1
        fi
    else
        print_info "Uploads directory not found, skipping files backup"
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    print_info "Cleaning up old backups (older than $RETENTION_DAYS days)..."
    
    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
    
    print_success "Cleanup completed"
}

# Upload to cloud storage (optional)
upload_to_cloud() {
    if [ -n "$AWS_S3_BUCKET" ] && command -v aws &> /dev/null; then
        print_info "Uploading backups to S3..."
        
        aws s3 sync "$BACKUP_DIR" "s3://$AWS_S3_BUCKET/backups/" \
            --exclude "*" \
            --include "*_$TIMESTAMP.*"
        
        print_success "Upload to S3 completed"
    elif [ -n "$GOOGLE_CLOUD_BUCKET" ] && command -v gsutil &> /dev/null; then
        print_info "Uploading backups to Google Cloud Storage..."
        
        gsutil -m cp "$BACKUP_DIR"/*_$TIMESTAMP.* "gs://$GOOGLE_CLOUD_BUCKET/backups/"
        
        print_success "Upload to Google Cloud Storage completed"
    fi
}

# Send notification (optional)
send_notification() {
    if [ -n "$WEBHOOK_URL" ]; then
        local message="Backup completed successfully at $(date)"
        
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$message\"}" \
            > /dev/null 2>&1
    fi
}

# Main backup function
main() {
    print_info "Starting backup process..."
    
    backup_database
    backup_files
    cleanup_old_backups
    upload_to_cloud
    send_notification
    
    print_success "Backup process completed successfully!"
    
    # Show backup summary
    echo ""
    print_info "Backup Summary:"
    ls -lh "$BACKUP_DIR"/*_$TIMESTAMP.*
}

# Run main function
main "$@"

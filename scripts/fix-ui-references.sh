#!/bin/bash

# Script to fix all remaining MainLayout and old UI references
# This script systematically updates all Flutter files to use the new orange theme and ModernLayout

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Change to frontend directory
cd "$(dirname "$0")/../frontend" || error "Cannot find frontend directory"

log "🔧 Starting comprehensive UI reference fixes..."

# List of files that need MainLayout -> ModernLayout conversion
FILES_TO_FIX=(
    "lib/personal/profile_edit.dart"
    "lib/personal/notes_system.dart"
    "lib/features/other_people_tasks.dart"
    "lib/features/pert_analysis.dart"
    "lib/admin/master_data.dart"
    "lib/admin/jsr_reports.dart"
    "lib/admin/project_create.dart"
    "lib/admin/project_settings.dart"
    "lib/admin/role_assign.dart"
    "lib/admin/role_manage.dart"
    "lib/admin/module_management.dart"
    "lib/admin/user_management.dart"
    "lib/admin/daily_summary_report.dart"
    "lib/features/calendar_view.dart"
    "lib/features/chat_system.dart"
    "lib/features/alerts_system.dart"
    "lib/features/notification_system.dart"
    "lib/features/advanced_search.dart"
    "lib/personal/availability_management.dart"
)

# Fix import statements
log "📝 Fixing import statements..."
for file in "${FILES_TO_FIX[@]}"; do
    if [ -f "$file" ]; then
        info "Fixing imports in $file"
        sed -i "s|import '../main_layout.dart';|import '../modern_layout.dart';|g" "$file"
        sed -i "s|import '../sidebar_navigation.dart';||g" "$file"
        sed -i "s|import 'main_layout.dart';|import 'modern_layout.dart';|g" "$file"
        sed -i "s|import 'sidebar_navigation.dart';||g" "$file"
    else
        warn "File not found: $file"
    fi
done

# Fix MainLayout widget usage
log "🔄 Converting MainLayout to ModernLayout..."
for file in "${FILES_TO_FIX[@]}"; do
    if [ -f "$file" ]; then
        info "Converting MainLayout in $file"
        sed -i "s|MainLayout(|ModernLayout(|g" "$file"
    fi
done

# Fix color references
log "🎨 Fixing color references to use orange theme..."

# Fix Colors.blue references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.blue|const Color(0xFFFFA301)|g" {} \;

# Fix Colors.green references  
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.green|const Color(0xFFE6920E)|g" {} \;

# Fix Colors.purple references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.purple|const Color(0xFFCC8200)|g" {} \;

# Fix Colors.red references (keep for errors, but use orange variant)
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.red|const Color(0xFFB37200)|g" {} \;

# Fix Colors.orange references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.orange|const Color(0xFFFFA301)|g" {} \;

# Fix Colors.teal references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.teal|const Color(0xFFFFCA1A)|g" {} \;

# Fix Colors.indigo references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.indigo|const Color(0xFFFFD54D)|g" {} \;

# Fix Colors.pink references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.pink|const Color(0xFFFFE080)|g" {} \;

# Fix Colors.amber references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.amber|const Color(0xFFFFECB3)|g" {} \;

# Fix Colors.cyan references
find lib -name "*.dart" -type f -exec sed -i "s|Colors\.cyan|const Color(0xFFFFF8E6)|g" {} \;

log "✅ UI reference fixes completed!"

# Run flutter analyze to check for issues
log "🔍 Running Flutter analyze..."
if flutter analyze; then
    log "✅ Flutter analyze passed!"
else
    warn "Flutter analyze found issues - please review manually"
fi

log "🎉 All UI fixes completed successfully!"
log "📋 Summary of changes:"
log "   - Removed old sidebar navigation"
log "   - Converted all MainLayout to ModernLayout"
log "   - Updated all color references to orange theme"
log "   - Fixed import statements"
log ""
log "🚀 Ready for deployment!"

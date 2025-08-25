#!/bin/bash

# Fix admin pages color scheme - replace blue/green/red with orange theme

echo "🎨 Fixing admin pages color scheme..."

# List of admin files to fix
ADMIN_FILES=(
    "frontend/lib/admin/module_management.dart"
    "frontend/lib/admin/role_manage.dart"
    "frontend/lib/admin/project_create.dart"
    "frontend/lib/admin/project_settings.dart"
    "frontend/lib/admin/role_assign.dart"
    "frontend/lib/admin/jsr_reports.dart"
    "frontend/lib/admin/daily_summary_report.dart"
)

# Color replacements
declare -A COLOR_REPLACEMENTS=(
    ["Colors.blue"]="Color(0xFFFFA301)"
    ["Colors.green"]="Color(0xFFFFA301)"
    ["Colors.red"]="Color(0xFFE6920E)"
    ["color: Colors.blue"]="color: Color(0xFFFFA301)"
    ["color: Colors.green"]="color: Color(0xFFFFA301)"
    ["color: Colors.red"]="color: Color(0xFFE6920E)"
    ["backgroundColor: Colors.blue"]="backgroundColor: Color(0xFFFFA301)"
    ["backgroundColor: Colors.green"]="backgroundColor: Color(0xFFFFA301)"
    ["backgroundColor: Colors.red"]="backgroundColor: Color(0xFFE6920E)"
)

for file in "${ADMIN_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "Fixing colors in $file"
        
        # Apply color replacements
        for old_color in "${!COLOR_REPLACEMENTS[@]}"; do
            new_color="${COLOR_REPLACEMENTS[$old_color]}"
            sed -i "s/$old_color/const $new_color/g" "$file"
        done
        
        echo "✅ Fixed $file"
    else
        echo "⚠️ File not found: $file"
    fi
done

echo "🎨 Admin color scheme fix completed!"

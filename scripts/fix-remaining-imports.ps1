# PowerShell script to fix all remaining MainLayout references
# This script systematically updates all Flutter files

Write-Host "🔧 Starting comprehensive MainLayout fixes..." -ForegroundColor Green

# Change to frontend directory
Set-Location "frontend"

# List of files that need fixing
$filesToFix = @(
    "lib/admin/master_data.dart",
    "lib/admin/project_create.dart", 
    "lib/admin/role_assign.dart",
    "lib/admin/role_manage.dart",
    "lib/admin/module_management.dart",
    "lib/features/pert_analysis.dart",
    "lib/features/calendar_view.dart",
    "lib/features/chat_system.dart",
    "lib/features/alerts_system.dart",
    "lib/features/other_people_tasks.dart",
    "lib/features/notification_system.dart",
    "lib/features/advanced_search.dart",
    "lib/personal/notes_system.dart",
    "lib/personal/availability_management.dart"
)

Write-Host "📝 Fixing import statements..." -ForegroundColor Yellow

foreach ($file in $filesToFix) {
    if (Test-Path $file) {
        Write-Host "Fixing imports in $file" -ForegroundColor Cyan
        
        # Fix main_layout import
        (Get-Content $file) -replace "import '../main_layout.dart';", "import '../modern_layout.dart';" | Set-Content $file
        
        # Fix MainLayout widget usage
        (Get-Content $file) -replace "MainLayout\(", "ModernLayout(" | Set-Content $file
        
        Write-Host "✅ Fixed $file" -ForegroundColor Green
    } else {
        Write-Host "⚠️ File not found: $file" -ForegroundColor Yellow
    }
}

Write-Host "🎨 Fixing remaining color references..." -ForegroundColor Yellow

# Fix any remaining color references in all dart files
Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName
    $modified = $false
    
    # Replace Colors.blue with orange
    if ($content -match "Colors\.blue") {
        $content = $content -replace "Colors\.blue", "const Color(0xFFFFA301)"
        $modified = $true
    }
    
    # Replace any remaining Material colors
    if ($content -match "Colors\.green") {
        $content = $content -replace "Colors\.green", "const Color(0xFFE6920E)"
        $modified = $true
    }
    
    if ($content -match "Colors\.purple") {
        $content = $content -replace "Colors\.purple", "const Color(0xFFCC8200)"
        $modified = $true
    }
    
    if ($modified) {
        Set-Content $_.FullName $content
        Write-Host "🎨 Updated colors in $($_.Name)" -ForegroundColor Magenta
    }
}

Write-Host "✅ All fixes completed!" -ForegroundColor Green
Write-Host "🔍 Running Flutter analyze..." -ForegroundColor Yellow

# Run flutter analyze
flutter analyze

Write-Host "🎉 MainLayout fixes completed successfully!" -ForegroundColor Green

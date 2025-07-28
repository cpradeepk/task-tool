#!/bin/bash

# SwargFood Task Management Tool - Quick Deployment Script
# Domain: ai.swargfood.com/task
# Path: /var/www/task

set -e

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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  SwargFood Task Management     ${NC}"
    echo -e "${BLUE}  Deployment Script             ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Check if running as root
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        print_info "Please run as a regular user with sudo privileges"
        exit 1
    fi
}

# Install system dependencies
install_dependencies() {
    print_info "Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y curl wget gnupg2 software-properties-common
    
    # Install Node.js 18
    if ! command -v node &> /dev/null; then
        print_info "Installing Node.js 18..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    
    # Install PostgreSQL
    if ! command -v psql &> /dev/null; then
        print_info "Installing PostgreSQL..."
        sudo apt install -y postgresql postgresql-contrib
    fi
    
    # Install Nginx
    if ! command -v nginx &> /dev/null; then
        print_info "Installing Nginx..."
        sudo apt install -y nginx
    fi
    
    # Install PM2
    if ! command -v pm2 &> /dev/null; then
        print_info "Installing PM2..."
        sudo npm install -g pm2
    fi
    
    print_success "System dependencies installed"
}

# Setup application directory
setup_directory() {
    print_info "Setting up application directory..."
    
    sudo mkdir -p /var/www/task
    sudo chown -R $USER:$USER /var/www/task
    
    # Create necessary subdirectories
    mkdir -p /var/www/task/logs
    mkdir -p /var/www/task/uploads
    
    print_success "Application directory setup completed"
}

# Setup database
setup_database() {
    print_info "Setting up PostgreSQL database..."
    
    # Start PostgreSQL service
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    # Create database and user
    sudo -u postgres psql -c "CREATE DATABASE taskmanagement;" 2>/dev/null || true
    sudo -u postgres psql -c "CREATE USER taskuser WITH PASSWORD 'swargfood2024';" 2>/dev/null || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE taskmanagement TO taskuser;" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER USER taskuser CREATEDB;" 2>/dev/null || true
    
    print_success "Database setup completed"
}

# Deploy application
deploy_application() {
    print_info "Deploying application..."
    
    cd /var/www/task
    
    # Install backend dependencies
    cd backend
    npm install --production
    
    # Generate Prisma client
    npm run generate
    
    # Run database migrations
    npm run migrate:prod
    
    # Start application with PM2
    pm2 start ecosystem.config.js --env production
    pm2 save
    pm2 startup
    
    cd ..
    print_success "Application deployed successfully"
}

# Configure Nginx
configure_nginx() {
    print_info "Configuring Nginx..."
    
    # Create Nginx configuration
    sudo tee /etc/nginx/sites-available/swargfood-task > /dev/null <<'EOF'
server {
    listen 80;
    server_name ai.swargfood.com;

    # Task Management Backend API
    location /task/api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Task Management Socket.IO
    location /task/socket.io/ {
        proxy_pass http://localhost:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Task Management Frontend
    location /task/ {
        alias /var/www/task/frontend/build/web/;
        index index.html;
        try_files $uri $uri/ /task/index.html;
    }

    # File uploads
    location /task/uploads/ {
        alias /var/www/task/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location /task/health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }
}
EOF

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/swargfood-task /etc/nginx/sites-enabled/
    
    # Test configuration
    sudo nginx -t
    
    # Restart Nginx
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    print_success "Nginx configuration completed"
}

# Setup SSL certificate
setup_ssl() {
    print_info "Setting up SSL certificate..."
    
    # Install Certbot
    sudo apt install -y certbot python3-certbot-nginx
    
    # Get certificate (this will prompt for email and agreement)
    print_warning "You will be prompted to enter your email and agree to terms"
    sudo certbot --nginx -d ai.swargfood.com
    
    # Setup auto-renewal
    sudo crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | sudo crontab -
    
    print_success "SSL certificate setup completed"
}

# Create environment file
create_env_file() {
    print_info "Creating environment configuration..."
    
    if [ ! -f /var/www/task/.env ]; then
        cat > /var/www/task/.env <<EOF
# SwargFood Task Management Configuration
NODE_ENV=production
PORT=3000

# Database
DATABASE_URL="postgresql://taskuser:swargfood2024@localhost:5432/taskmanagement"

# JWT Security (CHANGE THESE IN PRODUCTION!)
JWT_SECRET="swargfood-task-management-jwt-secret-2024"
JWT_REFRESH_SECRET="swargfood-task-management-refresh-secret-2024"

# Google OAuth (UPDATE WITH YOUR CREDENTIALS)
GOOGLE_CLIENT_ID="your-google-client-id.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="your-google-client-secret"

# SwargFood Configuration
API_BASE_URL="https://ai.swargfood.com/task"
FRONTEND_URL="https://ai.swargfood.com/task"
CORS_ORIGIN="https://ai.swargfood.com"
SOCKET_CORS_ORIGIN="https://ai.swargfood.com"

# File Storage
UPLOAD_DIR="/var/www/task/uploads"
MAX_FILE_SIZE=10485760

# Email (Optional)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="your-email@swargfood.com"
SMTP_PASS="your-app-password"
FROM_EMAIL="noreply@swargfood.com"
FROM_NAME="SwargFood Task Management"

# Logging
LOG_LEVEL="error"
LOG_FILE="/var/www/task/logs/app.log"
EOF
        
        print_warning "Environment file created with default values"
        print_warning "Please update .env file with your actual credentials"
    else
        print_info "Environment file already exists"
    fi
}

# Health check
health_check() {
    print_info "Running health check..."
    
    sleep 5
    
    # Check if backend is running
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        print_success "Backend is healthy"
    else
        print_error "Backend health check failed"
        return 1
    fi
    
    # Check if Nginx is serving the site
    if curl -f http://ai.swargfood.com/task/health > /dev/null 2>&1; then
        print_success "Frontend is accessible"
    else
        print_warning "Frontend may not be accessible yet (SSL setup needed?)"
    fi
    
    print_success "Health check completed"
}

# Show final instructions
show_final_instructions() {
    echo ""
    print_success "🎉 Deployment completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "1. Update /var/www/task/.env with your Google OAuth credentials"
    echo "2. Update JWT secrets in .env file"
    echo "3. Configure your email settings (optional)"
    echo "4. Build and deploy the Flutter frontend"
    echo ""
    print_info "Access URLs:"
    echo "• Frontend: https://ai.swargfood.com/task/"
    echo "• API: https://ai.swargfood.com/task/api/"
    echo "• Health: https://ai.swargfood.com/task/health"
    echo ""
    print_info "Useful commands:"
    echo "• Check status: pm2 status"
    echo "• View logs: pm2 logs"
    echo "• Restart app: pm2 restart swargfood-task-management"
    echo "• Check Nginx: sudo nginx -t"
    echo ""
}

# Main deployment function
main() {
    print_header
    
    check_permissions
    install_dependencies
    setup_directory
    setup_database
    create_env_file
    deploy_application
    configure_nginx
    
    # Ask about SSL setup
    read -p "Do you want to setup SSL certificate now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_ssl
    else
        print_warning "SSL setup skipped. You can run 'sudo certbot --nginx -d ai.swargfood.com' later"
    fi
    
    health_check
    show_final_instructions
}

# Run main function
main "$@"

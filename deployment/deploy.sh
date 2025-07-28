#!/bin/bash

# Task Management Tool - Deployment Script
# This script helps deploy the application to various environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKEND_DIR="backend"
FRONTEND_DIR="frontend"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Task Management Tool Deploy   ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

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

check_requirements() {
    print_info "Checking requirements..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 18+ first."
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm first."
        exit 1
    fi
    
    # Check Flutter (for frontend deployment)
    if ! command -v flutter &> /dev/null; then
        print_warning "Flutter is not installed. Frontend deployment will be skipped."
        FLUTTER_AVAILABLE=false
    else
        FLUTTER_AVAILABLE=true
    fi
    
    # Check Docker (for containerized deployment)
    if ! command -v docker &> /dev/null; then
        print_warning "Docker is not installed. Containerized deployment will be skipped."
        DOCKER_AVAILABLE=false
    else
        DOCKER_AVAILABLE=true
    fi
    
    print_success "Requirements check completed"
}

setup_environment() {
    print_info "Setting up environment..."
    
    # Create .env file if it doesn't exist
    if [ ! -f "$BACKEND_DIR/.env" ]; then
        if [ -f "$BACKEND_DIR/.env.example" ]; then
            cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
            print_warning "Created .env file from .env.example. Please update it with your configuration."
        else
            print_error ".env.example file not found. Please create .env file manually."
            exit 1
        fi
    fi
    
    print_success "Environment setup completed"
}

deploy_backend() {
    print_info "Deploying backend..."
    
    cd "$BACKEND_DIR"
    
    # Install dependencies
    print_info "Installing backend dependencies..."
    npm install --production
    
    # Generate Prisma client
    print_info "Generating Prisma client..."
    npm run generate
    
    # Run database migrations
    print_info "Running database migrations..."
    if [ "$ENVIRONMENT" = "production" ]; then
        npm run migrate:prod
    else
        npm run migrate
    fi
    
    # Start the application
    if [ "$DEPLOYMENT_TYPE" = "pm2" ]; then
        print_info "Starting backend with PM2..."
        npm install -g pm2
        pm2 start ecosystem.config.js --env "$ENVIRONMENT"
        pm2 save
    elif [ "$DEPLOYMENT_TYPE" = "systemd" ]; then
        print_info "Setting up systemd service..."
        setup_systemd_service
    else
        print_info "Starting backend in development mode..."
        npm run dev &
    fi
    
    cd ..
    print_success "Backend deployment completed"
}

deploy_frontend() {
    if [ "$FLUTTER_AVAILABLE" = false ]; then
        print_warning "Skipping frontend deployment (Flutter not available)"
        return
    fi
    
    print_info "Deploying frontend..."
    
    cd "$FRONTEND_DIR"
    
    # Get dependencies
    print_info "Getting Flutter dependencies..."
    flutter pub get
    
    # Build for web
    if [ "$FRONTEND_TARGET" = "web" ] || [ "$FRONTEND_TARGET" = "all" ]; then
        print_info "Building Flutter web app..."
        flutter build web --release
        print_success "Web build completed. Files are in build/web/"
    fi
    
    # Build for Android
    if [ "$FRONTEND_TARGET" = "android" ] || [ "$FRONTEND_TARGET" = "all" ]; then
        print_info "Building Android APK..."
        flutter build apk --release
        print_success "Android APK completed. File is in build/app/outputs/flutter-apk/"
    fi
    
    cd ..
    print_success "Frontend deployment completed"
}

deploy_docker() {
    if [ "$DOCKER_AVAILABLE" = false ]; then
        print_warning "Skipping Docker deployment (Docker not available)"
        return
    fi
    
    print_info "Deploying with Docker..."
    
    # Build and start containers
    docker-compose up -d --build
    
    # Wait for database to be ready
    print_info "Waiting for database to be ready..."
    sleep 10
    
    # Run migrations
    print_info "Running database migrations..."
    docker-compose exec backend npm run migrate:prod
    
    print_success "Docker deployment completed"
    print_info "Application is running at http://localhost:3000"
}

setup_systemd_service() {
    print_info "Setting up systemd service..."
    
    # Create systemd service file
    sudo tee /etc/systemd/system/task-management.service > /dev/null <<EOF
[Unit]
Description=Task Management Tool
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/task/backend
ExecStart=/usr/bin/node src/server.js
Restart=on-failure
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and start service
    sudo systemctl daemon-reload
    sudo systemctl enable task-management
    sudo systemctl start task-management
    
    print_success "Systemd service setup completed"
}

setup_nginx() {
    print_info "Setting up Nginx configuration..."

    # Create Nginx configuration
    sudo tee /etc/nginx/sites-available/task-management > /dev/null <<EOF
server {
    listen 80;
    server_name ai.swargfood.com;

    # Task Management Backend API
    location /task/api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Task Management Socket.IO
    location /task/socket.io/ {
        proxy_pass http://localhost:3000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Task Management Frontend
    location /task/ {
        alias /var/www/task/frontend/build/web/;
        try_files \$uri \$uri/ /task/index.html;
    }
}
EOF

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/task-management /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
    
    print_success "Nginx configuration completed"
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Set environment (development|staging|production)"
    echo "  -t, --type TYPE         Set deployment type (local|pm2|docker|systemd)"
    echo "  -f, --frontend TARGET   Set frontend target (web|android|all|skip)"
    echo "  -n, --nginx             Setup Nginx configuration"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e production -t pm2 -f web"
    echo "  $0 -e development -t local"
    echo "  $0 -t docker"
}

# Main deployment function
main() {
    print_header
    
    # Parse command line arguments
    ENVIRONMENT="development"
    DEPLOYMENT_TYPE="local"
    FRONTEND_TARGET="web"
    SETUP_NGINX=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -t|--type)
                DEPLOYMENT_TYPE="$2"
                shift 2
                ;;
            -f|--frontend)
                FRONTEND_TARGET="$2"
                shift 2
                ;;
            -n|--nginx)
                SETUP_NGINX=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    print_info "Deployment Configuration:"
    print_info "Environment: $ENVIRONMENT"
    print_info "Type: $DEPLOYMENT_TYPE"
    print_info "Frontend: $FRONTEND_TARGET"
    echo ""
    
    # Run deployment steps
    check_requirements
    setup_environment
    
    if [ "$DEPLOYMENT_TYPE" = "docker" ]; then
        deploy_docker
    else
        deploy_backend
        if [ "$FRONTEND_TARGET" != "skip" ]; then
            deploy_frontend
        fi
    fi
    
    if [ "$SETUP_NGINX" = true ]; then
        setup_nginx
    fi
    
    print_success "Deployment completed successfully!"
    
    # Show next steps
    echo ""
    print_info "Next steps:"
    echo "1. Update your .env file with production values"
    echo "2. Configure your domain name in Nginx (if using)"
    echo "3. Set up SSL certificate with Let's Encrypt"
    echo "4. Configure your database connection"
    echo "5. Set up monitoring and logging"
}

# Run main function
main "$@"

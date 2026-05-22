#!/bin/bash

# La Suite Docs Production Deployment Script
# For docs.intelligentsalesman.com

set -e  # Exit on any error

# Configuration variables
SERVER_IP="118.139.165.145"
POSTGRES_PORT="25432"
REDIS_PORT="26379"
KEYCLOAK_URL="https://keycloak.intelligentsalesman.com"

ENV_FILE_PATH="./env.d/grow24/common"
NGINX_CONFIG_PATH="./docker/files/grow24/etc/nginx/prod.conf"

DOCKER_COMPOSE_FILE="./docker_compose_production.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
# if [[ $EUID -eq 0 ]]; then
#    print_error "This script should not be run as root for security reasons"
#    exit 1
# fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Starting La Suite Docs deployment..."

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p data/media
mkdir -p data/static
# mkdir -p env.d/grow24
# mkdir -p docker/files/grow24/etc/nginx
mkdir -p logs

# Set proper permissions
print_status "Setting proper permissions..."
sudo chown -R $USER:$USER data/
chmod 755 data/
chmod 755 data/media
chmod 755 data/static

# Check if .env files exist
if [ ! -f "$ENV_FILE_PATH" ]; then
    print_error "Production environment file not found!"
    print_error "Please create $ENV_FILE_PATH with your configuration"
    exit 1
fi

# Check if nginx config exists
if [ ! -f "$NGINX_CONFIG_PATH" ]; then
    print_error "Nginx production config not found!"
    print_error "Please create $NGINX_CONFIG_PATH"
    exit 1
fi

set -a
. "$ENV_FILE_PATH"
set +a

# Function to check if external services are reachable
check_external_services() {
    print_status "Checking external services connectivity..."
    
    # Check PostgreSQL
    if ! timeout 5 bash -c "</dev/tcp/$SERVER_IP/$POSTGRES_PORT"; then
        print_error "Cannot connect to PostgreSQL on port $POSTGRES_PORT"
        exit 1
    fi
    print_success "PostgreSQL connection OK"
    
    # Check Redis
    if ! timeout 5 bash -c "</dev/tcp/$SERVER_IP/$REDIS_PORT"; then
        print_error "Cannot connect to Redis on port $REDIS_PORT"
        exit 1
    fi
    print_success "Redis connection OK"
    
    # Check Keycloak
    if ! curl -sf $KEYCLOAK_URL/health > /dev/null 2>&1; then
        print_warning "Keycloak health check failed - please ensure it's running"
    else
        print_success "Keycloak connection OK"
    fi
}

# Function to build images
build_images() {
    print_status "Building Docker images..."
    
    # Check if we need to build or if images exist
    if [[ "$1" == "--force-build" ]] || ! docker images | grep -q "grow24_office_docs:backend-production-docs"; then
        print_status "Building backend production image..."
        docker compose -f $DOCKER_COMPOSE_FILE build app-prod
    fi

    # if [[ "$1" == "--force-build" ]] || ! docker images | grep -q "grow24_office_docs:frontend-production-docs"; then
    #     print_status "Building frontend production image..."
    #     docker compose -f $DOCKER_COMPOSE_FILE build frontend-production
    # fi
    
    if [[ "$1" == "--force-build" ]] || ! docker images | grep -q "grow24_office_docs:y-provider-production-docs"; then
        print_status "Building y-provider production image..."
        docker compose -f $DOCKER_COMPOSE_FILE build y-provider-production
    fi
}

# Function to run database migrations
run_migrations() {
    print_status "Running database migrations..."
    docker compose exec app-prod python manage.py migrate
    print_success "Database migrations completed"
}

# Function to collect static files
collect_static() {
    print_status "Collecting static files..."
    docker compose exec app-prod python manage.py collectstatic --noinput
    print_success "Static files collected"
}

# Function to create superuser
create_superuser() {
    print_status "Creating superuser (if not exists)..."
    docker compose -f $DOCKER_COMPOSE_FILE exec app-prod python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(is_superuser=True).exists():
    User.objects.create_superuser('admin', 'admin@intelligentsalesman.com', 'your-secure-admin-password')
    print('Superuser created successfully')
else:
    print('Superuser already exists')
"
}

# Function to start services
start_services() {
    print_status "Starting La Suite Docs services..."
    
    # Start infrastructure services first
    print_status "Starting infrastructure services..."
    docker compose -f $DOCKER_COMPOSE_FILE up -d minio

    # Wait for MinIO to be healthy
    # print_status "Waiting for MinIO to be ready..."
    # timeout 60 bash -c 'until docker compose -f docker_compose_production.yml exec minio mc ready local; do sleep 2; done'

    # Create buckets
    print_status "Creating MinIO buckets..."
    docker compose -f $DOCKER_COMPOSE_FILE up createbuckets

    # Start application services
    # print_status "Starting application services..."
    # docker compose -f $DOCKER_COMPOSE_FILE up -d app-prod celery-prod y-provider-production

    # Wait for backend to be ready
    print_status "Waiting for backend to be ready..."
    timeout 120 bash -c 'until curl -sf http://localhost:20001/api/v1.0/ > /dev/null 2>&1; do sleep 5; done'
    
    # Start frontend and proxy
    print_status "Starting frontend and proxy..."
    docker compose -f $DOCKER_COMPOSE_FILE up -d frontend-production nginx-proxy

    print_success "All services started successfully!"
}

# Function to show status
show_status() {
    print_status "Service status:"
    docker compose -f $DOCKER_COMPOSE_FILE ps

    print_status "\nService URLs:"
    echo "Main Application: http://localhost:20080"
    echo "Backend API: http://localhost:20001"
    echo "Frontend: http://localhost:20003"
    echo "MinIO Console: http://localhost:20010"
    echo "Y-Provider: http://localhost:20004"
    
    print_status "\nTo access via Apache, configure reverse proxy to port 20080"
}

# Function to stop services
stop_services() {
    print_status "Stopping La Suite Docs services..."
    docker compose -f $DOCKER_COMPOSE_FILE down
    print_success "Services stopped"
}

# Function to show logs
show_logs() {
    if [ -n "$2" ]; then
        docker compose logs -f "$2"
    else
        docker compose logs -f
    fi
}

# Function to backup data
backup_data() {
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    print_status "Creating backup in $BACKUP_DIR..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup media files
    cp -r data/media "$BACKUP_DIR/"
    
    # Backup static files
    cp -r data/static "$BACKUP_DIR/"
    
    # Backup environment files
    cp -r env.d "$BACKUP_DIR/"
    
    print_success "Backup created in $BACKUP_DIR"
}

# Function to update services
update_services() {
    print_status "Updating La Suite Docs..."
    
    # Pull latest code
    git pull origin main
    
    # Rebuild images
    build_images --force-build
    
    # Restart services
    docker compose -f $DOCKER_COMPOSE_FILE down
    start_services
    
    # Run migrations and collect static
    sleep 10  # Wait for services to be ready
    run_migrations
    collect_static
    
    print_success "Update completed!"
}

# Main script logic
case "$1" in
    start)
        check_external_services
        build_images
        start_services
        sleep 10  # Wait for services to be ready
        run_migrations
        collect_static
        create_superuser
        show_status
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 5
        start_services
        sleep 10
        show_status
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$@"
        ;;
    build)
        build_images --force-build
        ;;
    migrate)
        run_migrations
        ;;
    static)
        collect_static
        ;;
    superuser)
        create_superuser
        ;;
    backup)
        backup_data
        ;;
    update)
        update_services
        ;;
    shell)
        docker compose -f $DOCKER_COMPOSE_FILE exec app-prod python manage.py shell
        ;;
    bash)
        if [ -n "$2" ]; then
            docker compose -f $DOCKER_COMPOSE_FILE exec "$2" /bin/bash
        else
            docker compose -f $DOCKER_COMPOSE_FILE exec app-prod /bin/bash
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|build|migrate|static|superuser|backup|update|shell|bash [service]}"
        echo ""
        echo "Commands:"
        echo "  start     - Start all services"
        echo "  stop      - Stop all services"
        echo "  restart   - Restart all services"
        echo "  status    - Show service status and URLs"
        echo "  logs      - Show logs (add service name for specific service)"
        echo "  build     - Force rebuild all images"
        echo "  migrate   - Run database migrations"
        echo "  static    - Collect static files"
        echo "  superuser - Create Django superuser"
        echo "  backup    - Backup data and configuration"
        echo "  update    - Update from git and restart services"
        echo "  shell     - Open Django shell"
        echo "  bash      - Open bash shell (add service name for specific service)"
        echo ""
        echo "Examples:"
        echo "  $0 start                    # Start all services"
        echo "  $0 logs app-prod           # Show backend logs"
        echo "  $0 bash frontend-production # Open bash in frontend container"
        exit 1
        ;;
esac
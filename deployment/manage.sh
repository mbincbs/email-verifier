#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${YELLOW}Warning: .env file not found. Using default values.${NC}"
fi

# Default values
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.override.yml" ]; then
    COMPOSE_FILE="${COMPOSE_FILE} -f docker-compose.override.yml"
fi

# Function to display usage
usage() {
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start             Start all services"
    echo "  stop              Stop all services"
    echo "  restart           Restart all services"
    echo "  status            Show status of services"
    echo "  logs [service]    Show logs (all or specific service)"
    echo "  shell [service]   Open a shell in a running container"
    echo "  backup            Create a backup of the application data"
    echo "  restore           Restore the application from a backup"
    echo "  update            Update the application"
    echo "  help              Show this help message"
    echo ""
    exit 1
}

# Function to start services
start_services() {
    echo -e "${GREEN}Starting Email Verifier services...${NC}"
    docker-compose $COMPOSE_FILE up -d
    echo -e "${GREEN}Services started successfully!${NC}
    echo -e "Access the application at: https://${DOMAIN:-localhost}"
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}Stopping Email Verifier services...${NC}"
    docker-compose $COMPOSE_FILE down
    echo -e "${GREEN}Services stopped successfully!${NC}"
}

# Function to restart services
restart_services() {
    echo -e "${YELLOW}Restarting Email Verifier services...${NC}"
    docker-compose $COMPOSE_FILE restart
    echo -e "${GREEN}Services restarted successfully!${NC}"
}

# Function to show status
show_status() {
    echo -e "${GREEN}Current status of Email Verifier services:${NC}"
    docker-compose $COMPOSE_FILE ps
}

# Function to show logs
show_logs() {
    if [ -z "$1" ]; then
        docker-compose $COMPOSE_FILE logs -f
    else
        docker-compose $COMPOSE_FILE logs -f "$1"
    fi
}

# Function to open a shell in a container
open_shell() {
    local service=${1:-email-verifier}
    echo -e "${GREEN}Opening shell in ${service} container...${NC}"
    docker-compose $COMPOSE_FILE exec "$service" sh
}

# Function to create a backup
create_backup() {
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_dir="./backups/$timestamp"
    
    echo -e "${GREEN}Creating backup in ${backup_dir}...${NC}"
    
    mkdir -p "$backup_dir"
    
    # Backup certificates
    if [ -d "./certs" ]; then
        echo "Backing up certificates..."
        cp -r ./certs "$backup_dir/"
    fi
    
    # Backup nginx configuration
    if [ -d "./nginx" ]; then
        echo "Backing up nginx configuration..."
        cp -r ./nginx "$backup_dir/"
    fi
    
    # Backup .env file
    if [ -f ".env" ]; then
        echo "Backing up .env file..."
        cp .env "$backup_dir/"
    fi
    
    # Create a tarball of the backup
    echo "Creating backup tarball..."
    tar -czf "email-verifier-backup-$timestamp.tar.gz" -C "$backup_dir" .
    
    echo -e "${GREEN}Backup created: email-verifier-backup-${timestamp}.tar.gz${NC}"
}

# Function to restore from backup
restore_backup() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        echo -e "${YELLOW}Please specify a backup file to restore from.${NC}"
        echo "Available backups:"
        ls -1 email-verifier-backup-*.tar.gz 2>/dev/null || echo "No backup files found."
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${YELLOW}Backup file not found: $backup_file${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring from backup: $backup_file${NC}"
    echo -e "${YELLOW}This will overwrite existing files. Continue? [y/N]${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Restore cancelled."
        exit 1
    fi
    
    # Stop services
    stop_services
    
    # Extract backup
    local temp_dir=$(mktemp -d)
    echo "Extracting backup..."
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Restore files
    echo "Restoring files..."
    
    if [ -d "${temp_dir}/certs" ]; then
        echo "Restoring certificates..."
        rm -rf ./certs
        cp -r "${temp_dir}/certs" ./
    fi
    
    if [ -d "${temp_dir}/nginx" ]; then
        echo "Restoring nginx configuration..."
        rm -rf ./nginx
        cp -r "${temp_dir}/nginx" ./
    fi
    
    if [ -f "${temp_dir}/.env" ]; then
        echo "Restoring .env file..."
        cp "${temp_dir}/.env" ./
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Start services
    start_services
    
    echo -e "${GREEN}Restore completed successfully!${NC}"
}

# Function to update the application
update_application() {
    echo -e "${GREEN}Updating Email Verifier...${NC}"
    
    # Stop services
    stop_services
    
    # Pull latest changes
    echo "Pulling latest changes..."
    git pull
    
    # Rebuild and start services
    echo "Rebuilding services..."
    docker-compose $COMPOSE_FILE build --no-cache
    
    # Start services
    start_services
    
    echo -e "${GREEN}Update completed successfully!${NC}"
}

# Main command handler
case "$1" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    shell)
        open_shell "$2"
        ;;
    backup)
        create_backup
        ;;
    restore)
        restore_backup "$2"
        ;;
    update)
        update_application
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${YELLOW}Unknown command: $1${NC}"
        usage
        ;;
esac

exit 0

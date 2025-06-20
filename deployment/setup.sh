#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Please run as root or with sudo${NC}"
    exit 1
fi

echo -e "${GREEN}Starting Email Verifier deployment...${NC}"

# Update package list
echo -e "\n${GREEN}Updating package list...${NC}"
apt-get update

# Install required packages
echo -e "\n${GREEN}Installing required packages...${NC}"
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Add Docker's official GPG key
echo -e "\n${GREEN}Adding Docker's GPG key...${NC}"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo -e "\n${GREEN}Adding Docker repository...${NC}"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
echo -e "\n${GREEN}Installing Docker Engine...${NC}"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl enable --now docker

# Add current user to docker group
echo -e "\n${GREEN}Adding current user to docker group...${NC}"
usermod -aG docker $SUDO_USER

# Create necessary directories
echo -e "\n${GREEN}Creating deployment directories...${NC}"
mkdir -p /opt/email-verifier/{certs,www,nginx/conf.d}
chown -R $SUDO_USER:$SUDO_USER /opt/email-verifier

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo -e "\n${GREEN}Creating .env file...${NC}"
    cat > .env <<EOL
# Application Configuration
DOMAIN=your-domain.com
EMAIL=admin@your-domain.com
STAGING=true  # Set to false for production

# Docker Configuration
DOCKER_NETWORK=email-verifier-network

# Paths
NGINX_CONF_PATH=./nginx/conf.d
CERTS_PATH=./certs
WWW_PATH=./www
EOL
    echo -e "${YELLOW}Please edit the .env file with your configuration.${NC}"
fi

# Set proper permissions
chmod 600 .env

# Create docker-compose.override.yml for development
if [ ! -f "docker-compose.override.yml" ]; then
    echo -e "\n${GREEN}Creating docker-compose.override.yml for development...${NC}"
    cat > docker-compose.override.yml <<EOL
version: '3.8'

services:
  email-verifier:
    build:
      context: ..
      dockerfile: Dockerfile
    environment:
      - STAGING=true
    volumes:
      - ../:/app
    ports:
      - "8080:8080"
    restart: unless-stopped

  nginx:
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certs:/etc/letsencrypt
      - ./www:/var/www/html
EOL
fi

echo -e "\n${GREEN}Setup complete!${NC}"
echo -e "\nNext steps:"
echo -e "1. Edit the .env file with your domain and email"
echo -e "2. Run 'docker-compose up -d' to start the services"
echo -e "3. Check the logs with 'docker-compose logs -f'"

echo -e "${YELLOW}Important:${NC} Don't forget to set STAGING=false in the .env file for production!"

# Email Verifier - Deployment Guide

This document provides instructions for deploying the Email Verifier application using Docker and Docker Compose.

## Prerequisites

- Ubuntu 20.04/22.04 LTS server
- Docker (latest version)
- Docker Compose (latest version)
- Domain name (for production)
- Ports 80 and 443 open in your firewall

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd email-verifier/deployment
   ```

2. **Run the setup script**
   ```bash
   sudo ./setup.sh
   ```
   This will install Docker, set up the environment, and create necessary directories.

3. **Configure the application**
   Edit the `.env` file with your configuration:
   ```bash
   nano .env
   ```

4. **Start the application**
   ```bash
   ./manage.sh start
   ```

## Management Commands

Use the `manage.sh` script to control the application:

```bash
# Start services
./manage.sh start

# Stop services
./manage.sh stop

# Restart services
./manage.sh restart

# View logs
./manage.sh logs [service]

# Open a shell in a container
./manage.sh shell [service]

# Create a backup
./manage.sh backup

# Restore from backup
./manage.sh restore <backup-file>

# Update the application
./manage.sh update
```

## Configuration

### Environment Variables

Create a `.env` file in the `deployment` directory with the following variables:

```
# Application
DOMAIN=your-domain.com
EMAIL=admin@your-domain.com
STAGING=true  # Set to false for production

# Docker
DOCKER_NETWORK=email-verifier-network

# Paths
NGINX_CONF_PATH=./nginx/conf.d
CERTS_PATH=./certs
WWW_PATH=./www
```

### SSL Certificates

For production, you'll need SSL certificates. The deployment is set up to automatically obtain and renew Let's Encrypt certificates.

1. Set `STAGING=false` in your `.env` file
2. Update the domain in `nginx/conf.d/app.conf`
3. Run `./manage.sh start`

## File Structure

```
deployment/
├── certs/                  # SSL certificates (auto-generated)
├── nginx/                  # Nginx configuration
│   ├── conf.d/
│   │   └── app.conf       # Main Nginx configuration
│   └── nginx.conf          # Base Nginx configuration
├── www/                    # Web root for Let's Encrypt challenges
├── docker-compose.yml       # Main Docker Compose file
├── manage.sh               # Management script
├── setup.sh                # Setup script
└── .env                    # Environment configuration
```

## Deployment Steps

### 1. Initial Setup on Ubuntu VM

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Git
sudo apt install -y git

# Clone the repository
git clone <repository-url>
cd email-verifier/deployment

# Run the setup script (as root)
sudo ./setup.sh

# Edit the configuration
nano .env

# Start the application
./manage.sh start
```

### 2. Verify the Installation

- API: `https://your-domain.com/api/health`
- Test Page: `https://your-domain.com/test.html`

## Maintenance

### Updating the Application

```bash
# Pull the latest changes
git pull

# Rebuild and restart services
./manage.sh update
```

### Backup and Restore

#### Create a Backup

```bash
./manage.sh backup
```

#### Restore from Backup

```bash
./manage.sh restore email-verifier-backup-<timestamp>.tar.gz
```

## Troubleshooting

### Check Logs

```bash
# View all logs
./manage.sh logs

# View logs for a specific service
./manage.sh logs nginx
```

### Common Issues

1. **Port Conflicts**
   - Ensure ports 80 and 443 are not in use by other services
   ```bash
   sudo lsof -i :80
   sudo lsof -i :443
   ```

2. **Certificate Issues**
   - Check Let's Encrypt logs:
   ```bash
   ./manage.sh logs certbot
   ```

3. **Docker Permissions**
   - If you encounter permission issues, add your user to the docker group:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

## Security Considerations

1. **Firewall**
   - Only expose necessary ports (80, 443, 22)
   - Use UFW to restrict access:
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

2. **Updates**
   - Regularly update Docker images and host system
   - Monitor for security advisories

   - Set up monitoring for the application and server
   - Configure log rotation

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

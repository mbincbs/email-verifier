# Email Verifier Deployment Guide

This guide explains how to deploy the Email Verifier application on an Ubuntu VM using Docker.

## Prerequisites

- Ubuntu 20.04/22.04 LTS server
- SSH access to the server
- Sudo privileges

## Deployment Steps

1. **Transfer the files to your Ubuntu VM**
   - Copy the following files to your Ubuntu VM (in the same directory):
     - `Dockerfile`
     - `docker-compose.yml`
     - `deploy.sh`
     - `test_api.html`

2. **Make the deployment script executable**
   ```bash
   chmod +x deploy.sh
   ```

3. **Run the deployment script**
   ```bash
   ./deploy.sh
   ```
   This script will:
   - Install Docker and Docker Compose
   - Set up the application in `/opt/email-verifier`
   - Configure the application to start on boot

4. **Access the application**
   - API Server: `http://<server-ip>:8080`
   - Test Page: `http://<server-ip>:8081/test_api.html`

## Verifying the Installation

1. Check if the containers are running:
   ```bash
   docker ps
   ```

2. Check the service status:
   ```bash
   sudo systemctl status email-verifier
   ```

3. View logs:
   ```bash
   journalctl -u email-verifier -f
   ```

## Updating the Application

1. Stop the service:
   ```bash
   sudo systemctl stop email-verifier
   ```

2. Pull the latest changes

3. Rebuild and restart:
   ```bash
   cd /opt/email-verifier
   docker compose build --no-cache
   docker compose up -d
   ```

## Firewall Configuration

If you have a firewall enabled, make sure to allow the necessary ports:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 8081/tcp
sudo ufw enable
```

## Security Considerations

1. **HTTPS**: For production use, set up Nginx as a reverse proxy with Let's Encrypt for HTTPS.
2. **Authentication**: The API currently has no authentication. Consider adding API keys or OAuth.
3. **Rate Limiting**: Implement rate limiting to prevent abuse.
4. **Updates**: Regularly update Docker images and the host system.

## Troubleshooting

1. **Port conflicts**: Check if ports 8080 or 8081 are already in use.
2. **Docker permissions**: If you get permission errors, log out and back in after adding your user to the docker group.
3. **Container logs**: View logs with `docker compose logs` in the deployment directory.
4. **Resource limits**: Monitor system resources with `docker stats`.

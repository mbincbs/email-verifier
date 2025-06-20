#!/bin/bash

# Update package list and install required packages
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add current user to docker group to avoid using sudo
sudo usermod -aG docker $USER

# Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Create deployment directory
DEPLOY_DIR="/opt/email-verifier"
sudo mkdir -p $DEPLOY_DIR

# Set proper permissions
sudo chown -R $USER:$USER $DEPLOY_DIR

# Copy necessary files
cp docker-compose.yml $DEPLOY_DIR/
cp test_api.html $DEPLOY_DIR/

# Create a simple nginx config for the web server
cat << 'EOF' > $DEPLOY_DIR/nginx-default.conf
server {
    listen       80;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  test_api.html;
    }

}
EOF

# Create a .env file for environment variables
cat << 'EOF' > $DEPLOY_DIR/.env
PORT=8080
EOF

# Create a systemd service file for the application
cat << 'EOF' | sudo tee /etc/systemd/system/email-verifier.service > /dev/null
[Unit]
Description=Email Verifier Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/email-verifier
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable email-verifier

# Start the service
sudo systemctl start email-verifier

echo "\nDeployment complete!"
echo "The application should now be running on:"
echo "- API Server: http://<server-ip>:8080"
echo "- Test Page: http://<server-ip>:8081/test_api.html"
echo "\nYou may need to open these ports in your firewall if needed."

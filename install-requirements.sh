#!/bin/bash

# Fresh Ubuntu Server Setup Script for VPN Docker Deployment
# This script installs Docker, Docker Compose, and configures firewall

set -e

echo "🚀 Setting up fresh Ubuntu server for VPN Docker deployment..."
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    echo "❌ sudo is not available. Please install sudo first."
    exit 1
fi

echo "📦 Step 1: Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git unzip ca-certificates gnupg lsb-release

echo ""
echo "🐳 Step 2: Installing Docker..."

# Remove any old Docker installations
sudo apt remove docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install Docker using the official script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

echo ""
echo "🔧 Step 3: Installing Docker Compose..."

# Install Docker Compose (latest version)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create symlink for easier access
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

echo ""
echo "🔥 Step 4: Configuring firewall..."

# Install UFW if not present
sudo apt install -y ufw

echo ""
echo "Please select your server role:"
echo "1. Server1 (Exit Point) - Opens port 443 for VMess"
echo "2. Server2 (Entry Point) - Opens port 3128 for HTTP proxy"
echo "3. Skip firewall configuration"
echo ""
read -p "Enter your choice (1/2/3): " SERVER_ROLE

case $SERVER_ROLE in
    1)
        echo "Configuring firewall for Server1 (Exit Point)..."
        sudo ufw --force reset
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow 22/tcp
        sudo ufw allow 443/tcp
        sudo ufw --force enable
        echo "✅ Firewall configured for Server1"
        ;;
    2)
        echo "Configuring firewall for Server2 (Entry Point)..."
        sudo ufw --force reset
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow 22/tcp
        sudo ufw allow 3128/tcp
        sudo ufw --force enable
        echo "✅ Firewall configured for Server2"
        ;;
    3)
        echo "⏭️  Skipping firewall configuration"
        ;;
    *)
        echo "❌ Invalid choice. Skipping firewall configuration."
        ;;
esac

echo ""
echo "✅ Step 5: Verifying installation..."

# Test Docker installation
echo "Testing Docker..."
sudo docker --version
sudo docker run hello-world

echo ""
echo "Testing Docker Compose..."
docker-compose --version

echo ""
echo "🎉 Installation completed successfully!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. **Log out and back in** for Docker group changes to take effect:"
echo "   logout"
echo ""
echo "2. **Test Docker without sudo:**"
echo "   docker --version"
echo "   docker ps"
echo ""
echo "3. **Deploy VPN servers:**"
echo ""
if [[ $SERVER_ROLE == "1" ]]; then
    echo "   # Server1 (Exit Point) Deployment:"
    echo "   wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server1.yml"
    echo "   docker-compose -f docker-compose.server1.yml up -d"
elif [[ $SERVER_ROLE == "2" ]]; then
    echo "   # Server2 (Entry Point) Deployment:"
    echo "   wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server2.yml"
    echo "   sed -i 's/SERVER1_IP_PLACEHOLDER/YOUR_SERVER1_IP/' docker-compose.server2.yml"
    echo "   docker-compose -f docker-compose.server2.yml up -d"
else
    echo "   # Server1 (Exit Point):"
    echo "   wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server1.yml"
    echo "   docker-compose -f docker-compose.server1.yml up -d"
    echo ""
    echo "   # Server2 (Entry Point):"
    echo "   wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server2.yml"
    echo "   sed -i 's/SERVER1_IP_PLACEHOLDER/YOUR_SERVER1_IP/' docker-compose.server2.yml"
    echo "   docker-compose -f docker-compose.server2.yml up -d"
fi
echo ""
echo "4. **Test deployment:**"
echo "   wget https://github.com/m3di/ai_vpn/releases/latest/download/test-production.sh"
echo "   chmod +x test-production.sh"
echo "   ./test-production.sh SERVER2_IP SERVER1_IP"
echo ""
echo "📚 For detailed documentation, see:"
echo "   https://github.com/m3di/ai_vpn/blob/main/DEPLOYMENT.md" 
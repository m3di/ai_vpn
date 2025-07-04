#!/bin/bash

# VPN Server1 (Exit Point) Installation Script
# Run with: sudo ./install.sh

set -e

echo "=========================================="
echo "Installing VPN Server1 (Exit Point)"
echo "=========================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Update system
echo "Updating system packages..."
apt-get update -y

# Set non-interactive mode to avoid configuration prompts
export DEBIAN_FRONTEND=noninteractive
# Keep existing configuration files during upgrade
apt-get upgrade -y -o Dpkg::Options::="--force-confold"

# Install squid
echo "Installing Squid proxy..."
apt-get install -y squid -o Dpkg::Options::="--force-confold"

# Backup original config
echo "Backing up original squid configuration..."
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Create new squid configuration
echo "Creating VPN server1 configuration..."
cat > /etc/squid/squid.conf << 'EOF'
# VPN Server1 (Exit Point) - Minimal Working Configuration

# Listen on port 3128
http_port 3128

# Allow all access - no restrictions for VPN proxy
http_access allow all

# Disable caching completely (perfect for VPN)
cache deny all

# Minimal logging to avoid permission issues
access_log stdio:/dev/stdout
cache_log /dev/null

# Basic settings
visible_hostname vpn-server1
dns_nameservers 8.8.8.8 8.8.4.4

# Performance settings
client_lifetime 1 hour
half_closed_clients off

# Security headers (optional for VPN)
request_header_access Via deny all
request_header_access X-Forwarded-For deny all
EOF

# Stop squid if it's running (in case it was auto-started during package installation)
echo "Stopping squid service (if running)..."
systemctl stop squid 2>/dev/null || true
pkill -f squid 2>/dev/null || true

# Create systemd override to skip cache initialization (since we disabled caching)
echo "Creating systemd override..."
mkdir -p /etc/systemd/system/squid.service.d
cat > /etc/systemd/system/squid.service.d/override.conf << 'EOF'
[Service]
ExecStartPre=
ExecStartPre=/usr/sbin/squid --foreground -f /etc/squid/squid.conf -k parse
EOF

# Reload systemd
systemctl daemon-reload

# Enable and start squid service (no cache initialization needed)
echo "Starting squid service..."
systemctl enable squid
systemctl start squid

# Configure firewall
echo "Configuring firewall..."
ufw allow 3128/tcp
ufw allow ssh
ufw --force enable

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "=========================================="
echo "✅ VPN Server1 installation completed!"
echo "=========================================="
echo "Server IP: $SERVER_IP"
echo "Proxy Port: 3128"
echo "Service Status: $(systemctl is-active squid)"
echo ""
echo "To check status: sudo systemctl status squid"
echo "To view logs: sudo tail -f /var/log/squid/access.log"
echo "To restart: sudo systemctl restart squid"
echo ""
echo "⚠️  IMPORTANT: Configure your server2 to use this server as:"
echo "   Server1 IP: $SERVER_IP"
echo "   Port: 3128"
echo "==========================================" 
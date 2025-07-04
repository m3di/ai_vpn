#!/bin/bash

# VPN Server2 (Entry Point) Installation Script
# Run with: sudo ./install.sh

set -e

echo "=========================================="
echo "Installing VPN Server2 (Entry Point)"
echo "=========================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

# Get Server1 IP from user
echo ""
echo "📋 Configuration Required:"
echo "You need to provide the IP address of your Server1 (VPN Exit Point)"
echo ""
read -p "Enter Server1 IP address: " SERVER1_IP

# Validate IP format
if [[ ! $SERVER1_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "❌ Invalid IP address format. Please use format: x.x.x.x"
    exit 1
fi

echo ""
echo "Testing connection to Server1 ($SERVER1_IP:3128)..."
if ! timeout 5 bash -c "echo >/dev/tcp/$SERVER1_IP/3128"; then
    echo "⚠️  Warning: Cannot connect to Server1 at $SERVER1_IP:3128"
    echo "Make sure Server1 is installed and running before proceeding."
    read -p "Do you want to continue anyway? (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
else
    echo "✅ Connection to Server1 successful!"
fi

echo ""
echo "Installing with Server1 IP: $SERVER1_IP"
echo "Proceeding with installation..."

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
echo "Creating VPN server2 configuration..."
cat > /etc/squid/squid.conf << EOF
# VPN Server2 (Entry Point) - Minimal Working Configuration
# This server forwards traffic to Server1 ($SERVER1_IP)

# Listen on port 3128
http_port 3128

# Allow all access - no restrictions for VPN proxy
http_access allow all

# Forward requests to Server1 as parent proxy
cache_peer $SERVER1_IP parent 3128 0 no-query default

# Don't go direct, always use parent (Server1)
prefer_direct off
never_direct allow all

# Disable caching completely (perfect for VPN)
cache deny all

# Minimal logging to avoid permission issues
access_log stdio:/dev/stdout
cache_log /dev/null

# Basic settings
visible_hostname vpn-server2
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
SERVER2_IP=$(hostname -I | awk '{print $1}')

# Create configuration file for reference
echo "Creating configuration reference file..."
cat > /root/vpn-config.txt << EOF
VPN Configuration:
==================
Server2 (Entry Point): $SERVER2_IP:3128
Server1 (Exit Point):  $SERVER1_IP:3128

Client Configuration:
Use Server2 as proxy: $SERVER2_IP:3128

Traffic Flow:
Client → Server2 ($SERVER2_IP) → Server1 ($SERVER1_IP) → Internet
EOF

echo "=========================================="
echo "✅ VPN Server2 installation completed!"
echo "=========================================="
echo "Server2 IP: $SERVER2_IP"
echo "Server1 IP: $SERVER1_IP"
echo "Proxy Port: 3128"
echo "Service Status: $(systemctl is-active squid)"
echo ""
echo "📋 Client Configuration:"
echo "   Use proxy: $SERVER2_IP:3128"
echo ""
echo "🔄 Traffic Flow:"
echo "   Client → Server2 → Server1 → Internet"
echo ""
echo "To check status: sudo systemctl status squid"
echo "To view logs: sudo tail -f /var/log/squid/access.log"
echo "To restart: sudo systemctl restart squid"
echo "Config saved to: /root/vpn-config.txt"
echo ""
echo "🧪 Test the setup:"
echo "   curl --proxy $SERVER2_IP:3128 https://httpbin.org/ip"
echo "==========================================" 
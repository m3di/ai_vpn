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
apt-get upgrade -y

# Install squid
echo "Installing Squid proxy..."
apt-get install -y squid

# Backup original config
echo "Backing up original squid configuration..."
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Create new squid configuration
echo "Creating VPN server2 configuration..."
cat > /etc/squid/squid.conf << EOF
# VPN Server2 (Entry Point) Configuration
# This server forwards traffic to Server1 ($SERVER1_IP)

# Allow access from all internal networks
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16

# Allow HTTP and HTTPS
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 443         # https
acl Safe_ports port 8080        # http-alt
acl Safe_ports port 21          # ftp
acl Safe_ports port 22          # ssh
acl Safe_ports port 873         # rsync
acl Safe_ports port 1025-65535  # unregistered ports
acl CONNECT method CONNECT

# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Allow localhost manager access
http_access allow localhost manager
http_access deny manager

# Allow access from local networks
http_access allow localnet
http_access allow localhost

# Deny all other access
http_access deny all

# Squid normally listens on port 3128
http_port 3128

# Forward requests to Server1 as parent proxy
cache_peer $SERVER1_IP parent 3128 0 no-query default

# Don't go direct, always use parent (Server1)
prefer_direct off
never_direct allow all

# Performance optimizations
cache_mem 256 MB
maximum_object_size_in_memory 64 KB
maximum_object_size 1024 MB

# Cache directory
cache_dir ufs /var/spool/squid 1000 16 256

# Leave coredumps in the first cache dir
coredump_dir /var/spool/squid

# Enable access logging
access_log /var/log/squid/access.log squid

# Enable cache logging
cache_log /var/log/squid/cache.log

# Forward all requests without modification
forwarded_for on

# Set visible hostname
visible_hostname vpn-server2

# DNS settings
dns_nameservers 8.8.8.8 8.8.4.4

# Connection limits
client_lifetime 1 hour
half_closed_clients off

# Security headers
request_header_access Via deny all
request_header_access X-Forwarded-For deny all
EOF

# Create squid user and set permissions
echo "Setting up squid user and permissions..."
if ! id squid &>/dev/null; then
    useradd -r -s /bin/false squid
fi

# Create cache directory
mkdir -p /var/spool/squid
chown -R squid:squid /var/spool/squid
chmod 750 /var/spool/squid

# Create log directory
mkdir -p /var/log/squid
chown -R squid:squid /var/log/squid

# Initialize squid cache
echo "Initializing squid cache..."
squid -z

# Enable and start squid service
echo "Starting squid service..."
systemctl enable squid
systemctl restart squid

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
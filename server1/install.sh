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
apt-get upgrade -y

# Install squid
echo "Installing Squid proxy..."
apt-get install -y squid

# Backup original config
echo "Backing up original squid configuration..."
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Create new squid configuration
echo "Creating VPN server1 configuration..."
cat > /etc/squid/squid.conf << 'EOF'
# VPN Server1 (Exit Point) Configuration
# This is the final proxy before reaching the internet

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
visible_hostname vpn-server1

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
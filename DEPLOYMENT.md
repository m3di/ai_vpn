# Production Deployment Guide

This guide covers deploying the VPN proxy chain on real Ubuntu servers for production use.

## Overview

The VPN setup consists of two servers:
- **Server1** (Exit Point): Makes final requests to the internet
- **Server2** (Entry Point): Receives client connections, forwards to Server1

```
Client → Server2 → Server1 → Internet
```

## Prerequisites

### Server Requirements

Both servers need:
- **Ubuntu 18.04 or later**
- **Root access** (sudo privileges)
- **Port 3128** available and not blocked by firewall
- **Minimum 1GB RAM** (2GB recommended)
- **Network connectivity** between servers

### Network Requirements

- Server1 must be able to reach the internet
- Server2 must be able to reach Server1 on port 3128
- Clients must be able to reach Server2 on port 3128

## Step-by-Step Deployment

### 1. Download Installation Packages

Get the latest release packages from GitHub:

```bash
# Download server1 package
wget https://github.com/m3di/ai_vpn/releases/latest/download/server1.tar.gz

# Download server2 package
wget https://github.com/m3di/ai_vpn/releases/latest/download/server2.tar.gz
```

### 2. Install Server1 (Exit Point)

**⚠️ Install Server1 FIRST!**

```bash
# Extract and install server1
tar -xzf server1.tar.gz
cd server1
chmod +x install.sh
sudo ./install.sh
```

**What this does:**
- Installs Squid proxy server
- Configures firewall (UFW)
- Sets up automatic startup
- Optimizes performance settings
- Creates secure user permissions

**After installation:**
- Note the displayed Server1 IP address
- Verify service is running: `sudo systemctl status squid`

### 3. Install Server2 (Entry Point)

```bash
# Extract and install server2
tar -xzf server2.tar.gz
cd server2
chmod +x install.sh
sudo ./install.sh
```

**During installation:**
- Script will prompt for Server1 IP address
- Enter the IP address from Server1 installation
- Script will test connectivity to Server1

**What this does:**
- Installs Squid proxy server
- Configures forwarding to Server1
- Sets up firewall rules
- Creates configuration backup in `/root/vpn-config.txt`

## Testing the Setup

### 1. Test Server1 Directly

```bash
# From any machine with internet access
curl --proxy SERVER1_IP:3128 https://httpbin.org/ip
```

Should return Server1's IP address.

### 2. Test Server2 Chain

```bash
# From any machine with internet access
curl --proxy SERVER2_IP:3128 https://httpbin.org/ip
```

Should return Server1's IP address (proving the chain works).

### 3. Test from Client Applications

Configure your browser or application:
- **Proxy Type**: HTTP Proxy
- **Proxy Server**: SERVER2_IP
- **Port**: 3128

## Management Commands

### Service Management

```bash
# Check status
sudo systemctl status squid

# Start service
sudo systemctl start squid

# Stop service
sudo systemctl stop squid

# Restart service
sudo systemctl restart squid

# Enable auto-start on boot
sudo systemctl enable squid
```

### Monitoring

```bash
# View real-time access logs
sudo tail -f /var/log/squid/access.log

# View cache logs
sudo tail -f /var/log/squid/cache.log

# Check listening ports
sudo netstat -tlnp | grep 3128

# View configuration
sudo cat /etc/squid/squid.conf
```

### Configuration Management

```bash
# View VPN configuration (Server2 only)
sudo cat /root/vpn-config.txt

# Backup configuration
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Test configuration
sudo squid -k parse

# Reload configuration
sudo squid -k reconfigure
```

## Security Considerations

### Firewall Configuration

The installation automatically configures UFW:
- **Allows**: SSH (port 22) and Squid (port 3128)
- **Blocks**: All other incoming connections

### Service Security

- Squid runs as non-root user (`squid`)
- Minimal file permissions
- Secure cache directories
- No unnecessary services exposed

### Monitoring Security

- All connections are logged
- Access logs include client IPs and requested URLs
- Failed connection attempts are logged

## Troubleshooting

### Common Issues

1. **Cannot connect to Server1 from Server2**
   ```bash
   # Test connectivity
   telnet SERVER1_IP 3128
   # Check firewall on both servers
   sudo ufw status
   ```

2. **Squid service won't start**
   ```bash
   # Check configuration
   sudo squid -k parse
   # Check logs
   sudo journalctl -u squid
   ```

3. **Permission denied errors**
   ```bash
   # Fix cache permissions
   sudo chown -R squid:squid /var/spool/squid
   sudo chmod 750 /var/spool/squid
   ```

### Log Analysis

```bash
# Check for errors in access log
sudo grep "TCP_DENIED\|ERROR" /var/log/squid/access.log

# Check cache log for startup issues
sudo grep "ERROR\|FATAL\|WARNING" /var/log/squid/cache.log

# Monitor live connections
sudo ss -tlnp | grep 3128
```

## Performance Optimization

### For High Traffic

Edit `/etc/squid/squid.conf`:

```bash
# Increase cache memory
cache_mem 512 MB

# Increase maximum object size
maximum_object_size 2048 MB

# Increase file descriptors
max_filedescriptors 4096

# Optimize for speed
cache_replacement_policy heap LFUDA
```

After changes:
```bash
sudo systemctl restart squid
```

### System Optimization

```bash
# Increase system limits
echo "squid soft nofile 4096" | sudo tee -a /etc/security/limits.conf
echo "squid hard nofile 8192" | sudo tee -a /etc/security/limits.conf

# Reboot to apply limits
sudo reboot
```

## Maintenance

### Regular Tasks

1. **Log rotation** (automatic via logrotate)
2. **Cache cleanup** (automatic)
3. **System updates**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

### Monthly Tasks

1. **Check disk usage**:
   ```bash
   sudo du -sh /var/spool/squid
   sudo df -h
   ```

2. **Review logs for issues**:
   ```bash
   sudo grep "ERROR\|DENY" /var/log/squid/access.log | tail -20
   ```

3. **Update system packages**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo systemctl restart squid
   ```

## Advanced Configuration

### Custom Access Control

Edit `/etc/squid/squid.conf` to add custom rules:

```bash
# Allow specific IP ranges
acl allowed_ips src 192.168.1.0/24
acl allowed_ips src 10.0.0.0/8
http_access allow allowed_ips

# Block specific domains
acl blocked_domains dstdomain .facebook.com .twitter.com
http_access deny blocked_domains
```

### SSL/HTTPS Support

For HTTPS interception (advanced):

```bash
# Generate SSL certificates
sudo mkdir /etc/squid/ssl
sudo openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -keyout /etc/squid/ssl/squid.key -out /etc/squid/ssl/squid.crt

# Add to squid.conf
https_port 3129 cert=/etc/squid/ssl/squid.crt key=/etc/squid/ssl/squid.key
```

## Support

For issues and questions:
1. Check the logs first
2. Review this documentation
3. Create an issue on GitHub
4. Include relevant log excerpts and system information 
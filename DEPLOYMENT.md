# Production Deployment Guide - Docker

This guide covers deploying the VPN proxy chain using Docker containers on production servers with VMess protocol for enhanced security.

## Prerequisites

### Fresh Ubuntu Server Setup

If you're starting with a fresh Ubuntu server, follow these steps to install all required dependencies.

#### 1. Update System Packages

```bash
# Update package list and upgrade system
sudo apt update && sudo apt upgrade -y

# Install basic utilities
sudo apt install -y curl wget git unzip
```

#### 2. Install Docker

```bash
# Remove any old Docker installations
sudo apt remove docker docker-engine docker.io containerd runc 2>/dev/null || true

# Install Docker using the official script (recommended)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group (optional, allows running Docker without sudo)
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker installation
sudo docker --version
sudo docker run hello-world
```

#### 3. Install Docker Compose

```bash
# Install Docker Compose (latest version)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make it executable
sudo chmod +x /usr/local/bin/docker-compose

# Create a symlink for easier access (optional)
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify Docker Compose installation
docker-compose --version
```

#### 4. Configure Firewall (UFW)

```bash
# Install and configure UFW firewall
sudo apt install -y ufw

# Configure firewall rules based on server role
# For Server1 (Exit Point):
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # VMess server port

# For Server2 (Entry Point):
sudo ufw allow 22/tcp    # SSH  
sudo ufw allow 3128/tcp  # HTTP proxy port

# Enable firewall
sudo ufw --force enable

# Check firewall status
sudo ufw status
```

#### 5. Optional: Log out and back in

If you added your user to the docker group, log out and back in for the changes to take effect:

```bash
# Log out and back in, or use:
newgrp docker

# Test Docker without sudo
docker --version
docker ps
```

#### 6. Verify Complete Installation

```bash
# Test that everything works
docker --version
docker-compose --version
docker run hello-world
```

You should see output similar to:
```
Docker version 24.0.7, build afdd53b
Docker Compose version v2.21.0
Hello from Docker!
```

## Overview

The VPN setup consists of two Docker containers:
- **Server1** (Exit Point): Xray VMess server that makes final requests to the internet
- **Server2** (Entry Point): Xray HTTP proxy + VMess client that forwards to Server1

```
Client → Server2 (HTTP:3128 → VMess) → Server1 (VMess Server) → Internet
```

## Prerequisites

### Server Requirements

Both servers need:
- **Docker Engine 20.10+**
- **Docker Compose 2.0+** (recommended)
- **Ubuntu 18.04+** or any Docker-compatible OS
- **Port 443** available on Server1 (VMess)
- **Port 3128** available on Server2 (HTTP proxy)
- **Minimum 1GB RAM** (2GB recommended)
- **Network connectivity** between servers

### Docker Installation

If Docker is not installed:

```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add user to docker group (optional)
sudo usermod -aG docker $USER
```

## Step-by-Step Deployment

### Method 1: Using Docker Compose (Recommended)

#### 1. Deploy Server1 (Exit Point)

**⚠️ Deploy Server1 FIRST!**

```bash
# Download production compose file
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server1.yml

# Deploy server1
docker-compose -f docker-compose.server1.yml up -d

# Check status
docker-compose -f docker-compose.server1.yml ps
```

**Verify Server1:**
```bash
# Check logs
docker logs vpn-server1

# Test VMess port
nc -zv localhost 443
```

#### 2. Deploy Server2 (Entry Point)

```bash
# Download production compose file
wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server2.yml

# Update SERVER1_IP in the compose file
export SERVER1_IP="YOUR_SERVER1_IP_HERE"
sed -i "s/SERVER1_IP_PLACEHOLDER/$SERVER1_IP/" docker-compose.server2.yml

# Deploy server2
docker-compose -f docker-compose.server2.yml up -d

# Check status
docker-compose -f docker-compose.server2.yml ps
```

**Verify Server2:**
```bash
# Check logs
docker logs vpn-server2

# Test proxy port
nc -zv localhost 3128
```

### Method 2: Using Docker Run Commands

#### 1. Deploy Server1 (Exit Point)

```bash
# Create network (optional)
docker network create vpn-network

# Run server1 container
docker run -d \
  --name vpn-server1 \
  --network vpn-network \
  -p 443:443 \
  --restart unless-stopped \
  --memory 512m \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=5 \
  m3di/ai-vpn:server1-latest

# Check status
docker ps | grep vpn-server1
```

#### 2. Deploy Server2 (Entry Point)

```bash
# Run server2 container
docker run -d \
  --name vpn-server2 \
  --network vpn-network \
  -p 3128:3128 \
  --restart unless-stopped \
  --memory 512m \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=5 \
  -e SERVER1_HOST=YOUR_SERVER1_IP \
  m3di/ai-vpn:server2-latest

# Check status
docker ps | grep vpn-server2
```

## Configuration

### Environment Variables

#### Server1 (VMess Server)
- `LOG_LEVEL`: Xray log level (default: info)
- `VMESS_UUID`: VMess UUID (default: 550e8400-e29b-41d4-a716-446655440000)

#### Server2 (VMess Client)
- `SERVER1_HOST`: Server1 IP address (required)
- `SERVER1_PORT`: Server1 VMess port (default: 443)
- `LOG_LEVEL`: Xray log level (default: info)
- `VMESS_UUID`: VMess UUID (must match Server1)

### Custom Configuration

#### Using Custom VMess UUID

```bash
# Generate new UUID
export CUSTOM_UUID=$(uuidgen)

# Deploy with custom UUID
docker run -d \
  --name vpn-server1 \
  -p 443:443 \
  -e VMESS_UUID=$CUSTOM_UUID \
  m3di/ai-vpn:server1-latest

docker run -d \
  --name vpn-server2 \
  -p 3128:3128 \
  -e SERVER1_HOST=YOUR_SERVER1_IP \
  -e VMESS_UUID=$CUSTOM_UUID \
  m3di/ai-vpn:server2-latest
```

#### Volume Mounts for Persistence

```bash
# Create volumes for logs and config
docker volume create vpn-server1-logs
docker volume create vpn-server2-logs

# Deploy with persistent volumes
docker run -d \
  --name vpn-server1 \
  -p 443:443 \
  -v vpn-server1-logs:/var/log/xray \
  m3di/ai-vpn:server1-latest
```

## Testing the Setup

### 1. Basic Connectivity Test

```bash
# Test Server1 VMess port
nc -zv SERVER1_IP 443

# Test Server2 HTTP proxy port
nc -zv SERVER2_IP 3128
```

### 2. End-to-End VMess Chain Test

```bash
# Test the complete VMess chain
curl --proxy SERVER2_IP:3128 https://httpbin.org/ip

# Should return Server1's IP address
```

### 3. Performance Test

```bash
# Download test script
wget https://github.com/m3di/ai_vpn/releases/latest/download/test-production.sh
chmod +x test-production.sh

# Run production tests
./test-production.sh SERVER2_IP SERVER1_IP
```

### 4. Client Application Test

Configure your application:
- **Proxy Type**: HTTP Proxy
- **Proxy Server**: SERVER2_IP
- **Port**: 3128

## Management

### Container Management

```bash
# Check container status
docker ps

# View container logs
docker logs vpn-server1
docker logs vpn-server2

# Follow logs in real-time
docker logs -f vpn-server1

# Restart containers
docker restart vpn-server1
docker restart vpn-server2

# Stop containers
docker stop vpn-server1 vpn-server2

# Remove containers
docker rm vpn-server1 vpn-server2
```

### Resource Monitoring

```bash
# Monitor resource usage
docker stats

# Check container details
docker inspect vpn-server1

# View container processes
docker exec vpn-server1 ps aux
```

### Log Management

```bash
# View Xray access logs
docker exec vpn-server1 tail -f /var/log/xray/access.log
docker exec vpn-server2 tail -f /var/log/xray/access.log

# View error logs
docker exec vpn-server1 tail -f /var/log/xray/error.log

# Export logs
docker cp vpn-server1:/var/log/xray/access.log ./server1-access.log
```

## Security Considerations

### Container Security

- Containers run as non-root users
- Minimal base images (Ubuntu 22.04)
- Resource limits to prevent abuse
- Network isolation between containers
- Read-only root filesystem where possible

### VMess Security

- UUID-based authentication
- Protocol obfuscation
- Encrypted communication between servers
- No TLS termination for enhanced performance

### Network Security

```bash
# Configure firewall (if using UFW)
sudo ufw allow 443/tcp   # Server1 VMess port
sudo ufw allow 3128/tcp  # Server2 HTTP proxy port
sudo ufw allow 22/tcp    # SSH
sudo ufw --force enable
```

### Security Hardening

```bash
# Disable unnecessary services
sudo systemctl disable apache2 nginx 2>/dev/null || true

# Update system packages
sudo apt update && sudo apt upgrade -y

# Enable automatic security updates
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

## Updates and Maintenance

### Updating Docker Images

```bash
# Pull latest images
docker pull m3di/ai-vpn:server1-latest
docker pull m3di/ai-vpn:server2-latest

# Stop current containers
docker stop vpn-server1 vpn-server2

# Remove old containers
docker rm vpn-server1 vpn-server2

# Restart with new images
docker-compose -f docker-compose.server1.yml up -d
docker-compose -f docker-compose.server2.yml up -d
```

### Automated Updates

Create update script:

```bash
cat > update-vpn.sh << 'EOF'
#!/bin/bash
echo "Updating VPN containers..."

# Pull latest images
docker pull m3di/ai-vpn:server1-latest
docker pull m3di/ai-vpn:server2-latest

# Restart containers with new images
docker-compose -f docker-compose.server1.yml pull
docker-compose -f docker-compose.server1.yml up -d

echo "Update completed"
EOF

chmod +x update-vpn.sh
```

### Health Checks

```bash
# Add to compose file for health monitoring
healthcheck:
  test: ["CMD", "nc", "-z", "localhost", "443"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## Troubleshooting

### Common Issues

1. **Container won't start**
   ```bash
   # Check container logs
   docker logs vpn-server1
   
   # Check if port is already in use
   sudo netstat -tlnp | grep 443
   sudo netstat -tlnp | grep 3128
   ```

2. **VMess connection fails**
   ```bash
   # Verify Server1 is reachable
   nc -zv SERVER1_IP 443
   
   # Check UUID matches between containers
   docker exec vpn-server1 cat /etc/xray/config.json | grep uuid
   docker exec vpn-server2 cat /etc/xray/config.json | grep id
   ```

3. **High memory usage**
   ```bash
   # Check resource usage
   docker stats
   
   # Add memory limits
   docker update --memory 512m vpn-server1
   ```

### Log Analysis

```bash
# Check for VMess connection errors
docker exec vpn-server1 grep "VMess\|error\|fail" /var/log/xray/error.log

# Monitor live connections
docker exec vpn-server2 tail -f /var/log/xray/access.log | grep -E "(accepted|rejected)"

# Check system resources
docker exec vpn-server1 df -h
docker exec vpn-server1 free -h
```

## Performance Optimization

### Container Optimization

```bash
# Optimize for high traffic
docker run -d \
  --name vpn-server1 \
  -p 443:443 \
  --memory 1g \
  --cpus 2 \
  --ulimit nofile=65536:65536 \
  m3di/ai-vpn:server1-latest
```

### System Optimization

```bash
# Increase system limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings
echo "net.core.rmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## Backup and Recovery

### Backup Configuration

```bash
# Create backup script
cat > backup-vpn.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/vpn-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup configurations
docker cp vpn-server1:/etc/xray/config.json $BACKUP_DIR/server1-config.json
docker cp vpn-server2:/etc/xray/config.json $BACKUP_DIR/server2-config.json

# Backup logs
docker cp vpn-server1:/var/log/xray $BACKUP_DIR/server1-logs
docker cp vpn-server2:/var/log/xray $BACKUP_DIR/server2-logs

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x backup-vpn.sh
```

### Disaster Recovery

```bash
# Quick recovery from backup
docker run -d \
  --name vpn-server1-recovery \
  -p 443:443 \
  -v /backup/vpn-latest/server1-config.json:/etc/xray/config.json:ro \
  m3di/ai-vpn:server1-latest
```

## Support

For issues and questions:
1. Check container logs first: `docker logs <container-name>`
2. Review this documentation
3. Test connectivity with provided scripts
4. Create an issue on GitHub with logs and system information
5. Include Docker version and system details 
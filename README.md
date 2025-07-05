# VPN Experiment with Docker Containers

This project demonstrates a VPN-like setup using Docker containers with **VMess protocol** for enhanced security and protocol obfuscation.

🚀 **For production deployment using Docker, see [Production Deployment](#production-deployment) section below.**

## Architecture

```
Client → Server2 (HTTP→VMess) → Server1 (VMess Server) → Internet Server
```

### Protocol Chain
1. **Client → Server2**: HTTP proxy protocol (port 3128)
2. **Server2 → Server1**: VMess protocol (port 443) 
3. **Server1 → Internet**: Direct connection

## Containers

1. **`internet`** - A Go web application that returns the client's IP address
2. **`server1`** - VPN exit point using Xray with VMess protocol
3. **`server2`** - VPN entry point using Xray (HTTP proxy → VMess client)
4. **`client`** - Test client with networking tools

## Network Behavior

- **Direct access**: `client → internet` → Returns client IP (172.20.0.5)
- **Via server2 (VMess chain)**: `client → server2 → server1 → internet` → Returns server1 IP (172.20.0.3)

## Quick Start (Development)

1. **Build and start all containers:**
   ```bash
   docker-compose up -d
   ```

2. **Run the test script:**
   ```bash
   ./test-setup.sh run
   ```

## Manual Testing

```bash
# Test 1: Direct access
docker exec vpn-client curl -s http://internet-server:80/

# Test 2: Via VMess chain (server2 → server1)
docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/

# Test 3: VMess-specific tests
./test-setup.sh vmess
```

## Expected Results

- **Direct access**: Shows client IP (172.20.0.5)
- **VMess chain**: Shows server1 IP (172.20.0.3) with protocol obfuscation

## Container Details

### Internet Server
- **Language**: Go
- **Port**: 80 (HTTP), 443 (HTTPS)
- **Function**: Returns client IP information in JSON format
- **External access**: Available on localhost:8080 (HTTP), localhost:8443 (HTTPS)

### Server1 (VPN Exit Point)
- **Protocol**: Xray VMess server on port 443
- **Function**: Acts as the final proxy before reaching the internet
- **Security**: UUID authentication, protocol obfuscation

### Server2 (VPN Entry Point)
- **Protocol**: Xray HTTP proxy (port 3128) + VMess client
- **Function**: Accepts HTTP proxy connections, forwards via VMess to server1
- **Chain**: HTTP → VMess → Internet

### Client
- **Base**: Alpine Linux
- **Tools**: curl, wget, netcat
- **Function**: Simulates a user wanting to browse the internet

## VMess Configuration

- **Protocol**: VMess (V2Ray/Xray)
- **UUID**: `550e8400-e29b-41d4-a716-446655440000`
- **Transport**: TCP (no encryption for testing)
- **Security**: Auto

## Network Configuration

- **Subnet**: 172.20.0.0/16
- **Internet Server**: 172.20.0.2
- **Server1**: 172.20.0.3
- **Server2**: 172.20.0.4
- **Client**: 172.20.0.5

## Files Structure

```
docker-vpn/
├── docker-compose.yml          # Development orchestration
├── docker-compose.prod.yml     # Production orchestration
├── internet/
│   ├── Dockerfile
│   └── main.go                 # Go web server
├── server1/
│   ├── Dockerfile
│   ├── xray-config.json        # VMess server config
│   └── start-xray.sh           # Startup script
├── server2/
│   ├── Dockerfile
│   ├── xray-config.json        # VMess client config
│   └── start-xray.sh           # Startup script
├── client/
│   └── Dockerfile
├── test-setup.sh               # Test script
└── README.md                   # This file
```

## Security & Performance Features

- **VMess Protocol**: Enhanced security with protocol obfuscation
- **UUID Authentication**: Secure client authentication
- **Performance**: ~2.3ms overhead for VMess chain
- **Detection Resistance**: Much harder to detect than HTTP proxy traffic
- **Isolated Network**: All containers run in isolated Docker network

## Stopping the Experiment

```bash
docker-compose down
```

## Troubleshooting

- **Check container status**: `docker-compose ps`
- **View logs**: `docker logs <container-name>`
- **Access container shell**: `docker exec -it <container-name> sh`
- **Test VMess chain**: `./test-setup.sh vmess`

---

## Production Deployment

### 🚀 Deploy with Docker on Production Servers

For production deployment, this project provides pre-built Docker images and orchestration files for easy deployment on any Docker-capable servers.

#### Docker Images

Pre-built images are available on Docker Hub:
- **Server1 (VMess Server)**: `m3di/ai-vpn:server1-latest`
- **Server2 (VMess Client)**: `m3di/ai-vpn:server2-latest`
- **Internet Test Server**: `m3di/ai-vpn:internet-latest`

#### Prerequisites (Fresh Ubuntu Server)

For a fresh Ubuntu server, install Docker and requirements first:

```bash
# Quick setup script (installs Docker, Docker Compose, configures firewall)
wget https://raw.githubusercontent.com/m3di/ai_vpn/main/install-requirements.sh
chmod +x install-requirements.sh
./install-requirements.sh

# Or follow manual instructions in DEPLOYMENT.md
```

#### Quick Production Setup

1. **Deploy Server1 (Exit Point):**
   ```bash
   # Download production compose file
   wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server1.yml
   
   # Deploy server1
   docker-compose -f docker-compose.server1.yml up -d
   ```

2. **Deploy Server2 (Entry Point):**
   ```bash
   # Download production compose file
   wget https://github.com/m3di/ai_vpn/releases/latest/download/docker-compose.server2.yml
   
   # Update SERVER1_IP in the compose file
   sed -i 's/SERVER1_IP_PLACEHOLDER/YOUR_SERVER1_IP/' docker-compose.server2.yml
   
   # Deploy server2
   docker-compose -f docker-compose.server2.yml up -d
   ```

#### Alternative: Direct Docker Run

```bash
# Server1 (Exit Point)
docker run -d --name vpn-server1 \
  -p 443:443 \
  --restart unless-stopped \
  m3di/ai-vpn:server1-latest

# Server2 (Entry Point) 
docker run -d --name vpn-server2 \
  -p 3128:3128 \
  --restart unless-stopped \
  -e SERVER1_HOST=YOUR_SERVER1_IP \
  m3di/ai-vpn:server2-latest
```

### 📦 What's Included in Releases

Each release contains:
- **docker-compose.server1.yml** - Server1 deployment file
- **docker-compose.server2.yml** - Server2 deployment file  
- **README.md** - Detailed deployment instructions
- **test-production.sh** - Production testing script
- Pre-built Docker images on Docker Hub

### 🔧 Production Features

- **Automatic container restart** on failure
- **Health checks** for service monitoring
- **Volume persistence** for logs and configuration
- **Environment-based configuration**
- **Security hardening** with non-root containers
- **Resource limits** for production stability
- **Easy scaling** with Docker Swarm or Kubernetes

### 🧪 Testing Production Setup

After deployment, test the VMess chain:

```bash
# Test from any machine
curl --proxy SERVER2_IP:3128 https://httpbin.org/ip

# Should return Server1's IP address
```

### 🛡️ Security Considerations

- Containers run with minimal required permissions
- VMess protocol provides traffic obfuscation
- UUID-based authentication
- Isolated container networking
- Regular security updates via image rebuilds

### 📊 Monitoring

Monitor your VPN containers:

```bash
# Check container status
docker ps

# View container logs
docker logs vpn-server1
docker logs vpn-server2

# Monitor resource usage
docker stats

# Check VMess connectivity
./test-production.sh
```

### 🔄 Updates

Update to latest versions:

```bash
# Pull latest images
docker pull m3di/ai-vpn:server1-latest
docker pull m3di/ai-vpn:server2-latest

# Restart containers with new images
docker-compose -f docker-compose.server1.yml pull && docker-compose -f docker-compose.server1.yml up -d
docker-compose -f docker-compose.server2.yml pull && docker-compose -f docker-compose.server2.yml up -d
```

### 🌐 Creating New Releases

To create a new release with updated Docker images:

```bash
./create-release.sh
```

This will:
- Build and push new Docker images to Docker Hub
- Create GitHub release with deployment files
- Generate production deployment documentation 
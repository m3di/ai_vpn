# VPN Experiment with Docker Containers

This project demonstrates a VPN-like setup using 4 Docker containers representing real-world computers in multiple locations.

🚀 **For production deployment on Ubuntu servers, see [Production Deployment](#production-deployment) section below.**

## Architecture

```
Client → Server2 (Entry Point) → Server1 (Exit Point) → Internet Server
```

## Containers

1. **`internet`** - A Go web application that returns the client's IP address
2. **`server1`** - VPN exit point using Squid proxy
3. **`server2`** - VPN entry point using Squid proxy (forwards to server1)
4. **`client`** - Represents the client wanting to browse the internet

## Network Behavior

- **Direct access**: `client → internet` → Returns client IP (172.20.0.5)
- **Via server1**: `client → server1 → internet` → Returns server1 IP (172.20.0.3)
- **Via server2**: `client → server2 → server1 → internet` → Returns server1 IP (172.20.0.3)

## Quick Start

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

# Test 2: Via server1 proxy
docker exec vpn-client curl -s --proxy http://vpn-server1:3128 http://internet-server:80/

# Test 3: Via server2 proxy
docker exec vpn-client curl -s --proxy http://vpn-server2:3128 http://internet-server:80/
```

## Expected Results

- **Direct access**: Shows client IP (172.20.0.5)
- **Server1 proxy**: Shows server1 IP (172.20.0.3)
- **Server2 proxy**: Shows server1 IP (172.20.0.3) because server2 forwards to server1

## Container Details

### Internet Server
- **Language**: Go
- **Port**: 80
- **Function**: Returns client IP information in JSON format
- **External access**: Available on localhost:8080

### Server1 (VPN Exit Point)
- **Proxy**: Squid on port 3128
- **Function**: Acts as the final proxy before reaching the internet
- **Configuration**: Allows all traffic, forwards client information

### Server2 (VPN Entry Point)
- **Proxy**: Squid on port 3128
- **Function**: Forwards all traffic to server1
- **Configuration**: Uses server1 as parent proxy

### Client
- **Base**: Alpine Linux
- **Tools**: curl, wget, netcat
- **Function**: Simulates a user wanting to browse the internet

## Network Configuration

- **Subnet**: 172.20.0.0/16
- **Internet Server**: 172.20.0.2
- **Server1**: 172.20.0.3
- **Server2**: 172.20.0.4
- **Client**: 172.20.0.5

## Files Structure

```
docker-vpn/
├── docker-compose.yml          # Main orchestration file
├── internet/
│   ├── Dockerfile
│   └── main.go                 # Go web server
├── server1/
│   ├── Dockerfile
│   └── squid.conf              # Squid configuration
├── server2/
│   ├── Dockerfile
│   └── squid.conf              # Squid configuration
├── client/
│   └── Dockerfile
├── test-setup.sh               # Test script
└── README.md                   # This file
```

## Security & Performance Notes

- Traffic is routed through multiple proxies to simulate real-world VPN behavior
- Squid proxy is configured for optimal performance
- All containers run in an isolated Docker network
- No caching is enabled for testing purposes

## Stopping the Experiment

```bash
docker-compose down
```

## Troubleshooting

- **Check container status**: `docker-compose ps`
- **View logs**: `docker logs <container-name>`
- **Access container shell**: `docker exec -it <container-name> sh`

---

## Production Deployment

### 🏗️ Deploy on Real Ubuntu Servers

For production deployment on actual Ubuntu servers, this repository includes automated packaging and deployment scripts.

#### Quick Production Setup

1. **Get the latest release packages:**
   ```bash
   # Download server1 package
   wget https://github.com/YOUR_USERNAME/YOUR_REPO/releases/latest/download/server1.zip
   
   # Download server2 package  
   wget https://github.com/YOUR_USERNAME/YOUR_REPO/releases/latest/download/server2.zip
   ```

2. **Install Server1 (Exit Point) first:**
   ```bash
   unzip server1.zip
   cd server1
   chmod +x install.sh
   sudo ./install.sh
   ```

3. **Install Server2 (Entry Point) second:**
   ```bash
   unzip server2.zip
   cd server2
   chmod +x install.sh
   sudo ./install.sh
   # Enter Server1 IP when prompted
   ```

#### Creating New Releases

To create a new release with installation packages:

1. **Create and push a version tag:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **GitHub Actions will automatically:**
   - Create a release
   - Package server1 and server2 into zip files
   - Upload installation packages as release assets
   - Generate deployment documentation

#### Manual Release

You can also trigger a release manually:
1. Go to **Actions** tab in GitHub
2. Select **Create VPN Server Release**
3. Click **Run workflow**

### 📦 What's Included in Releases

Each release contains:
- **server1.zip** - Complete installation package for VPN exit point
- **server2.zip** - Complete installation package for VPN entry point
- **README.md** - Detailed deployment instructions
- Installation scripts with automatic configuration
- Firewall setup and security hardening
- Service management and monitoring tools

### 🔧 Production Features

- **Automatic service startup** on boot
- **Firewall configuration** with UFW
- **Performance optimization** for production loads
- **Security hardening** with proper user isolation
- **Logging and monitoring** capabilities
- **Connection validation** between servers
- **Easy management commands** for operations

### 🧪 Testing Production Setup

After deployment, test the VPN chain:

```bash
# Test from any machine
curl --proxy SERVER2_IP:3128 https://httpbin.org/ip

# Should return Server1's IP address
```

### 🛡️ Security Considerations

- Servers run with minimal required permissions
- Firewall blocks all unnecessary ports
- Traffic logging for monitoring and debugging
- Secure inter-server communication
- Regular security updates recommended

### 📊 Monitoring

Monitor your VPN servers:

```bash
# Check service status
sudo systemctl status squid

# View real-time logs
sudo tail -f /var/log/squid/access.log

# Check connections
sudo netstat -tlnp | grep 3128
``` 